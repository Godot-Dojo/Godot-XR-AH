# Godot XR Auto Hand addon

Use this addon for hand tracking that is automatically compatible with XRControllers and creates button and thumbstick events from hand gestures.

Video: https://www.youtube.com/watch?v=RTVatH8KDVA&feature=youtu.be

## To Use

Simply instantiate `auto_handtracker.tscn` under each `XRController3D` beside your chosen hand model from the [godot-xr-tools](https://github.com/GodotVR/godot-xr-tools) addon library

The controls are:

* **Trigger Button** - Index and thumb facing forward and pinch.  The default controller's XRPositionalTracker maps this to a `select_button` signal, which is treated the same in some applications.

* **Grip Button** - Make a fist using the middle, ring and little fingers.  The index finger is ignored so it is free to make a pinch gesture independently.  

* **Thumbstick** - Palm upwards with thumb, middle and ring fingers close together, then move this in a horizontal plane.  Circles appear to illustate the extent of the area for the joystick's motion.

* **AX and BY Buttons** - Same as thumbstick but up and down, this way round because the AX is often use for jump.

* **Stick click** - Not yet supported.

## Demo project

The project in the top level of the repo provides a panel with each of the 

![image](https://github.com/Godot-Dojo/Godot-XR-AH/assets/677254/ddaff4ac-56b6-4530-a00a-f2e446b46d67)

A precompiled APK suitable for the Meta Quest is available here.

## How it works

The `XRServer` has a number of `XRTrackers` registered to it.  If the XR interface is running each `XRController3D` is associated to a `XRControllerTracker` either called "left_hand" or "right_hand".  

If hand tracking is enabled and working there will also be `XRHandTracker` objects called "/user/hand_tracker/left" and "/user/hand_tracker/right" in the `XRServer`.  These have the function `get_hand_joint_transform(j)` which returns the position of any of the 26 joints in each hand.  This is sufficient to map the position and skeleton bone orientations of a hand model to conform with these positions.

To operate the controller buttons with hand gestures there are two new `XRPositionalTracker` objects called "left_autohand" and "right_autohand" added to the `XRServer` which are operated in software according to the positions detected by particular hand joint positions.

## 

See the documentation [here](https://docs.godotengine.org/en/latest/tutorials/xr/openxr_hand_tracking.html)


This addon automatically enables hand tracking on the hand models found in the either 
[godot-xr-tools](https://github.com/GodotVR/godot-xr-tools) addon library.  
Simply instantiate an AutoHand scene under the XRController3Ds or the 
hand objects themselves and this library will take over the animation of 
the fingers when hand tracking is used.

This addon does not depend on `godot-xr-tools` since it uses only the OpenXR hand tracking 
API function calls made available in Godot4.2.
Tested on the Quest2 and Pico4.  **Don't forget to enable hand tracking 
when you export the project**.


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


The aim [XRPose](https://docs.godotengine.org/en/latest/classes/class_xrpose.html) is copied 
across from the controller output to the hand output instead of using something 
derived from the hand-positions.  This is why there is a mismatch which you can see 
by the filtering applied to the aim pose to stabilize it.
