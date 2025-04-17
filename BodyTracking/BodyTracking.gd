extends Node3D

@onready var xrcamera : Node3D = get_node("/root/Main/XROrigin3D/XRCamera3D")
@onready var xrleft = get_node("/root/Main/XROrigin3D/XRController3DLeft")
@onready var xrright = get_node("/root/Main/XROrigin3D/XRController3DRight")

func _ready():
	#Relative to the Grip Pose
	$HeadClaw/PivotMarker.position = Vector3(0.0, -0.109, 0.09)
	$LeftClaw/PivotMarker.position = Vector3(-0.041, 0.048, 0.028)
	$RightClaw/PivotMarker.position = Vector3(0.038, 0.045, 0.033)
	$LeftClaw/PivotMarkerElbow.position = Vector3(-0.162, 0.205, 0.172)
	$RightClaw/PivotMarkerElbow.position = Vector3(0.146, 0.214, 0.177)
	$LeftClaw/PivotMarkerShoulder.position = Vector3(-0.22, 0.589, 0.136)
	$RightClaw/PivotMarkerShoulder.position = Vector3(0.17, 0.318, 0.155)

func startbodytracking():
	set_process(true)
	var footpos = xrcamera.global_position
	footpos.y = 0.0
	var sitedir = xrcamera.global_transform.basis.z
	sitedir.y = 0.0
	var posfootpos = footpos - sitedir.normalized()*1.1
	position = posfootpos - footpos
	visible = true

func stopbodytracking():
	visible = false
	set_process(false)

func _process(delta):
	if not $MotionAnimation.active:
		$HeadClaw.transform = xrcamera.transform
		$LeftClaw.transform = xrleft.transform
		$RightClaw.transform = xrright.transform
		if animrec:
			processanimrec(delta)
		
func getcontextmenutexts():
	return [ "StopBody", "PlayAnim", 
			 "FixHeadClaw", "FixLeftClaw", "FixRightClaw",
			 "RotateBody" ]

func _on_radial_menu_menuitemselected(menutext):
	if menutext == "StopBody":
		$MotionAnimation.stop()
		$MotionAnimation.active = false
		stopbodytracking()
	if menutext == "PlayAnim":
		$MotionAnimation.play("animreclibrary/animrec")
		$MotionAnimation.active = true
	if menutext == "RotateBody":
		rotation_degrees.y += 30
	if menutext.begins_with("Fix"):
		var anim = $MotionAnimation.get_animation("animreclibrary/animrec")
		if anim:
			var i = animtrackers.find(menutext.substr(3))
			var trs = [ ]
			for k in range(anim.track_get_key_count(i*2)):
				var tr = Transform3D(anim.track_get_key_value(i*2+1, k), anim.track_get_key_value(i*2, k))
				trs.append(tr)
			var pm = get_node(menutext.substr(3)).get_node("PivotMarker")
			var vec = searchfixedpivotvec(trs, pm.position)
			pm.position = vec

const animtrackers = [ "HeadClaw", "LeftClaw", "RightClaw" ]
var animrec : Animation = null
var animrecT = 0.0
func startaxbuttondown():
	if visible and not $MotionAnimation.active:
		print("Start anim recording ", animrecT)
		$RecordingMarker.visible = true
		animrec = Animation.new()
		animrecT = 0.0
		for i in range(len(animtrackers)):
			animrec.add_track(Animation.TYPE_POSITION_3D)
			animrec.track_set_path(i*2, animtrackers[i])
			animrec.add_track(Animation.TYPE_ROTATION_3D)
			animrec.track_set_path(i*2+1, animtrackers[i])

func processanimrec(delta):
	for i in range(len(animtrackers)):
		var tr = get_node(animtrackers[i]).transform
		animrec.position_track_insert_key(i*2, animrecT, tr.origin)
		animrec.rotation_track_insert_key(i*2+1, animrecT, Quaternion(tr.basis.orthonormalized()))
	animrec.length = animrecT + 1.0
	animrecT += delta
	
func stopaxbuttondown():
	if animrec:
		print("Finish anim recording ", animrecT)
		$RecordingMarker.visible = false
		animrec.length = animrecT
		animrec.loop_mode = Animation.LOOP_LINEAR
		var animlibrary : AnimationLibrary = $MotionAnimation.get_animation_library("animreclibrary")
		animlibrary.remove_animation("animrec")
		animlibrary.add_animation("animrec", animrec)
		animrec = null
	
func searchfixedpivotvec(trs, vec):
	var ddel = 0.0001
	for k in range(12):
		var E0 = variancescore(trs, vec)
		var E0x = variancescore(trs, vec + Vector3(ddel,0,0))
		var E0y = variancescore(trs, vec + Vector3(0,ddel,0))
		var E0z = variancescore(trs, vec + Vector3(0,0,ddel))
		var E0d = Vector3((E0x - E0)/ddel, (E0y - E0)/ddel, (E0z - E0)/ddel)
		var E0gs = E0d.length_squared()
		var c = 0.5
		var tau = 0.5
		var delta = 2.0
		print(vec, " E0 ", E0, E0d)
		for i in range(10):
			var E1 = variancescore(trs, vec - E0d*delta)
			prints("ii ", delta, E1)
			if E1 < E0 - delta*c*E0gs:
				break
			delta = delta*tau
		vec -= E0d*delta
	return vec

func variancescore(trs, vec):
	var npts = [ ]
	var spts = Vector3.ZERO
	for tr in trs:
		var p = tr*vec
		npts.append(p)
		spts += p
	var apt = spts/len(trs)
	var vsum = 0.0
	for pt in npts:
		var vs = (pt - apt).length_squared()
		vsum += vs
	return vsum/len(trs)
