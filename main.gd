extends Node3D

var xr_interface : OpenXRInterface

# Called when the node enters the scene tree for the first time.
func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		var vp = get_viewport()

		# Enable XR on the main viewport
		vp.use_xr = true

		# Make sure v-sync is disabled, we're using the headsets v-sync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		$XROrigin3D/HandJoints.set_xr_interface(xr_interface)

		xr_interface.play_area_changed.connect(_on_play_area_changed)
		xr_interface.pose_recentered.connect(_on_openxr_pose_recentered)
		print("OpenXR initialized successfully")
	else:
		print("OpenXR not initialized, please check if your headset is connected")


# this really hacky and is supposed to be called every frame
@onready var uninitialized_hmd_transform:Transform3D = XRServer.get_hmd_transform()
var hmd_synchronized = false
func sync_headset_orientation():
	"""
	Synchronizes headset ORIENTATION as soon as tracking information begins to arrive :
	"""
	if not hmd_synchronized:
		if uninitialized_hmd_transform != XRServer.get_hmd_transform():
			hmd_synchronized = true
			_on_openxr_pose_recentered()

func _on_openxr_pose_recentered() -> void:
	print("  _on_openxr_pose_recentered")
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	print("New reference frame!! ", XRServer.get_reference_frame())

func _on_play_area_changed(mode):
	print(" on_play_area_changed ", mode)



const joyvelocity = 1.1
func _process(delta):
	var joyleft = $XROrigin3D/XRController3DLeft.get_vector2("primary")
	var camerafore = Vector3($XROrigin3D/XRCamera3D.transform.basis.z.x, 0.0, $XROrigin3D/XRCamera3D.transform.basis.z.z).normalized()
	var cameraside = Vector3(camerafore.z, 0.0, -camerafore.x)
	$XROrigin3D.transform.origin += -camerafore*(joyleft.y*joyvelocity*delta) + cameraside*(joyleft.x*joyvelocity*delta)

var Dvr = true
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

#	if Dvr:
#		switch_to_ar()
#		Dvr = false
#	else:
#		switch_to_vr()
#		Dvr = true

	
@onready var viewport : Viewport = get_viewport()
@onready var environment : Environment = $WorldEnvironment.environment
func switch_to_ar() -> bool:
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			viewport.transparent_bg = true
		elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			viewport.transparent_bg = false
	else:
		return false

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	return true

func switch_to_vr() -> bool:
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_OPAQUE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		else:
			return false

	viewport.transparent_bg = false
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	return true
