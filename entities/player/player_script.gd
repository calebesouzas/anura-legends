class_name Player extends AliveEntity

func _init() -> void:
  self.health = 1000

"""
State Machine:
  IDLE_MOVE -> movement, friction (breaking movement)
    transitions: [JUMP, FALL, SWIM, DASH]
  JUMP -> jumping with variable height
    transitions: [IDLE_MOVE, FALL, SWIM, DASH]
  FALL -> falling with uniform gravity
    transitions: [IDLE_MOVE, SWIM, ROLL: # special jump #, DASH]
  ROLL -> [
    second jump in the air,
    goes in the direction totally relative to the camera,
    if `self.dot` is near `-1.0` it will suddenly change direction,
    otherwise it's gonna just add velocity to the roll direction
  ]
    transitions: [IDLE_MOVE, FALL]
  SWIM -> the Walk In Plasma skill. It gives you a DASH, lowers friction and keeps momentum!
    transitions: [IDLE_MOVE, FALL, DASH]
  DASH -> fast impulse towards move direction, with a down force if done in the air or an up
    force if you jump within a defined tick window!
    transitions: [IDLE_MOVE, FALL, SWIM]
"""

enum State {IDLE_MOVE, JUMP, FALL, ROLL, SWIM, DASH}
var move_locked: bool
var swim_locked: bool
var trigger_locked: bool
var jump_pressed: bool
var swim_pressed: bool
var trigger_pressed: bool
var just_move: bool
var just_jump: bool
var just_dash: bool
var grounded: bool
var wanna_move: bool

var state: State
signal state_changed(old_state: State, new_state: State)
var state_ticks: int = 0

var aim_locked: bool = false

@export_group("Physics")
@export var IDLE_MOVE_SPEED: float = 5.0
@export var FALL_SPEED: float = 5.0
@export var JUMP_SPEED: float = 8.0
@export var ROLL_SPEED: float = JUMP_SPEED
@export var GROUND_ACCELERATION: float = 21.0
@export var AIR_ACCELERATION: float = 10.5
@export var JUMP_FORCE: float = 5.0
@export var JUMP_CURVE: Curve
@export var GRAVITY: float = 12.0
@export var FRICTION: float = 10.0
@export var MOVE_DEADZONE: float = 0.2
@export var ADD_POINT: float = 8.0
var time: float = 0.0
var ground_speed: float
var speed: float
var final_speed: float
var state_speeds: Array[float]
var jump_force: float

@export_group("Bunny Hopping")
@export_range(-1.0, 1.0, 0.01) var DOT_POINT: float = 0.0
@export_range(0.05, 0.5, 0.05) var DOT_RANGE: float = 0.1

#@todo swim!
@export_group("Swimming")
@export var SWIM_SPEED: float = 12.0
@export var SWIM_ACCELERATION: float = 3.0
@export var SWIM_OPPOSITE_ACCELERATION: float = 10.0

@export_group("Dashing")
@export var DASH_SPEED: float = 10.0
@export var DASH_ACCELERATION: float = 500.0
@export var DASH_DURATION_IN_TICKS: int = 30
var dash_ticks: int = 0 # how many Physics Ticks we've been dashing

"""
Yo! New idea!
What if i do SWIM and SHOOT (while swimming) to DASH?
Splatoon has a thing about using secondary weapon while shooting to dodge...

I should definitelly develop this idea!
"""

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
@onready var feet_ray: RayCast3D = %feet_ray

var airbone_time: float = 0

@export_group("Skin")
@onready var skin: Node3D = %skin
@onready var health_indicator: Label3D = %health_indicator
@export var ROTATION_SPEED: float = 12.0

@export_group("Combat")
@export var bullet_scene: PackedScene
@onready var bullet: PlasmaProjectile = self.bullet_scene.instantiate()
@export var shots_per_second: float:
  set(value):
    shots_per_second = value
    fire_time = 1.0 / shots_per_second
var fire_time: float

var input_direction: Vector2
var move_direction: Vector3
var prev_move_len: float
var curr_move_len: float

var dot: float

func _ready() -> void:
  if not OS.has_feature("android"):
    %hud.queue_free()
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  aim_lock_timer.timeout.connect(func(): aim_locked = false)
  skin.visibility_changed.connect(func(): health_indicator.visible = not skin.visible)
  health_indicator.visible = false
  for state_key: StringName in State.keys():
    state_speeds.append(self[state_key + "_SPEED"])
  # self.state_changed.connect(func(_old: State, new: State): print(State.keys()[new]))

