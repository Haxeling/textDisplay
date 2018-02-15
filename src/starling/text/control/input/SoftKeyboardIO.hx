package starling.text.control.input;

import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import starling.core.Starling;
import starling.events.Event;
import starling.text.TextDisplay;

/**
 * ...
 * @author P.J.Shand
 */
@:access(starling.text)
class SoftKeyboardIO
{
	@:isVar public var active(get, set):Bool = true;
	private var textDisplay:TextDisplay;
	private static var nativeTextField:TextField;

	@:allow(starling.text)
	private function new(textDisplay:TextDisplay)
	{
		this.textDisplay = textDisplay;
		
		if(nativeTextField == null){
			nativeTextField = new TextField();
			nativeTextField.y = -1000000; // place off stage
			nativeTextField.type = TextFieldType.INPUT;
			nativeTextField.needsSoftKeyboard = active;
			Starling.current.nativeStage.addChild(nativeTextField);
		}
		
		textDisplay.addEventListener(starling.events.Event.FOCUS_CHANGE, OnFocusChange);
	}
	
	private function OnFocusChange(e:starling.events.Event):Void 
	{
		if (!active) return;
		if (textDisplay.hasFocus) {
			//nativeTextField.text = "";
			nativeTextField.requestSoftKeyboard();
		}
	}
	
	function get_active():Bool 
	{
		return active;
	}
	
	function set_active(value:Bool):Bool 
	{
		if (nativeTextField == null) {
			nativeTextField.needsSoftKeyboard = value;
		}
		return active = value;
	}
}