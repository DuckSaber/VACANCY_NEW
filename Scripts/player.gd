extends CharacterBody3D

@export var speed := 3.0
@export var mouse_sensitivity := 0.002

@onready var camera_pivot: Node3D = $CameraPivot
@onready var interaction_ray: RayCast3D = $CameraPivot/InteractionRay
@onready var interaction_prompt: Label = $"../NodeUI/UIOverlay/CenterContainer/InteractionPrompt"
@onready var item_inspector: CanvasLayer = $"../ItemInspector"

var camera_pitch := 0.0
var current_interactable: Interactable = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interaction_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if item_inspector.inspecting: 
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(-89),
			deg_to_rad(89)
		)

		camera_pivot.rotation.x = camera_pitch

	# Release mouse
	

	# Interaction
	if event.is_action_pressed("interact"):
		if interaction_ray.is_colliding():
			var object = interaction_ray.get_collider()

			if object is Interactable:
				item_inspector.inspect_item(object.model, object.inspection_rotation, object.item_name, object.item_description)
				
	if event.is_action_pressed("quit_game"):
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if item_inspector.inspecting:
		velocity.x = 0
		velocity.z = 0
		return
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement input
	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	# Movement relative to player rotation
	var direction := (
		transform.basis.x * input.x +
		transform.basis.z * input.y
	).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	update_interaction_prompt()


func update_interaction_prompt() -> void:
	var new_interactable: Interactable = null

	# Find what we're currently looking at
	if interaction_ray.is_colliding():
		var object = interaction_ray.get_collider()

		if object is Interactable:
			new_interactable = object

	# Has the object we're looking at changed?
	if new_interactable != current_interactable:

		# Remove highlight from previous object
		if current_interactable:
			current_interactable.set_highlighted(false)

		# Add highlight to new object
		if new_interactable:
			new_interactable.set_highlighted(true)

		# Remember the new object
		current_interactable = new_interactable

	# Update interaction prompt
	if current_interactable:
		interaction_prompt.text = "[E] " + current_interactable.interaction_prompt
		interaction_prompt.visible = true
	else:
		interaction_prompt.visible = false
