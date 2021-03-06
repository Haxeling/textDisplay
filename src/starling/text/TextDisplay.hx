package starling.text;

import openfl.geom.Rectangle;
import starling.display.Border;
import starling.display.DisplayObjectContainer;
import starling.display.Quad;
import starling.events.Event;
import starling.events.TextDisplayEvent;
import starling.events.EventDispatcher;
import starling.text.TextFieldAutoSize;
import starling.text.control.focus.ClickFocus;
import starling.text.control.history.HistoryControl;
import starling.text.control.input.KeyboardInput;
import starling.text.control.input.KeyboardShortcuts;
import starling.text.control.input.MouseInput;
import starling.text.display.Caret;
import starling.text.display.ClipMask;
import starling.text.display.Highlight;
import starling.text.display.HitArea;
import starling.text.display.Links;
import starling.text.model.format.TextWrapping;
import starling.utils.SpecialChar;
import starling.utils.Updater;
import starling.text.control.input.EventForwarder;
import starling.text.control.input.SoftKeyboardIO;
import starling.text.control.BoundsControl;
import starling.text.model.content.ContentModel;
import starling.text.model.format.FormatModel;

import starling.text.model.layout.Alignment;
import starling.text.model.layout.CharLayout;
import starling.text.model.selection.Selection;
import starling.text.model.format.Format;
import starling.text.model.history.HistoryModel;
import starling.text.model.layout.Char;
import starling.text.util.CharRenderer;
import starling.text.util.FormatParser;

#if (starling >= "2.0.0")

#else
	import starling.utils.HAlign;
	import starling.utils.VAlign;
#end

/**
 * ...
 * @author P.J.Shand
 */
class TextDisplay extends DisplayObjectContainer
{
	static public var defaultSnapCharsTo:Float = 0;

    static var resizeEvent:Event;

	// DISPLAY
	@:allow(starling.text) var caret:Caret;
	@:allow(starling.text) var highlight:Highlight;
	@:allow(starling.text) var hitArea:HitArea;
	@:allow(starling.text) var clipMask:ClipMask;
	@:allow(starling.text) var links:Links;
	@:allow(starling.text) var boundsBorder:Border;
	@:allow(starling.text) var textBorder:Border;
	
	// MODEL
	@:allow(starling.text) var formatModel:FormatModel;
	@:allow(starling.text) var contentModel:ContentModel;
	@:allow(starling.text) var selection:Selection;
	@:allow(starling.text) var charLayout:CharLayout;
	@:allow(starling.text) var historyModel:HistoryModel;
	@:allow(starling.text) var alignment:Alignment;
	@:allow(starling.text) var boundsControl:BoundsControl;
	
	// UTILS
	@:allow(starling.text) var charRenderer:CharRenderer;
	
	// CONTROLLERS
	private var keyboardShortcuts:KeyboardShortcuts;
	private var keyboardInput:KeyboardInput;
	private var mouseInput:MouseInput;
	private var softKeyboardIO:SoftKeyboardIO;
	private var historyControl:HistoryControl;
	private var eventForwarder:EventForwarder;
	private var clickFocus:ClickFocus;
	
	@:isVar public var color(default, set):Null<UInt> = null;
	
	private var _value:String = "";
	@:allow(starling.text) var value(get, set):String;
	
	public var snapCharsTo(get, set):Float;
	
	// Needs testing after refactoring
	//@:isVar public var text(default, set):String;
	
	@:isVar public var text(get, set):String;
	@:isVar public var htmlText(get, set):String;
	@:isVar public var autoSize(default, set):String;
	@:isVar private var hasFocus(default, set):Bool = false;
	@:isVar public var editable(default, set):Bool = false;
	
	@:isVar public var showBoundsBorder(default, set):Bool = false;
	@:isVar public var showTextBorder(default, set):Bool = false;
	@:isVar public var debug(default, set):Bool = false;
	@:isVar public var clipOverflow(default, set):Bool = false;
	@:isVar public var textWrapping(default, set):TextWrapping = TextWrapping.WORD;
	@:isVar public var allowLineBreaks(default, set):Bool = true;

	@:isVar public var textureSmoothing(default, set):String; // Leave null to allow font to determine it's own smoothing
	
