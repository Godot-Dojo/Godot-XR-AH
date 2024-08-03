@tool
extends Node3D

# Settings that can be changed dynamically in the debugger to 
# see how they alter the mapping to the hand skeleton
@export var applymiddlefingerfix : bool = true
@export var applyscaling : bool = true
@export var coincidewristorknuckle : bool = true
@export var visiblehandtrackskeleton : bool = true
@export var visiblehandtrackskeletonRaw : bool = false
@export var enableautotracker : bool = true
@export var controllersourcefingertracking : bool = true

# Hand tracking data access object
var xr_interface : OpenXRInterface

# Local origin for the hand tracking positions
var xr_origin : XROrigin3D

# Controller and its tracker with the aim pose that we can use when hand-tracking active
var xr_controller_node : XRController3D = null
var tracker_nhand : XRPositionalTracker.TrackerHand = XRPositionalTracker.TrackerHand.TRACKER_HAND_UNKNOWN
var xr_controllertracker : XRPositionalTracker = null
var xr_handtracker : XRPositionalTracker = null
var xr_aimpose : XRPose = null
var xr_headtracker : XRPositionalTracker = null
var xr_camera_node : XRCamera3D = null



# Note the that the enumerations disagree
# XRPositionalTracker.TrackerHand.TRACKER_HAND_LEFT = 1 
# OpenXRInterface.Hand.HAND_LEFT = 0
var hand : OpenXRInterface.Hand
var tracker_name : String 
var handtrackingsource = HAND_TRACKED_SOURCE_UNKNOWN
var handtracker_name : String

# readings from OpenXR interface that can be pre-calculated by OpenXRHandData
var handtrackingactive = false
var handtrackingvalid = false
var oxrktransRaw = [ ]
var oxrktrans = [ ]
var oxrktransRaw_updated = false
var oxrktrans_updated = false
var oxrkradii = [ ]


# Copied out from OpenXRInterface.HandTrackedSource so it works on v4.2
const HAND_TRACKED_SOURCE_UNKNOWN = 0
const HAND_TRACKED_SOURCE_UNOBSTRUCTED = 1
const HAND_TRACKED_SOURCE_CONTROLLER = 2

var handnode = null
var skel = null
var handanimationtree = null

# values calculated from the hand skeleton itself
var handtoskeltransform
var wristboneindex
var wristboneresttransform
var hstw

var fingerboneindexes = [ ]
var fingerboneresttransforms = [ ]
var fingerbonescales = [ ]
var bYalignedAxes = false

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

#tIbasis = rotationtoalignScaled(fingerboneresttransforms[f][i+1].origin, mfg.affine_inverse()*kpositionsfip1 - atIorigin)
#var tIorigin = mfg.affine_inverse()*kpositionsfip1 - tIbasis*fingerboneresttransforms[f][i+1].origin # should be 0
#solve: 
#	mfg.affine_inverse()*kpositionsfip1 = tIbasis*Vector3(0,l,0) 

static func realignfingerbases(oxrktrans):
	for f in range(FINGERCOUNT):
		for i in range(3 if f == 0 else 4):
			var t0 = oxrktrans[carpallist[f]+i]
			var t1 = oxrktrans[carpallist[f]+i+1]
			var vec = t1.origin - t0.origin
			prints("frfr", t0.basis.y.length(), vec.dot(t0.basis.y), vec.dot(t0.basis.x), vec.dot(t0.basis.z))


func extractrestfingerbones():
	print(handnode.name)
	var lr = "L" if hand == 0 else "R"
	handtoskeltransform = handnode.global_transform.inverse()*skel.global_transform
	wristboneindex = skel.find_bone("Wrist_" + lr)
	wristboneresttransform = skel.get_bone_rest(wristboneindex)
	hstw = handtoskeltransform * wristboneresttransform
	assert (len(fingerboneindexes) == 0 and len(fingerboneresttransforms) == 0)
	for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		fingerboneindexes.push_back([ ])
		fingerboneresttransforms.push_back([ ])
		for b in ["Metacarpal", "Proximal", "Intermediate", "Distal", "Tip"]:
			var name = f + "_" + b + "_" + lr
			var ix = skel.find_bone(name)
			if ix != -1:
				fingerboneindexes[-1].push_back(ix)
				fingerboneresttransforms[-1].push_back(skel.get_bone_rest(ix))
			else:
				assert (f == "Thumb" and b == "Intermediate")

