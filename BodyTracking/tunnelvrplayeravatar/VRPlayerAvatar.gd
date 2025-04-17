extends Node3D

@onready var arvrorigin = XRHelpers.get_xr_origin(get_node("/root/Main/XROrigin3D"))

@onready var LeftHandController = XRHelpers.get_left_controller(arvrorigin)
@onready var RightHandController = XRHelpers.get_right_controller(arvrorigin)

var nextframeisfirst = false

const TRACKING_CONFIDENCE_HIGH = 2
const TRACKING_CONFIDENCE_NOT_APPLICABLE = -1
const TRACKING_CONFIDENCE_NONE = 0

var shrinkavatartransform = Transform3D()

@onready var handl = $simplelefthand
@onready var handlskel = handl.find_child("Skeleton3D")
@onready var chandl = LeftHandController.get_node("simplelefthand")
@onready var chandlskel = chandl.find_child("Skeleton3D")
@onready var handr = $simplerighthand
@onready var handrskel = handr.find_child("Skeleton3D")
@onready var chandr = RightHandController.get_node("simplerighthand")
@onready var chandrskel = chandr.find_child("Skeleton3D")

var projectedhands = false
static var selectedtrackslookup = { 
	".:position":-1, 
	".:rotation":-1,
	"HeadCam:rotation":-1 }

func _ready():
	var anim : Animation = $PlayerAnimation.get_animation("playeral/trackstemplate")
	var pf = get_node("PlayerFrame")
	if not pf.has_method("getnodepropertynamefortrack"):
		return
	for i in anim.get_track_count():
		var r = pf.getnodepropertynamefortrack(anim, self, i)
		if selectedtrackslookup.has(r):
			selectedtrackslookup[r] = i
	print("selectedtrackslookup ", selectedtrackslookup)
	
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PF_initlocalplayer():
	randomize()
	$HeadCam/NameplateLabel3D.text = possibleusernames[randi()%len(possibleusernames)]

func playername():
	return $HeadCam/NameplateLabel3D.text

func PF_spawninfo_fornewplayer():
	var spawnpos = transform.origin + Vector3(1,0,-1.5)
	var spawnrot = transform.basis.get_rotation_quaternion()*Quaternion(Vector3(0,1,0), deg_to_rad(45))
	return { "spawnpointtransform":Transform3D(spawnrot, spawnpos) }

func set_fade(p_value : float):
	XRToolsFade.set_fade("spawnpoint", Color(0, 0, 0, p_value))

func PF_spawninfo_receivedfromserver(sfd, PlayerConnection):
	var tween = get_tree().create_tween()
	tween.tween_method(set_fade, 0.0, 1.0, 0.34)
	await tween.finished
	arvrorigin.transform = sfd["spawnpointtransform"]
	tween = get_tree().create_tween()
	tween.tween_method(set_fade, 1.0, 0.0, 0.34)
	PlayerConnection.spawninfoforclientprocessed()
	await tween.finished
	

func skelbonescopy(skela, skelb):
	for i in range(skela.get_bone_count()):
		skela.set_bone_pose_rotation(i, skelb.get_bone_pose_rotation(i))

func PF_processlocalavatarposition(delta):
	transform = shrinkavatartransform*arvrorigin.transform
	$HeadCam.transform = arvrorigin.get_node("XRCamera3D").transform

	handl.transform = arvrorigin.global_transform.inverse()*chandl.global_transform
	skelbonescopy(handlskel, chandlskel)
	handr.transform = arvrorigin.global_transform.inverse()*chandr.global_transform
	skelbonescopy(handrskel, chandrskel)

	if projectedhands:
		var headface = Vector3($HeadCam.transform.basis.z.x, 0, $HeadCam.transform.basis.z.z).normalized()
		var headup = Vector3(headface.x, 0.8, headface.z)*0.25
		handl.transform.origin += Vector3(headface.x*0.2, 0.2, headface.z*0.2)
		handr.transform.origin += Vector3(headface.x*0.2, 0.2, headface.z*0.2)

func PF_setspeakingvolume(v):
	$HeadCam/AudioStreamPlayer/MouthSign.scale.z = v

func _process(_delta):
		# since we cannot animate fading of the mouth sign
	var v = $HeadCam/AudioStreamPlayer/MouthSign.scale.z
	$HeadCam/AudioStreamPlayer/MouthSign.visible = (v != 0.0)
	$HeadCam/AudioStreamPlayer/MouthSign.get_surface_override_material(0).albedo_color.a = v


static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset):
	if fd.has(NCONSTANTS.CFI_TIMESTAMP):
		fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_TIMESTAMPPREV):
		fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	var itrackpos = selectedtrackslookup[".:position"]
	var itrackheadrot = selectedtrackslookup[".:rotation"]
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+itrackpos):
		fd[NCONSTANTS.CFI_ANIMTRACKS+itrackpos].z += -2 # should only be set in the spawn point
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+itrackheadrot):
		print(var_to_str(fd[NCONSTANTS.CFI_ANIMTRACKS+itrackheadrot]))
		fd[NCONSTANTS.CFI_ANIMTRACKS+itrackheadrot] *= Quaternion(Vector3(0, 1, 0), deg_to_rad(180))


func PF_getvoicestream():
	return $HeadCam/AudioStreamPlayer.stream

func PF_setvoicestream(lstream):
	$HeadCam/AudioStreamPlayer.stream = lstream

func PF_playvoicestream():
	$HeadCam/AudioStreamPlayer.play()
	
func PF_setvoicespeedup(fac):
	$HeadCam/AudioStreamPlayer.pitch_scale = fac
