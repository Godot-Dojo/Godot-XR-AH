extends Node3D



const hjsticks = [ [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL, OpenXRInterface.HAND_JOINT_THUMB_DISTAL, OpenXRInterface.HAND_JOINT_THUMB_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL, OpenXRInterface.HAND_JOINT_INDEX_INTERMEDIATE, OpenXRInterface.HAND_JOINT_INDEX_DISTAL, OpenXRInterface.HAND_JOINT_INDEX_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL, OpenXRInterface.HAND_JOINT_MIDDLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_MIDDLE_DISTAL, OpenXRInterface.HAND_JOINT_MIDDLE_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_RING_PROXIMAL, OpenXRInterface.HAND_JOINT_RING_INTERMEDIATE, OpenXRInterface.HAND_JOINT_RING_DISTAL, OpenXRInterface.HAND_JOINT_RING_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_PROXIMAL, OpenXRInterface.HAND_JOINT_LITTLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_LITTLE_DISTAL, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]
			   ]

func _ready():
	var sticknode = $ExampleStick
	remove_child(sticknode)
	var jointnode = $ExampleJoint
	remove_child(jointnode)
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		var rj = jointnode.duplicate()
		rj.name = "J%d" % j
		rj.scale = Vector3(0.01, 0.01, 0.01)
		add_child(rj)

	for hjstick in hjsticks:
		for i in range(0, len(hjstick)-1):
			var rstick = sticknode.duplicate()
			var j1 = hjstick[i]
			var j2 = hjstick[i+1]
			rstick.name = "S%d_%d" % [j1, j2]
			rstick.scale = Vector3(0.01, 0.01, 0.01)
			add_child(rstick)
			#get_node("J%d" % hjstick[i+1]).get_node("Sphere").visible = (i > 0)


func updatevisiblehandskeleton(oxrjps, xrt, xr_interface, hand):
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		var jrot = xr_interface.get_hand_joint_rotation(hand, j)
		get_node("J%d" % j).global_transform = Transform3D(xrt.basis*Basis(jrot).scaled(Vector3(0.01, 0.01, 0.01)), xrt*oxrjps[j])

	for hjstick in hjsticks:
		for i in range(0, len(hjstick)-1):
			var j1 = hjstick[i]
			var j2 = hjstick[i+1]
			var rstick = get_node("S%d_%d" % [j1, j2])
			rstick.global_transform = sticktransform(xrt*oxrjps[j1], xrt*oxrjps[j2])

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
