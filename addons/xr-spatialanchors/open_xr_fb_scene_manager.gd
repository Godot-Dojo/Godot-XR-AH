extends OpenXRFbSceneManager

@onready var scene_manager: OpenXRFbSceneManager = self

var radialmenu
var spatialentityexample = null
var selectedanchormaterial = load("res://addons/xr-spatialanchors/selectedamchor.tres")
var unselectedanchormaterial = load("res://addons/xr-spatialanchors/unselectedanchor.tres")

func _ready():
	scene_manager.openxr_fb_scene_data_missing.connect(_scene_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_scene_capture_completed)
	scene_manager.openxr_fb_scene_anchor_created.connect(_openxr_fb_scene_anchor_created)
	
	radialmenu = get_node_or_null("../XRAimRight/RadialMenu")
	print("radialmenu ", radialmenu)

var citemprev = null
func _process(delta):
	if radialmenu:
		var citem = radialmenu.get_node("RayCast3D").get_collider()
		if citem != citemprev:
			print("Hit citem ", citem)
			if citemprev and citemprev.get_parent() is OpenXRFbSpatialEntity:
				citemprev.get_node("MeshInstance3D").set_surface_override_material(0, unselectedanchormaterial)
				citemprev = null
			if citem and citem.get_parent() is OpenXRFbSpatialEntity:
				citem.get_node("MeshInstance3D").set_surface_override_material(0, selectedanchormaterial)

			citemprev = citem

func _openxr_fb_scene_anchor_created(scene_node: Object, spatial_entity: Object):
	prints("**** _openxr_fb_scene_anchor_created", scene_node, spatial_entity)
	spatialentityexample = spatial_entity

func _scene_data_missing() -> void:
	print("**** _scene_data_missing")
	scene_manager.request_scene_capture()

func _scene_capture_completed(success: bool) -> void:
	print("**** _scene_capture_completed ", success)
