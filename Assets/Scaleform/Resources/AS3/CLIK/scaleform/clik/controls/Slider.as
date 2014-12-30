﻿/**
*   The Slider displays a numerical value in range, with a thumb to represent the value, as well as modify it via dragging.
    <b>Inspectable Properties</b>
        The inspectable properties of the Slider component are:
        <ul>
            <li><i>enabled</i>: Disables the Slider if set to false.</li>
            <li><i>focusable</i>: By default, Slider can receive focus for user interactions. Setting this property to false will disable focus acquisition.</li>
            <li><i>value</i>: The numeric value displayed by the Slider.</li>
            <li><i>minimum</i>: The minimum value of the Slider’s range.</li>
            <li><i>maximum</i>: The maximum value of the Slider’s range.</li>
            <li><i>snapping</i>: If set to true, then the thumb will snap to values that are multiples of snapInterval.</li>
            <li><i>snapInterval</i>: The snapping interval which determines which multiples of values the thumb snaps to. It has no effect if snapping is set to false.</li>
            <li><i>liveDragging</i>: If set to true, then the Slider will generate a change event when dragging the thumb. If false, then the Slider will only generate a change event after the dragging is over.</li>
            <li><i>offsetLeft</i>: Left offset for the thumb. A positive value will push the thumb inward.</li>
            <li><i>offsetRight</i>: Right offset for the thumb. A positive value will push the thumb inward.</li>
            <li><i>visible</i>: Hides the component if set to false.</li>
        </ul>
    
    <b>States</b>
    Like the ScrollIndicator and the ScrollBar, the Slider does not have explicit states. It uses the states of its child elements, the thumb and track Button components.
    
    <b>Events</b>
    All event callbacks receive a single Event parameter that contains relevant information about the event. The following properties are common to all events. <ul>
    <li><i>type</i>: The event type.</li>
    <li><i>target</i>: The target that generated the event.</li></ul>
        
    The events generated by the Slider component are listed below. The properties listed next to the event are provided in addition to the common properties.
    <ul>
        <li><i>ComponentEvent.SHOW</i>: The visible property has been set to true at runtime.</li>
        <li><i>ComponentEvent.HIDE</i>: The visible property has been set to false at runtime.</li>
        <li><i>FocusHandlerEvent.FOCUS_IN</i>: The component has received focus.</li>
        <li><i>FocusHandlerEvent.FOCUS_OUT</i>: The component has lost focus.</li>
        <li><i>ComponentEvent.STATE_CHANGE</i>: The component's state has changed.</li>
        <li><i>SliderEvent.VALUE_CHANGE</i>: The value of the Slider has changed.</li>
    </ul>
*/

/**************************************************************************

Filename    :   Slider.as

Copyright   :   Copyright 2011 Autodesk, Inc. All Rights reserved.

Use of this software is subject to the terms of the Autodesk license
agreement provided at the time of installation or download, or which
otherwise accompanies this software in either electronic or hard copy form.

**************************************************************************/