func _xr_controller_node_tracking_changed(tracking):
	var xr_pose = xr_controller_node.get_pose()
	print("_xr_controller_node_tracking_changed ", xr_pose.name if xr_pose else "<none>")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not (get_parent() is XRController3D):
		warnings.append("This node must be a child of an XRController3D node")
	return warnings

func findxrnodes():
	var nd = get_parent()
	if not (nd is XRController3D):
		push_error("Autohand not a child of XRController3D")
		return false
	xr_controller_node = nd
	tracker_nhand = xr_controller_node.get_tracker_hand()
	tracker_name = xr_controller_node.tracker
	xr_controller_node.tracking_changed.connect(_xr_controller_node_tracking_changed)
	nd = nd.get_parent()
	if not (nd is XROrigin3D):
		push_error("XRController3D not child of XROrigin3D")
		return false
	xr_origin = nd

	# Then look for the hand skeleton that we are going to map to
	for cch in xr_origin.get_children():
		if cch is XRCamera3D:
			xr_camera_node = cch

	# Finally decide if it is left or right hand and test consistency in the API
	var islefthand = (tracker_name == "left_hand")
	assert (tracker_name == ("left_hand" if islefthand else "right_hand"))
	hand = OpenXRInterface.Hand.HAND_LEFT if islefthand else OpenXRInterface.Hand.HAND_RIGHT

	print("All nodes for %s detected" % tracker_name)
	return true

func findhandnodes():
	if xr_controller_node == null:
		return
	for ch in xr_controller_node.get_children():
		var lskel = ch.find_child("Skeleton3D")
		if lskel:
			if lskel.get_bone_count() == 26:
				handnode = ch
			else:
				print("unrecognized skeleton in controller")
	if handnode == null:
		print("Warning, no handnode (mesh and animationtree) detected")
		return false
	skel = handnode.find_child("Skeleton3D")
	if skel == null:
		print("Warning, no Skeleton3D found")
		return false
	handanimationtree = handnode.get_node_or_null("AnimationTree")
	extractrestfingerbones()
	
func findxrtrackerobjects():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		return
	
	var tracker_name = xr_controller_node.tracker
	xr_controllertracker = XRServer.get_tracker(tracker_name)
	if xr_controllertracker == null:
		return
	assert (xr_controllertracker.hand == tracker_nhand)
	assert (tracker_nhand == XRPositionalTracker.TRACKER_HAND_LEFT or tracker_nhand == XRPositionalTracker.TRACKER_HAND_RIGHT)
	print(xr_controllertracker.description, " ", xr_controllertracker.hand, " ", xr_controllertracker.name, " ", xr_controllertracker.profile, " ", xr_controllertracker.type)

	xr_headtracker = XRServer.get_tracker("head")
	var islefthand = (tracker_name == "left_hand")
	assert (tracker_nhand == (XRPositionalTracker.TrackerHand.TRACKER_HAND_LEFT if islefthand else XRPositionalTracker.TrackerHand.TRACKER_HAND_RIGHT))
	print(tracker_name, "  ", tracker_nhand)
	handtracker_name = "/user/hand_tracker/left" if islefthand else "/user/hand_tracker/right"
	print("action_sets: ", xr_interface.get_action_sets())
	$AutoTracker.setupautotracker(tracker_nhand, islefthand, xr_controller_node)


func _ready():
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		oxrktransRaw.push_back(Transform3D())
		oxrktrans.push_back(Transform3D())
		oxrkradii.push_back(0.0) 
	oxrktrans_updated = false

	findxrnodes()
	findxrtrackerobjects()

	# As a transform we are effectively reparenting ourselves directly under the XROrigin3D
	if xr_origin != null:
		var rt = RemoteTransform3D.new()
		rt.remote_path = get_path()
		xr_origin.add_child.call_deferred(rt)

	findhandnodes()
	set_process(xr_interface != null)
	
func fixmiddlefingerpositions(oxrktrans):
	for j in [ OpenXRInterface.HAND_JOINT_MIDDLE_TIP, OpenXRInterface.HAND_JOINT_RING_TIP ]:
		var b = oxrktrans[j].basis
		oxrktrans[j].origin += -0.01*b.y + 0.005*b.z

