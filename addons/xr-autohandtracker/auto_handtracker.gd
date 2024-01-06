extends Node3D

# Settings that can be changed dynamically in the debugger to 
# see how they alter the mapping to the hand skeleton
@export var applymiddlefingerfix : bool = true
@export var applyscaling : bool = true
@export var coincidewristorknuckle : bool = true
@export var visiblehandtrackskeleton : bool = true

# Hand tracking data access object
var xr_interface : OpenXRInterface

# Local origin for the hand tracking positions
var xr_origin : XROrigin3D

# Objects needed only to handle the actions and signals
var xr_controller_node : XRController3D = null
var tracker_hand : XRPositionalTracker.TrackerHand = XRPositionalTracker.TrackerHand.TRACKER_HAND_UNKNOWN
var xr_tracker_hand : XRPositionalTracker = null

# Note the discrepancy in the enumerations where 
#   XRPositionalTracker.TrackerHand : { Left=1, Right=2 }
#   OpenXRInterface.Hand : { Left=0, Right=1 }
var hand : OpenXRInterface.Hand
var tracker_name : String 
var handtrackingactive = false

var handnode = null
var skel = null

# values calculated from the hand skeleton itself
var handtoskeltransform
var wristboneindex
var wristboneresttransform
var hstw
var fingerboneindexes
var fingerboneresttransforms

static func basisfromA(a, v):
	var vx = a.normalized()
	var vy = vx.cross(v.normalized())
	var vz = vx.cross(vy)
	return Basis(vx, vy, vz)

static func rotationtoalignB(a, b, va, vb):
	return basisfromA(b, vb)*basisfromA(a, va).inverse()

static func rotationtoalignScaled(a, b):
	var axis = a.cross(b).normalized()
	var sca = b.length()/a.length()
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads).scaled(Vector3(sca,sca,sca))
	return Basis().scaled(Vector3(sca,sca,sca))


func extractrestfingerbones():
	print(handnode.name)
	var lr = "L" if hand == 0 else "R"
	handtoskeltransform = handnode.global_transform.inverse()*skel.global_transform
	wristboneindex = skel.find_bone("Wrist_" + lr)
	wristboneresttransform = skel.get_bone_rest(wristboneindex)
	hstw = handtoskeltransform * wristboneresttransform
	fingerboneindexes = [ ]
	fingerboneresttransforms = [ ]
	for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		fingerboneindexes.push_back([ ])
		fingerboneresttransforms.push_back([ ])
		for b in ["Metacarpal", "Proximal", "Intermediate", "Distal", "Tip"]:
			var name = f + "_" + b + "_" + lr
			var ix = skel.find_bone(name)
			if ix != -1:
				fingerboneindexes[-1].push_back(ix)
				fingerboneresttransforms[-1].push_back(skel.get_bone_rest(ix) if ix != -1 else null)
			else:
				assert (f == "Thumb" and b == "Intermediate")

func findxrnodes():
	# first go up the tree to find the controller and origin
	var nd = self
	while nd != null and not (nd is XRController3D):
		nd = nd.get_parent()
	if nd == null:
		print("Warning, no controller node detected")
		return false
	xr_controller_node = nd
	while nd != null and not (nd is XROrigin3D):
		nd = nd.get_parent()
	if nd == null:
		print("Warning, no xrorigin node detected")
		return false
	xr_origin = nd

	# Then look for the hand skeleton that we are going to map to
	for ch in xr_controller_node.get_children():
		if ch.has_node("AnimationTree"):
			handnode = ch
	if handnode == null:
		print("Warning, no handnode (mesh and animationtree) detected")
		return false
	skel = handnode.find_child("Skeleton3D")
	if skel == null:
		print("Warning, no Skeleton3D found")
		return false

	# Finally decide if it is left or right hand and test consistency in the API
	tracker_hand = xr_controller_node.get_tracker_hand()
	tracker_name = xr_controller_node.tracker
	var islefthand = (tracker_hand == XRPositionalTracker.TrackerHand.TRACKER_HAND_LEFT)
	assert (tracker_name == ("left_hand" if islefthand else "right_hand"))
	hand = OpenXRInterface.Hand.HAND_LEFT if islefthand else OpenXRInterface.Hand.HAND_RIGHT

	print("All nodes for %s detected" % tracker_name)
	return true

func findxrtrackerobjects():
	xr_interface = XRServer.find_interface("OpenXR")
	#var trackers1 = XRServer.get_trackers(1)
	#xr_tracker_head = trackers1["head"]
	var trackers2 = XRServer.get_trackers(2)
	xr_tracker_hand = trackers2.get(tracker_name)
	if xr_tracker_hand == null:
		return false
	assert (xr_tracker_hand.hand == tracker_hand) 
	if xr_interface:
		print("action_sets: ", xr_interface.get_action_sets())
	xr_tracker_hand.button_pressed.connect(_button_signal.bind(hand, true))
	xr_tracker_hand.button_released.connect(_button_signal.bind(hand, false))
	#xr_tracker_hands.input_float_changed.connect(_input_float_changed.bind(hand))
	#xr_tracker_hands.input_vector2_changed.connect(_input_vector2_changed.bind(hand))
	return true