package scaleform.clik.controls {
    
    import flash.display.DisplayObject;
    import flash.display.MovieClip;
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.geom.Point;
    
    import scaleform.gfx.FocusManager;
    import scaleform.gfx.MouseEventEx;
    
    import scaleform.clik.constants.ConstrainMode;
    import scaleform.clik.constants.InvalidationType;
    import scaleform.clik.core.UIComponent;
    import scaleform.clik.events.InputEvent;
    import scaleform.clik.events.ComponentEvent;
    import scaleform.clik.events.SliderEvent;
    import scaleform.clik.constants.ControllerType;
    import scaleform.clik.ui.InputDetails;
    import scaleform.clik.constants.InputValue;
    import scaleform.clik.constants.NavigationCode;
    import scaleform.clik.utils.Constraints;
    
    [Event(name = "change", type = "flash.events.Event")]
    
    public class Slider extends UIComponent {
        
    // Constants:
        
    // Public Properties:
        /** Determines if the Slider dispatches "change" events while dragging the thumb, or only after dragging is complete. */
        [Inspectable(defaultValue="true")]
        public var liveDragging:Boolean = true;
        /** The mouse state of the button.  Mouse states can be "default", "disabled". */
        public var state:String = "default";
        /** Left offset for the thumb. A positive value will push the thumb inward. */
        [Inspectable(defaultValue=0, verbose=1)]
        public var offsetLeft:Number = 0;
        /** Right offset for the thumb. A positive value will push the thumb inward. */
        [Inspectable(defaultValue=0, verbose=1)]
        public var offsetRight:Number = 0;
        
    // Private Properties:
        protected var _minimum:Number = 0;
        protected var _maximum:Number = 10;
        protected var _value:Number = 0;
        protected var _snapInterval:Number = 1;
        protected var _snapping:Boolean = false;
        protected var _dragOffset:Object;
        protected var _trackDragMouseIndex:Number;
        protected var _trackPressed:Boolean = false;
        protected var _thumbPressed:Boolean = false;
        
    // UI Elements:
        /** A reference to the thumb symbol in the Slider, used to display the slider {@code value}, and change the {@code value} via dragging. */
        public var thumb:Button;
        /** A reference to the track symbol in the Slider used to display the slider range, but also to jump to a specific value via clicking. */
        public var track:Button;
        
    // Initialization:
        public function Slider() {
            super();
        }
        
        override protected function preInitialize():void {
            constraints = new Constraints(this, ConstrainMode.REFLOW);
        }
        
        override protected function initialize():void {
            super.initialize();
            tabChildren = false;
            mouseEnabled = mouseChildren = enabled;
        }
        
    // Public getter / setters:
        [Inspectable(defaultValue="true")]
        override public function get enabled():Boolean { return super.enabled; }
        override public function set enabled(value:Boolean):void {
            if (value == super.enabled) { return; }
            super.enabled = value;
            thumb.enabled = track.enabled = value;
            // setState(defaultState);
        }
        
        /**
         * Enable/disable focus management for the component. Setting the focusable property to 
         * {@code focusable=false} will remove support for tab key, direction key and mouse
         * button based focus changes.
         */
        [Inspectable(defaultValue="true")]
        override public function get focusable():Boolean { return _focusable; }
        override public function set focusable(value:Boolean):void { 
            super.focusable = value;
            tabChildren = false;
        }
        
        /**
         * The value of the slider between the {@code minimum} and {@code maximum}.
         * @see #maximum
         * @see #minimum
         */
        [Inspectable(defaultValue="0")]
        public function get value():Number { return _value; }
        public function set value(value:Number):void {
            _value = lockValue(value);
            dispatchEventAndSound( new SliderEvent(SliderEvent.VALUE_CHANGE, false, true, _value) );
            draw();
        }
        
        /**
         * The maximum allowed value. The {@code value} property will always be less than or equal to the {@code maximum}. 
         */
        [Inspectable(defaultValue="10")]
        public function get maximum():Number { return _maximum; }
        public function set maximum(value:Number):void {
            _maximum = value;
        }
        
        /**
         * The minimum allowed value. The {@code value} property will always be greater than or equal to the {@code minimum}. 
         */
        [Inspectable(defaultValue="0")]
        public function get minimum():Number { return _minimum; }
        public function set minimum(value:Number):void {
            _minimum = value;
        }
        
        /**
         * The {@code value} of the {@code Slider}, to make it polymorphic with a {@link ScrollIndicator}.
         */
        public function get position():Number { return _value; }
        public function set position(value:Number):void { _value = value; }
        
        /**
         * Whether or not the {@code value} "snaps" to a rounded value. When {@code snapping} is {@code true}, the value can only be set to multiples of the {@code snapInterval}.
         * @see #snapInterval
         */
        [Inspectable(defaultValue="false")]
        public function get snapping():Boolean { return _snapping; }
        public function set snapping(value:Boolean):void {
            _snapping = value;
            invalidateSettings();
        }
        
        /**
         * The interval to snap to when {@code snapping} is {@code true}.
         * @see #snapping
         */
        [Inspectable(defaultValue="1")]
        public function get snapInterval():Number { return _snapInterval; }
        public function set snapInterval(value:Number):void {
            _snapInterval = value;
            invalidateSettings();
        }
        
    // Public Methods:
        /** 
         * Marks the settings of the Slider (max, mix, snapping, snap interval) as invalid. These settings will be updated on the next Stage.RENDER event. 
         */
        public function invalidateSettings():void {
            invalidate(InvalidationType.SETTINGS);
        }
        
        /** @exclude */
        override public function handleInput(event:InputEvent):void {
            if (event.isDefaultPrevented()) { return; }
            var details:InputDetails = event.details;
            var index:uint = details.controllerIndex;
            
            var keyPress:Boolean = (details.value == InputValue.KEY_DOWN || details.value == InputValue.KEY_HOLD);
            switch (details.navEquivalent) {
                    case NavigationCode.RIGHT:
                    if (keyPress) { 
                        value += _snapInterval;
                        event.handled = true;
                    }
                    break;
                case NavigationCode.LEFT:
                    if (keyPress) {
                        value -= _snapInterval;
                        event.handled = true;
                    }
                    break;
                
                case NavigationCode.HOME:
                    if (!keyPress) {
                        value = minimum;
                        event.handled = true;
                    }
                    break;
                case NavigationCode.END:
                    if (!keyPress) {
                        value = maximum;
                        event.handled = true;
                    }
                    break;
                default:
                    break;
            }
        }
        
        /** @exclude */
        override public function toString():String { 
            return "[CLIK Slider " + name + "]";
        }
        
    // Protected Methods:
        override protected function configUI():void {
            addEventListener(InputEvent.INPUT, handleInput, false, 0, true);
            
            thumb.addEventListener(MouseEvent.MOUSE_DOWN, beginDrag, false, 0, true);
            track.addEventListener(MouseEvent.MOUSE_DOWN, trackPress, false, 0, true);
            
            tabEnabled = true;
            thumb.focusTarget = track.focusTarget = this;
            thumb.enabled = track.enabled = enabled;
            
            thumb.lockDragStateChange = true;
            constraints.addElement("track", track, Constraints.LEFT | Constraints.RIGHT);
        }
        
        override protected function draw():void {
            if (isInvalid(InvalidationType.STATE)) {
                gotoAndPlay(!enabled ? "disabled" : (_focused ? "focused" : "default"));
            }
            
            // Resize and update constraints
            if (isInvalid(InvalidationType.SIZE)) {
                setActualSize(_width, _height);
                constraints.update(_width, _height);
            }
            
            updateThumb();
        }
        
        override protected function changeFocus():void {
            super.changeFocus();
            invalidateState();
            
            // NFM: Moved here from within draw().
            if (enabled) {
                if (!_thumbPressed) {
                    thumb.displayFocus = (_focused != 0);
                }
                if (!_trackPressed) {
                    track.displayFocus = (_focused != 0);
                }
            }
        }
        
        protected function updateThumb():void {
            if (!enabled) { return; }
            var trackWidth:Number = (_width - offsetLeft - offsetRight);
            thumb.x = ((_value - _minimum) / (_maximum - _minimum) * trackWidth) - thumb.width / 2 + offsetLeft;
        }
        
        protected function beginDrag(e:MouseEvent):void {
            _thumbPressed = true;
            
            var lp:Point = globalToLocal( new Point(e.stageX, e.stageY) );
            _dragOffset = { x: (lp.x - thumb.x) - thumb.width / 2 };
            
            stage.addEventListener(MouseEvent.MOUSE_MOVE, doDrag, false, 0, true);
            stage.addEventListener(MouseEvent.MOUSE_UP, endDrag, false, 0, true);
        }
        
        protected function doDrag(e:MouseEvent):void {
            var lp:Point = globalToLocal( new Point(e.stageX, e.stageY) );
            var thumbPosition:Number = lp.x - _dragOffset.x;
            var trackWidth:Number = (_width - offsetLeft - offsetRight);
            var newValue:Number = lockValue( (thumbPosition - offsetLeft) / trackWidth * (_maximum - _minimum) + _minimum );
            
            if (value == newValue) { return; }
            _value = newValue;
            
            updateThumb();
            
            if (liveDragging) {
                dispatchEventAndSound( new SliderEvent(SliderEvent.VALUE_CHANGE, false, true, _value) );
            }
        }
        
        protected function endDrag(e:MouseEvent):void {
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, doDrag, false);
            stage.removeEventListener(MouseEvent.MOUSE_UP, endDrag, false);
            
            if (!liveDragging) { 
                dispatchEventAndSound( new SliderEvent(SliderEvent.VALUE_CHANGE, false, true, _value) ); 
            }
            
            // If the thumb became draggable on a track press,
            // manually generate the thumb events.
            /* 
            if (trackDragMouseIndex != undefined) {
                if (!thumb.hitTest(_root._xmouse, _root._ymouse)) {
                    thumb.onReleaseOutside(trackDragMouseIndex);
                } else {
                    thumb.onRelease(trackDragMouseIndex);
                }
            }
            */
            
            _trackDragMouseIndex = undefined;
            _thumbPressed = false;
            _trackPressed = false;
        }
        
        protected function trackPress(e:MouseEvent):void {
            _trackPressed = true;
            
            track.focused = _focused;
            
            var trackWidth:Number = (_width - offsetLeft - offsetRight);
            var newValue:Number = lockValue( (e.localX * scaleX - offsetLeft) / trackWidth * (_maximum - _minimum) + _minimum);
            
            if (value == newValue) { return; }
            value = newValue;
            
            if (!liveDragging) { 
                dispatchEventAndSound( new SliderEvent(SliderEvent.VALUE_CHANGE, false, true, _value) );
            }
            
            // Pressing on the track moves the grip to the cursor and the thumb becomes draggable.
            _trackDragMouseIndex = 0 // e.mouseIdx; // @todo, NFM: This needs to use the multi-controller system.
            
            // thumb.onPress(trackDragMouseIndex);
            _dragOffset = {x:0};
        }
        
        // Ensure the value is in range and snap it to the snapInterval
        protected function lockValue( lvalue:Number ):Number {
            lvalue = Math.max(_minimum, Math.min(_maximum, lvalue));
            if (!snapping) { return lvalue; }
            var result:Number = Math.round(lvalue / snapInterval) * snapInterval;
            return result;
        }
        
        protected function scrollWheel(delta:Number):void {
            if (_focused) {
                value -= delta * _snapInterval;
                dispatchEventAndSound( new Event(Event.CHANGE) ); 
            }
        }
    }
}