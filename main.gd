extends Node3D

var xr_interface : OpenXRInterface

# Called when the node enters the scene tree for the first time.
func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		var vp = get_viewport()

		# Enable XR on the main viewport
		vp.use_xr = true

		# Make sure v-sync is disabled, we're using the headsets v-sync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		$XROrigin3D/HandJoints.set_xr_interface(xr_interface)


const joyvelocity = 1.1
func _process(delta):
	var joyleft = $XROrigin3D/XRController3DLeft.get_vector2("primary")
	var camerafore = Vector3($XROrigin3D/XRCamera3D.transform.basis.z.x, 0.0, $XROrigin3D/XRCamera3D.transform.basis.z.z).normalized()
	var cameraside = Vector3(camerafore.z, 0.0, -camerafore.x)
	$XROrigin3D.transform.origin += -camerafore*(joyleft.y*joyvelocity*delta) + cameraside*(joyleft.x*joyvelocity*delta)

func triggerfingerbutton(hand):
	var handname = "Left" if hand == 0 else "Right"
	var displayoption = get_node("XROrigin3D/HandJoints/FrontOfPlayer/FlatDisplayMesh/SubViewport/FlatDisplay/HandDisplay%d" % hand)
	displayoption.selected = displayoption.selected + 1 if displayoption.selected < displayoption.item_count - 1 else 0
	var triggermode = displayoption.get_item_text(displayoption.selected)
	if triggermode == "XR":
		get_node("XROrigin3D/"+handname+"TrackedHand").visible = true
		get_node("XROrigin3D/"+handname+"TrackedHand").show_when_tracked = true
		get_node("XROrigin3D/XRController3D"+handname).visible = false
		get_node("XROrigin3D/XRController3D"+handname+"/AutoHandtracker").set_process(false)
	elif triggermode == "AH":
		get_node("XROrigin3D/"+handname+"TrackedHand").show_when_tracked = false
		get_node("XROrigin3D/"+handname+"TrackedHand").visible = false
		get_node("XROrigin3D/XRController3D"+handname).visible = true
		get_node("XROrigin3D/XRController3D"+handname+"/AutoHandtracker").set_process(true)
	get_node("XROrigin3D/XRController3D"+handname).trigger_haptic_pulse("haptic", 0, 1.0, 0.25, 0)
	
