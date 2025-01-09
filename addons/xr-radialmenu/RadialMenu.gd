extends Node3D

# Hold E and 2 down to simulate the context sensitive menu

signal menuitemselected(menutext)

var selectedsignmaterial = load("res://addons/xr-radialmenu/selectedsign.tres")
var unselectedsignmaterial = load("res://addons/xr-radialmenu/unselectedsign.tres")
var contextbutton = "ax_button"
var actionbutton = "trigger_click"
var radialmenuitemclass = load("res://addons/xr-radialmenu/RadialMenuItem.tscn")

var diskdistance = 0.4
var diskradius = 0.15

var menuitemtexts = [ ]

var xrorigin = null
var aimglobaltransform = null
var aimtransform = null
var currentradialitem = null

var contextclocksequence = [6, 8, 4, 9, 3, 10, 2, 12, 1, 11, 5, 7]

func controller_button_pressed(name):
	if name == contextbutton and aimtransform == null:
		makeradialmenu()
	if name == actionbutton and aimtransform != null:
		actreleaseradialmenu()

func controller_button_released(name):
	if name == contextbutton and aimtransform != null:
		actreleaseradialmenu()

func makeradialmenu():
	menuitemtexts = ["one", "two", "three", "four", "five"]
	aimglobaltransform = Transform3D(global_transform.basis, global_transform.origin - global_transform.basis.z * diskdistance)
	aimtransform = xrorigin.global_transform.affine_inverse()*aimglobaltransform
	
	$MenuDisk.transform = Transform3D(global_transform.basis, global_transform.origin - global_transform.basis.z * diskdistance)
	for i in range(len(menuitemtexts)):
		var radialmenuitem = radialmenuitemclass.instantiate()
		setupnamepos(radialmenuitem, menuitemtexts[i], contextclocksequence[i], diskradius)
		$MenuDisk.add_child(radialmenuitem)
	await get_tree().process_frame # necessary to set the text dimensions
	for menuitem in $MenuDisk.get_children():
		setbackgroundcollision(menuitem)
	$MenuDisk.visible = true
	
func actreleaseradialmenu():
	$MenuDisk.visible = false
	if currentradialitem != null:
		var menutextselected = currentradialitem.get_node("Label3D").text
		print("Selecting menu item: ", menutextselected)
		emit_signal("menuitemselected", menutextselected)
	for contextmenuitem in $MenuDisk.get_children():
		contextmenuitem.queue_free()
	currentradialitem = null
	aimtransform = null
	aimglobaltransform = null
	menuitemtexts.clear()

func _process(delta):
	if aimtransform != null:
		$MenuDisk.transform = xrorigin.global_transform*aimtransform
		var citem = $RayCast3D.get_collider()
		if citem != null and citem.get_parent() != $MenuDisk:
			citem = null
		if citem != currentradialitem:
			if currentradialitem != null:
				currentradialitem.get_node("Label3D/MeshInstance3D").set_surface_override_material(0, unselectedsignmaterial)
				currentradialitem = null
			if citem != null:
				currentradialitem = citem
				currentradialitem.get_node("Label3D/MeshInstance3D").set_surface_override_material(0, selectedsignmaterial)

func findandattachbuttonpresstocorrespondingcontroller():
	var xrnode = get_parent()
	if not (xrnode is XRNode3D):
		push_error("XRController3D not child of XRNode3D")
		return false
	xrorigin = xrnode.get_parent()
	if not (xrorigin is XROrigin3D):
		push_error("XRNode3D not child of XROrigin3D")
		return false
	if not (xrnode.tracker == "left_hand" or xrnode.tracker == "right_hand"):
		push_warning("Unexpected tracker name in xraim node: "+xrnode.tracker)
	if not (xrnode.tracker != "aim"):
		push_warning("Unexpected tracker pose in xraim: "+xrnode.pose)
	var xrcontroller = null
	for c in xrorigin.get_children():
		if c is XRController3D and c.tracker == xrnode.tracker:
			xrcontroller = c
	if xrcontroller != null:
		xrcontroller.button_pressed.connect(controller_button_pressed)
		xrcontroller.button_released.connect(controller_button_released)
	else:
		push_warning("No corresponding controller found for xraim node")

func setupnamepos(radialmenuitem, text, clock, rad):
	radialmenuitem.get_node("Label3D").text = text
	radialmenuitem.get_node("Label3D").visible = false
	radialmenuitem.get_node("CollisionShape3D").disabled = false
	var ang = deg_to_rad(clock*30)
	radialmenuitem.transform.origin.x = sin(ang)*rad if (clock % 6) != 0 else 0.0
	radialmenuitem.transform.origin.y = cos(ang)*rad
	radialmenuitem.get_node("Label3D/MeshInstance3D").set_surface_override_material(0, unselectedsignmaterial)

func setbackgroundcollision(radialmenuitem):
	var t = radialmenuitem.get_node("Label3D").get_aabb()
	radialmenuitem.get_node("Label3D/MeshInstance3D").mesh.size = Vector2(t.size.x, t.size.y)
	var cs = radialmenuitem.get_node("CollisionShape3D")
	cs.shape.size = Vector3(t.size.x, t.size.y, cs.shape.size.z)
	radialmenuitem.transform.origin.x += (t.size.x-t.size.y)*0.5*sign(transform.origin.x)
	radialmenuitem.get_node("Label3D").visible = true
	cs.disabled = false

func _ready():
	findandattachbuttonpresstocorrespondingcontroller()
	assert ($MenuDisk.top_level)
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not (get_parent() is XRNode3D):
		warnings.append("This node must be a child of an XRNode3D tracker pose node")
	return warnings
