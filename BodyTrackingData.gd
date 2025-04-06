extends Node3D

var axes3dscene = load("res://axes3d.tscn")

var bodyupperexists = false
var bodylowerexists = false
var bodyhandsexists = false

func createjoints(prefix, joints):
	for j in joints:
		var nj = axes3dscene.instantiate()
		nj.name = "%s%d" % [ prefix, j ]
		nj.scale = Vector3(0.02, 0.02, 0.02)
		nj.get_node("UntrackedMesh").visible = true
		$MiniBody.add_child(nj)

func _process(delta):
	var xr_bodytracker = XRServer.get_tracker("/user/body_tracker")
	if xr_bodytracker != null:
		if xr_bodytracker.body_flags & XRBodyTracker.BODY_FLAG_UPPER_BODY_SUPPORTED:
			if not bodyupperexists:
				createjoints("U", jointsupper)
				bodyupperexists = true
		if xr_bodytracker.body_flags & XRBodyTracker.BODY_FLAG_LOWER_BODY_SUPPORTED:
			if not bodylowerexists:
				createjoints("L", jointslower)
				bodylowerexists = true
		if xr_bodytracker.body_flags & XRBodyTracker.BODY_FLAG_HANDS_SUPPORTED:
			if not bodyhandsexists:
				createjoints("H", jointshands)
				bodyhandsexists = true

		for nj in $MiniBody.get_children():
			var j = int(nj.name)
			var jf = xr_bodytracker.get_joint_flags(j)
			nj.get_node("InvalidMesh").visible = not (jf & XRBodyTracker.JOINT_FLAG_POSITION_VALID)
			nj.get_node("UntrackedMesh").visible = not (jf & XRBodyTracker.JOINT_FLAG_POSITION_TRACKED)
			nj.get_node("Sphere").visible = (jf & XRBodyTracker.JOINT_FLAG_POSITION_TRACKED) and not (jf & XRBodyTracker.JOINT_FLAG_ORIENTATION_TRACKED)
			if (jf & (XRBodyTracker.JOINT_FLAG_POSITION_TRACKED | XRBodyTracker.JOINT_FLAG_ORIENTATION_TRACKED)):
				var tr = xr_bodytracker.get_joint_transform(j)
				if jf & XRBodyTracker.JOINT_FLAG_ORIENTATION_TRACKED:
					nj.transform.basis = tr.basis.scaled(Vector3(0.04, 0.04, 0.04))
				if jf & XRBodyTracker.JOINT_FLAG_POSITION_TRACKED:
					nj.transform.origin = tr.origin

var jointsupper = [ XRBodyTracker.JOINT_ROOT,
					XRBodyTracker.JOINT_HIPS, 
					XRBodyTracker.JOINT_SPINE,
					XRBodyTracker.JOINT_CHEST,
					XRBodyTracker.JOINT_UPPER_CHEST, 
					XRBodyTracker.JOINT_NECK,
					XRBodyTracker.JOINT_HEAD,
					XRBodyTracker.JOINT_HEAD_TIP,
					XRBodyTracker.JOINT_LEFT_SHOULDER,
					XRBodyTracker.JOINT_LEFT_UPPER_ARM,
					XRBodyTracker.JOINT_LEFT_LOWER_ARM,
					XRBodyTracker.JOINT_RIGHT_SHOULDER,
					XRBodyTracker.JOINT_RIGHT_UPPER_ARM,
					XRBodyTracker.JOINT_RIGHT_LOWER_ARM ]

var jointslower = [ XRBodyTracker.JOINT_HIPS, 
					XRBodyTracker.JOINT_LEFT_UPPER_LEG,
					XRBodyTracker.JOINT_LEFT_LOWER_LEG,
					XRBodyTracker.JOINT_LEFT_FOOT,
					XRBodyTracker.JOINT_LEFT_TOES,
					XRBodyTracker.JOINT_RIGHT_UPPER_LEG,
					XRBodyTracker.JOINT_RIGHT_LOWER_LEG,
					XRBodyTracker.JOINT_RIGHT_FOOT,
					XRBodyTracker.JOINT_RIGHT_TOES ]

var jointshands = [ XRBodyTracker.JOINT_LEFT_HAND, 
					XRBodyTracker.JOINT_LEFT_PALM,
					XRBodyTracker.JOINT_LEFT_WRIST,
					XRBodyTracker.JOINT_RIGHT_HAND,
					XRBodyTracker.JOINT_RIGHT_PALM,
					XRBodyTracker.JOINT_RIGHT_WRIST ]
