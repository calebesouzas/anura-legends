class_name Player extends AliveEntity

func _init() -> void:
  self.health = 1000

func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

@export_group("Physics")
@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 5.0
@export var GRAVITY: float = 12.0

@export_group("Camera")
@export_range(0.0, 1.0, 0.05, "Sensitivity on mobile")
var TOUCH_SENSITIVITY: float = 0.25

@export_range(0.0, 1.0, 0.05, "Sensitivity on mouse")
var MOUSE_SENSITIVITY: float = 0.25

@onready var pivot: Node3D = %pivot
@onready var camera: Camera3D = %camera
@onready var mesh: MeshInstance3D = %mesh
@onready var aim: Marker3D = %aim

@export_group("Combat")
@export var bullet_scene: PackedScene

var input_direction: Vector2
var move_direction: Vector2

func _physics_process(delta: float) -> void:
  if not self.is_on_floor():
    self.velocity.y -= self.GRAVITY * delta

  if Input.is_action_pressed("jump") and self.is_on_floor():
    self.velocity.y = self.JUMP_VELOCITY

  self.input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
  self.move_direction = self.get_camera_relative_movement().normalized()

  self.rotate_skin()

  if self.move_direction.length_squared() > 0:
    self.velocity.x = self.move_direction.x * self.SPEED
    self.velocity.z = self.move_direction.y * self.SPEED
  else:
    self.velocity.x = move_toward(self.velocity.x, 0, self.SPEED)
    self.velocity.z = move_toward(self.velocity.z, 0, self.SPEED)
  self.move_and_slide()

  if Input.is_action_just_pressed("trigger"):
    self.trigger()


func get_camera_relative_movement() -> Vector2:
  var forward: Vector3 = self.camera.global_transform.basis.z
  var right: Vector3 = self.camera.global_transform.basis.x
  var direction: Vector3 = forward * self.input_direction.y \
    + right * self.input_direction.x
  return Vector2(direction.x, direction.z)

func rotate_skin() -> void:
  if self.move_direction.length_squared() > 0:
    var target: Vector3 = self.position \
      + Vector3(self.move_direction.x, 0, self.move_direction.y)
    self.mesh.look_at(target) #@todo find a way to touch only the `y` field
    self.mesh.rotation.x = 0
    self.mesh.rotation.z = 0

func trigger() -> void:
  var direction: Vector3 = self.camera.global_position.direction_to(
    self.aim.global_position
  )
  self.plasma_manager.spawn_new_projectile(self.id, self.bullet_scene, direction)

func _unhandled_input(event: InputEvent) -> void:
  var is_camera_motion: bool = false
  var camera_motion: Vector2 = Vector2.ZERO
  if event is InputEventScreenDrag:
    camera_motion = event.screen_relative * self.TOUCH_SENSITIVITY
    is_camera_motion = true
  elif event is InputEventMouseMotion:
    camera_motion = event.screen_relative * self.MOUSE_SENSITIVITY
    is_camera_motion = true

  if is_camera_motion:
    self.pivot.rotation_degrees.y -= camera_motion.x
    self.pivot.rotation_degrees.x -= camera_motion.y
    # don't accumulate rotation indefinitelly
    self.pivot.rotation_degrees.y = wrapf(
      self.pivot.rotation_degrees.y, 0.0, 360.0
    )
    # limit vertical rotation to prevent camera getting upside-down and breaking
    self.pivot.rotation_degrees.x = clampf(
      self.pivot.rotation_degrees.x,
      -85.0, # look down limit
      60.0 # look up limit
    )
  elif event is InputEventKey and event.keycode == KEY_ESCAPE:
    self.get_tree().quit()
