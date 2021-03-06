package starling.text.model.format;
import starling.text.BitmapFont;

/**
 * ...
 * @author P.J.Shand
 */
class Format
{
	public var size:Null<Float>;
	public var face:Null<String>;
	public var color:Null<UInt>;
	public var kerning:Null<Float>; // letter spacing
	public var leading:Null<Float>; // line spacing
	public var baseline:Null<Float>; // offset baseline
	public var textTransform:TextTransform;
	public var href:String;
	
	public function new(?face:String, ?size:Null<Int>, ?color:Null<UInt>, ?kerning:Null<Float>, ?leading:Null<Float>, ?textTransform:TextTransform, ?href:String) 
	{
		this.face = face;
		this.size = size;
		this.color = color;
		this.kerning = kerning;
		this.leading = leading;
		this.textTransform = textTransform;
		this.href = href;
	}
	
	public function toString():String
	{
		var returnVal:String = "";
		returnVal += "\nface = " + face + "\n";
		returnVal += "size = " + size + "\n";
		returnVal += "color = " + StringTools.hex(color, 6) + "\n";
		returnVal += "kerning = " + kerning + "\n";
		returnVal += "leading = " + leading + "\n";
		returnVal += "baseline = " + baseline + "\n";
		returnVal += "textTransform = " + textTransform + "\n";
		returnVal += "href = " + href + "\n";
		return returnVal;
	}
	
	public function clone():Format
	{
		var inputFormat = new Format();
		inputFormat.size = this.size;
		inputFormat.face = this.face;
		inputFormat.color = this.color;
		inputFormat.kerning = this.kerning;
		inputFormat.leading = this.leading;
		inputFormat.baseline = this.baseline;
		inputFormat.textTransform = this.textTransform;
		inputFormat.href = this.href;
		return inputFormat;
	}
	
	public function clear():Void
	{
		size = null;
		face = null;
		color = null;
		kerning = null;
		leading = null;
		baseline = null;
		textTransform = null;
		href = null;
	}
	
	
	public function isClear() 
	{
		return 
			size == null
		&&	face == null
		&&	color == null
		&&	kerning == null
		&&	leading == null
		&&	baseline == null
		&&	textTransform == null
		&&	href == null;
	}
}