func update_oxrktransRaw():
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		oxrktransRaw[j] = xr_handtracker.get_hand_joint_transform(j)

func calchandnodetransform(oxrktrans, xrt):
	# solve for handnodetransform where
	# avatarwristtrans = handnode.get_parent().global_transform * handnodetransform * handtoskeltransform * wristboneresttransform
	# avatarwristpos = avatarwristtrans.origin
	# avatarmiddleknucklepos = avatarwristtrans * fingerboneresttransforms[2][0] * fingerboneresttransforms[2][1]
	# handwrist = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_WRIST]
	# handmiddleknuckle = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL]
	#  so that avatarwristpos->avatarmiddleknucklepos is aligned along handwrist->handmiddleknuckle
	#  and rotated so that the line between index and ring knuckles are in the same plane
	
	# We want skel.global_transform*wristboneresttransform to have origin xrorigintransform*gg[OpenXRInterface.HAND_JOINT_WRIST].origin
	var wristorigin = xrt*oxrktrans[OpenXRInterface.HAND_JOINT_WRIST].origin

	var middleknuckle = xrt*oxrktrans[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL].origin
	var leftknuckle = xrt*oxrktrans[OpenXRInterface.HAND_JOINT_RING_PROXIMAL if hand == 0 else OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL].origin
	var rightknuckle = xrt*oxrktrans[OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL if hand == 0 else OpenXRInterface.HAND_JOINT_RING_PROXIMAL].origin

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
		
const carpallist = [ OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, 
					OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, 
					OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL ]
const FINGERCOUNT = 5
func calcboneposes(oxrktrans, handnodetransform, xrt):
	var fingerbonetransformsOut = fingerboneresttransforms.duplicate(true)
	for f in range(FINGERCOUNT):
		var mfg = handnodetransform * hstw
		# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
		for i in range(len(fingerboneresttransforms[f])-1):
			mfg = mfg*fingerboneresttransforms[f][i]
			# (tIbasis,atIorigin)*fingerboneresttransforms[f][i+1]).origin = mfg.inverse()*kpositions[f][i+1]
			# tIbasis*fingerboneresttransforms[f][i+1] = mfg.inverse()*kpositions[f][i+1] - atIorigin
			var atIorigin = Vector3(0,0,0)  
			var kpositionsfip1 = xrt*oxrktrans[carpallist[f] + i+1].origin
			var tIbasis = rotationtoalignScaled(fingerboneresttransforms[f][i+1].origin, mfg.affine_inverse()*kpositionsfip1 - atIorigin)
			var tIorigin = mfg.affine_inverse()*kpositionsfip1 - tIbasis*fingerboneresttransforms[f][i+1].origin # should be 0
			var tI = Transform3D(tIbasis, tIorigin)
			fingerbonetransformsOut[f][i] = fingerboneresttransforms[f][i]*tI
			mfg = mfg*tI
	return fingerbonetransformsOut

static func rotationtoalignUnScaled(a, b):
	assert (is_zero_approx(a.x) and is_zero_approx(a.z))
	var axis = a.cross(b).normalized()
	var rot = Basis()
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		rot = Basis(axis, angle_rads)
	return rot

# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)

# A.origin = B.origin - A.basis*B.origin

