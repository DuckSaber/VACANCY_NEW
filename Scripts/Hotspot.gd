extends StaticBody3D

func inspect_interact() -> void:
	var photo_frame: Node3D = get_parent()

	var animation_player: AnimationPlayer = photo_frame.get_node("AnimationPlayer")

	animation_player.play("remove_back")