	@:allow(starling.text) var targetWidth:Null<Float>;
	@:allow(starling.text) var targetHeight:Null<Float>;
	@:allow(starling.text) var actualWidth:Null<Float>;
	@:allow(starling.text) var actualHeight:Null<Float>;
	
	@:allow(starling.text) var _textBounds = new Rectangle();
	
	public var defaultFormat(get, set):Format;
	
	public var textWidth(get, null):Float;
	public var textHeight(get, null):Float;
	public var textBounds(get, null):Rectangle;
    
	
	public var undoSteps(get, set):Int;
	public var clearUndoOnFocusLoss(get, set):Bool;
	
	public var highlightAlpha(get, set):Float;
	public var highlightColour(get, set):UInt;
	
	public var hAlign(get, set):String;
	public var vAlign(get, set):String;
	
	public var maxLines:Null<Int>;
	public var maxCharacters:Null<Int>;
	
	public var ellipsis:String = "...";
	
	var updater:Updater;
	
	@:isVar public var numLines(get, null):Int;
	
	@:isVar public static var focus(default, set):TextDisplay = null;
	static var focusDispatcher = new EventDispatcher();
	
	var editabilitySetup:Bool = false;
	
	public function new(width:Null<Float>=null, height:Null<Float>=null) 
	{
		super();
		
		updater = new Updater(update);
		
		if (height == null && width == null) autoSize = TextFieldAutoSize.BOTH_DIRECTIONS;
		else if (height == null) autoSize = TextFieldAutoSize.VERTICAL;
		else if (width == null) autoSize = TextFieldAutoSize.HORIZONTAL
		else autoSize = TextFieldAutoSize.NONE;
		
		targetWidth = width;
		targetHeight = height;
		actualWidth = width == null ? 100 : width;
		actualHeight = height == null ? 100 : height;
		
		createModels();
		createUtils();
		createDisplays();
		createListeners();
		
		hasFocus = false;
		this.width = width;
		this.height = height;
		
		this.snapCharsTo = defaultSnapCharsTo;
	}
	
	function createModels() 
	{
		formatModel = new FormatModel(this);
		contentModel = new ContentModel(this);
		charLayout = new CharLayout(this);
		selection = new Selection(this);
		historyModel = new HistoryModel(this);
		alignment = new Alignment(this);
		boundsControl = new BoundsControl(this);

        charLayout.boundsChanged.add(onBoundsChanged);
	}

    function onBoundsChanged(){
        if(hasEventListener(Event.RESIZE)){
            if(resizeEvent == null) resizeEvent = new Event(Event.RESIZE);
            dispatchEvent(resizeEvent);
        }
    }
	
	function createUtils() 
	{
		charRenderer = new CharRenderer(this);
	}
	
	function createDisplays() 
	{
		
		clipMask = new ClipMask(this);
		addChild(clipMask);
	}
	
	function createEditability() 
	{
		if (editabilitySetup) return;
		editabilitySetup = true;
		
		
		createHighlight();
		
		hitArea = new HitArea(this, width, height);
		addChild(hitArea);
	
		links = new Links(this);
		addChild(links);
	
		caret = new Caret(this);
		addChild(caret);
		
		softKeyboardIO = new SoftKeyboardIO(this);
		keyboardShortcuts = new KeyboardShortcuts(this);
		keyboardInput = new KeyboardInput(this);
		eventForwarder = new EventForwarder(this);
		mouseInput = new MouseInput(this);
		clickFocus = new ClickFocus(this);
	}
	
	
	function createListeners() 
	{
		selection.addEventListener(Event.SELECT, OnSelect);
	}
	
	// TODO: remove listeners on dispose
	//function removeListeners() 
	//{
	//	selection.removeEventListener(Event.SELECT, OnSelect);
	//}
	
	private function OnSelect(e:Event):Void 
	{
		dispatchEvent(e);
	}
	
	public function setSelectionFormat(format:Format):Void
	{
		var begin:Null<UInt> = selection.begin;
		var end:Null<UInt> = selection.end;
		if (begin != null && end != null) {
			setFormat(format, begin, end-1);
		}
		else {
			setFormat(format, selection.index, selection.index);
		}
	}
	
