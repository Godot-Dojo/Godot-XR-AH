extends StaticBody3D

func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var semantic_labels: PackedStringArray = entity.get_semantic_labels()
	prints("SsScene anchor setup_scene ", self, entity, "semantic_labels ", semantic_labels)
	$Label3D.text = semantic_labels[0]



"""
	var sceneobject = load("res://scenemanager/sceneanchor.tscn").instantiate()
	var sca = 0.2
	sceneobject.scale = Vector3(sca, sca, sca)

	var collision_shape = entity.create_collision_shape()
	var arrm = entity.get_triangle_mesh()

	if collision_shape:
		sceneobject.get_node("CollisionShape3D").shape = collision_shape.shape
		print("Collision shape ", collision_shape.shape, "  ", collision_shape.shape.get_class())
	sceneobject.get_node("Label3D").text = semantic_labels[0]
	var arr_mesh = ArrayMesh.new()
	if arrm and false:
		print("-- Verts ", len(arrm[Mesh.ARRAY_VERTEX]), "  indx ", len(arrm[Mesh.ARRAY_INDEX]))
		if true:
			var v = arrm[Mesh.ARRAY_VERTEX]
			var ids = arrm[Mesh.ARRAY_INDEX]
			arrm[Mesh.ARRAY_INDEX] = PackedInt32Array(range(len(ids)))
			var nv = [ ]
			for i in ids:
				nv.push_back(v[i])
			arrm[Mesh.ARRAY_VERTEX] = PackedVector3Array(nv)
		
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrm)
		sceneobject.get_node("MeshInstance3D").mesh = arr_mesh
	else:
		var m = entity.create_mesh_instance()
		arr_mesh = m.mesh
		print("  m ", arr_mesh.get_class())
		if arr_mesh.get_class() == "PlaneMesh":
			sceneobject.get_node("MeshInstance3D").material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
			print("arr_mesh.orientation ", arr_mesh.orientation)
	sceneobject.get_node("MeshInstance3D").mesh = arr_mesh
		 
	var col = Color.from_hsv(randf(), 0.5, 0.79)
	$MeshInstance3D.material_override.albedo_color = col
	sceneobject.get_node("MeshInstance3D").material_override.albedo_color = col
	get_node("/root/Main/MiniScene").add_child(sceneobject)
	
	print("global_transform ", global_transform)
	await get_tree().create_timer(1.0).timeout
	scradialmenueneobject.global_position = global_position*sca + Vector3(0,1,-1)
	sceneobject.global_rotation = global_rotation
	visible = false
	$CollisionShape3D.disabled = true
"""