func _button_signal(name, hand, pressed):
	print("buttonsignal ", hand, " ", name, " ", pressed)

func _ready():
	var xrnodesfound = findxrnodes()
	if xrnodesfound:
		extractrestfingerbones()
		createvisiblehandskeleton()
	var xctrackerobjectsfound = findxrtrackerobjects()
	set_process(xrnodesfound and xctrackerobjectsfound)

func getoxrjointpositions():
	var oxrjps = [ ]
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		oxrjps.push_back(xr_interface.get_hand_joint_position(hand, j))

	if applymiddlefingerfix:
		for j in [ OpenXRInterface.HAND_JOINT_MIDDLE_TIP, OpenXRInterface.HAND_JOINT_RING_TIP ]:
			var b = Basis(xr_interface.get_hand_joint_rotation(hand, j))
			oxrjps[j] += -0.01*b.y + 0.005*b.z
	
	return oxrjps

func calchandnodetransform(oxrjps, xrt):
	# solve for handnodetransform where
	# avatarwristtrans = handnode.get_parent().global_transform * handnodetransform * handtoskeltransform * wristboneresttransform
	# avatarwristpos = avatarwristtrans.origin
	# avatarmiddleknucklepos = avatarwristtrans * fingerboneresttransforms[2][0] * fingerboneresttransforms[2][1]
	# handwrist = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_WRIST]
	# handmiddleknuckle = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL]
	#  so that avatarwristpos->avatarmiddleknucklepos is aligned along handwrist->handmiddleknuckle
	#  and rotated so that the line between index and ring knuckles are in the same plane
	
	# We want skel.global_transform*wristboneresttransform to have origin xrorigintransform*gg[OpenXRInterface.HAND_JOINT_WRIST].origin
	var wristorigin = xrt*oxrjps[OpenXRInterface.HAND_JOINT_WRIST]

	var middleknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL]
	var leftknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_RING_PROXIMAL if hand == 0 else OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL]
	var rightknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL if hand == 0 else OpenXRInterface.HAND_JOINT_RING_PROXIMAL]

	var middlerestreltransform = fingerboneresttransforms[2][0] * fingerboneresttransforms[2][1]
	var leftrestreltransform = fingerboneresttransforms[3 if hand == 0 else 1][0] * fingerboneresttransforms[3 if hand == 0 else 1][1]
	var rightrestreltransform = fingerboneresttransforms[1 if hand == 0 else 3][0] * fingerboneresttransforms[1 if hand == 0 else 3][1]
	
	var m2g1 = middlerestreltransform
	var skelmiddleknuckle = handnode.transform * hstw * middlerestreltransform

	var m2g1g3 = leftrestreltransform.origin - rightrestreltransform.origin
	var hnbasis = rotationtoalignB(hstw.basis*m2g1.origin, middleknuckle - wristorigin, 
							hstw.basis*m2g1g3, leftknuckle - rightknuckle)

	var hnorigin = wristorigin - hnbasis*hstw.origin
	if not coincidewristorknuckle:
		hnorigin = middleknuckle - hnbasis*(hstw*middlerestreltransform).origin


	return Transform3D(hnbasis, hnorigin)
		
func calcboneposes(oxrjps, handnodetransform, xrt):
	var fingerbonetransformsOut = fingerboneresttransforms.duplicate(true)
	for f in range(5):
		var mfg = handnodetransform * hstw
		# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
		for i in range(len(fingerboneresttransforms[f])-1):
			mfg = mfg*fingerboneresttransforms[f][i]
			# (tIbasis,atIorigin)*fingerboneresttransforms[f][i+1]).origin = mfg.inverse()*kpositions[f][i+1]
			# tIbasis*fingerboneresttransforms[f][i+1] = mfg.inverse()*kpositions[f][i+1] - atIorigin
			var atIorigin = Vector3(0,0,0)  
			var kpositionsfip1 = xrt*oxrjps[carpallist[f] + i+1]
			var tIbasis = rotationtoalignScaled(fingerboneresttransforms[f][i+1].origin, mfg.affine_inverse()*kpositionsfip1 - atIorigin)
			var tIorigin = mfg.affine_inverse()*kpositionsfip1 - tIbasis*fingerboneresttransforms[f][i+1].origin # should be 0
			var tI = Transform3D(tIbasis, tIorigin)
			fingerbonetransformsOut[f][i] = fingerboneresttransforms[f][i]*tI
			mfg = mfg*tI
	return fingerbonetransformsOut

