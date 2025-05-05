extends Node3D

@onready var xrcamera : Node3D = get_node("/root/Main/XROrigin3D/XRCamera3D")
@onready var xrleft = get_node("/root/Main/XROrigin3D/XRController3DLeft")
@onready var xrright = get_node("/root/Main/XROrigin3D/XRController3DRight")

var wristshoulderlength = 0.6 - 0.1
var thoracicheight = 0.19
var thoracicshoulderwidth = 0.099792*2
@onready var thoracicvecleng = Vector2(thoracicheight, thoracicshoulderwidth/2).length()

func _ready():
	#Relative to the Grip Pose
	$HeadClaw/PivotMarker.position = Vector3(0.0, -0.109, 0.09)

	$LeftClaw/PivotMarker.position = Vector3(-0.041, 0.048, 0.028)
	$RightClaw/PivotMarker.position = Vector3(0.038, 0.045, 0.033)
	$LeftClaw/PivotMarkerElbow.position = Vector3(-0.028, 0.328, 0.121)
	$RightClaw/PivotMarkerElbow.position = Vector3(0.146, 0.214, 0.177)
	$LeftClaw/PivotMarkerShoulder.position = Vector3(-0.22, 0.589, 0.136)
	$RightClaw/PivotMarkerShoulder.position = Vector3(0.045, 0.566, 0.35)

	$LeftClaw/WristPivot.position = Vector3(-0.041, 0.048, 0.028)
	$LeftClaw/WristPivot.rotation_degrees = Vector3(20, 0, 0) # from wrist to elbow vector direction in YZ

	$HeadClaw/PivotMarker/LeftShoulder.position = Vector3(-thoracicheight, -0.0, thoracicshoulderwidth/2)
	$HeadClaw/PivotMarker/RightShoulder.position = Vector3(thoracicheight, -0.0, thoracicshoulderwidth/2)

	#if ResourceLoader.exists("res://data/animrec.anim"):
	#	var anim = ResourceLoader.load("res://data/animrec.anim")
	#	var animlibrary : AnimationLibrary = $MotionAnimation.get_animation_library("animreclibrary")
	#	animlibrary.remove_animation("animrec")
	#	animlibrary.add_animation("animrec", anim)

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
		positionshoulderslocus()
		repositionthorax()
		if animrec:
			processanimrec(delta)

func getcontextmenutexts():
	return [ "StopBody", "PlayAnim", 
			 "FixHeadClaw", "FixLeftClaw", "FixRightClaw",
			 "RotateBody", "SetShoulders", 
			 "SaveAnim" ]

func _on_radial_menu_menuitemselected(menutext):
	if menutext == "StopBody":
		$MotionAnimation.stop()
		$MotionAnimation.active = false
		$BodyTrackingData/BodyMotionAnimation.stop()
		$BodyTrackingData/BodyMotionAnimation.active = false
		stopbodytracking()
	if menutext == "PlayAnim":
		$MotionAnimation.play("animreclibrary/animrec")
		$MotionAnimation.active = true
		$BodyTrackingData/BodyMotionAnimation.play("manimreclibrary/manimrec")
		$BodyTrackingData/BodyMotionAnimation.active = true
	if menutext == "SaveAnim":
		var anim = $MotionAnimation.get_animation("animreclibrary/animrec")
		var manim = $BodyTrackingData/BodyMotionAnimation.get_animation("manimreclibrary/manimrec")
		var save_path = "user://animrec.anim"
		var msave_path = "user://manimrec.anim"
		print("OS.get_data_dir ", OS.get_data_dir())
		if OS.has_feature("android"):
			save_path = "/storage/emulated/0/Android/datac/com.example.godotxrah/files/animrec.anim"
			msave_path = "/storage/emulated/0/Android/data/com.example.godotxrah/files/manimrec.anim"
		var E = ResourceSaver.save(anim, save_path)
		print("Resourcesaver Error=", E)
		var mE = ResourceSaver.save(manim, msave_path)
		print("mResourcesaver Error=", mE)
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

	if menutext == "SetShoulders":
		var rs = $RightClaw/PivotMarkerShoulder.global_position
		var ls = $LeftClaw/PivotMarkerShoulder.global_position
		var nk = $HeadClaw/PivotMarker.global_position
		var svec = rs - ls
		var lam = svec.dot(nk - ls)/svec.length_squared()
		print("Mid point neck lam... ", lam)
		$HeadClaw/PivotMarker.global_basis = AutoHandFuncs.basisfromA(svec, nk - ls)
		$HeadClaw/PivotMarker/LeftShoulder.global_position = $LeftClaw/PivotMarkerShoulder.global_position
		$HeadClaw/PivotMarker/RightShoulder.global_position = $RightClaw/PivotMarkerShoulder.global_position
		prints("LR thorax shoulders", $HeadClaw/PivotMarker/LeftShoulder.position, $HeadClaw/PivotMarker/RightShoulder.position)

