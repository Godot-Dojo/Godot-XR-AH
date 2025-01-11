extends Node3D


func _on_request_permissions_result(permission: String, granted: bool):
	prints("_on_request_permissions_result", permission, granted)
	if permission == "RECORD_AUDIO" and granted:
		print("RECORD_AUDIO----SECOND_TIME ", OS.request_permission("RECORD_AUDIO"))

func _ready():
	get_tree().on_request_permissions_result.connect(_on_request_permissions_result)
	print("RECORD_AUDIO---- ", OS.request_permission("RECORD_AUDIO"))
	for bb in faudioblendshapegroups:
		if bb[1] >= faudiocutoff:
			audioblendshapegroups.append(bb)
	var vaudioblendshapes = [ ]
	for bb in audioblendshapegroups:
		vaudioblendshapes.append_array(bb.slice(2))
	for i in range(XRFaceTracker.FT_MAX):
		if not vaudioblendshapes.has(i):
			zeroedaudioblendshapes.append(i)
	var blendstickscene = load("res://blendshapestick.tscn")
	print(len(audioblendshapegroups))
	var ncolumnsize = int(len(audioblendshapegroups)/4)
	for j in range(len(audioblendshapegroups)):
		var bss = blendstickscene.instantiate()
		bss.name = "bs%d" % j
		bss.transform.origin = Vector3(int(j/ncolumnsize-ncolumnsize/2+1)*0.13,(j%ncolumnsize)*0.03,0)
		bss.get_node("Label3D").text = audioblendshapegroups[j][0]
		$FaceTrackSticks.add_child(bss)
	

var Dmaxbs = [ ]
var T0 = 10
func _process(delta):
	var xr_facetracker = XRServer.get_tracker("/user/face_tracker")
	if xr_facetracker != null:
		var blendshapes = xr_facetracker.blend_shapes
		var ablendshapes = toaudioblendshapes(blendshapes)
		for j in range(len(ablendshapes)):
			$FaceTrackSticks.get_child(j).get_node("Stick").scale.x = ablendshapes[j]
			$FaceTrackSticks.get_child(j).get_node("StickSensitive").scale.x = min(1.0, ablendshapes[j]*10)
			if len(Dmaxbs) <= j:
				Dmaxbs.append(0)
			Dmaxbs[j] = max(Dmaxbs[j],ablendshapes[j])
		T0 -= delta
		if T0 < 0:
			T0 = 10
			print("Dmaxbs", Dmaxbs)
			Dmaxbs = [ ]
		#print(ablendshapes)
		
func toaudioblendshapes(blendshapes):
	var ablendshapes = [ ]
	for bb in audioblendshapegroups:
		for i in range(2, len(bb)-1):
			if blendshapes[bb[i]] != blendshapes[bb[-1]]:
				prints("non-equal blendshape ", i, bb)
		ablendshapes.append(blendshapes[bb[-1]])
	for i in zeroedaudioblendshapes:
		if blendshapes[i] > faudiocutoff:
			prints("non-zero blendshape", i, blendshapes[i], ">", faudiocutoff)
	return ablendshapes

