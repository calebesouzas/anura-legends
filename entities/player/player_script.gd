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
  if not self.is_on_floor():
    self.velocity += self.get_gravity() * delta

  # Handle jump.
  if Input.is_action_pressed("jump") and self.is_on_floor():
    self.velocity.y = self.JUMP_VELOCITY

  # Get the input direction and handle the movement/deceleration.
  # As good practice, you should replace UI actions with custom gameplay actions.
  self.input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
  self.move_direction = self.get_camera_relative_movement().normalized()
  if self.move_direction.length_squared() > 0:
    self.velocity.x = self.move_direction.x * self.SPEED
    self.velocity.z = self.move_direction.y * self.SPEED
  else:
    self.velocity.x = move_toward(self.velocity.x, 0, self.SPEED)
    self.velocity.z = move_toward(self.velocity.z, 0, self.SPEED)

  self.move_and_slide()
  
  #if Input.is_action_just_pressed("trigger"):
  #  trigger()


func get_camera_relative_movement() -> Vector2:
  var forward: Vector3 = self.camera.global_transform.basis.z
  var right: Vector3 = self.camera.global_transform.basis.x
  forward.y = 0
  right.y = 0
  forward = forward.normalized()
  right = right.normalized()
                
  # PERF: Não acho que seja muito bom ficar alocando tantos 'Vector' intermediários...
  var direction: Vector3 = forward * self.input_direction.y + right * self.input_direction.x
  return Vector2(direction.x, direction.z)

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenDrag:
    self.pivot.rotation_degrees.y -= event.screen_relative.x * self.TOUCH_SENSITIVITY
    self.pivot.rotation_degrees.x -= event.screen_relative.y * self.TOUCH_SENSITIVITY
    return
  if event is InputEventMouseMotion:
    self.pivot.rotation_degrees.y -= event.screen_relative.x * self.MOUSE_SENSITIVITY
    self.pivot.rotation_degrees.x -= event.screen_relative.y * self.MOUSE_SENSITIVITY
    return
  if event is InputEventKey and event.keycode == KEY_ESCAPE:
    self.get_tree().quit()
    # return is unreachable