	public function setFormat(format:Format, begin:Null<Int>=null, end:Null<Int>=null) 
	{
		if (begin == null && end == null) formatModel.setDefaults(format);
		contentModel.setFormat(format, begin, end);
		FormatParser.mergeNodes(contentModel.nodes);
		markForUpdate();
		dispatchEvent(new Event(Event.CHANGE));
	}
	public function getFormat(begin:Int, end:Int):Format
	{
		return FormatParser.getFormat(this, contentModel.nodes, begin, end);
	}
	
	public function getSelectionFormat():Format
	{
		var begin:Null<Int> = null;
		var end:Null<Int> = null;
		
		if (selection.begin == null && selection.end == null) {
			begin = selection.index;
			end = begin;
		}
		else {
			begin = selection.begin;
			end = selection.end;
		}
		
		if (begin == null && end == null) {
			return formatModel.defaultFormat;
		}
		return {
			if (value.length == 0) return formatModel.defaultFormat;
			else return FormatParser.getFormat(this, contentModel.nodes, begin, end);
		}
	}
	
	public function getSelectedText() 
	{
		if (selection.begin != null && selection.end != null) {
			return value.substring(selection.begin, selection.end);
		}
		else {
			return "";
		}
	}
	
	function get_text():String 
	{
		if (value == "") return "";
		return FormatParser.nodesToPlainText(contentModel.nodes);
	}
	
	function set_text(v:String):String 
	{
		if (this.text == v) return v;
		if (v == null) v = "";
		//if (!allowLineBreaks) v = FormatParser.removeLineBreaks(v);
		
		if (maxCharacters != null) {
			if (v.length >= maxCharacters) v = v.substr(0, maxCharacters - ellipsis.length) + ellipsis;
		}
		FormatParser.recycleNodes(contentModel.nodes);
		contentModel.nodes = FormatParser.textAndFormatToNodes(v, defaultFormat.clone());
		this.value = FormatParser.nodesToPlainText(contentModel.nodes);
		selection.index = this.value.length;
		dispatchEvent(new Event(Event.CHANGE));
		return text;
	}
	
	private function get_htmlText():String 
	{
		if (value == "") return "";
		return FormatParser.nodesToHtml(contentModel.nodes);
	}
	
	private function set_htmlText(v:String):String 
	{
		if (v == null) v = "";
		//if (!allowLineBreaks) v = FormatParser.removeLineBreaks(v);
		else v = v.split("<BR/>").join("<br/>");
		
		FormatParser.recycleNodes(contentModel.nodes);
		contentModel.nodes = FormatParser.htmlToNodes(v);
		this.value = FormatParser.nodesToPlainText(contentModel.nodes);
		
		if (maxCharacters != null) {
			if (value.length >= maxCharacters) {
				FormatParser.removeAfterIndex(contentModel.nodes, maxCharacters - ellipsis.length);
				v = FormatParser.nodesToPlainText(contentModel.nodes) + ellipsis;
				
				FormatParser.recycleNodes(contentModel.nodes);
				contentModel.nodes = FormatParser.htmlToNodes(v);
				this.value = v;
			}
		}
		
		selection.index = this.value.length;
		dispatchEvent(new Event(Event.CHANGE));
		return htmlText;
	}
	
	private function get_value():String 
	{
		return _value;
	}
	
	private function set_value(v:String):String 
	{
		_value = v;
		selection.clear(true);
		createCharacters();
		if (_value.length > 0) selection.index = 0;
		else selection.clear();
		
		if(links != null){
			links.update();
		}
		
		return _value;
	}
	
	function createCharacters() 
	{
		contentModel.update();
		markForUpdate();
	}
	
	function set_hasFocus(value:Null<Bool>):Null<Bool> 
	{
		if (hasFocus == value) return value;
		hasFocus = value;
        //if(!value && selection!= null) selection.clear();
		dispatchEvent(new TextDisplayEvent(TextDisplayEvent.FOCUS_CHANGE));
		UpdateActive();
		return hasFocus;
	}
	