var zeroedaudioblendshapes = [ ]
var audioblendshapegroups = [ ]
var faudiocutoff = 0.05
var faudioblendshapegroups = [
	["EyeClose", 1.0, XRFaceTracker.FT_EYE_CLOSED_RIGHT, XRFaceTracker.FT_EYE_CLOSED_LEFT, XRFaceTracker.FT_EYE_CLOSED],
	["EyeSquint", 1.0, XRFaceTracker.FT_EYE_SQUINT_RIGHT, XRFaceTracker.FT_EYE_SQUINT_LEFT, XRFaceTracker.FT_EYE_SQUINT],
	["BrowLower", 0.0001, XRFaceTracker.FT_BROW_LOWERER_RIGHT, XRFaceTracker.FT_BROW_LOWERER_LEFT],
	["BrowInUp", 0.01, XRFaceTracker.FT_BROW_INNER_UP_RIGHT, XRFaceTracker.FT_BROW_INNER_UP_LEFT],
	["BrowOutUp", 0.0001, XRFaceTracker.FT_BROW_OUTER_UP_RIGHT, XRFaceTracker.FT_BROW_OUTER_UP_LEFT],
	["NoseSneer", 0.01, XRFaceTracker.FT_NOSE_SNEER_RIGHT, XRFaceTracker.FT_NOSE_SNEER_LEFT, XRFaceTracker.FT_NOSE_SNEER],
	["CheekSqnt", 0.01, XRFaceTracker.FT_CHEEK_SQUINT_RIGHT, XRFaceTracker.FT_CHEEK_SQUINT_LEFT, XRFaceTracker.FT_CHEEK_SQUINT],
	["CheekPuff", 0.01, XRFaceTracker.FT_CHEEK_PUFF_RIGHT, XRFaceTracker.FT_CHEEK_PUFF_LEFT, XRFaceTracker.FT_CHEEK_PUFF],
	["JawOpen", 1.0, XRFaceTracker.FT_JAW_OPEN],
	["MouthClose", 1.0, XRFaceTracker.FT_MOUTH_CLOSED],
	["JawFore", 0.1, XRFaceTracker.FT_JAW_FORWARD],
	["LipPuckUp", 0.1, XRFaceTracker.FT_LIP_PUCKER_UPPER_RIGHT, XRFaceTracker.FT_LIP_PUCKER_UPPER_LEFT, XRFaceTracker.FT_LIP_PUCKER_LOWER_RIGHT, XRFaceTracker.FT_LIP_PUCKER_LOWER_LEFT],
	["MouthUpper", 1.0, XRFaceTracker.FT_MOUTH_UPPER_UP_RIGHT, XRFaceTracker.FT_MOUTH_UPPER_UP_LEFT, XRFaceTracker.FT_MOUTH_UPPER_UP],
	["MouthLower", 0.1, XRFaceTracker.FT_MOUTH_LOWER_DOWN_RIGHT, XRFaceTracker.FT_MOUTH_LOWER_DOWN_LEFT, XRFaceTracker.FT_MOUTH_LOWER_DOWN],
	["MouthCorn", 0.1, XRFaceTracker.FT_MOUTH_CORNER_PULL_RIGHT, XRFaceTracker.FT_MOUTH_CORNER_PULL_LEFT],
	["MouthStch", 0.1, XRFaceTracker.FT_MOUTH_STRETCH_RIGHT, XRFaceTracker.FT_MOUTH_STRETCH_LEFT, XRFaceTracker.FT_MOUTH_STRETCH],
	["MouthDimp", 0.1, XRFaceTracker.FT_MOUTH_DIMPLE_RIGHT, XRFaceTracker.FT_MOUTH_DIMPLE_LEFT, XRFaceTracker.FT_MOUTH_DIMPLE],
	["MouthRasUpp", 1.0, XRFaceTracker.FT_MOUTH_RAISER_UPPER],
	["MouthRasLow", 0.1, XRFaceTracker.FT_MOUTH_RAISER_LOWER],
	["MouthTight", 0.001, XRFaceTracker.FT_MOUTH_TIGHTENER_RIGHT,XRFaceTracker.FT_MOUTH_TIGHTENER_LEFT, XRFaceTracker.FT_MOUTH_TIGHTENER],
	["TongFlat", 1.0, XRFaceTracker.FT_TONGUE_FLAT],
	["BrowDown", 0.0001, XRFaceTracker.FT_BROW_DOWN_RIGHT, XRFaceTracker.FT_BROW_DOWN_LEFT, XRFaceTracker.FT_BROW_DOWN],
	["BrowUp", 0.01, XRFaceTracker.FT_BROW_UP_RIGHT, XRFaceTracker.FT_BROW_UP_LEFT, XRFaceTracker.FT_BROW_UP],
	["LipPuck", 0.1, XRFaceTracker.FT_LIP_PUCKER_UPPER, XRFaceTracker.FT_LIP_PUCKER_LOWER, XRFaceTracker.FT_LIP_PUCKER],
	["MouthOpen", 0.1, XRFaceTracker.FT_MOUTH_OPEN],
	["MouthSmile", 0.1, XRFaceTracker.FT_MOUTH_SMILE_RIGHT, XRFaceTracker.FT_MOUTH_SMILE_LEFT, XRFaceTracker.FT_MOUTH_SMILE]
]
	
	
	#var xr_bodytracker = XRServer.get_tracker("/user/body_tracker")
	#if xr_bodytracker != null:
	#	prints(" bodytracker ", xr_bodytracker.body_flags, xr_bodytracker.has_tracking_data)
	
