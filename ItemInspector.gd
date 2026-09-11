extends CanvasLayer

@onready var item_holder: Node3D = $SubViewportContainer/SubViewport/ItemHolder
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@onready var item_name_label: Label = $ItemName
@onready var item_description_label: Label = $ItemDescription
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer

var inspect_cursor: Texture2D = preload("res://UI/Cursor.png")
var rotate_cursor: Texture2D = preload("res://UI/Hand.png")

var current_item: Node3D = null
var inspecting := false
var rotating := false

var rotation_speed := 0.01

var zoom_speed := 0.1
var min_zoom := 0.7
var max_zoom := 1.2
var current_zoom := 1.0


func _ready() -> void:
	visible = false


func inspect_item(
	model: Node3D,
	inspection_rotation: Vector3,
	item_name: String,
	item_description: String
) -> void:

	if current_item:
		current_item.queue_free()

	current_item = model.duplicate()
	item_holder.add_child(current_item)

	sub_viewport.world_3d = get_viewport().world_3d

	current_item.position = Vector3.ZERO
	current_item.rotation_degrees = inspection_rotation
	current_item.scale = Vector3.ONE

	item_name_label.text = item_name
	item_description_label.text = item_description

	await get_tree().process_frame

	frame_item()

	visible = true
	inspecting = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_custom_mouse_cursor(
		inspect_cursor,
		Input.CURSOR_ARROW,
		Vector2(16, 16)
	)


func close_inspector() -> void:

	if current_item:
		current_item.queue_free()
		current_item = null

	visible = false
	inspecting = false
	rotating = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Input.set_custom_mouse_cursor(null)


func _unhandled_input(event: InputEvent) -> void:

	if not inspecting:
		return

	# ESCAPE
	if event.is_action_pressed("ui_cancel"):
		close_inspector()
		return

	# MOUSE BUTTONS
	if event is InputEventMouseButton:

		# LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				var hotspot: Node = get_inspection_hit()

				if hotspot != null:

					print("CLICKED: ", hotspot.name)

					if hotspot.has_method("inspect_interact"):
						hotspot.inspect_interact()
						return

				# Nothing clickable, so start rotating
				rotating = true

				Input.set_custom_mouse_cursor(
					rotate_cursor,
					Input.CURSOR_DRAG,
					Vector2(16, 16)
				)

			else:

				rotating = false

				Input.set_custom_mouse_cursor(
					inspect_cursor,
					Input.CURSOR_ARROW,
					Vector2(16, 16)
				)

		# MOUSE WHEEL
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1.0)

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0)

	# MOUSE ROTATION
	if event is InputEventMouseMotion and rotating:

		if current_item:

			current_item.rotate_y(
				event.relative.x * rotation_speed
			)

			current_item.rotate_x(
				event.relative.y * rotation_speed
			)

	# CONTROLLER ZOOM
	if event is InputEventJoypadMotion:

		if event.axis == JOY_AXIS_RIGHT_Y:

			if abs(event.axis_value) > 0.2:
				zoom(event.axis_value * 0.05)


func get_inspection_hit() -> Node:
	if current_item == null:
		return null

	var mouse_position: Vector2 = sub_viewport_container.get_local_mouse_position()

	var viewport_size: Vector2 = Vector2(
		sub_viewport.size.x,
		sub_viewport.size.y
	)

	var container_size: Vector2 = sub_viewport_container.size

	# Convert the mouse position from the displayed container
	# into the actual SubViewport's coordinates.
	var viewport_position: Vector2 = Vector2(
		mouse_position.x / container_size.x * viewport_size.x,
		mouse_position.y / container_size.y * viewport_size.y
	)

	var ray_origin: Vector3 = camera.project_ray_origin(viewport_position)
	var ray_direction: Vector3 = camera.project_ray_normal(viewport_position)

	var ray_end: Vector3 = ray_origin + ray_direction * 100.0

	var world_3d: World3D = sub_viewport.world_3d

	if world_3d == null:
		return null

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)

	# Look at the default collision layer.
	query.collision_mask = 2

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return null

	return result["collider"] as Node


func zoom(amount: float) -> void:

	current_zoom += amount * zoom_speed

	current_zoom = clampf(
		current_zoom,
		min_zoom,
		max_zoom
	)

	update_zoom()


func update_zoom() -> void:

	if current_item == null:
		return

	var largest_dimension: float = get_item_size()

	var distance: float = largest_dimension * 1.5

	camera.position.z = distance * current_zoom


func get_item_size() -> float:

	if current_item == null:
		return 1.0

	var meshes := current_item.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	if meshes.is_empty():
		return 1.0

	var combined_aabb: AABB
	var first_mesh := true

	for mesh_instance in meshes:

		if mesh_instance.mesh == null:
			continue

		var local_aabb: AABB = mesh_instance.get_aabb()

		var global_aabb: AABB = mesh_instance.global_transform * local_aabb

		if first_mesh:

			combined_aabb = global_aabb
			first_mesh = false

		else:

			combined_aabb = combined_aabb.merge(global_aabb)

	if first_mesh:
		return 1.0

	return maxf(
		combined_aabb.size.x,
		maxf(
			combined_aabb.size.y,
			combined_aabb.size.z
		)
	)


func frame_item() -> void:

	if current_item == null:
		return

	var meshes := current_item.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	if meshes.is_empty():
		return

	var combined_aabb: AABB
	var first_mesh := true

	for mesh_instance in meshes:

		if mesh_instance.mesh == null:
			continue

		var local_aabb: AABB = mesh_instance.get_aabb()

		var global_aabb: AABB = mesh_instance.global_transform * local_aabb

		if first_mesh:

			combined_aabb = global_aabb
			first_mesh = false

		else:

			combined_aabb = combined_aabb.merge(global_aabb)

	if first_mesh:
		return

	var centre := combined_aabb.get_center()

	current_item.position = -centre

	var size := combined_aabb.size

	var largest_dimension := maxf(
		size.x,
		maxf(size.y, size.z)
	)

	var distance := largest_dimension * 1.5

	current_zoom = 1.0

	camera.position = Vector3(
		0,
		0,
		distance
	)

	camera.look_at(Vector3.ZERO)
