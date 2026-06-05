class_name Player extends AliveEntity

func _init() -> void:
  self.health = 1000

var aim_locked: bool = false

@export_group("Physics")
@export var GROUND_SPEED: float = 7.0
@export var ACCELERATION: float = 21.0
@export_range(0.1, 1.0, 0.05) var GROUND_CONTROL: float = 1.0
@export_range(0.1, 1.0, 0.05) var AIR_CONTROL: float = 0.5
@export var JUMP_VELOCITY: float = 5.0
@export var GRAVITY: float = 12.0
var max_speed: float = self.GROUND_SPEED
var control_ratio: float = self.GROUND_CONTROL
var time: float = 0.0
var speed: float

@export_group("Camera")
@export_range(0.0, 1.0, 0.05, "Sensitivity on mobile")
var TOUCH_SENSITIVITY: float = 0.25

@export_range(0.0, 1.0, 0.05, "Sensitivity on mouse")
var MOUSE_SENSITIVITY: float = 0.25

var camera_direction: Vector3

@onready var pivot: Node3D = %pivot
@onready var camera: Camera3D = %camera
@onready var aim: Marker3D = %aim
@onready var aim_lock_timer: Timer = %aim_lock_timer
@onready var fire_locked_timer: Timer = %fire_locked_timer
@onready var animations: AnimationPlayer = %animations
@onready var animator: PlayerAnimator = %animator

@export_group("Skin")
@onready var skin: Node3D = %skin
@export var rotation_speed: float = 12.0

@export_group("Combat")
@export var bullet_scene: PackedScene
@onready var bullet: PlasmaProjectile = self.bullet_scene.instantiate()
@export var shots_per_second: float:
  set(value):
    shots_per_second = value
    self.fire_time = 1.0 / shots_per_second
var fire_time: float
@onready var aim_ray: RayCast3D = %aim_ray

var input_direction: Vector2
var move_direction: Vector3

func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  self.aim_lock_timer.timeout.connect(func(): self.aim_locked = false)
  self.aim_ray.target_position = Vector3.FORWARD * self.bullet.reach

func _physics_process(delta: float) -> void:
  self.animator.advance(delta)
  self.time += delta
  self.camera_direction = self.camera.global_position.direction_to(
    self.aim.global_position
  )

  if not self.is_on_floor():
    self.velocity.y -= self.GRAVITY * delta
    self.control_ratio = self.AIR_CONTROL
  else:
    self.control_ratio = self.GROUND_CONTROL

  if Input.is_action_pressed("jump") and self.is_on_floor():
    self.velocity.y = self.JUMP_VELOCITY

  self.input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
  self.move_direction = self.get_camera_relative_movement().normalized()
  self.move_direction.y = 0.0

  if self.move_direction.length_squared() > 0:
    self.velocity.x = move_toward(
      self.velocity.x,
      self.move_direction.x * self.max_speed,
      self.ACCELERATION * self.control_ratio * delta
    )
    self.velocity.z = move_toward(
      self.velocity.z,
      self.move_direction.z * self.max_speed,
      self.ACCELERATION * self.control_ratio * delta
    )
    var target_angle: float = Vector3.FORWARD.signed_angle_to(self.move_direction, Vector3.UP)
    self.skin.rotation.y = lerp_angle(
      self.skin.rotation.y,
      target_angle,
      self.rotation_speed * delta
    )
    self.update_speed()
    self.animator.play("running")
    self.animator.walk(delta)
  else:
    self.velocity.x = move_toward(self.velocity.x, 0, self.ACCELERATION * delta)
    self.velocity.z = move_toward(self.velocity.z, 0, self.ACCELERATION * delta)
    self.update_speed()
    self.animator.play("idle")
  self.move_and_slide()

  if Input.is_action_pressed("trigger") and self.fire_locked_timer.is_stopped():
    self.aim_locked = true
    self.aim_lock_timer.start()
    self.fire_locked_timer.start(self.fire_time)
    self.animator.shoot(self.fire_time)
    self.trigger()

  if self.aim_locked:
    var target_angle: float = Vector3.FORWARD.signed_angle_to(self.camera_direction, Vector3.UP)
    self.skin.rotation.y = lerp_angle(
      self.skin.rotation.y,
      target_angle,
      self.rotation_speed * 2.0 * delta
    )
    self.animator.lock_head_at_angle(self.pivot.global_rotation)

func update_speed() -> void:
  self.speed = Vector2(self.velocity.x, self.velocity.z).length()

func get_camera_relative_movement() -> Vector3:
  var forward: Vector3 = self.camera.global_transform.basis.z
  var right: Vector3 = self.camera.global_transform.basis.x
  return forward * self.input_direction.y \
    + right * self.input_direction.x

func trigger() -> void:
  self.plasma_manager.spawn_new_projectile(self.id, self.bullet_scene, self.camera_direction)

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
