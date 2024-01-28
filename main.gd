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