	@:allow(starling.text)
	private function clearSelected(offset:Int=0) 
	{
		if (selection.begin != null) {
			remove(selection.begin + offset, selection.end + offset);
		}
		else {
			remove(selection.index - 1 + offset, selection.index + offset);	
		}
	}
	
	
	private function remove(start:Int, end:Int):Void
	{
		if (start < 0) start = 0;
		if (end < 0) end = 0;
		
		var split:Array<String> = _value.split("");
		split.splice(start, end - start);
		_value = split.join("");
		contentModel.remove(start, end);
		FormatParser.removeEmptyNodes(contentModel.nodes);
		FormatParser.mergeNodes(contentModel.nodes);
		charLayout.remove(start, end);
		dispatchEvent(new Event(Event.CHANGE));
	}
	
	
	
	private function replaceSelection(newChars:String):Void 
	{
		if (selection.begin != null) {
			createKeyboardHistory();
			historyControl.setIgnoreChanges(true);
			clearSelected();
			historyControl.setIgnoreChanges(false);
		}
		
		if(selection.index == -1){
			add(newChars, 0);
			selection.index = newChars.length;
		}else{
			add(newChars, selection.index);
		}
	}
	
	private function add(letter:String, ?index:Int):Void
	{
		if (!allowLineBreaks && SpecialChar.isLineBreak(letter)) return;
		if (maxCharacters != null){
			if (_value.length >= maxCharacters) return;
		}

        if(index == null) index = _value.length;
		
		var newValue:String = _value;
		if (index == _value.length){
			newValue += letter;
		}else if (index == 0){
			newValue = letter + _value;
		}else{
			newValue = _value.substr(0, index) + letter + _value.substr(index);
		}
		_value = newValue;
		
		contentModel.insert(letter, index);
		FormatParser.removeEmptyNodes(contentModel.nodes);
		FormatParser.mergeNodes(contentModel.nodes);
		charLayout.add(letter, index);
		dispatchEvent(new Event(Event.CHANGE));
	}
	
	private function set_showBoundsBorder(value:Bool):Bool	{ return boundsControl.showBoundsBorder = value; }
	private function set_showTextBorder(value:Bool):Bool	{ return boundsControl.showTextBorder = value; }
	private function set_debug(value:Bool):Bool
	{
		debug = value;
		this.showBoundsBorder = value;
		this.showTextBorder = value;
		return value;
	}
	private function set_clipOverflow(value:Bool):Bool
	{
		clipOverflow = value;
		this.clipMask.updateMask();
		return value;
	}
	private function set_textWrapping(value:TextWrapping):TextWrapping
	{
		textWrapping = value;
		markForUpdate();
		return value;
	}
	private function set_allowLineBreaks(value:Bool):Bool
	{
		allowLineBreaks = value;
		markForUpdate();
		return value;
	}
	
	private function get_snapCharsTo():Float				{ return charLayout.snapCharsTo; }
	private function set_snapCharsTo(value:Float):Float		{ return charLayout.snapCharsTo = value; }
	
	private function get_vAlign():String					{ return alignment.vAlign; }
	private function set_vAlign(value:String):String		{ return alignment.vAlign = value; }
	private function get_hAlign():String					{ return alignment.hAlign; }
	private function set_hAlign(value:String):String		{ return alignment.hAlign = value; }
	
	private function get_highlightAlpha():Float				{ createHighlight(); return highlight.highlightAlpha; }
	private function set_highlightAlpha(value:Float):Float	{ createHighlight(); return highlight.highlightAlpha = value; }
	private function get_highlightColour():UInt				{ createHighlight(); return highlight.highlightColour; }
	private function set_highlightColour(value:UInt):UInt	{ createHighlight(); return highlight.highlightColour = value; }
	
	private function get_textHeight():Float 				{ triggerUpdate(); return _textBounds.height; }
	private function get_textWidth():Float 					{ triggerUpdate(); return _textBounds.width; }
	private function get_textBounds():Rectangle 			{ triggerUpdate(); return _textBounds; }
	
	
	override function get_height():Float { triggerUpdate(); return actualHeight; }
	override function set_height(value:Float):Float 
	{
		if (targetHeight == value) return value;
		targetHeight = value;
		markForUpdate();
		dispatchEvent(new TextDisplayEvent(TextDisplayEvent.SIZE_CHANGE));
		return value;
	}
	
	override function get_width():Float { triggerUpdate(); return actualWidth; }
	override function set_width(value:Float):Float 
	{
		if (targetWidth == value) return value;
		targetWidth = value;
		markForUpdate();
		dispatchEvent(new TextDisplayEvent(TextDisplayEvent.SIZE_CHANGE));
		return value;
	}
	