func calcboneposesScaledInY(oxrktrans, handnodetransform, xrt):
	var fingerbonetransformsOut = fingerboneresttransforms.duplicate(true)
	for f in range(FINGERCOUNT):
		var mfg = handnodetransform * hstw
		# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
		var tIscalebasisprevInv = Basis()
		#print(" ---- ", handnodetransform.basis.get_scale(), hstw.basis.get_scale())
		for i in range(len(fingerboneresttransforms[f])-1):
			var kpositionsfip0 = xrt*oxrktrans[carpallist[f] + i].origin
			var kpositionsfip1 = xrt*oxrktrans[carpallist[f] + i+1].origin
			var mfgS = mfg*Transform3D(tIscalebasisprevInv, Vector3())
			var mfgR = mfgS*fingerboneresttransforms[f][i]
			var mfgRinv = mfgR.affine_inverse()
			print(f, " ", i, " sss ", kpositionsfip0 - mfg*fingerboneresttransforms[f][i].origin, fingerboneresttransforms[f][i].origin)

			# (tIbasis,atIorigin)*fingerboneresttransforms[f][i+1]).origin = mfg.inverse()*kpositions[f][i+1]
			# tIbasis*fingerboneresttransforms[f][i+1] = mfg.inverse()*kpositions[f][i+1] - atIorigin

			var bonerestvec = fingerboneresttransforms[f][i+1].origin
			assert (is_zero_approx(bonerestvec.x) and is_zero_approx(bonerestvec.z))
			var bonetargetvec = mfgRinv*kpositionsfip1
			#var bonetargetvec = mfgRinv.origin + mfgRinv.basis*kpositionsfip1
			var tIbasisUnscaled = rotationtoalignUnScaled(bonerestvec, bonetargetvec)
			
			#bonetargetvec = rotationtoalignUnScaled(bonerestvec, bonetargetvec)* (tIscalebasis*bonerestvec = (0,y,0))
			
			var sca = bonetargetvec.length()/bonerestvec.length()
			var tIscalebasis = Basis().scaled(Vector3(1.0, sca, 1.0))
			var tIbasis = tIbasisUnscaled*tIscalebasis
			var tIorigin = mfgRinv*kpositionsfip1 - tIbasis*bonerestvec # should be 0
			assert (tIorigin.length() < 0.001)
			var tI = Transform3D(tIbasis, tIorigin)

			var fingerbonetransformsOutS = Transform3D(fingerboneresttransforms[f][i].basis*tIbasisUnscaled*tIscalebasis, fingerboneresttransforms[f][i].origin)
			#fingerbonetransformsOutS = fingerboneresttransforms[f][i]*tI
			fingerbonetransformsOut[f][i] = mfg.affine_inverse()*mfgS*fingerbonetransformsOutS

			var mfg1 = mfg*fingerbonetransformsOut[f][i]

#mfg1*fingerboneresttransforms[f][i+1].origin

#mfg*(0,ly,0) == mfg.origin + mfg.basis*(0,ly,0)
#mfg = (mfg.basis*fingerbonetransformsOut[f][i].basis,
#		mfg.origin + mfg.basis*fingerbonetransformsOut[f][i].origin)

#kpositionsfip0 - mfg*fingerboneresttransforms[f][i].origin
#kpositionsfip1 - mfg1*fingerboneresttransforms[f][i+1].origin
#mfg1 = mfg*fingerbonetransformsOut[f][i]

#kpositionsfip0 - mfg1.origin   # wrong
#kpositionsfip0 - (mfg*fingerbonetransformsOut[f][i]).origin
#kpositionsfip0 - (mfgS*fingerbonetransformsOutS).origin
#kpositionsfip0 - (mfgS.origin + mfgS.basis*fingerbonetransformsOutS.origin)
#kpositionsfip0 - (mfg.origin + mfgS.basis*fingerboneresttransforms[f][i].origin)
#kpositionsfip0 - (mfg.origin + mfg.basis*tIscalebasisprevInv*fingerboneresttransforms[f][i].origin)

#kpositionsfip0 - mfg*fingerboneresttransforms[f][i].origin   # right
#kpositionsfip0 - (mfg.origin + mfg.basis*fingerboneresttransforms[f][i].origin)


#			print(f, " ", i, " ", sca, " ssk ", kpositionsfip1 - mfg1*fingerboneresttransforms[f][i+1].origin, kpositionsfip0 - mfg1.origin, kpositionsfip0 - mfg*fingerboneresttransforms[f][i].origin)
#			print(f, " ", i, " ", sca, " ssk ", kpositionsfip1 - mfg1*fingerboneresttransforms[f][i+1].origin, kpositionsfip0 - mfg1.origin, kpositionsfip0 - (mfg.origin + mfg.basis*tIscalebasisprevInv*fingerboneresttransforms[f][i].origin))
			mfg = mfg1
			tIscalebasisprevInv = Basis().scaled(Vector3(1.0, 1.0/1.0, 1.0))
			
	return fingerbonetransformsOut

