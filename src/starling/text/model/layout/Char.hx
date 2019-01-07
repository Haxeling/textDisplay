package starling.text.model.layout;

import starling.text.BitmapChar;
import starling.text.BitmapFont;
import starling.text.model.format.InputFormat;



/**
 * ...
 * @author P.J.Shand
 */
class Char
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var width(get, null):Float = 0;
	public var height(get, null):Float = 0;
	public var lineNumber:Int = 0;
	public var charLinePositionX:Int = 0;
	
	public var character:String;
	public var id:Int = 0;
	public var index:Int = 0;
	public var line:Line;
	
	public var scale(get, null):Float;
	
	public var visible:Bool = true;
	
	@:allow(starling.text)
	private var isEndChar:Bool = false;
	
	@:allow(starling.text)
	private var isWhitespace:Bool = false;
	
	
	public var bitmapChar:BitmapChar;
	public var font:BitmapFont;
	public var format:InputFormat = new InputFormat();
	
	public function new(character:String, index:Int=0) 
	{
		if(character != null) init(character, index);
	}
	
	public function init(character:String, index:Int=0) 
	{
		this.id = character.charCodeAt(0);
		this.character = character;
		this.index = index;
		this.isWhitespace = (character == ' ' || character == '\r' || character == '\n'  || character == '\t');
	}
	
	
	public function clear() 
	{
		x = 0;
		y = 0;
		lineNumber = 0;
		charLinePositionX = 0;
		character = null;
		id = 0;
		index = 0;
		line = null;
		visible = true;
		isEndChar = false;
		bitmapChar = null;
		font = null;
		format.clear();
	}
	
	public function toString():String
	{
		return "(" + character + ", " + id + ", " + x + ")";
	}
	
	function get_width():Float 
	{
		if (bitmapChar == null) return 0;
		return return bitmapChar.width * scale;
	}
	
	function get_height():Float 
	{
		if (bitmapChar == null) return 0;
		return return bitmapChar.height * scale;
	}
	
	function get_scale():Float 
	{
		
		if (format.size == null){
			return 1;
		}else{
			return format.size / font.size;
		}
	}
	
	public function getLineHeight():Float 
	{
		if (font == null) return 0;
		return font.baseline * scale;
	}
}