	function set_editable(value:Bool):Bool 
	{
		if (editable == value) return value;
		editable = value;
		UpdateActive();
		return editable;
	}
	
	function set_textureSmoothing(value:String):String 
	{
		if (textureSmoothing == value) return value;
		textureSmoothing = value;
		markForUpdate();
		return textureSmoothing;
	}
	
	@:allow(starling.text) function markForUpdate() updater.markForUpdate();
	@:allow(starling.text) function triggerUpdate(?force:Bool) updater.triggerUpdate(force);
	function update(){
		#if debug
		var startTime = openfl.Lib.getTimer();
		#end
		
		charLayout.doProcess();
		
		#if debug
		var dur = openfl.Lib.getTimer() - startTime;
		if (dur > 5){
			var v = StringTools.replace(StringTools.replace(_value, "\n", "\\n"), "\t", "\\t");
			trace("TextDisplay took long time to update: " + dur + "ms '" + (v.length > 33 ? v.substr(0, 30) + "..." : v) + "' (length: " + _value.length + ")");
		}
		#end
	}
	
	function UpdateActive() 
	{
		if (editable) {
			
			createEditability();
			
			eventForwarder.active = keyboardInput.active = keyboardShortcuts.active = caret.active = hasFocus;
			mouseInput.active = true;
			if (highlight != null) highlight.visible = true;
			if (historyControl != null) historyModel.active = hasFocus;
			
		}
		else {
			if(editabilitySetup){
				eventForwarder.active = false;
				keyboardInput.active = false;
				keyboardShortcuts.active = false;
				mouseInput.active = false;
				caret.active = false;
			}
			if (highlight != null) highlight.visible = false;
			if (historyControl != null) historyModel.active = false;
		}
	}
	
	function get_undoSteps():Int 
	{
		if (historyControl == null) return 0;
		return historyModel.undoSteps;
	}
	
	function set_undoSteps(value:Int):Int 
	{
		createKeyboardHistory();
		return historyModel.undoSteps = value;
	}
	
	function get_clearUndoOnFocusLoss():Bool 
	{
		if (historyControl == null) return false;
		return historyModel.clearUndoOnFocusLoss;
	}
	
	function set_clearUndoOnFocusLoss(value:Bool):Bool 
	{
		createKeyboardHistory();
		return historyModel.clearUndoOnFocusLoss = value;
	}
	
	function createKeyboardHistory() 
	{
		if (historyControl == null){
			historyControl = new HistoryControl(this);
			historyModel.active = hasFocus && editable;
		}
	}
	
	function createHighlight() 
	{
		if (highlight == null){
			highlight = new Highlight(this);
			addChildAt(highlight, 0);
			highlight.touchable = false;
			highlight.visible = hasFocus && editable;
		}
	}
	
	function set_autoSize(value:String):String 
	{
		if (autoSize == value) return value;
		autoSize = value;
		if(charLayout != null) markForUpdate();
		return value;
	}
	
	function get_defaultFormat():Format 
	{
		return formatModel.defaultFormat;
	}
	function set_defaultFormat(value:Format):Format 
	{
		if(value != null){
			formatModel.setDefaults(value);
			markForUpdate();
			dispatchEvent(new Event(Event.CHANGE));
		}
		return formatModel.defaultFormat;
	}
	
	
	
	override function dispose() 
	{
		if(TextDisplay.focus == this) TextDisplay.focus = null;

		super.dispose();
		charRenderer.dispose();
	}
	
	function get_numLines():Int 
	{
		return charLayout.lines.length;
	}
	
	static function set_focus(value:TextDisplay):TextDisplay 
	{
        if(focus == value) return value;

        var oldFocus:TextDisplay = focus;

		focus = value;
        if(oldFocus != null) oldFocus.hasFocus = false;
        if(focus != null) focus.hasFocus = true;
		TextDisplay.focusDispatcher.dispatchEvent(new TextDisplayEvent(TextDisplayEvent.FOCUS_CHANGE));
		return focus;
	}
	
	function set_color(value:Null<UInt>):Null<UInt> 
	{
		charRenderer.setColor(value);
		return color = value;
	}
}