func _input(event):
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_L:
		var frontofplayer = get_node("/root/Main/XROrigin3D/HandJoints/FrontOfPlayer")
		frontofplayer.position.y = max(frontofplayer.position.y, 3)
		$BodyTrackingData.makenodesforanimation()
		_on_radial_menu_menuitemselected("PlayAnim")
		#$MotionAnimation.play("animreclibrary/animrec")
		$MotionAnimation.stop()
		$BodyTrackingData/BodyMotionAnimation.speed_scale = 0.1
		$BodyTrackingData/BodyMotionAnimation.play("manimreclibrary/manimrec", 0)
		$BodyTrackingData/BodyMotionAnimation.active = true
		get_node("../davali/AnimationPlayer").speed_scale = 0.1
		get_node("../davali/AnimationPlayer").play("dreclibrary/danim", 0)

		
func positionshoulderlocus(nk, w):
	var vw = w - nk
	var m = vw.length()
	var h = thoracicvecleng
	var l = wristshoulderlength
	var b = (m*m - l*l + h*h)/(2*m)
	var asq = h*h - b*b
	var a = sqrt(max(0, asq))
	var vy = vw/m
	var vx = Vector3(0,1,0).cross(vy).normalized()
	var vz = vx.cross(vy)
	var c = nk + b*vy
	return Transform3D(Basis(vx*a, vy*a, vz*a), c)
	
func positionshoulderslocus():
	var nk = $HeadClaw/PivotMarker.global_position
	$LeftShoulderLocus.global_transform = positionshoulderlocus(nk, $LeftClaw/PivotMarker.global_position)
	$RightShoulderLocus.global_transform = positionshoulderlocus(nk, $RightClaw/PivotMarker.global_position)
	#var thoracicheight = 0.19
	#var thoracicshoulderwidth = 0.099792*2
	#@onready var thoracicvecleng = Vector2(thoracicheight, thoracicshoulderwidth/2).length()
	#wristshoulderlength

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
			print("aaaa ", [animtrackers[i]])
			animrec.track_set_path(i*2, animtrackers[i])
			animrec.add_track(Animation.TYPE_ROTATION_3D)
			animrec.track_set_path(i*2+1, animtrackers[i])
		$BodyTrackingData.createanimation()

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
	$BodyTrackingData.finishanimation()
	
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

func measurethoraxrot(thoraxquat):
	var thoraxtrans = $HeadClaw.global_transform*Transform3D(thoraxquat, $HeadClaw/PivotMarker.position)
	var tsleft = thoraxtrans*$HeadClaw/PivotMarker/LeftShoulder.position
	var tsright = thoraxtrans*$HeadClaw/PivotMarker/RightShoulder.position
	var lw = $LeftClaw/PivotMarker.global_position
	var rw = $RightClaw/PivotMarker.global_position
	var swl = (tsleft - lw).length() - wristshoulderlength
	var swr = (tsright - rw).length() - wristshoulderlength
	return swl*swl + swr*swr

func repositionthorax():
	var propthoraxquat = $HeadClaw/PivotMarker.basis.get_rotation_quaternion()
	var Dpropthoraxquat = propthoraxquat
	var eps = 0.001
	var qeps = sqrt(1.0 - eps*eps)
	for k in range(12):
		var E0 = measurethoraxrot(propthoraxquat)
		var gx = measurethoraxrot(propthoraxquat*Quaternion(eps, 0, 0, qeps))
		var gy = measurethoraxrot(propthoraxquat*Quaternion(0, eps, 0, qeps))
		var gz = measurethoraxrot(propthoraxquat*Quaternion(0, 0, eps, qeps))
		var gradE = Vector3(gx-E0, gy-E0, gz-E0)/eps
		var gradEsq = gradE.length_squared()
		var c = 0.5
		var tau = 0.5
		var delta = 0.2
		for i in range(10):
			var v = -gradE*delta
			var addpropthoraxquat = Quaternion(v.x, v.y, v.z, sqrt(1.0 - v.length_squared()))
			var E1 = measurethoraxrot(propthoraxquat*addpropthoraxquat)
			if E1 < E0 - delta*c*gradEsq:
				propthoraxquat = propthoraxquat*addpropthoraxquat 
				break
			delta = delta*tau
	#print(Dpropthoraxquat.inverse()*propthoraxquat)
	$HeadClaw/PivotMarker.basis = Basis(propthoraxquat)
	
