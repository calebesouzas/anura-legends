class_name Player extends AliveEntity

func _init() -> void:
  self.health = 1000

enum State {IDLE, RUN, JUMP, FALL, DASH}
enum Flags {MOVE_LOCKED = 1, TRIGGER_LOCKED = 2, GROUNDED = 4}

var state: State
signal state_changed(old_state: State, new_state: State)
var flags: int = 0

var aim_locked: bool = false

@export_group("Physics")
@export var GROUND_SPEED: float = 7.0
@export var GROUND_ACCELERATION: float = 21.0
@export var AIR_SPEED: float = 5.0
@export var AIR_ACCELERATION: float = 10.5
@export var JUMP_FORCE: float = 5.0
@export var GRAVITY: float = 12.0
@export var MOVE_DEADZONE: float = 0.2
var time: float = 0.0
var ground_speed: float
var jump_force: float

@export_group("Dashing")
@export var DASH_SPEED: float = 20.0
@export var DASH_ACCELERATION: float = 500.0
@onready var dash_timer: Timer = %dash_timer

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

@export_group("Skin")
@onready var skin: Node3D = %skin
@export var ROTATION_SPEED: float = 12.0

@export_group("Combat")
@export var bullet_scene: PackedScene
@onready var bullet: PlasmaProjectile = self.bullet_scene.instantiate()
@export var shots_per_second: float:
  set(value):
    shots_per_second = value
    self.fire_time = 1.0 / shots_per_second
var fire_time: float

var input_direction: Vector2
var move_direction: Vector3

func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  self.aim_lock_timer.timeout.connect(func(): self.aim_locked = false)
  self.state_changed.connect(func(_old: State, new: State): print(State.keys()[new]))

func _physics_process(delta: float) -> void:
  self.time += delta
  self.camera_direction = self.camera.global_position.direction_to(
    self.aim.global_position
  )
  self.ground_speed = Vector2(self.velocity.x, self.velocity.z).length()
  if self.is_on_floor():
    self.flags |= Flags.GROUNDED
  else:
    self.flags &= ~Flags.GROUNDED

  if not self.flags & Flags.MOVE_LOCKED:
    self.input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    self.move_direction = Vector3(self.input_direction.x, 0.0, self.input_direction.y).rotated(Vector3.UP, self.pivot.rotation.y)

  self.handle_state(delta)

  self.move_and_slide()
  
  if self.flags & Flags.TRIGGER_LOCKED:
    return

  if Input.is_action_pressed("trigger") and self.fire_locked_timer.is_stopped():
    self.aim_locked = true
    self.aim_lock_timer.start()
    self.fire_locked_timer.start(self.fire_time)
    self.trigger()

  if self.move_direction.length_squared() <= pow(self.MOVE_DEADZONE, 2):
    return

  var target_angle: float = \
    Vector3.FORWARD.signed_angle_to(self.camera_direction, Vector3.UP) \
  if self.aim_locked else Vector3.FORWARD.signed_angle_to(self.velocity, Vector3.UP)

  self.skin.rotation.y = lerp_angle(
    self.skin.rotation.y,
    target_angle,
    self.ROTATION_SPEED * 2.0 * delta
  )

func handle_state(delta: float) -> void:
  match self.state:
    State.IDLE:
      self.velocity.x = move_toward(self.velocity.x, 0, self.GROUND_ACCELERATION * delta)
      self.velocity.z = move_toward(self.velocity.z, 0, self.GROUND_ACCELERATION * delta)
      if self.input_direction.length_squared() > self.MOVE_DEADZONE*self.MOVE_DEADZONE:
        self.set_state(State.RUN) #@issue one tick of input lag for movement...
      elif not self.flags & Flags.GROUNDED:
        self.set_state(State.FALL)
      elif Input.is_action_pressed("jump"):
        self.set_state(State.JUMP)
    State.RUN:
      self.move_2d(self.move_direction, self.GROUND_SPEED, self.GROUND_ACCELERATION, delta)
      if self.input_direction.length_squared() < self.MOVE_DEADZONE*self.MOVE_DEADZONE:
        self.set_state(State.IDLE)
      elif not self.flags & Flags.GROUNDED:
        self.set_state(State.FALL)
      elif Input.is_action_pressed("jump"):
        self.set_state(State.JUMP)
    State.FALL:
      if self.flags & Flags.GROUNDED:
        self.set_state(State.IDLE)
        return
      self.move_2d(self.move_direction, self.AIR_SPEED, self.AIR_ACCELERATION, delta)
      self.velocity.y -= self.GRAVITY * delta
    State.JUMP:
      if not Input.is_action_pressed("jump") or self.jump_force <= 0:
        self.jump_force = self.JUMP_FORCE
        self.set_state(State.FALL)
        return
      self.move_2d(self.move_direction, self.GROUND_SPEED, self.AIR_ACCELERATION, delta)
      self.velocity.y = self.jump_force

      self.jump_force = move_toward(self.jump_force, 0.0, self.GRAVITY * delta)
    _:
      assert(false, "Unhandled state: " + State.keys()[self.state])

func set_state(new_state: State) -> void:
  self.state_changed.emit(self.state, new_state)
  self.state = new_state

func move_3d(direction: Vector3, speed: float, acceleration: float, delta: float) -> void:
  self.velocity = self.velocity.move_toward(direction * speed, acceleration * delta)

func move_2d(direction: Vector3, speed: float, acceleration: float, delta: float) -> void:
  self.velocity.x = move_toward(self.velocity.x, direction.x * speed, acceleration * delta)
  self.velocity.z = move_toward(self.velocity.z, direction.z * speed, acceleration * delta)

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
