extends Node3D

var skelbonerest = { }
var skeltrackertrans = { }
@onready var skel = $Armature/Skeleton3D
var ascale = 2.0

# missing optional "Upper Chest"
var vrclookup = { "Root":".", "Hips":"Hips", "Spine":"Spine", "Chest":"Chest", "Upper Chest":"", "Neck":"Neck",
					"Left Shoulder":"Left shoulder", "Left Upper Arm":"Left arm",
					"Left Lower Arm":"Left elbow", "Left Hand":"Left wrist",
					"Right Shoulder":"Right shoulder", "Right Upper Arm":"Right arm",
					"Right Lower Arm":"Right elbow", "Right Hand":"Right wrist" }

var joints = [ XRBodyTracker.JOINT_HIPS, XRBodyTracker.JOINT_SPINE, XRBodyTracker.JOINT_CHEST, 
				XRBodyTracker.JOINT_UPPER_CHEST, XRBodyTracker.JOINT_NECK, XRBodyTracker.JOINT_HEAD, 
				XRBodyTracker.JOINT_LEFT_SHOULDER, XRBodyTracker.JOINT_LEFT_UPPER_ARM, XRBodyTracker.JOINT_LEFT_LOWER_ARM, XRBodyTracker.JOINT_LEFT_WRIST,
				XRBodyTracker.JOINT_RIGHT_SHOULDER, XRBodyTracker.JOINT_RIGHT_UPPER_ARM, XRBodyTracker.JOINT_RIGHT_LOWER_ARM, XRBodyTracker.JOINT_RIGHT_WRIST ]
				
var jointvrc = { XRBodyTracker.JOINT_HIPS:"Hips", XRBodyTracker.JOINT_SPINE:"Spine", XRBodyTracker.JOINT_CHEST:"Chest", XRBodyTracker.JOINT_NECK:"Neck",
				 XRBodyTracker.JOINT_LEFT_SHOULDER:"Left shoulder", XRBodyTracker.JOINT_LEFT_UPPER_ARM:"Left arm", 
				 XRBodyTracker.JOINT_LEFT_LOWER_ARM:"Left elbow", XRBodyTracker.JOINT_LEFT_WRIST:"Left wrist",
				 XRBodyTracker.JOINT_RIGHT_SHOULDER:"Right shoulder", XRBodyTracker.JOINT_RIGHT_UPPER_ARM:"Right arm", 
				 XRBodyTracker.JOINT_RIGHT_LOWER_ARM:"Right elbow", XRBodyTracker.JOINT_RIGHT_WRIST:"Right wrist"
				}

var roty180 = Basis().rotated(Vector3(0,1,0), rad_to_deg(180))
var roty90 = Basis().rotated(Vector3(0,1,0), rad_to_deg(90))
var jointsinverted =  { XRBodyTracker.JOINT_LEFT_UPPER_ARM:roty180, XRBodyTracker.JOINT_LEFT_LOWER_ARM:roty90, XRBodyTracker.JOINT_LEFT_WRIST:roty180,
						XRBodyTracker.JOINT_RIGHT_UPPER_ARM:roty90, XRBodyTracker.JOINT_RIGHT_LOWER_ARM:roty180, XRBodyTracker.JOINT_RIGHT_WRIST:roty90 }

func _ready():
	for ib in range(skel.get_bone_count()):
		skelbonerest[skel.get_bone_name(ib)] = skel.get_bone_rest(ib)
		prints(ib, skel.get_bone_name(ib))

var topbodydatfile = null
func _input(event):
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_M:
		topbodydatfile = FileAccess.open("res://data/topbody.dat", FileAccess.READ)


var dN = 0
func _process(delta):
	if topbodydatfile:
		dN += 1
		if dN < 5:
			return
		dN = 0
		var ttrackdata = topbodydatfile.get_var()
		if ttrackdata:
			_process_bodytrack(ttrackdata)
		else:
			topbodydatfile.close()
			topbodydatfile = null

	var xr_bodytracker = XRServer.get_tracker("/user/body_tracker")
	if xr_bodytracker == null:
		return
	var trackdata = { "delta":delta }
	for j in range(XRBodyTracker.JOINT_MAX):
		var jf = xr_bodytracker.get_joint_flags(j)
		if (jf & XRBodyTracker.JOINT_FLAG_POSITION_TRACKED) and (jf & XRBodyTracker.JOINT_FLAG_ORIENTATION_TRACKED):
			trackdata[j] = xr_bodytracker.get_joint_transform(j)
	if len(trackdata) > 1:
		_process_bodytrack(trackdata)
		if datlog:
			datlog.store_var(trackdata)
				
func _process_bodytrack(trackdata):
	for j in range(XRBodyTracker.JOINT_MAX):
		if trackdata.has(j):
			skeltrackertrans[j] = trackdata[j]
			if jointsinverted.has(j):
				skeltrackertrans[j].basis = skeltrackertrans[j].basis*jointsinverted[j]
			skeltrackertrans[j].origin = skeltrackertrans[j].origin/ascale

	var skelroot = skeltrackertrans.get(XRBodyTracker.JOINT_ROOT, Transform3D())
	skel.transform = Transform3D(skelroot.basis, skelroot.origin + Vector3(0,1,0))
	for j in range(XRBodyTracker.JOINT_MAX):
		if jointvrc.has(j) and skeltrackertrans.has(j):
			var i = skel.find_bone(jointvrc[j])
			var ip = skel.get_bone_parent(i)
			var parenttrans = skelroot*(skel.get_bone_global_pose(ip) if ip != -1 else Transform3D())
			var trans = parenttrans.inverse()*skeltrackertrans[j]
			#skel.set_bone_pose(i, trans)
			skel.set_bone_pose_rotation(i, Quaternion(trans.basis.orthonormalized()))

var datlog = null
func start_topbodylogging():
	var save_path = "user://topbody.dat"
	print("OS.get_data_dir ", OS.get_data_dir())
	print("*** starting top body logging")
	if OS.has_feature("android"):
		save_path = "/storage/emulated/0/Android/data/com.example.godotxrah/files/topbody.dat"
	datlog = FileAccess.open(save_path, FileAccess.WRITE)

func stop_topbodylogging():
	if datlog != null:
		datlog.close()
		datlog = null
		print("*** stopped top body logging")
