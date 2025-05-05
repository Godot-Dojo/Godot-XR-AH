extends Node3D

var ascale = 2.0
@onready var manim : Animation = ResourceLoader.load("res://data/manimrec.anim")
@onready var danim : Animation = Animation.new()

func getjointtrans(t, j):
	var tp = "U" if j < XRBodyTracker.JOINT_LEFT_HAND else "H"
	var tn = "%s%d" % [tp, j] 
	var ihp = manim.find_track(tn, Animation.TYPE_POSITION_3D)
	var ihr = manim.find_track(tn, Animation.TYPE_ROTATION_3D)
	return Transform3D(manim.rotation_track_interpolate(ihr, t), manim.position_track_interpolate(ihp, t)/ascale)

var dtracks = { }
func daddtrtrack(nm):
	var jp = danim.add_track(Animation.TYPE_POSITION_3D)
	danim.track_set_path(jp, nm)
	var jr = danim.add_track(Animation.TYPE_ROTATION_3D)
	danim.track_set_path(jr, nm)
	dtracks[nm] = [ jp, jr ]

func daddkey(j, t, tr):
	#danim.track_insert_key(dtracks[j][0], t, tr.origin)
	danim.track_insert_key(dtracks[j][1], t, Quaternion(tr.basis.orthonormalized()))
	
func _ready():
	#$Armature.scale = Vector3(ascale, ascale, ascale)
	danim.length = manim.length
	danim.loop_mode = manim.loop_mode
	
	var ih = manim.find_track("U%d" % XRBodyTracker.JOINT_HEAD, Animation.TYPE_POSITION_3D)
	var ts = [ ]
	for k in range(manim.track_get_key_count(ih)):
		var t = manim.track_get_key_time(ih, k)
		ts.append(t)
	
	# XRBodyTracker.JOINT_ROOT,JOINT_HIPS,JOINT_SPINE,JOINT_CHEST,JOINT_UPPER_CHEST,JOINT_NECK,JOINT_HEAD
	# Skel: Hips,Spine,Chest,Neck,Head
	# XRBodyTracker.JOINT_LEFT_SHOULDER,JOINT_LEFT_UPPER_ARM,JOINT_LEFT_LOWER_ARM,JOINT_LEFT_WRIST
	# Skel: Chest,Left shoulder,Left arm,Left elbow,Left wrist

	daddtrtrack(".")
	daddtrtrack(":Hips")
	daddtrtrack(":Spine")
	daddtrtrack(":Chest")
	daddtrtrack(":Neck")
	daddtrtrack(":Head")
	daddtrtrack(":Left shoulder")
	daddtrtrack(":Left arm")
	daddtrtrack(":Left elbow")
	daddtrtrack(":Left wrist")
	daddtrtrack(":Right shoulder")
	daddtrtrack(":Right arm")
	daddtrtrack(":Right elbow")
	daddtrtrack(":Right wrist")
	for t in ts:
		var trroot = getjointtrans(t, XRBodyTracker.JOINT_ROOT)
		var trhips = getjointtrans(t, XRBodyTracker.JOINT_HIPS)
		var trspine = getjointtrans(t, XRBodyTracker.JOINT_SPINE)
		var trchest = getjointtrans(t, XRBodyTracker.JOINT_CHEST)
		var trupperchest = getjointtrans(t, XRBodyTracker.JOINT_UPPER_CHEST)
		var trneck = getjointtrans(t, XRBodyTracker.JOINT_NECK)
		var trhead = getjointtrans(t, XRBodyTracker.JOINT_HEAD)

		var trleftshoulder = getjointtrans(t, XRBodyTracker.JOINT_LEFT_SHOULDER)
		var trleftupperarm = getjointtrans(t, XRBodyTracker.JOINT_LEFT_UPPER_ARM)
		var trleftlowerarm = getjointtrans(t, XRBodyTracker.JOINT_LEFT_LOWER_ARM)
		var trleftwrist = getjointtrans(t, XRBodyTracker.JOINT_LEFT_WRIST)

		var trrightshoulder = getjointtrans(t, XRBodyTracker.JOINT_RIGHT_SHOULDER)
		var trrightupperarm = getjointtrans(t, XRBodyTracker.JOINT_RIGHT_UPPER_ARM)
		var trrightlowerarm = getjointtrans(t, XRBodyTracker.JOINT_RIGHT_LOWER_ARM)
		var trrightwrist = getjointtrans(t, XRBodyTracker.JOINT_RIGHT_WRIST)

		var roty180 = Basis().rotated(Vector3(0,1,0), rad_to_deg(180))
		trrightupperarm.basis = trrightupperarm.basis*roty180
		trrightlowerarm.basis = trrightlowerarm.basis*roty180
		trrightwrist.basis = trrightwrist.basis*roty180
		trleftupperarm.basis = trleftupperarm.basis*roty180
		trleftlowerarm.basis = trleftlowerarm.basis*roty180
		trleftwrist.basis = trleftwrist.basis*roty180
		
		daddkey(".", t, trroot)
		daddkey(":Hips", t, trroot.inverse()*trhips)
		daddkey(":Spine", t, trhips.inverse()*trspine)
		daddkey(":Chest", t, trspine.inverse()*trchest)
		daddkey(":Neck", t, trchest.inverse()*trneck)
		daddkey(":Head", t, trneck.inverse()*trhead)
		daddkey(":Left shoulder", t, trchest.inverse()*trleftshoulder)
		daddkey(":Left arm", t, trleftshoulder.inverse()*trleftupperarm)
		daddkey(":Left elbow", t, trleftupperarm.inverse()*trleftlowerarm)
		daddkey(":Left wrist", t, trleftlowerarm.inverse()*trleftwrist)
		daddkey(":Right shoulder", t, trchest.inverse()*trrightshoulder)
		daddkey(":Right arm", t, trrightshoulder.inverse()*trrightupperarm)
		daddkey(":Right elbow", t, trrightupperarm.inverse()*trrightlowerarm)
		daddkey(":Right wrist", t, trrightlowerarm.inverse()*trrightwrist)

	var animlibrary : AnimationLibrary = $AnimationPlayer.get_animation_library("dreclibrary")
	animlibrary.add_animation("danim", danim)
	$AnimationPlayer.active = true
	$AnimationPlayer.play("dreclibrary/danim")

#Hips Spine Chest Neck Head		
#XRBodyTracker.JOINT_ROOT,
#					XRBodyTracker.JOINT_HIPS, 
#					XRBodyTracker.JOINT_SPINE,
#					XRBodyTracker.JOINT_CHEST,
#					XRBodyTracker.JOINT_UPPER_CHEST, 
#					XRBodyTracker.JOINT_NECK,
#					XRBodyTracker.JOINT_HEAD,
