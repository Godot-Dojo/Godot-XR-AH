extends Node

const hjtips = [ OpenXRInterface.HAND_JOINT_THUMB_TIP, 
				 OpenXRInterface.HAND_JOINT_INDEX_TIP, 
				 OpenXRInterface.HAND_JOINT_MIDDLE_TIP, 
				 OpenXRInterface.HAND_JOINT_RING_TIP, 
				 OpenXRInterface.HAND_JOINT_LITTLE_TIP ]

class FingerPinchHold:
	const fingerpinchdistanceon = 0.03
	const fingerpinchdistanceoff = 0.05
	const fingerpinchtipgrabdistance = 0.02

	var bpinched = false
	var oppositepinchedjoint = -1
	var thumbtransformtojoint = Transform3D()

	func updatepinchingstatus(oxrktransRaw, oppositeoxrktransRaw):
		var pinchvec = oxrktransRaw[OpenXRInterface.HAND_JOINT_THUMB_TIP].origin - oxrktransRaw[OpenXRInterface.HAND_JOINT_INDEX_TIP].origin
		var pinchveclen = pinchvec.length()
		if not bpinched and pinchveclen < fingerpinchdistanceon:
			var midpinch = 0.5*(oxrktransRaw[OpenXRInterface.HAND_JOINT_THUMB_TIP].origin + oxrktransRaw[OpenXRInterface.HAND_JOINT_INDEX_TIP].origin)
			oppositepinchedjoint = -1
			var oppositepinchedjointdistance = fingerpinchtipgrabdistance
			for j in hjtips:
				var loppositepinchedjointdistance = (oppositeoxrktransRaw[j].origin - midpinch).length()
				if loppositepinchedjointdistance < oppositepinchedjointdistance:
					oppositepinchedjointdistance = loppositepinchedjointdistance
					oppositepinchedjoint = j
			if oppositepinchedjoint != -1:
				thumbtransformtojoint = oxrktransRaw[OpenXRInterface.HAND_JOINT_THUMB_TIP].inverse()*oppositeoxrktransRaw[oppositepinchedjoint]
			bpinched = true
		elif bpinched and pinchveclen > fingerpinchdistanceoff:
			bpinched = false

	func applypinchingdrag(oxrktrans, oppositeoxrktrans, oxrktransRaw, oppositeoxrktransRaw):
		if bpinched and oppositepinchedjoint != -1:
			oppositeoxrktrans[oppositepinchedjoint] = oxrktransRaw[OpenXRInterface.HAND_JOINT_THUMB_TIP]*thumbtransformtojoint

			
var leftpinchhold = FingerPinchHold.new()
var rightpinchhold = FingerPinchHold.new()
 
func processfingergrabstate(leftoxrktrans, rightoxrktrans, leftoxrktransRaw, rightoxrktransRaw):
	leftpinchhold.updatepinchingstatus(leftoxrktransRaw, rightoxrktransRaw)
	rightpinchhold.updatepinchingstatus(rightoxrktransRaw, leftoxrktransRaw)
	for i in range(OpenXRInterface.HAND_JOINT_MAX):
		rightoxrktrans[i] = rightoxrktransRaw[i]
		leftoxrktrans[i] = leftoxrktransRaw[i]
	leftpinchhold.applypinchingdrag(leftoxrktrans, rightoxrktrans, leftoxrktransRaw, rightoxrktransRaw)
	rightpinchhold.applypinchingdrag(rightoxrktrans, leftoxrktrans, rightoxrktransRaw, leftoxrktransRaw)


func _process(delta):
	var autohandright = get_parent().autohandright
	var autohandleft = get_parent().autohandleft
	if autohandright.oxrktransRaw_updated and autohandleft.oxrktransRaw_updated:
		if not (autohandright.oxrktrans_updated and autohandleft.oxrktrans_updated):
			processfingergrabstate(autohandleft.oxrktrans, autohandright.oxrktrans, autohandleft.oxrktransRaw, autohandright.oxrktransRaw)
			autohandright.oxrktrans_updated = true
			autohandleft.oxrktrans_updated = true

			
