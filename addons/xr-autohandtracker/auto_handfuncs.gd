class_name AutoHandFuncs

const carpallist = [ OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, 
					OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, 
					OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL ]
const FINGERCOUNT = 5

static func basisfromA(a, v):
	var vx = a.normalized()
	var vy = vx.cross(v.normalized())
	var vz = vx.cross(vy)
	return Basis(vx, vy, vz)

static func rotationtoalignB(a, b, va, vb):
	return basisfromA(b, vb)*basisfromA(a, va).inverse()

static func rotationtoalignUnScaled(a, b):
	#assert (is_zero_approx(a.x) and is_zero_approx(a.z))
	var axis = a.cross(b).normalized()
	var rot = Basis()
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		rot = Basis(axis, angle_rads)
	return rot

static func rotationtoalignScaled(a, b):
	var axis = a.cross(b).normalized()
	var sca = b.length()/a.length()
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads).scaled(Vector3(sca,sca,sca))
	return Basis().scaled(Vector3(sca,sca,sca))