func _physics_process(delta: float) -> void:
  time += delta
  state_ticks += 1
  camera_direction = camera.global_position.direction_to(
    aim.global_position
  )

  ground_speed = Vector2(velocity.x, velocity.z).length()

  grounded = is_on_floor()
  if grounded:
    if airbone_time > 0: print("Air time ", airbone_time)
    airbone_time = 0
  else:
    airbone_time += delta

  if not move_locked:
    input_direction = get_movement()
    prev_move_len = move_direction.length_squared()
    move_direction = Vector3(input_direction.x, 0.0, input_direction.y).rotated(Vector3.UP, pivot.rotation.y)
    curr_move_len = move_direction.length_squared()
    wanna_move = curr_move_len > MOVE_DEADZONE ** 2
    just_move = is_equal_approx(prev_move_len, 0) and wanna_move

  dot = velocity.dot(move_direction)

  just_jump = Input.is_action_just_pressed("jump")
  jump_pressed = Input.is_action_pressed("jump")

  swim_pressed = Input.is_action_pressed("swim")

  trigger_pressed = not trigger_locked and Input.is_action_pressed("trigger")

  just_dash = Input.is_action_just_pressed("dash")

  speed = state_speeds[state]
  final_speed = lerp(
    speed,
    speed + (ground_speed if ground_speed > ADD_POINT else 0.0),
    delta
  )
  handle_state(delta)

  move_and_slide()

  health_indicator.text = str(health)

  if trigger_pressed and fire_locked_timer.is_stopped():
    aim_locked = true
    aim_lock_timer.start()
    fire_locked_timer.start(fire_time)
    trigger()

  if not wanna_move:
    return

  var target_angle: float = \
    Vector3.FORWARD.signed_angle_to(camera_direction, Vector3.UP) \
      if aim_locked else Vector3.FORWARD.signed_angle_to(velocity, Vector3.UP)
  skin.rotation.y = lerp_angle(
    skin.rotation.y,
    target_angle,
    ROTATION_SPEED * 2.0 * delta
  )
func handle_state(delta: float) -> void:
  match state:
    State.IDLE_MOVE:
      if wanna_move:
        move_2d(move_direction, GROUND_ACCELERATION, delta)
      else:
        move_2d(Vector3.ZERO, FRICTION, delta)

      if not grounded:
        set_state(State.FALL)
      elif jump_pressed:
        set_state(State.JUMP)
      elif swim_pressed:
        set_state(State.SWIM)
      elif just_dash:
        set_state(State.DASH)

    State.FALL:
      if grounded:
        set_state(State.SWIM if swim_pressed else State.IDLE_MOVE)
        return
      elif just_dash:
        set_state(State.DASH)
        return

      move_2d(move_direction, AIR_ACCELERATION, delta)
      velocity.y -= GRAVITY * delta

    State.JUMP:
      if not jump_pressed or jump_force <= 0:
        jump_force = JUMP_FORCE
        set_state(State.FALL)
        return
      elif just_dash:
        set_state(State.DASH)
        return

      move_2d(move_direction, AIR_ACCELERATION, delta)
      velocity.y = jump_force
      jump_force = JUMP_CURVE.sample(airbone_time) * JUMP_FORCE

    State.DASH:
      if state_ticks > DASH_DURATION_IN_TICKS:
        set_state(State.FALL)
        move_locked = false
        trigger_locked = false
        return

      if state_ticks == 1:
        move_locked = true
        trigger_locked = true
        #@todo effect!

      if grounded:
        move_2d(move_direction, DASH_ACCELERATION, delta)
      else:
        move_3d(move_direction + Vector3.DOWN, DASH_ACCELERATION, delta)

    State.SWIM:
      if not plasma_manager.can_swim(feet_ray.get_collision_point(), team_color) \
          or not swim_pressed:
        trigger_locked = false
        skin.visible = true
        set_state(State.IDLE_MOVE)
        return

      trigger_locked = true
      #@todo effect!
      skin.visible = false
      move_2d(
        move_direction,
        SWIM_OPPOSITE_ACCELERATION if dot < 0.0 else SWIM_ACCELERATION,
        delta
      )

      if just_dash:
        set_state(State.DASH)
      elif jump_pressed:
        set_state(State.JUMP)
      elif not grounded:
        set_state(State.FALL)
    _:
      assert(false, "Unhandled state: " + State.keys()[state])

func set_state(new_state: State) -> void:
  state_changed.emit(state, new_state)
  state = new_state
  state_ticks = 0

func move_3d(direction: Vector3, acceleration: float, delta: float) -> void:
  velocity = velocity.move_toward(direction * final_speed, acceleration * delta)

func move_2d(direction: Vector3, acceleration: float, delta: float) -> void:
  velocity.x = move_toward(velocity.x, direction.x * final_speed, acceleration * delta)
  velocity.z = move_toward(velocity.z, direction.z * final_speed, acceleration * delta)

func trigger() -> void:
  plasma_manager.spawn_new_projectile(id, bullet_scene, team_color, camera_direction)

func get_movement() -> Vector2:
  return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func has_the_dot() -> bool:
  return DOT_POINT - DOT_RANGE < dot and dot < DOT_POINT + DOT_RANGE

func _unhandled_input(event: InputEvent) -> void:
  var is_camera_motion: bool = false
  var camera_motion: Vector2 = Vector2.ZERO
  if event is InputEventScreenDrag:
    camera_motion = event.screen_relative * TOUCH_SENSITIVITY
    is_camera_motion = true
  elif event is InputEventMouseMotion:
    camera_motion = event.screen_relative * MOUSE_SENSITIVITY
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
