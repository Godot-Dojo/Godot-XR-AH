extends Node3D

var xr_interface : OpenXRInterface

var facetracker : XRFaceTracker = null
func Dtracker_added(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		var anchortracker : XRPositionalTracker= XRServer.get_tracker(tracker_name)
		var pp = anchortracker.get_pose("default")
		prints("anchor_tracker_added", tracker_name, anchortracker)
		var aa = load("res://scenemanager/xr_anchor_3d.tscn").instantiate()
		aa.tracker = tracker_name
		$XROrigin3D.add_child(aa)
		
	elif type == XRServer.TRACKER_FACE:
		facetracker = XRServer.get_tracker(tracker_name)
		print("***** facetracker added ", tracker_name, facetracker)
	elif type == XRServer.TRACKER_CONTROLLER:
		prints("controller tracker added", tracker_name, type)
	elif type == XRServer.TRACKER_BODY:
		prints("body tracker_added", tracker_name, type)
	elif type == XRServer.TRACKER_HAND:
		prints("hand tracker_added", tracker_name, type)
	else:
		prints("Dtracker_added", tracker_name, type)

func Dtracker_removed(tracker_name: StringName, type: int):
	prints("Dtracker_removed", tracker_name, type)

func Dtracker_updated(tracker_name: StringName, type: int):
	prints("Dtracker_updated", tracker_name, type)

func Dinterface_added(interface_name: StringName):
	prints("Dinterface_added", interface_name)
	
func Dinterface_removed(interface_name: StringName):
	prints("Dinterface_removed", interface_name)

func _ready():
	XRServer.tracker_added.connect(Dtracker_added)
	XRServer.tracker_removed.connect(Dtracker_removed)
	XRServer.tracker_updated.connect(Dtracker_updated)
	XRServer.interface_added.connect(Dinterface_added)
	XRServer.interface_removed.connect(Dinterface_removed)
	print("XRServer.TRACKER_ANY ", XRServer.get_trackers(XRServer.TRACKER_ANY))
	print("XRServer.TRACKER_FACE ", XRServer.get_trackers(XRServer.TRACKER_FACE))
	print("XRServer.TRACKER_HAND ", XRServer.get_trackers(XRServer.TRACKER_HAND))
	print("XRServer.TRACKER_CONTROLLER ", XRServer.get_trackers(XRServer.TRACKER_CONTROLLER))

	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		var vp = get_viewport()

		# Enable XR on the main viewpoCrt
		vp.use_xr = true

		# Make sure v-sync is disabled, we're using the headsets v-sync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		$XROrigin3D/HandJoints.set_xr_interface(xr_interface)

		xr_interface.play_area_changed.connect(_on_play_area_changed)
		xr_interface.pose_recentered.connect(_on_openxr_pose_recentered)
		print("OpenXR initialized successfully")
	else:
		print("OpenXR not initialized, please check if your headset is connected")

func getcontextmenutexts():
	return [ "VR", "AR", "FBTrackerL", "AutoTrackerL", "camerapos" ]


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

var siglogcount = 0
var ignore_recentre = true
func _on_openxr_pose_recentered() -> void:
	print("  _on_openxr_pose_recentered")
	if ignore_recentre:
		print("Ignore poser_recentred signal")
	else:
			XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	$XROrigin3D/XRCamera3D/SignalLog.text = "%dposrec" % siglogcount
	siglogcount += 1
	print(" headpos ", $XROrigin3D/XRCamera3D.transform)
	print("New reference frame!! ", XRServer.get_reference_frame())

func _on_play_area_changed(mode):
	print(" on_play_area_changed ", mode)
	$XROrigin3D/XRCamera3D/SignalLog2.text = "%dplayareach %d" % [siglogcount, mode]
	$XROrigin3D/XRCamera3D/SignalLog2.visible = true
	siglogcount += 1

const joyvelocity = 1.1
var prevhmdpos = Vector3(0,0,0)
func _process(delta):
	var joyleft = $XROrigin3D/XRController3DLeft.get_vector2("primary")
	var camerafore = Vector3($XROrigin3D/XRCamera3D.transform.basis.z.x, 0.0, $XROrigin3D/XRCamera3D.transform.basis.z.z).normalized()
	var cameraside = Vector3(camerafore.z, 0.0, -camerafore.x)
	$XROrigin3D.transform.origin += -camerafore*(joyleft.y*joyvelocity*delta) + cameraside*(joyleft.x*joyvelocity*delta)

	var hmdpos = $XROrigin3D/XRCamera3D.position
	if (prevhmdpos - hmdpos).length() > 1:
		$XROrigin3D/XRCamera3D/SignalLog.text = "%.1f,%.1f,%.1f" % [hmdpos.x,hmdpos.y,hmdpos.z]
		prevhmdpos = hmdpos
	# look for save_to_storage!!!

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

func _on_radial_menu_menuitemselected(menutext):
	if menutext == "VR":
		switch_to_vr()
	elif menutext == "AR":
		switch_to_ar()
	elif menutext == "FBTrackerL":
		$XROrigin3D/XRController3DLeft/AutoHandtracker.visible = false
		$XROrigin3D/LeftHandFbTracker.visible = true
	elif menutext == "AutoTrackerL":
		$XROrigin3D/XRController3DLeft/AutoHandtracker.visible = true
		$XROrigin3D/LeftHandFbTracker.visible = false
	elif menutext == "camerapos":
		var headtransform = get_node("XROrigin3D/XRCamera3D").transform	
		$XROrigin3D/HandJoints/FrontOfPlayer.transform = Transform3D(headtransform.basis, headtransform.origin - headtransform.basis.z*0.5 + Vector3(0,-0.2,0))
