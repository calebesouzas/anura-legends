class_name Player extends AliveEntity

@export_group("Camera")
@export_range(0.0, 1.0, 0.05, "Sensitivity on mobile")
var TOUCH_SENSITIVITY: float = 0.25
@export_range(0.0, 1.0, 0.05, "Sensitivity on mouse")
var MOUSE_SENSITIVITY: float = 0.25
@export_range(0.0, 1.0, 0.05, "Sensitivity on controller")
var CONTROLLER_SENSITIVITY: float = 0.25
@onready var pivot: Node3D = %pivot
@onready var camera: Camera3D = %camera
var aim_locked: bool = false

@onready var aim_lock_timer: Timer = %aim_lock_timer
@onready var fire_locked_timer: Timer = %fire_locked_timer
@onready var feet_ray: RayCast3D = %feet_ray

@export_group("Skin")
@onready var skin: Node3D = %skin
@export var SKIN_ROTATION_SPEED: float = 12.0

## input
@export var MOVE_DEADZONE: float = 0.2
var input_direction: Vector2
var move_direction: Vector3

func pressed(action: StringName) -> bool:
  return Input.is_action_pressed(action)

func just_pressed(action: StringName) -> bool:
  return Input.is_action_just_pressed(action)

func _process(_delta: float) -> void:
  input_direction = Input.get_vector(
    "move_left", "move_right", "move_forward", "move_backward")

func _unhandled_input(event: InputEvent) -> void:
  var is_camera_motion: bool = false
  var camera_motion: Vector2 = Vector2.ZERO
  if event is InputEventScreenDrag:
    camera_motion = event.screen_relative * TOUCH_SENSITIVITY
    is_camera_motion = true
  elif event is InputEventMouseMotion:
    camera_motion = event.screen_relative * MOUSE_SENSITIVITY
    is_camera_motion = true
  elif event is InputEventJoypadMotion:
    if event.axis == JoyAxis.JOY_AXIS_RIGHT_X:
      camera_motion.x = event.axis_value * CONTROLLER_SENSITIVITY
      is_camera_motion = true
    elif event.axis ==  JoyAxis.JOY_AXIS_RIGHT_Y:
      camera_motion.y = event.axis_value * CONTROLLER_SENSITIVITY
      is_camera_motion = true

  if is_camera_motion:
    pivot.rotation_degrees.y -= camera_motion.x
    pivot.rotation_degrees.x -= camera_motion.y
    # don't accumulate rotation indefinitelly
    pivot.rotation_degrees.y = wrapf(
      pivot.rotation_degrees.y, 0.0, 360.0
    )
    # limit vertical rotation to prevent camera getting upside-down and breaking
    pivot.rotation_degrees.x = clampf(
      pivot.rotation_degrees.x,
      -85.0, # look down limit
      60.0 # look up limit
    )
  elif event is InputEventKey and event.keycode == KEY_ESCAPE:
    get_tree().quit()

## physics
var wanna_move: bool

enum State {IDLE_MOVE, JUMP, FALL, FLIP, DASH}
var input_locked: bool = false
var grounded: bool
var dot: float

var ticks: int = 0
var state_ticks: int = 0
var prev_state: State
var state: State = State.IDLE_MOVE:
  set(new_state):
    if prev_state != state: prev_state = state
    state = new_state
    state_ticks = 0

var current_speed: float

var jump_window: int = 30
var jump_buf_window: int = 12
var jump_buffered: bool
var last_jump_tick: int

# this is the tick amount that input will be locked
var dash_window: int = 30

const SPEED: float = 5.0

const ADHESION_FACTOR: float = 2.0

const ACCELERATION: float = 30.0 # reaches `SPEED` in half second
const FRICTION: float = 60.0 # stops movement in a quarter of a second

const HIGH_JUMP: float = 2.0
const JUMP: float = 1.0

const DASH_FORCE: float = 10.0

### State Machine
func handle_state(delta: float) -> void:
  match state:
    State.IDLE_MOVE:
      if wanna_move:
        move_2d(move_direction, delta)
      else:
        move_2d(Vector3.ZERO, delta, FRICTION)

      if not grounded:
        state = State.FALL
      elif pressed("jump") or jump_buffered:
        state = State.JUMP

    State.FALL:
      if grounded:
        state = State.IDLE_MOVE
        return
      elif just_pressed("jump") and prev_state == State.IDLE_MOVE \
          and state_ticks < jump_buf_window:
        state = State.JUMP
        return

      move_2d(move_direction, delta)
      velocity += get_gravity() * delta

    State.JUMP:
      if pressed("adhesion") and can_join():
        state = State.DASH
        return
      if state_ticks > jump_window or not pressed("jump") and not jump_buffered:
        state = State.FALL
        return

      move_2d(move_direction, delta)
      if state_ticks == 1:
        velocity.y = HIGH_JUMP
      else:
        velocity.y += JUMP * delta

    State.DASH:
      if state_ticks > dash_window:
        state = State.FALL
        input_locked = false
        return

      if state_ticks == 1:
        input_locked = true
        #@todo effect!
        velocity += move_direction * DASH_FORCE # no friction!

    _:
      assert(false, "Unhandled state: " + State.keys()[state])

func _physics_process(delta: float) -> void:
  ticks += 1
  state_ticks += 1

  current_speed = Vector2(velocity.x, velocity.z).length()

  grounded = is_on_floor()

  if just_pressed("jump"):
    last_jump_tick = ticks

  jump_buffered = ticks - last_jump_tick < jump_buf_window

  if not input_locked:
    move_direction = Vector3(input_direction.x, 0.0, input_direction.y) \
      .rotated(Vector3.UP, pivot.rotation.y)
    wanna_move = move_direction.length_squared() > MOVE_DEADZONE ** 2

  dot = velocity.dot(move_direction)

  handle_state(delta)

  move_and_slide()

  if pressed("trigger") and fire_locked_timer.is_stopped():
    aim_locked = true
    aim_lock_timer.start()
    fire_locked_timer.start(fire_time)
    trigger()

  rotate_skin(delta)

## movement
### move_2D horizontal movement, Y axis ignored
func move_2d(
    direction: Vector3,
    delta: float,
    speed: float = SPEED,
    acceleration: float = ACCELERATION
) -> void:
  velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
  velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

## adhesion
func can_join() -> bool:
  if not feet_ray.is_colliding(): return false
  return plasma_manager.can_join(self)

## combat
@export_group("Combat")
@export var bullet_scene: PackedScene
@onready var bullet: PlasmaProjectile = self.bullet_scene.instantiate()
@onready var bullet_point: Marker3D = %bullet_point
@export var shots_per_second: float:
  set(value):
    shots_per_second = value
    fire_time = 1.0 / shots_per_second
var fire_time: float

func trigger() -> void:
  plasma_manager.spawn_new_projectile(id, bullet_scene, team_color, -pivot.basis.z)

## visual
func rotate_skin(delta: float) -> void:
  if not wanna_move: return
  var target_angle: float = Vector3.FORWARD \
    .signed_angle_to(-pivot.basis.z, Vector3.UP) if aim_locked \
      else Vector3.FORWARD.signed_angle_to(move_direction, Vector3.UP)
  skin.rotation.y = lerp_angle(
    skin.rotation.y,
    target_angle,
    SKIN_ROTATION_SPEED * delta
  )

## misc
func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  aim_lock_timer.timeout.connect(func(): aim_locked = false)

func _init() -> void:
  health = 1000
