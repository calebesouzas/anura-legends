class_name Player extends CharacterBody3D

func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5

const TOUCH_SENSITIVITY: float = 0.25
const MOUSE_SENSITIVITY: float = 0.25

var id: int

@onready var pivot: Node3D = %pivot
@onready var camera: Camera3D = %camera

var input_direction: Vector2
var move_direction: Vector2

func _physics_process(delta: float) -> void:
  # Add the gravity.
  if not is_on_floor():
    velocity += get_gravity() * delta

  # Handle jump.
  if Input.is_action_pressed("jump") and is_on_floor():
    velocity.y = JUMP_VELOCITY

  # Get the input direction and handle the movement/deceleration.
  # As good practice, you should replace UI actions with custom gameplay actions.
  input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
  move_direction = get_camera_relative_movement().normalized()
  if move_direction.length_squared() > 0:
    velocity.x = move_direction.x * SPEED
    velocity.z = move_direction.y * SPEED
  else:
    velocity.x = move_toward(velocity.x, 0, SPEED)
    velocity.z = move_toward(velocity.z, 0, SPEED)

  move_and_slide()
  
  #if Input.is_action_just_pressed("trigger"):
  #  trigger()


func get_camera_relative_movement() -> Vector2:
  var forward: Vector3 = camera.global_transform.basis.z
  var right: Vector3 = camera.global_transform.basis.x
  forward.y = 0
  right.y = 0
  forward = forward.normalized()
  right = right.normalized()
                
  # PERF: Não acho que seja muito bom ficar alocando tantos 'Vector' intermediários...
  var direction: Vector3 = forward * input_direction.y + right * input_direction.x
  return Vector2(direction.x, direction.z)

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenDrag:
    pivot.rotation_degrees.y -= event.screen_relative.x * TOUCH_SENSITIVITY
    pivot.rotation_degrees.x -= event.screen_relative.y * TOUCH_SENSITIVITY
    return
  if event is InputEventMouseMotion:
    pivot.rotation_degrees.y -= event.screen_relative.x * MOUSE_SENSITIVITY
    pivot.rotation_degrees.x -= event.screen_relative.y * MOUSE_SENSITIVITY
    return
  if event is InputEventKey and event.keycode == KEY_ESCAPE:
    get_tree().quit()
    # return is unreachable
