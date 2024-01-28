extends Node3D

var hjtips = [ OpenXRInterface.HAND_JOINT_THUMB_TIP, OpenXRInterface.HAND_JOINT_INDEX_TIP, OpenXRInterface.HAND_JOINT_MIDDLE_TIP, 
			   OpenXRInterface.HAND_JOINT_RING_TIP, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]

var hjsticks = [ [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL, OpenXRInterface.HAND_JOINT_THUMB_DISTAL, OpenXRInterface.HAND_JOINT_THUMB_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL, OpenXRInterface.HAND_JOINT_INDEX_INTERMEDIATE, OpenXRInterface.HAND_JOINT_INDEX_DISTAL, OpenXRInterface.HAND_JOINT_INDEX_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL, OpenXRInterface.HAND_JOINT_MIDDLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_MIDDLE_DISTAL, OpenXRInterface.HAND_JOINT_MIDDLE_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_RING_PROXIMAL, OpenXRInterface.HAND_JOINT_RING_INTERMEDIATE, OpenXRInterface.HAND_JOINT_RING_DISTAL, OpenXRInterface.HAND_JOINT_RING_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_PROXIMAL, OpenXRInterface.HAND_JOINT_LITTLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_LITTLE_DISTAL, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]
			   ]

var xr_interface : OpenXRInterface



@onready var flat_display = $FrontOfPlayer/FlatDisplayMesh/SubViewport/FlatDisplay
@onready var joints2D = $FrontOfPlayer/Joints2D

var buttonsignalnames = [ 
	"select_button", "menu_button", 
	"trigger_touch", "trigger_click", 
	"grip_touch", "grip_click", 
	"primary_touch", "primary_click", 
	"ax_touch", "ax_button",
	"by_touch", "by_button",
]



const stickradius = 0.01
static func sticktransformB(j1, j2):
	var v = j2 - j1
	var vlen = v.length()
	var b
	if vlen != 0:
		var vy = v/vlen
		var vyunaligned = Vector3(0,1,0) if abs(vy.y) < abs(vy.x) + abs(vy.z) else Vector3(1,0,0)
		var vz = vy.cross(vyunaligned)
		var vx = vy.cross(vz)
		b = Basis(vx*stickradius, v, vz*stickradius)
	else:
		b = Basis().scaled(Vector3(0.01, 0.0, 0.01))
	return Transform3D(b, (j1 + j2)*0.5)

# Set up the displayed axes for each hand and each joint of the hand 
func _ready():
	var axes3dscene = load("res://axes3d.tscn")
	var stickscene = load("res://stick.tscn")
	
	for hand in range(2):
		var LRd = "L%d" if hand == 0 else "R%d"

		# Make the axes for each hand joint
		for j in range(OpenXRInterface.HAND_JOINT_MAX):
			# static copy of each joint arranged on 2D panel
			var rjf = axes3dscene.instantiate()
			rjf.name = LRd % j
			rjf.scale = Vector3(0.01, 0.01, 0.01)
			var p = flatlefthandjointsfromwrist[j]
			rjf.transform.origin = Vector3(p.x - 0.12, -p.z, p.y) if hand == 0 else Vector3(-p.x + 0.12, -p.z, p.y)
			joints2D.add_child(rjf)

		# Make the white sticks between connecting joints to see the skeleton 
		var LRstick = "L%dt%d" if hand == 0 else "R%dt%d"
		for hjstick in hjsticks:
			for i in range(0, len(hjstick)-1):
				var rstick = stickscene.instantiate()
				var j1 = hjstick[i]
				var j2 = hjstick[i+1]

				var rstickf = stickscene.instantiate()
				rstickf.name = LRstick % [hjstick[i], hjstick[i+1]]
				joints2D.add_child(rstickf)
				rstickf.transform = sticktransformB(joints2D.get_node(LRd % j1).transform.origin, joints2D.get_node(LRd % j2).transform.origin)


		# Make the toggle buttons that show the activated button signals
		var vboxsignals = flat_display.get_node("VBoxTrackers%d" % hand)
		var buttonsig = vboxsignals.get_child(0)
		vboxsignals.remove_child(buttonsig)
		for bn in buttonsignalnames:
			var bs = buttonsig.duplicate()
			bs.text = bn
			bs.name = bn
			vboxsignals.add_child(bs)

	var controllers = [ get_node("../XRController3DLeft"), get_node("../XRController3DRight") ]
	for hand in range(2):
		var controller = controllers[hand]
		controller.button_pressed.connect(_button_signal.bind(hand, true))
		controller.button_released.connect(_button_signal.bind(hand, false))
		controller.input_float_changed.connect(_input_float_changed.bind(hand))
		controller.input_vector2_changed.connect(_input_vector2_changed.bind(hand))