func DcalcboneposesScaledInY(oxrktrans, handnodetransform, xrt):
	var fingerbonetransformsOut = fingerboneresttransforms.duplicate(true)
	for f in range(FINGERCOUNT):
		var mfg = handnodetransform * hstw
		for i in range(len(fingerboneresttransforms[f])-1):
			var kpositionsfip0 = xrt*oxrktrans[carpallist[f] + i].origin
			var bonerestvec0 = fingerboneresttransforms[f][i].origin
			var kpos0 = mfg*bonerestvec0 # the spot we are at
			#var kpos0 = mfg.origin + mfg.basis*bonerestvec0 # the spot we are at
			# if i != 0 then kpos0 = kpositionsfip0
			var kpositionsfip1 = xrt*oxrktrans[carpallist[f] + i+1].origin # the spot we want to go to
			var bonerestvec1 = fingerboneresttransforms[f][i+1].origin # (0,ly,0)
			assert (is_zero_approx(bonerestvec1.x) and is_zero_approx(bonerestvec1.z))
			var bonetargetvec1 = kpositionsfip1 - kpos0
			var bonetargetvec1len = bonetargetvec1.length()
			var sca = bonetargetvec1len/bonerestvec1.length()
			
			# we need to find mfg1 (transform for the next bone) such that 
			# kpositionsfip1 = mfg1*bonerestvec1 = mfg1.origin + mfg1.basis*bonerestvec1
			# and mfg1.basis = rot*Basis(1,sca,1)
			# and mfg1 = mfg*fingerbonetransformsOut[f][i]
			# where fingerbonetransformsOut[f][i] = (b, bonerestvec0)
			# so mfg1.basis = mfg.basis*b
			# and mfg1.origin = mfg.origin + mfg.basis*bonerestvec0
			# therefore kpositionsfip1 = mfg.origin + mfg.basis*bonerestvec0 + mfg1.basis*bonerestvec1
			# so mfg1.basis*bonerestvec1 = kpositionsfip1 - mfg.origin - mfg.basis*bonerestvec0
			# so mfg1.basis*bonerestvec1 = kpositionsfip1 - kpos0
			var ktarg = bonetargetvec1.normalized()
			#var Drot = rotationtoalignUnScaled(bonerestvec1, bonetargetvec1)
			
			var mfgrest1basis = mfg.basis*fingerboneresttransforms[f][i].basis
			mfgrest1basis = mfgrest1basis.orthonormalized()
			var roty = bonetargetvec1*(1.0/bonetargetvec1len)  # normalized
			var rotz = (mfgrest1basis.x.cross(roty)).normalized()
			var rotx = roty.cross(rotz)
			#var rot = Basis(rotx, roty, rotz)
			var mfg1origin = mfg.origin + mfg.basis*bonerestvec0
			var mfg1basis = Basis(rotx, roty*sca, rotz)
			
			var mfg1 = Transform3D(mfg1basis, mfg1origin)
			fingerbonetransformsOut[f][i] = mfg.affine_inverse()*mfg1
			mfg = mfg1  # mfg*fingerbonetransformsOut[f][i]
			
	return fingerbonetransformsOut


func calcfingerbonescales(oxrktrans):
	assert (len(fingerbonescales) == 0)
	bYalignedAxes = true
	for f in range(5):
		fingerbonescales.push_back([ 1.0 ])
		for i in range(len(fingerboneresttransforms[f])-1):
			var restvec = fingerboneresttransforms[f][i+1].origin
			if not is_zero_approx(restvec.x) or not is_zero_approx(restvec.z):
				bYalignedAxes = false
			var restlength = restvec.length()
			var measuredlength = (oxrktrans[carpallist[f] + i+1].origin - oxrktrans[carpallist[f] + i].origin).length()
			if measuredlength == 0.0:
				fingerbonescales = [ ]
				print("bad zero reading in calcfingerbonescales")
				bYalignedAxes = false
				return
			fingerbonescales[-1].push_back(measuredlength/restlength)
	prints("fingerbonescales", fingerbonescales)
	prints("bYalignedAxes", bYalignedAxes)

