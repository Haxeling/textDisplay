package starling.text.model.layout;

import openfl.geom.Point;
import openfl.geom.Rectangle;
import starling.text.BitmapFont;
import starling.text.model.format.InputFormat;
import starling.text.model.format.TextWrapping;
import starling.text.model.layout.Char;
import starling.text.model.layout.Line;
import starling.text.model.selection.Selection;
import starling.text.model.layout.Word;
import starling.display.Quad;
import starling.events.Event;
import starling.events.EventDispatcher;
import starling.text.BitmapChar;
import starling.text.TextDisplay;
import starling.text.util.CharacterHelper;
import starling.utils.SpecialChar;

/*#if starling2
	import starling.utils.Align;
#else*/
	import starling.utils.HAlign;
	import starling.utils.VAlign;
//#end

import starling.text.TextFieldAutoSize;

/**
 * ...
 * @author P.J.Shand
 */
class CharLayout extends EventDispatcher
{
	private var lineNumber:Int;
	private var placement:Point;
	private var words:Array<Word>;
	private var charLinePositionX:Int;
	private var textDisplay:TextDisplay;
	private var _endChar:EndChar;
	private var endChar(get, null):EndChar;
	private var changeEvent:Event;
	private var resizeEvent:Event;
	var wordBreakFound:Bool;
	var limitReached:Bool;
	
	var defaultChar:Char;
	
	public var characters = new Array<Char>();
	public var allCharacters:Array<Char>;
	public var lines = new Array<Line>();
	public var textWrapping:TextWrapping = TextWrapping.WORD;
	
	@:allow(starling.text)
	private function new(textDisplay:TextDisplay) 
	{
		super();
		this.textDisplay = textDisplay;
		
		_endChar = new EndChar("", 0, textDisplay);
		_endChar.isEndChar = true;
		allCharacters = [_endChar];
		
		defaultChar = new Char(null, 0);
		
		resizeEvent = new Event(Event.RESIZE);
		changeEvent = new Event(Event.CHANGE);
	}
	
	public function doProcess() 
	{
		this.characters = textDisplay.contentModel.characters;
		this.allCharacters = characters.concat([_endChar]);
		
		var iformat:InputFormat = textDisplay.defaultFormat;
		CharacterHelper.updateCharFormat(textDisplay.defaultFormat, defaultChar, textDisplay.formatModel.defaultFont);
		
		setPlacementX();
		findWords();
		findLineHeight();
		//findLinePositions();
		setLinePositions();
		
		var sizeChange = calcTextSize();
		this.dispatchEvent(resizeEvent);
		align();
		
		textDisplay._textBounds.x = Math.POSITIVE_INFINITY;
		if (lines.length > 0) textDisplay._textBounds.y = lines[0].y;
		for (i in 0...lines.length) 
		{
			if (textDisplay._textBounds.x > lines[i].x) textDisplay._textBounds.x = lines[i].x;
		}
		if (textDisplay._textBounds.x == Math.POSITIVE_INFINITY) {
			textDisplay._textBounds.x = 0;
		}
		
		
		if (textDisplay.autoSize == TextFieldAutoSize.NONE) {
			textDisplay.actualWidth = textDisplay.targetWidth;
			textDisplay.actualHeight = textDisplay.targetHeight;
		}
		else if (textDisplay.autoSize == TextFieldAutoSize.BOTH_DIRECTIONS) {
			textDisplay.actualWidth = textDisplay.textWidth;
			textDisplay.actualHeight = textDisplay.textHeight;
		}
		else if (textDisplay.autoSize == TextFieldAutoSize.HORIZONTAL) {
			textDisplay.actualWidth = textDisplay.textWidth;
			textDisplay.actualHeight = textDisplay.targetHeight;
		}
		else if (textDisplay.autoSize == TextFieldAutoSize.VERTICAL) {
			textDisplay.actualWidth = textDisplay.targetWidth;
			textDisplay.actualHeight = textDisplay.textHeight;
		}
		
		this.dispatchEvent(changeEvent);
		if (sizeChange && textDisplay.hasEventListener(Event.RESIZE)){
			textDisplay.dispatchEvent(resizeEvent);
		}
	}
	
