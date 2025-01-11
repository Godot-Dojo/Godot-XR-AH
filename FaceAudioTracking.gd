extends Node3D


func _on_request_permissions_result(permission: String, granted: bool):
	prints("_on_request_permissions_result", permission, granted)
	if permission == "RECORD_AUDIO" and granted:
		print("RECORD_AUDIO----SECOND_TIME ", OS.request_permission("RECORD_AUDIO"))

func _ready():
	get_tree().on_request_permissions_result.connect(_on_request_permissions_result)
	print("RECORD_AUDIO---- ", OS.request_permission("RECORD_AUDIO"))
	var vaudioblendshapes = [ ]
	for bb in audioblendshapegroups:
		vaudioblendshapes.append_array(bb)
	for i in range(XRFaceTracker.FT_MAX):
		if not vaudioblendshapes.has(i):
			zeroedaudioblendshapes.append(i)

	var blendstickscene = load("res://blendshapestick.tscn")
	for j in range(len(audioblendshapegroups)):
		var bss = blendstickscene.instantiate()
		bss.name = "bs%d" % j
		bss.transform.origin = Vector3(0,j*0.03,0)
		$FaceTrackSticks.add_child(bss)
	
func _process(delta):
	var xr_facetracker = XRServer.get_tracker("/user/face_tracker")
	if xr_facetracker != null:
		var blendshapes = xr_facetracker.blend_shapes
		var ablendshapes = toaudioblendshapes(blendshapes)
		for j in range(len(ablendshapes)):
			$FaceTrackSticks.get_child(j).get_node("Stick").scale.x = ablendshapes[j]
		#print(ablendshapes)
		
func toaudioblendshapes(blendshapes):
	var ablendshapes = [ ]
	for bb in audioblendshapegroups:
		for i in range(len(bb)-1):
			if blendshapes[bb[i]] != blendshapes[bb[-1]]:
				prints("non-equal blendshape ", i, bb)
		ablendshapes.append(blendshapes[bb[-1]])
	for i in zeroedaudioblendshapes:
		if blendshapes[i] != 0.0:
			prints("non-zero blendshape", i, blendshapes[i])
	return ablendshapes

var zeroedaudioblendshapes = [ ]
var audioblendshapegroups = [
	[XRFaceTracker.FT_EYE_CLOSED_RIGHT, XRFaceTracker.FT_EYE_CLOSED_LEFT],
	[XRFaceTracker.FT_EYE_SQUINT_RIGHT, XRFaceTracker.FT_EYE_SQUINT_LEFT],
	[XRFaceTracker.FT_BROW_LOWERER_RIGHT, XRFaceTracker.FT_BROW_LOWERER_LEFT],
	[XRFaceTracker.FT_BROW_INNER_UP_RIGHT, XRFaceTracker.FT_BROW_INNER_UP_LEFT],
	[XRFaceTracker.FT_BROW_OUTER_UP_RIGHT, XRFaceTracker.FT_BROW_OUTER_UP_LEFT],
	[XRFaceTracker.FT_NOSE_SNEER_RIGHT, XRFaceTracker.FT_NOSE_SNEER_LEFT],
	[XRFaceTracker.FT_CHEEK_SQUINT_RIGHT, XRFaceTracker.FT_CHEEK_SQUINT_LEFT],
	[XRFaceTracker.FT_CHEEK_PUFF_RIGHT, XRFaceTracker.FT_CHEEK_PUFF_LEFT],
	[XRFaceTracker.FT_JAW_OPEN],
	[XRFaceTracker.FT_MOUTH_CLOSED],
	[XRFaceTracker.FT_JAW_FORWARD],
	[XRFaceTracker.FT_LIP_PUCKER_UPPER_RIGHT, XRFaceTracker.FT_LIP_PUCKER_UPPER_LEFT, XRFaceTracker.FT_LIP_PUCKER_LOWER_RIGHT, XRFaceTracker.FT_LIP_PUCKER_LOWER_LEFT],
	[XRFaceTracker.FT_MOUTH_UPPER_UP_RIGHT, XRFaceTracker.FT_MOUTH_UPPER_UP_LEFT],
	[XRFaceTracker.FT_MOUTH_LOWER_DOWN_RIGHT, XRFaceTracker.FT_MOUTH_LOWER_DOWN_LEFT],
	[XRFaceTracker.FT_MOUTH_CORNER_PULL_RIGHT, XRFaceTracker.FT_MOUTH_CORNER_PULL_LEFT],
	[XRFaceTracker.FT_MOUTH_STRETCH_RIGHT, XRFaceTracker.FT_MOUTH_STRETCH_LEFT],
	[XRFaceTracker.FT_MOUTH_DIMPLE_RIGHT, XRFaceTracker.FT_MOUTH_DIMPLE_LEFT],
	[XRFaceTracker.FT_MOUTH_RAISER_UPPER],
	[XRFaceTracker.FT_MOUTH_RAISER_LOWER],
	[XRFaceTracker.FT_MOUTH_TIGHTENER_RIGHT,XRFaceTracker.FT_MOUTH_TIGHTENER_LEFT],
	[XRFaceTracker.FT_TONGUE_FLAT],
	[XRFaceTracker.FT_EYE_CLOSED],
	[XRFaceTracker.FT_EYE_SQUINT],
	[XRFaceTracker.FT_BROW_DOWN_RIGHT, XRFaceTracker.FT_BROW_DOWN_LEFT, XRFaceTracker.FT_BROW_DOWN],
	[XRFaceTracker.FT_BROW_UP_RIGHT, XRFaceTracker.FT_BROW_UP_LEFT, XRFaceTracker.FT_BROW_UP],
	[XRFaceTracker.FT_NOSE_SNEER],
	[XRFaceTracker.FT_CHEEK_PUFF],
	[XRFaceTracker.FT_CHEEK_SUCK],
	[XRFaceTracker.FT_CHEEK_SQUINT],
	[XRFaceTracker.FT_LIP_PUCKER_UPPER, XRFaceTracker.FT_LIP_PUCKER_LOWER, XRFaceTracker.FT_LIP_PUCKER],
	[XRFaceTracker.FT_MOUTH_UPPER_UP],
	[XRFaceTracker.FT_MOUTH_LOWER_DOWN],
	[XRFaceTracker.FT_MOUTH_OPEN],
	[XRFaceTracker.FT_MOUTH_SMILE_RIGHT, XRFaceTracker.FT_MOUTH_SMILE_LEFT, XRFaceTracker.FT_MOUTH_SMILE],
	[XRFaceTracker.FT_MOUTH_STRETCH],
	[XRFaceTracker.FT_MOUTH_DIMPLE],
	[XRFaceTracker.FT_MOUTH_TIGHTENER]
]
	
	
	#var xr_bodytracker = XRServer.get_tracker("/user/body_tracker")
	#if xr_bodytracker != null:
	#	prints(" bodytracker ", xr_bodytracker.body_flags, xr_bodytracker.has_tracking_data)
	