func copyouttransformstoskel(fingerbonetransformsOut):
	for f in range(len(fingerboneindexes)):
		for i in range(len(fingerboneindexes[f])):
			var ix = fingerboneindexes[f][i]
			var t = fingerbonetransformsOut[f][i]
			assert (ix >= 0 and ix < skel.get_bone_count())
			if not applyscaling:
				skel.set_bone_pose_rotation(ix, t.basis.get_rotation_quaternion())
				t = fingerboneresttransforms[f][i]
				skel.set_bone_pose_position(ix, t.origin)
				skel.set_bone_pose_scale(ix, t.basis.get_scale())
			else:
				skel.set_bone_pose(ix, t)

func process_handtrackingsource():
	if xr_handtracker == null:
		xr_handtracker = XRServer.get_tracker(handtracker_name)
		if xr_handtracker == null:
			handtrackingactive = false
			handtrackingvalid = false
			return
			
	var lhandtrackingsource = xr_handtracker.get_hand_tracking_source()
	if handtrackingsource != lhandtrackingsource:
		handtrackingsource = lhandtrackingsource
		handtrackingactive = (handtrackingsource == HAND_TRACKED_SOURCE_UNOBSTRUCTED) or (controllersourcefingertracking and (handtrackingsource == HAND_TRACKED_SOURCE_CONTROLLER))
		handnode.top_level = handtrackingactive
		if handanimationtree:
			handanimationtree.active = not handtrackingactive
		print("setting hand tracking source "+str(hand)+": ", handtrackingsource)
		if handtrackingsource == HAND_TRACKED_SOURCE_UNOBSTRUCTED:
			if enableautotracker:
				$AutoTracker.activateautotracker(xr_controller_node)
		else:
			if $AutoTracker.autotrackeractive:
				$AutoTracker.deactivateautotracker(xr_controller_node, xr_controllertracker)
			handnode.transform = Transform3D()

		for j in range(OpenXRInterface.HAND_JOINT_MAX):
			oxrkradii[j] = xr_handtracker.get_hand_joint_radius(j)

	handtrackingvalid = handtrackingactive and ((xr_handtracker.get_hand_joint_flags(OpenXRInterface.HAND_JOINT_WRIST) & OpenXRInterface.HAND_JOINT_POSITION_VALID) != 0)
	$VisibleHandTrackSkeleton.visible = visiblehandtrackskeleton and handtrackingvalid
	
	
func _process(delta):
	if not oxrktransRaw_updated:
		process_handtrackingsource()
	if not handtrackingvalid:
		return
	if not oxrktrans_updated:
		if not oxrktransRaw_updated:
			update_oxrktransRaw()
			oxrktransRaw_updated = true
		for j in range(OpenXRInterface.HAND_JOINT_MAX):
			oxrktrans[j] = oxrktransRaw[j]
		oxrktransRaw_updated = false
		oxrktrans_updated = true

	if oxrktrans_updated and len(fingerbonescales) == 0:  # should be on the raw update
		calcfingerbonescales(oxrktransRaw)
		

	var xrt = xr_origin.global_transform
	if $AutoTracker.autotrackeractive:
		$AutoTracker.autotrackgestures(oxrktrans, xrt, xr_camera_node)
	if applymiddlefingerfix:
		fixmiddlefingerpositions(oxrktrans)
	var handnodetransform = calchandnodetransform(oxrktrans, xrt)
	var fingerbonetransformsOut = DcalcboneposesScaledInY(oxrktrans, handnodetransform, xrt) if bYalignedAxes else calcboneposes(oxrktrans, handnodetransform, xrt)
	handnode.transform = handnodetransform
	copyouttransformstoskel(fingerbonetransformsOut)
	if visible and $VisibleHandTrackSkeleton.visible:
		$VisibleHandTrackSkeleton.updatevisiblehandskeleton(oxrktransRaw if visiblehandtrackskeletonRaw else oxrktrans, xrt)

	if xr_aimpose == null and xr_controllertracker != null:
		xr_aimpose = xr_controllertracker.get_pose("aim")
		print("...xr_aimpose ", xr_aimpose)
	if xr_aimpose != null and $AutoTracker.autotrackeractive:
		$AutoTracker.xr_autotracker.set_pose(xr_controller_node.pose, xr_aimpose.transform, xr_aimpose.linear_velocity, xr_aimpose.angular_velocity, xr_aimpose.tracking_confidence)
		
	oxrktrans_updated = false