	public function getChar(index:Int):Char
	{
		if (index >= characters.length) return null;
		return characters[index];
	}
	
	public function getCharOrEnd(index:Int):Char
	{
		if (index >= characters.length) return endChar;
		return characters[index];
	}
	
	public function getWordByPosition(_x:Float, _y:Float):Word
	{
		var char:Char = getCharByPosition(_x, _y, false);
		if (char == null || words == null) return null;
		
		for (word in words) 
		{
			if (word == null) continue;
			if (word.containsIndex(char.index)) {
				return word;
			}
		}
		return null;
	}
	
	public function getCharByPosition(_x:Float, _y:Float, allowEndChar:Bool=true):Char
	{
		var closestIndex:Int = -1;
		var closestValue:Float = Math.POSITIVE_INFINITY;
		
		for (i in 0...lines.length) 
		{
			var top:Float = lines[i].y;
			var bottom:Float = lines[i].y + lines[i].height;
			if (_y > top && _y < bottom) {
				closestIndex = i;
				break;
			}
			else {
				var dif:Float = Math.abs(lines[i].y - _y);
				if (Math.abs(dif) < closestValue) {
					closestValue = dif;
					closestIndex = i;
				}
				else {
					break; // closest found and now moving away from closest line
				}
			}	
		}
		if (closestIndex == -1){
			return null;
		}
		return getCharByLineAndPosX(closestIndex, _x, allowEndChar);
	}
	
	public function getCharByLineAndPosX(lineNumber:Int, _x:Float, allowEndChar:Bool=true):Char
	{
		var closestChar:Char = null;
		var closestValue:Float = Math.POSITIVE_INFINITY;
		
		if (lineNumber > lines.length - 1) lineNumber = lines.length - 1;
		if (lineNumber < 0) lineNumber = 0;
		
		var line:Line = lines[lineNumber];
		
		for(char in line.chars){
			var dif:Float = Math.abs(char.x - _x);
			if (dif < closestValue) {
				closestValue = dif;
				closestChar = char;
			}
		}
		var endChar = this.endChar; // calling getter validates endChar
		return (allowEndChar || closestChar!=endChar ? closestChar : null);
	}
	
	public function getLine(index:Int):Line
	{
		return lines[index];
	}
	
	public function remove(start:Int, end:Int):Void
	{
		characters.splice(start, end - start);
		for (i in start...characters.length) 
		{
			characters[i].index -= end - start;
		}
		textDisplay.triggerUpdate(true);
		textDisplay.selection.index = start; // Must set index after updating text otherwise HistoryControl will modify previous HistoryStep
	}
	
	public function add(newStr:String, index:Int):Void
	{
		var format:InputFormat = textDisplay.formatModel.defaultFormat;
		var font:BitmapFont = textDisplay.formatModel.defaultFont;
		
		if (textDisplay.caret != null && textDisplay.caret.format != null){
			format = textDisplay.caret.format.clone();
			font = textDisplay.caret.font;
		}
		
		var newStrSplit:Array<String> = newStr.split("");
		for (j in 0...newStrSplit.length) 
		{
			var _index:Int = index + j;
			characters.insert(_index, new Char(newStrSplit[j], _index));
		}
		//characters.insert(index, new Char(newStr, index));
		for (i in (index + newStrSplit.length)...characters.length) 
		{
			characters[i].index += newStrSplit.length;
		}
		textDisplay.triggerUpdate(true);
		textDisplay.selection.index += newStrSplit.length;
	}
	
