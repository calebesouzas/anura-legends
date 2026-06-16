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
@export var MOVE_DEADZONE: float = 0.2
@export var CONTROLLER_CAMERA_DEADZONE: float = 0.04
var input_direction: Vector2
var wishdir: Vector3

func pressed(action: StringName) -> bool:
  return Input.is_action_pressed(action)

func just_pressed(action: StringName) -> bool:
  return Input.is_action_just_pressed(action)

func is_action_valid(action_name: StringName) -> bool:
  return pressed(action_name) or self[action_name + "_buffer"] > 0

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
var dot: float

var state_ticks: int = 0
var state: State = State.IDLE_MOVE:
  set(new_state):
    state = new_state
    state_ticks = 0

var current_speed: float

var grounded: bool

const LANDED_WINDOW: int = 2
var landed_buffer: int

const COYOTE_WINDOW: int = 6
var coyote_buffer: int

const JUMP_DURATION: int = 15
const JUMP_WINDOW: int = 6
var jump_buffer: int

const FLIP_DURATION: int = 15
const FLIP_ADD_FORCE: float = 3.0
const FLIP_SET_FORCE: float = 4.5
var can_flip: bool = false
const FLIP_RELOAD_DELAY: int = 6

const DASH_DURATION: int = 15 # tick amount that input will be locked
const SUPER_DASH_UNLOCK_MOMENT: int = 10
const DASH_FORCE: float = 5.0

const ADHESION_WINDOW: int = 6
var adhesion_buffer: int

const SPEED: float = 5.0

const ADHESION_FACTOR: float = 3.0

const AIR_ACCELERATION: float = 3.0
const ACCELERATION: float = 30.0 # reaches `SPEED` in half second
const FRICTION: float = 60.0 # stops movement in a quarter of a second

const HIGH_JUMP: float = 3.0
const JUMP: float = 6.0

### State Machine
func handle_state(delta: float) -> void:
  match state:
    State.IDLE_MOVE:
      can_flip = state_ticks > FLIP_RELOAD_DELAY
      var factor: float = 1.0
      if can_join() and adhesion_buffer > 0:
        factor = ADHESION_FACTOR

      if wanna_move:
        # no friction when landing and jumping at the same time
        if state_ticks <= LANDED_WINDOW and jump_buffer > 0:
          move_2d(wishdir, delta, AIR_ACCELERATION * factor)
        else:
          move_2d(wishdir, delta, ACCELERATION * factor)
      else:
        move_2d(Vector3.ZERO, delta, FRICTION * factor)

      if not grounded:
        state = State.FALL
      elif is_action_valid("jump"):
        state = dash_or_jump()
        jump_buffer = 0
        coyote_buffer = 0

    State.FALL:
      if grounded:
        state = State.IDLE_MOVE
        return
      elif jump_buffer > 1 and coyote_buffer > 0:
        state = dash_or_jump()
        jump_buffer = 0
        coyote_buffer = 0
        return
      elif just_pressed("jump") and can_flip \
          and not is_action_valid("adhesion"):
        can_flip = false
        state = State.FLIP
        return

      if wanna_move:
        move_2d(wishdir, delta, AIR_ACCELERATION)
      velocity += get_gravity() * delta

    State.JUMP:
      if state_ticks > JUMP_DURATION or not is_action_valid("jump"):
        state = State.FALL
        return

      if wanna_move:
        move_2d(wishdir, delta, AIR_ACCELERATION)

      if state_ticks == 1:
        velocity.y = HIGH_JUMP
      else:
        velocity.y += JUMP * delta

    State.DASH:
      if state_ticks > DASH_DURATION:
        state = State.FALL
        input_locked = false
        return

      can_flip = true

      if state_ticks == 1:
        input_locked = true
        #@todo effect!
        velocity += \
        (camera_relative_movement()
          if not grounded
          else wishdir.normalized()) * DASH_FORCE # no friction!

      if jump_buffer > 0 and coyote_buffer > 0 \
          and state_ticks >= SUPER_DASH_UNLOCK_MOMENT:
        velocity.y += DASH_FORCE
        jump_buffer = 0
        coyote_buffer = 0

    State.FLIP:
      if state_ticks > FLIP_DURATION:
        state = State.FALL
        skin.rotation_degrees.x = 0
        return

      jump_buffer = 0
      coyote_buffer = 0

      rotate_skin(delta * 2, true)
      if state_ticks > 1:
        const ANGLE: float = -360 # negarive to go forward
        skin.rotation_degrees.x = lerp(skin.rotation_degrees.x, ANGLE,
          (1.0/60) * state_ticks)
        return

      var movement: Vector3 = camera_relative_movement()
      if movement.length_squared() < MOVE_DEADZONE ** 2:
        velocity.y = FLIP_SET_FORCE
      elif velocity.dot(movement) < 0.0:
        velocity = movement * FLIP_SET_FORCE
      else:
        velocity += movement * FLIP_ADD_FORCE

    _:
      assert(false, "Unhandled state: " + State.keys()[state])

func _physics_process(delta: float) -> void:
  state_ticks += 1

  current_speed = Vector2(velocity.x, velocity.z).length()

  if is_on_floor():
    if not grounded:
      landed_buffer = LANDED_WINDOW
    elif landed_buffer > 0:
      landed_buffer -= 1
    grounded = true
    coyote_buffer = COYOTE_WINDOW
  else:
    grounded = false
    if coyote_buffer > 0: coyote_buffer -= 1

  if just_pressed("jump"):
    jump_buffer = JUMP_WINDOW
  elif jump_buffer > 0:
    jump_buffer -= 1

  if just_pressed("adhesion"):
    adhesion_buffer = ADHESION_WINDOW
  elif adhesion_buffer > 0:
    adhesion_buffer -= 1

  if not input_locked:
    wishdir = Vector3(input_direction.x, 0.0, -input_direction.y) \
      .rotated(Vector3.UP, pivot.rotation.y)
    wanna_move = wishdir.length_squared() > MOVE_DEADZONE ** 2

  dot = velocity.dot(wishdir)

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
func dash_or_jump() -> State:
  return State.DASH if is_action_valid("adhesion") else State.JUMP

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

func can_join() -> bool:
  return plasma_manager.can_join(self)

## visual
func rotate_skin(delta: float, force: bool = false) -> void:
  if not wanna_move and not force: return
  var target_angle: float = Vector3.FORWARD \
    .signed_angle_to(-pivot.basis.z, Vector3.UP) if aim_locked \
      else Vector3.FORWARD.signed_angle_to(wishdir, Vector3.UP)
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
  debug_value("state", State.keys()[state])
  debug_field("state_ticks")
  debug_field("grounded")
  debug_field("dot")
  debug_value("can_join()", can_join())
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
