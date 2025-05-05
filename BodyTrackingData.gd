extends Node3D

var axes3dscene = load("res://axes3d.tscn")

var bodyupperexists = false
var bodylowerexists = false
var bodyhandsexists = false

var manimrec = null
var manimrecT = 0.0
func createanimation():
	manimrec = Animation.new()
	for i in range($MiniBody.get_child_count()):
		manimrec.add_track(Animation.TYPE_POSITION_3D)
		manimrec.track_set_path(i*2, String($MiniBody.get_child(i).name))
		manimrec.add_track(Animation.TYPE_ROTATION_3D)
		manimrec.track_set_path(i*2+1, String($MiniBody.get_child(i).name))

func createjoints(prefix, joints, untrackedmeshvisibility=true):
	for j in joints:
		var nj = axes3dscene.instantiate()
		nj.name = "%s%d" % [ prefix, j ]
		nj.scale = Vector3(0.02, 0.02, 0.02)*4
		nj.get_node("UntrackedMesh").visible = untrackedmeshvisibility
		$MiniBody.add_child(nj)

func makenodesforanimation():
	if $MiniBody.get_child_count() == 0:
		createjoints("U", jointsupper, false)
		createjoints("H", jointshands, false)

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
					if manimrec:
						var i = manimrec.find_track(String(nj.get_name()), Animation.TYPE_ROTATION_3D)
						manimrec.rotation_track_insert_key(i, manimrecT, Quaternion(tr.basis.orthonormalized()))

				if jf & XRBodyTracker.JOINT_FLAG_POSITION_TRACKED:
					nj.transform.origin = tr.origin
					if manimrec:
						var i = manimrec.find_track(String(nj.get_name()), Animation.TYPE_POSITION_3D)
						manimrec.position_track_insert_key(i, manimrecT, tr.origin)

	if manimrec:
		manimrec.length = manimrecT + 1.0
		manimrecT += delta

func finishanimation():
	if manimrec:
		print("Finish anim recording ", manimrecT)
		manimrec.length = manimrecT
		manimrec.loop_mode = Animation.LOOP_LINEAR
		var animlibrary : AnimationLibrary = $BodyMotionAnimation.get_animation_library("manimreclibrary")
		animlibrary.remove_animation("manimrec")
		animlibrary.add_animation("manimrec", manimrec)
		manimrec = null

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
