class_name Interactable
extends StaticBody3D

@export var interaction_prompt := "Inspect"
@export var model: Node3D
@export var inspection_rotation: Vector3 = Vector3.ZERO
@export var item_name: String = "Unknown Item"
@export_multiline var item_description: String = ""




func interact() -> void:
	print("Interacted with ", name)


func set_highlighted(value: bool) -> void:
	var highlight_mesh := get_node("HighlightMesh") as MeshInstance3D
	highlight_mesh.visible = value
	