func _button_signal(name, hand, pressed):
	var buttonsig = flat_display.get_node_or_null("VBoxTrackers%d/%s" % [ hand, name ])
	if buttonsig:
		buttonsig.button_pressed = pressed
	else:
		print("buttonsignal ", hand, " ", name, " ", pressed)
		
func _input_float_changed(name, value, hand):
	var ifsig = flat_display.get_node_or_null("VSlider%d%s" % [ hand, name ])
	if ifsig:
		ifsig.value = value*100
	else:
		print("inputfloatchanged ", hand, " ", name, " ", value)

func _input_vector2_changed(name, vector, hand):
	var ifstick = flat_display.get_node_or_null("Thumbstick%d" % hand)
	if ifstick:
		ifstick.get_node("Pos").position = (vector + Vector2(1,1))*(70/2)
	else:
		print("inputvector2changed ", hand, " ", name, " ", vector)
	#print("inputvector2changed ", name)  # it's always primary

# Get the trackers once the interface has been initialized
func set_xr_interface(lxr_interface : OpenXRInterface):
	# wire up the signals from the hand trackers
	xr_interface = lxr_interface
		
	# reset the position of the 2D information panel 3 times in the first 15 seconds
	for t in range(3):
		await get_tree().create_timer(5).timeout
		var headtransform = get_node("../XRCamera3D").transform	
		$FrontOfPlayer.transform = Transform3D(headtransform.basis, headtransform.origin - headtransform.basis.z*0.5 + Vector3(0,-0.2,0))


func _process(delta):
	if xr_interface != null:
		for hand in range(2):
			var LRd = "L%d" if hand == 0 else "R%d"
			for j in range(OpenXRInterface.HAND_JOINT_MAX):
				var jointradius = xr_interface.get_hand_joint_radius(hand, j)
				var handjointflags = xr_interface.get_hand_joint_flags(hand, j);
				var joint2d = joints2D.get_node(LRd % j)
				joint2d.get_node("InvalidMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_VALID)
				joint2d.get_node("UntrackedMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_TRACKED)
				joint2d.transform.basis = Basis(xr_interface.get_hand_joint_rotation(hand, j))*0.013


var flatlefthandjointsfromwrist = [
	Vector3(0.000861533, -0.0012695, -0.0477441), Vector3(0, 0, 0), Vector3(0.0315846, -0.0131271, -0.0329833), Vector3(0.0545926, -0.0174885, -0.0554602), 
	Vector3(0.0757424, -0.0190563, -0.0816979), Vector3(0.0965827, -0.0188126, -0.0947297), Vector3(0.0204946, -0.00802441, -0.0356591), 
	Vector3(0.0235117, -0.00730439, -0.0958373), Vector3(0.0364556, -0.00840877, -0.131404), Vector3(0.0444214, -0.00928009, -0.154306), 
	Vector3(0.0501041, -0.00590578, -0.175658), Vector3(0.00431204, -0.00690232, -0.0335003), Vector3(0.00172306, -0.00253896, -0.0954883), 
	Vector3(0.00447122, 0.00162174, -0.138053), Vector3(0.00599042, 0.00439228, -0.165375), Vector3(0.00627589, 0.0124663, -0.188982), 
	Vector3(-0.0149675, -0.00600582, -0.034718), Vector3(-0.0174363, -0.00651854, -0.0885469), Vector3(-0.0249593, 0.000487596, -0.126097), 
	Vector3(-0.0302005, 0.00494818, -0.151718), Vector3(-0.0342363, 0.0119404, -0.17468), Vector3(-0.0229605, -0.00940424, -0.0340171), 
	Vector3(-0.034996, -0.0136686, -0.0777668), Vector3(-0.0520341, -0.00539365, -0.101889), Vector3(-0.0647082, 0.000211, -0.116692), 
	Vector3(-0.0764616, 0.00869788, -0.133135)
]
