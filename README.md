# Godot Auto Hand addon

Adds hand tracking to any godot-xr-tools based XR game by animating the 
fingers to fit with the hand assets and generating button controller 
events based on hand gestures.

Video: https://www.youtube.com/watch?v=RTVatH8KDVA&feature=youtu.be

## Installation

Clone the repo and copy the `addons/godot-xr-autohandtrack` folder into your project's `addons` folder.   
(May be added to the AssetLib later).

Demo is included in the top level, as well as a precompiled APK suitable for the Meta Quest.

## To Use

This addon automatically enables hand tracking on the hand models found in the 
[godot-xr-tools](https://github.com/GodotVR/godot-xr-tools) addon library.  
Simply instantiate an AutoHand scene under the XRController3Ds or the 
hand objects themselves and this library will take over the animation of 
the fingers when hand tracking is used.

This addon does not depend on `godot-xr-tools` since it uses only the OpenXR hand tracking 
API function calls made available in Godot4.2.
Tested on the Quest2 and Pico4.  **Don't forget to enable hand tracking 
when you export the project**.

## Hand finger animation

The three functions `get_hand_joint_position()`, `get_hand_joint_rotation()` 
and `get_hand_joint_flags()` in the [OpenXRInterface](https://docs.godotengine.org/en/latest/classes/class_openxrinterface.html) class 
provide the absolute space positions and rotations for 26 joints of each hand.  

Given the rest poses of the bones in the hands of the Godot-xr-toolkit 
we can calculate the new poses and scalings of each bone in order to force 
them to conform and fit to these joint locations.  Experimental options 
(*applymiddlefingerfix*, *coincidewristorknuckle*, etc) are available to help understand 
the factors that go into this calculation.

## Comparison to XRHandModifier3D

This library predates and replicates the hand tracking features implemented 
in Godot 4.3 that depend on an `XRNode3D` set to `user/hand_tracker/...` 
containing a special Z-aligned `Skeleton3D`  
containing an `XRHandModifier3D` node.
See the documentation [here](https://docs.godotengine.org/en/latest/tutorials/xr/openxr_hand_tracking.html)

There are differences, and demo project allows you to switch between these 
two implementations for comparison by touching the yellow sphere with your index fingers.  
XRHandModifier3D ignores bone lengths (the distance between the 
joints) and only the bone orientations are read and set, so your fingertips are 
mis-aligned if your hands don't match the base model's dimensions exactly.

## Hand action signals

Hand tracking can't do anything on its own without the capability to  
generate the equivalent of button presses and joystick motions from the 
finger gestures.

We have encoded several finger gestures to match controller button presses by 
creating a new [XRPositionalTracker](https://docs.godotengine.org/en/latest/classes/class_xrpositionaltracker.html) object and temporarily swapping it in on the 
[XRController3D](https://docs.godotengine.org/en/latest/classes/class_xrcontroller3d.html) node when hand tracking is active.  

These gestures simulate the full controller-button experience, including the touch, squeeze value 
and click.  This was necessary because the godot-xr-tools pickup feature ignores the 
`grip_click` signal and just relies on floating point `grip` value to determin if the 
player is squeezing the grip button.  

A panel in the demo example illustrates and animates all the incoming signals from the 
controllers or the hands.

The hand signal controls are:
	
* Pinch (tips of index and thumb close together) is mapped to the trigger.  The 
default controller's XRPositionalTracker maps this to a `select_button` signal, 
which is treated like a trigger click in some applications, but then you 
don't get any other signals.

* Grasp (a fist gesture where the position of the index finger is ignored) is 
mapped to the grip button.  The index finger is free to make the pinch gesture 
independently.  

* Joystick (palm up, thumb touches tips of middle and ring fingers, then 
move side to side or forward and back.  Circles will appear to illustate 
the extent of the area for the joystick's motion.

* AX and BY buttons (same as joystick, but move up or down beyond the discs)
These are reversed by default as they appear on the controllers due to the 
convention of using the A button for jumping up.

* Stick click.  We don't have a gesture for this.  Possibly curling the little finger.

The aim [XRPose](https://docs.godotengine.org/en/latest/classes/class_xrpose.html) is copied 
across from the controller output to the hand output instead of using something 
derived from the hand-positions.  This is why there is a mismatch which you can see 
by the filtering applied to the aim pose to stabilize it.

## Demo

A demo suitable for the Meta Quest is available at: https://github.com/Godot-Dojo/Godot-XR-AH/releases/tag/v0.9

![image](https://github.com/Godot-Dojo/Godot-XR-AH/assets/677254/ddaff4ac-56b6-4530-a00a-f2e446b46d67)