	function setPlacementX() 
	{
		placement = new Point(0, 0);
		lineNumber = 0;
		
		var lastSpaceIndex:Int = 0;
		charLinePositionX = 0;
		
		var i:Int = 0;
		var goBack:Bool = false;
		limitReached = false;
		
		var lastChar:Char = null;
		var hasWrap:Bool = (textWrapping != TextWrapping.NONE);
		
		while (i < allCharacters.length) 
		{
			goBack = false;
			var char:Char = allCharacters[i];
			if (char.isEndChar && lastChar != null){
				char.font = lastChar.font;
				char.format = lastChar.format;
			}else{
				CharacterHelper.findCharFormat(textDisplay, char, textDisplay.contentModel.nodes);
				CharacterHelper.findBitmapChar(char);
			}
			
			if (!textDisplay.allowLineBreaks && (char.character == SpecialChar.Return || char.character == SpecialChar.NewLine)) {
				i++;
				continue;
			}
			
			if (char.character == SpecialChar.Space) {
				lastSpaceIndex = i;
				wordBreakFound = true;
			}
			
			if (withinBoundsX(placement.x + char.width) == false && i < allCharacters.length-1 && char.character != SpecialChar.Space && hasWrap) {
				
				if (lastSpaceIndex != i && wordBreakFound) {
					var lastSpaceChar:Char = allCharacters[lastSpaceIndex];
					if (lastSpaceChar.lineNumber == lineNumber) {
						i = lastSpaceIndex+1;
						goBack = true;
					}
				}
				progressLine();
				if (goBack) {
					var backChar:Char = allCharacters[i];
					continue;
				}
			}
			
			char.x = placement.x;
			if (limitReached) char.visible = false;
			else char.visible = true;
			
			if (char.bitmapChar != null) char.x += char.bitmapChar.xOffset * char.scale;
			
			char.lineNumber = lineNumber;
			char.charLinePositionX = charLinePositionX;
			charLinePositionX++;
			
			if (char.character != SpecialChar.Space || charLinePositionX != 0) {
				if (char.bitmapChar != null) {
					placement.x += (char.bitmapChar.xAdvance * char.scale);
					if (char.format.kerning != null) {
						placement.x += char.format.kerning;
					}
				}
			}
			
			if (withinBoundsX(placement.x) == false && i < allCharacters.length-2 && char.character != SpecialChar.Space && hasWrap) {
				if (lastSpaceIndex != i && wordBreakFound) {
					var lastSpaceChar:Char = allCharacters[lastSpaceIndex];
					if (lastSpaceChar.lineNumber == lineNumber) {
						i = lastSpaceIndex + 1;
						goBack = true;
					}
				}
				progressLine();
				if (goBack) {
					var backChar:Char = allCharacters[i];
					continue;
				}
			}
			else if (char.character == SpecialChar.Return) {
				progressLine();
			}
			else if (char.character == SpecialChar.NewLine) {
				if(lastChar == null || lastChar.character != SpecialChar.Return){
					// The sequence '\r\n' should only be rendered as a single line break
					progressLine();
				}
			}
			lastChar = char;
			i++;
		}
	}
	
	function findWords() 
	{
		words = new Array<Word>();
		
		var t:Int = -1;
		var lt:Int = -1;
		var word:Word = null;
		for (i in 0...allCharacters.length) 
		{
			var char:Char = allCharacters[i];
			if (char.character == SpecialChar.Space) t = 0;
			else if (char.character == SpecialChar.Tab) t = 1;
			else if (char.character == SpecialChar.NewLine) t = 2;
			else if (char.character == SpecialChar.Return) t = 3;
			else t = 4;
			if (lt != t) {
				word = new Word();
				word.index = words.length;
				words.push(word);
			}
			word.characters.push(char);
			lt = t;
		}
	}
	
