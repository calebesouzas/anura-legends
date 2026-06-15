class_name Player extends AliveEntity

@export_group("Camera")
@export_range(0.0, 1.0, 0.05, "Sensitivity on mobile")
var TOUCH_SENSITIVITY: float = 0.25
@export_range(0.0, 1.0, 0.05, "Sensitivity on mouse")
var MOUSE_SENSITIVITY: float = 0.25
@export_range(0.0, 1.0, 0.05, "Sensitivity on controller")
var CONTROLLER_SENSITIVITY: float = 5.0
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
const DEFAULT_INPUT_BUF_WINDOW: int = 12
@export var MOVE_DEADZONE: float = 0.2
@export var CONTROLLER_CAMERA_DEADZONE: float = 0.04
var input_direction: Vector2
var move_direction: Vector3

func pressed(action: StringName) -> bool:
  return Input.is_action_pressed(action)

func just_pressed(action: StringName) -> bool:
  return Input.is_action_just_pressed(action)

func _process(_delta: float) -> void:
  input_direction = Input.get_vector(
    "move_left", "move_right", "move_backward", "move_forward")
  if Input.get_connected_joypads().size() > 0:
    var camera_motion: Vector2 = Input.get_vector(
      "camera_right", "camera_left", "camera_down", "camera_up", CONTROLLER_CAMERA_DEADZONE)
    pivot.rotation_degrees.y += camera_motion.x * CONTROLLER_SENSITIVITY
    pivot.rotation_degrees.x += camera_motion.y * CONTROLLER_SENSITIVITY

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
    return

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
  elif event.is_action_pressed("debug"):
    debug.visible = not debug.visible

## physics
var wanna_move: bool

enum State {IDLE_MOVE, JUMP, FALL, FLIP, DASH}
var input_locked: bool = false
var grounded: bool
var dot: float

var ticks: int = 0
var state_ticks: int = 0
var state: State = State.IDLE_MOVE:
  set(new_state):
    state = new_state
    state_ticks = 0

var current_speed: float

const JUST_LAND_WINDOW: int = 2
var last_land_tick: int

var jump_window: int = 30
var jump_buf_window: int = DEFAULT_INPUT_BUF_WINDOW
var jump_buffered: bool
var last_jump_tick: int

var dash_window: int = 15 # tick amount that input will be locked
var dash_buf_window: int = DEFAULT_INPUT_BUF_WINDOW
var dash_buffered: bool
var last_dash_tick: int
var can_dash: bool = false

var adhesion_buf_window: int = DEFAULT_INPUT_BUF_WINDOW
var adhesion_buffered: bool
var last_adhesion_tick: int

const SPEED: float = 5.0

const ADHESION_FACTOR: float = 3.0

const AIR_ACCELERATION: float = 3.0
const ACCELERATION: float = 30.0 # reaches `SPEED` in half second
const FRICTION: float = 60.0 # stops movement in a quarter of a second

const HIGH_JUMP: float = 2.0
const JUMP: float = 1.0

const DASH_FORCE: float = 5.0

### State Machine
func handle_state(delta: float) -> void:
  match state:
    State.IDLE_MOVE:
      var factor: float = 1.0
      if can_join():
        can_dash = true
        if adhesion_wanted():
          factor = ADHESION_FACTOR
      else:
        can_dash = false

      if wanna_move:
        # no friction when landing and jumping at the same time
        if state_ticks <= JUST_LAND_WINDOW and jump_wanted():
          move_2d(move_direction, delta, AIR_ACCELERATION * factor)
        else:
          move_2d(move_direction, delta, ACCELERATION * factor)
      else:
        move_2d(Vector3.ZERO, delta, FRICTION * factor)

      if not grounded:
        state = State.FALL
      elif jump_wanted():
        state = State.JUMP
      elif dash_wanted() and can_dash:
        state = State.DASH

    State.FALL:
      if grounded:
        state = State.IDLE_MOVE
        return
      elif just_pressed("jump") and can_jump():
        state = State.JUMP
        return
      elif just_pressed("dash") and can_dash:
        state = State.DASH
        return

      if wanna_move:
        move_2d(move_direction, delta, AIR_ACCELERATION)
      velocity += get_gravity() * delta

    State.JUMP:
      if state_ticks > jump_window or not pressed("jump") and not jump_buffered:
        state = State.FALL
        return

      if wanna_move:
        move_2d(move_direction, delta, AIR_ACCELERATION)

      if state_ticks == 1:
        velocity.y = HIGH_JUMP
      else:
        velocity.y += JUMP * delta

      if dash_wanted() and can_dash:
        state = State.DASH

    State.DASH:
      can_dash = false
      if state_ticks > dash_window:
        state = State.FALL
        input_locked = false
        return

      if state_ticks == 1:
        input_locked = true
        #@todo effect!
        velocity += \
        (camera_relative_movement()
          if not grounded
          else move_direction.normalized()) * DASH_FORCE # no friction!

      if just_pressed("jump") and can_jump():
        velocity.y += DASH_FORCE

    _:
      assert(false, "Unhandled state: " + State.keys()[state])