func copyouttransformstoskel(fingerbonetransformsOut):
	for f in range(len(fingerboneindexes)):
		for i in range(len(fingerboneindexes[f])):
			var ix = fingerboneindexes[f][i]
			var t = fingerbonetransformsOut[f][i]
			skel.set_bone_pose_rotation(ix, t.basis.get_rotation_quaternion())
			if not applyscaling:
				t = fingerboneresttransforms[f][i]
			skel.set_bone_pose_position(ix, t.origin)
			skel.set_bone_pose_scale(ix, t.basis.get_scale())


func _process(delta):
	var handjointflagswrist = xr_interface.get_hand_joint_flags(hand, OpenXRInterface.HAND_JOINT_WRIST);
	var lhandtrackingactive = (handjointflagswrist & OpenXRInterface.HAND_JOINT_POSITION_VALID) != 0
	if handtrackingactive != lhandtrackingactive:
		handtrackingactive = lhandtrackingactive
		handnode.top_level = handtrackingactive
		handnode.get_node("AnimationTree").active = not handtrackingactive
		print("setting hand "+str(hand)+" active: ", handtrackingactive)
		$VisibleHandTrackSkeleton.visible = visiblehandtrackskeleton and handtrackingactive
	if handtrackingactive:
		var oxrjps = getoxrjointpositions()
		var xrt = xr_origin.global_transform
		var handnodetransform = calchandnodetransform(oxrjps, xrt)
		var fingerbonetransformsOut = calcboneposes(oxrjps, handnodetransform, xrt)
		handnode.transform = handnodetransform
		copyouttransformstoskel(fingerbonetransformsOut)
		if visible and $VisibleHandTrackSkeleton.visible:
			updatevisiblehandskeleton(oxrjps)

	
const carpallist = [ OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL ]


const hjsticks = [ [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL, OpenXRInterface.HAND_JOINT_THUMB_DISTAL, OpenXRInterface.HAND_JOINT_THUMB_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL, OpenXRInterface.HAND_JOINT_INDEX_INTERMEDIATE, OpenXRInterface.HAND_JOINT_INDEX_DISTAL, OpenXRInterface.HAND_JOINT_INDEX_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL, OpenXRInterface.HAND_JOINT_MIDDLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_MIDDLE_DISTAL, OpenXRInterface.HAND_JOINT_MIDDLE_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_RING_PROXIMAL, OpenXRInterface.HAND_JOINT_RING_INTERMEDIATE, OpenXRInterface.HAND_JOINT_RING_DISTAL, OpenXRInterface.HAND_JOINT_RING_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_PROXIMAL, OpenXRInterface.HAND_JOINT_LITTLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_LITTLE_DISTAL, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]
			   ]
func createvisiblehandskeleton():
	var sticknode = $VisibleHandTrackSkeleton/ExampleStick
	$VisibleHandTrackSkeleton.remove_child(sticknode)
	var jointnode = $VisibleHandTrackSkeleton/ExampleJoint
	$VisibleHandTrackSkeleton.remove_child(jointnode)
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		var rj = jointnode.duplicate()
		rj.name = "J%d" % j
		rj.scale = Vector3(0.01, 0.01, 0.01)
		$VisibleHandTrackSkeleton.add_child(rj)

	for hjstick in hjsticks:
		for i in range(0, len(hjstick)-1):
			var rstick = sticknode.duplicate()
			var j1 = hjstick[i]
			var j2 = hjstick[i+1]
			rstick.name = "S%d_%d" % [j1, j2]
			rstick.scale = Vector3(0.01, 0.01, 0.01)
			$VisibleHandTrackSkeleton.add_child(rstick)
			#$VisibleHandTrackSkeleton.get_node("J%d" % hjstick[i+1]).get_node("Sphere").visible = (i > 0)

func rotationtoalign(a, b):
	var axis = a.cross(b).normalized();
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads)
	return Basis()

func sticktransform(j1, j2):
	var b = rotationtoalign(Vector3(0,1,0), j2 - j1)
	var d = (j2 - j1).length()
	return Transform3D(b, (j1 + j2)*0.5).scaled_local(Vector3(0.01, d, 0.01))

func updatevisiblehandskeleton(oxrjps):
	var xrt = xr_origin.global_transform
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		var jrot = xr_interface.get_hand_joint_rotation(hand, j)
		$VisibleHandTrackSkeleton.get_node("J%d" % j).global_transform = Transform3D(xrt.basis*Basis(jrot).scaled(Vector3(0.01, 0.01, 0.01)), xrt*oxrjps[j])

	for hjstick in hjsticks:
		for i in range(0, len(hjstick)-1):
			var j1 = hjstick[i]
			var j2 = hjstick[i+1]
			var rstick = $VisibleHandTrackSkeleton.get_node("S%d_%d" % [j1, j2])
			rstick.global_transform = sticktransform(xrt*oxrjps[j1], xrt*oxrjps[j2])
			