	function findLineHeight() 
	{
		lines = new Array<Line>();
		
		var rise:Float = Math.NaN;
		var fall:Float = Math.NaN;
		var leading:Float = Math.NaN;
		var top:Float = Math.NaN;
		var bottom:Float = Math.NaN;
		
		var line:Line = null;
		var lineStack:Float = 0;
		var lastFont:BitmapFont = null;
		for (i in 0...allCharacters.length) {
			var char:Char = allCharacters[i];
			if (char.lineNumber >= lines.length) {
				if (line != null){
					lineStack = finishLine(line, rise, fall, leading, lineStack, top, bottom, lines.length == 1, false);
				}
				
				line = new Line();
				line.index = lines.length;
				lines.push(line);
				rise = Math.NaN;
				fall = Math.NaN;
				leading = Math.NaN;
				top = Math.NaN;
				bottom = Math.NaN;
				lastFont = null;
			}
			char.line = line;
			if (char.font != lastFont){
				var scale = char.scale;
				
				var charRise = char.font.baseline * scale;
				var charFall = (char.font.lineHeight - char.font.baseline) * scale;
				var charLeading = char.format.leading;
				
				if (Math.isNaN(rise)){
					rise = charRise;
					fall = charFall;
					leading = charLeading;
				}else{
					if (rise < charRise) rise = charRise;
					if (fall < charFall) fall = charFall;
					if (leading < charLeading) leading = charLeading;
				}
				lastFont = char.font;
			}
			
			if (char.bitmapChar != null && !char.isEndChar && !char.isWhitespace){
				var charTop:Float = (char.bitmapChar.yOffset * char.scale);
				var charBottom:Float = ((char.bitmapChar.yOffset + char.bitmapChar.height) * char.scale);
					
				if (Math.isNaN(top)){
					top = charTop;
					bottom = charBottom;
				}else{
					if (top > charTop) top = charTop;
					if (bottom < charBottom) bottom = charBottom;
				}
			}
			
			line.chars.push(char);
		}
		if (line != null){
			finishLine(line, rise, fall, leading, lineStack, top, bottom, lines.length == 1, true);
		}
	}
	
	function finishLine(line:Line, rise:Float, fall:Float, leading:Float, lineStack:Float, top:Float, bottom:Float, first:Bool, last:Bool) : Float 
	{
		lineStack += leading;
		
		var paddingTop:Float = (Math.isNaN(top) ? 0 : top);
		var paddingBottom:Float = (Math.isNaN(bottom) ? 0 : (rise + fall) - bottom);
		
		line.setMetrics(rise, fall, leading, paddingTop, paddingBottom);
		line.y = lineStack;
		
		lineStack += line.height;
		return lineStack;
	}
	
	function setLinePositions() 
	{
		for (i in 0...allCharacters.length) 
		{
			var char:Char = allCharacters[i];
			if (char.font == null) continue;
			
			var scale = char.scale;
			
			char.y = char.line.y + char.line.rise;
			char.y -= char.font.baseline * scale;
			if (char.format.baseline != null) char.y += char.format.baseline;
			
			if (char.bitmapChar != null) char.y += char.bitmapChar.yOffset * scale;
		}
	}
	
	function calcTextSize() : Bool
	{
		var boundsX:Float = 0;
		var boundsY:Float = 0;
		var boundsW:Float = 0;
		var boundsH:Float = 0;
		
		for (i in 0...lines.length) 
		{
			var line = lines[i];
			if (boundsW < line.width) {
				boundsW = line.width;
			}
		}
		
		if (lines.length > 0) {
			var firstLine = lines[0];
			var lastLine = lines[lines.length-1];
			boundsX = firstLine.x;
			boundsY = firstLine.y + firstLine.paddingTop;// + firstLine.rise - firstLine.top;
			boundsH = (lastLine.y + lastLine.height - lastLine.paddingBottom) - boundsY;
		}
		
		var hasChanged:Bool = true;
		if (textDisplay._textBounds.width == boundsW && textDisplay._textBounds.height == boundsH) hasChanged = false;
		textDisplay._textBounds.setTo(boundsX, boundsY, boundsW, boundsH);
		return hasChanged;
	}
	