func _physics_process(delta: float) -> void:
  ticks += 1
  state_ticks += 1

  current_speed = Vector2(velocity.x, velocity.z).length()

  if is_on_floor():
    if not grounded: last_land_tick = ticks
    grounded = true
  else:
    grounded = false

  if just_pressed("jump"):
    last_jump_tick = ticks
  jump_buffered = ticks - last_jump_tick < jump_buf_window

  if just_pressed("adhesion"):
    last_adhesion_tick = ticks
  adhesion_buffered = ticks - last_adhesion_tick < adhesion_buf_window

  if just_pressed("dash"):
    last_dash_tick = ticks
  dash_buffered = ticks - last_dash_tick < dash_buf_window

  if not input_locked:
    move_direction = Vector3(input_direction.x, 0.0, -input_direction.y) \
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

  debug_update()

## movement
### move_2D horizontal movement, Y axis ignored
func move_2d(
    direction: Vector3,
    delta: float,
    acceleration: float = ACCELERATION,
    speed: float = SPEED
) -> void:
  velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
  velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

func camera_relative_movement() -> Vector3:
  var forward: Vector3 = -camera.global_transform.basis.z
  var right: Vector3 = camera.global_transform.basis.x
  return forward * input_direction.y + right * input_direction.x

### dashes and jumps
func jump_wanted() -> bool:
  return jump_buffered or pressed("jump")

func can_jump() -> bool:
  return grounded or ticks - last_land_tick < jump_buf_window

func dash_wanted() -> bool:
  return dash_buffered or pressed("dash")

### adhesion
func adhesion_wanted() -> bool:
  return adhesion_buffered or pressed("adhesion")

func can_join() -> bool:
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

### paint
var ground_color: Team.BlockColor

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

## debug
@onready var debug: RichTextLabel = %debug

func debug_field(field_name: StringName) -> void:
  debug.add_text(field_name + " = " + str(self[field_name]))
  debug.newline()

func debug_value(value_name: StringName, value: Variant, new_line: bool = true) -> void:
  debug.add_text(value_name + " = " + str(value))
  if new_line: debug.newline()

func debug_update() -> void:
  debug.clear()
  debug_field("velocity")
  debug_field("current_speed")
  debug_field("ticks")
  debug_value("state", State.keys()[state])
  debug_field("state_ticks")
  debug_field("grounded")
  debug_field("dot")
  debug_field("can_dash")
  debug_value("can_join()", can_join())
  debug_value("jump_wanted()", jump_wanted())
  debug_value("dash_wanted()", dash_wanted())
  debug_value("adhesion_wanted()", adhesion_wanted())
  debug_value("feet_ray.is_colliding()", feet_ray.is_colliding(), false)
  if feet_ray.is_colliding():
    debug_value("; feet_ray.get_collision_point()", feet_ray.get_collision_point())
  else:
    debug.newline()
  debug_value("ground_color", Team.BlockColor.keys()[ground_color])
  debug_field("health")

## misc
func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  debug.visible = false
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  aim_lock_timer.timeout.connect(func(): aim_locked = false)

func _init() -> void:
  health = 1000