	function align() 
	{
		var textY:Float = textDisplay._textBounds.y;
		var textHeight:Float = textDisplay._textBounds.height;
		
		var alignOffsetY:Float = -textY;
		if (textDisplay.targetHeight != null){
			if (textDisplay.vAlign == VAlign.CENTER){
				alignOffsetY += (textDisplay.targetHeight - textHeight) / 2;
			}
			else if (textDisplay.vAlign == VAlign.BOTTOM) {
				alignOffsetY += textDisplay.targetHeight - textHeight;
			}
		}
		//alignOffsetY -= lines[0].leading;
		
		var widestLine:Float = 0;
		for (i in 0 ... lines.length) 
		{
			var line = lines[i];
			if (widestLine< line.width) {
				widestLine = line.width;
			}
		}
		
		var targetWidth:Float = (textDisplay.autoSize == TextFieldAutoSize.HORIZONTAL || textDisplay.autoSize == TextFieldAutoSize.BOTH_DIRECTIONS ? textDisplay.textWidth : textDisplay.targetWidth);
		
		for (i in 0 ... lines.length) 
		{
			var line = lines[i];
			var lineOffset:Float = 0;
			
			
			if (textDisplay.hAlign == HAlign.LEFT) lineOffset = 0;
			else if (textDisplay.hAlign == HAlign.CENTER) {
				lineOffset = (targetWidth - line.width) / 2;
			}
			else if (textDisplay.hAlign == HAlign.RIGHT || textDisplay.hAlign == HAlign.JUSTIFY) {
				lineOffset = targetWidth - line.width;
			}
			
			if (textDisplay.hAlign == HAlign.JUSTIFY){
				//line.width += lineOffset;
			}else{
				line.x += lineOffset;
			}
			line.y += alignOffsetY;
			
			/*if (textDisplay.vAlign == VAlign.TOP) {
				line.y -= line.rise;
			}
			else if (textDisplay.vAlign == VAlign.CENTER) {
				line.y -= (line.largestChar.font.lineHeight - line.largestChar.font.baseline) * line.largestChar.scale * 0.5;
			}
			else if (textDisplay.vAlign == VAlign.BOTTOM) {
				// Do nothing
			}*/
			
			var first = true;
			var t:Float = 0;
			for (char in line.chars) 
			{
				if (textDisplay.hAlign == HAlign.JUSTIFY) {
					if (line.validJustify && char.lineNumber < lines.length - 1) {	
						var t:Float = char.charLinePositionX / (line.chars.length-2);
						char.x += lineOffset * t;
					}
				}
				else char.x += lineOffset;
				
				char.y += alignOffsetY;
			}
		}
	}
	
	private function progressLine():Void
	{
		wordBreakFound = false;	
		charLinePositionX = 0;
		placement.x = 0;
		lineNumber++;
		if (!textDisplay.allowLineBreaks) {
			limitReached = true;
		}
	}
	
	function withinBoundsX(value:Float):Bool
	{
		if (textDisplay.autoSize == TextFieldAutoSize.HORIZONTAL || textDisplay.autoSize == TextFieldAutoSize.BOTH_DIRECTIONS)
			return true;
		else if (value < textDisplay.targetWidth) return true;
		return false;
	}
	
	function withinBoundsY(value:Float):Bool
	{
		if (textDisplay.autoSize == TextFieldAutoSize.VERTICAL || textDisplay.autoSize == TextFieldAutoSize.BOTH_DIRECTIONS)
			return true;
		else if (value < textDisplay.targetHeight) return true;
		return false;
	}
	
	function get_endChar():EndChar 
	{
		if (characters.length > 0){
			var char:Char = characters[characters.length - 1];
			_endChar.font = char.font;
			_endChar.format = char.format;
		}else{
			_endChar.font = defaultChar.font;
			_endChar.format = defaultChar.format;
		}
		_endChar.index = characters.length;
		return _endChar;
	}
}