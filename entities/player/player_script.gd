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
  health_label.text = str(health)
  if health < LOW_HEALTH_POINT:
    health_label.label_settings.font_color = Color.DARK_RED
  else:
    health_label.label_settings.font_color = Color.DIM_GRAY
  health_label.label_settings.outline_color = health_label.label_settings.font_color.darkened(0.2)

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

enum State {IDLE_MOVE, JUMP, FALL, DASH}
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

# Jump duration and force may be increased by successful super dashes!
const JUMP_DURATION: int = 15
const SUPER_DASH_DURATION: int = 30 # jump duration when super dashing
const JUMP_WINDOW: int = 6
const JUMP_DELAY: int = 6
var jump_duration: int = JUMP_DURATION
var jump_buffer: int

const HIGH_JUMP: float = 3.0
const JUMP: float = 6.0
const HIGH_SUPER_DASH_FORCE: float = 3.75
const SUPER_DASH_FORCE: float = 7.5
var high_jump_force: float = HIGH_JUMP
var jump_force: float = JUMP

const DASH_TENSION: float = 0.2
const HYPER_DASH_TENSION: float = 0.3
var dash_tension: float = DASH_TENSION

const SUPER_DASH_UNLOCK_MOMENT: int = 10
const HYPER_DASH_WINDOW: int = 9

const DASH_RELOAD_MOMENT: int = 5 # delay to reload dash when done grounded

const DASH_FORCE: float = 7.5
const HYPER_DASH_FORCE: float = 12.0
var dash_force: float = DASH_FORCE

const DASH_DURATION: int = 15 # tick amount that input will be locked
const HYPER_DASH_DURATION: int = 20
var dash_duration: int = DASH_DURATION

const DASH_DELAY: int = 15
var dash_delay: int

var can_dash: bool = false
var super_dash: bool
var hyper_dash: bool

const ADHESION_WINDOW: int = 6
var adhesion_buffer: int

const SPEED: float = 5.0

const ADHESION_FACTOR: float = 3.0

const AIR_ACCELERATION: float = 2.15
const MAX_AIR_SPEED: float = 10.0

const ACCELERATION: float = 3.5
const MAX_SPEED: float = 5.0

const FRICTION: float = 40.0
const AIR_REDUCTION: float = 0.8

const TOUCH_PLASMA_WINDOW: int = 5
var touch_plasma_buffer: int
var touching_plasma: bool

var tile: Vector3i # position at `PlasmaManager.grid`

### State Machine
# Quake style but with limited magnitude
func accelerate(
    dir: Vector3,
    delta: float,
    wish_speed: float,
    acceleration: float
) -> Vector3:
  var add_accel: float
  var accel: float

  add_accel = wish_speed - velocity.dot(dir)

  if add_accel <= 0:
    return velocity

  accel = acceleration * delta * wish_speed

  if accel > add_accel:
    accel = add_accel

  var vel: Vector3 = velocity + dir * accel

  # cap speed here (it actually reduces a little)
  if vel.length_squared() > MAX_AIR_SPEED ** 2:
    return vel.lerp(vel.normalized() * MAX_AIR_SPEED, AIR_REDUCTION * delta);

  return vel

func apply_friction(
    dir: Vector3,
    delta: float,
    friction: float,
    max_speed: float
) -> Vector3:
  var vel: Vector3 = velocity
  vel.x = move_toward(vel.x, dir.x * max_speed, friction * delta)
  vel.z = move_toward(vel.z, dir.z * max_speed, friction * delta)
  return Vector3(vel.x, velocity.y, vel.z)

func handle_state(delta: float) -> void:
  match state:
    State.IDLE_MOVE:
      var factor: float = 1.0
      if touching_plasma:
        can_dash = true
        if is_action_valid("adhesion") and can_join():
          factor = ADHESION_FACTOR
          heal_amount = STICKY_HEAL_AMOUNT
        else:
          heal_amount = NORMAL_HEAL_AMOUNT

      velocity = accelerate(wishdir, delta, ACCELERATION, MAX_SPEED)

      # no friction when landing and jumping at the same time
      if state_ticks > LANDED_WINDOW:
        velocity = apply_friction(wishdir, delta,
          FRICTION * factor, MAX_SPEED)
      elif jump_buffer > 0: # jumped berofe the end of `LANDED_WINDOW`
        state = dash_or_jump()
        jump_buffer = 0
        coyote_buffer = 0
        return

      if not grounded:
        state = State.FALL
      # remove the second condition to allow auto bunny hopping
      elif is_action_valid("jump") and state_ticks > JUMP_DELAY:
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
      elif is_action_valid("adhesion") and can_dash and is_action_valid("jump"):
        state = State.DASH
        return

      velocity = accelerate(wishdir, delta, AIR_ACCELERATION, MAX_AIR_SPEED)
      velocity += get_gravity() * delta

    State.JUMP:
      if state_ticks > jump_duration or not is_action_valid("jump"):
        state = State.FALL
        high_jump_force = HIGH_JUMP
        jump_force = JUMP
        jump_duration = JUMP_DURATION
        return

      velocity = accelerate(wishdir, delta, AIR_ACCELERATION, MAX_AIR_SPEED)

      if state_ticks == 1:
        velocity.y = high_jump_force
      else:
        velocity.y += jump_force * delta

    State.DASH:
      var intensity: float = 0
      var frequency: int = 1
      var delay: float = 1.0/60*DASH_DURATION
      if state_ticks > dash_duration:
        #@todo effect!
        input_locked = false
        dash_delay = DASH_DELAY
        dash_force = DASH_FORCE
        dash_duration = DASH_DURATION
        dash_tension = DASH_TENSION
        hyper_dash = false
        super_dash = false
        state = State.FALL
        return

      # dash reloading delay, no buffer help for this one!
      if state_ticks <= DASH_RELOAD_MOMENT:
        intensity = 0.5
        can_dash = false
      elif touching_plasma:
        can_dash = true

      input_locked = true
      #@todo effect!
      var dash_dir: Vector3 = -skin.global_transform.basis.z
      if grounded and wanna_move:
        dash_dir = wishdir
      elif wanna_move: # just wanna move but not grounded
        dash_dir = camera_relative_movement()

      if state_ticks < HYPER_DASH_WINDOW and landed_buffer > 0 \
          and (touch_plasma_buffer > 0 or touching_plasma):
        #@todo effect!
        intensity = 1.0
        frequency = 2
        delay *= 2
        dash_force = HYPER_DASH_FORCE
        dash_duration = HYPER_DASH_DURATION
        dash_tension = HYPER_DASH_TENSION
        hyper_dash = true
        heal_amount = HYPER_HEAL_AMOUNT

      velocity = (velocity * dash_tension) + dash_dir * dash_force

      if jump_buffer > 0 and coyote_buffer > 0 \
          and state_ticks >= SUPER_DASH_UNLOCK_MOMENT:
        #@todo effect!
        intensity = 0.75
        input_locked = false
        high_jump_force = HIGH_SUPER_DASH_FORCE
        jump_force = SUPER_DASH_FORCE
        jump_duration = SUPER_DASH_DURATION
        jump_buffer = 0
        dash_force = DASH_FORCE
        dash_duration = DASH_DURATION
        dash_tension = DASH_TENSION
        coyote_buffer = 0
        super_dash = true
        state = State.JUMP

      flash(skin_color.lightened(intensity), frequency, delay)

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

  if dash_delay > 0:
    dash_delay -= 1

  tile = Vector3i(
    roundi(global_position.x),
    roundi(global_position.y) - 1, # right below the feet
    roundi(global_position.z)
  )
  var block_color: Team.BlockColor = plasma_manager.blocks \
    .get_cell_item(tile) as Team.BlockColor

  if block_color == Team.team_to_block_color(team_color):
    if not touching_plasma:
      touch_plasma_buffer = TOUCH_PLASMA_WINDOW
    elif touch_plasma_buffer > 0: # ... code repetition ...
      touch_plasma_buffer -= 1
    touching_plasma = true
    health += heal_amount
    if health > initial_health:
      health = initial_health
  else:
    touching_plasma = false
    if touch_plasma_buffer > 0:
      touch_plasma_buffer -= 1

  if not input_locked:
    wishdir = Vector3(input_direction.x, 0.0, -input_direction.y) \
      .rotated(Vector3.UP, pivot.rotation.y)
    wanna_move = wishdir.length_squared() > MOVE_DEADZONE ** 2

  dot = velocity.dot(wishdir)

  handle_state(delta)

  move_and_slide()

  if pressed("trigger") and fire_locked_timer.is_stopped():
    trigger()

  rotate_skin(delta)

  debug_update()

## movement
### move_2D horizontal movement, Y axis ignored
func dash_or_jump() -> State:
  return State.DASH \
    if is_action_valid("adhesion") and dash_delay <= 0 and can_dash \
    else State.JUMP

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
@export var plasma_cost: int = 50
const NORMAL_HEAL_AMOUNT: int = 2
const STICKY_HEAL_AMOUNT: int = 5
const HYPER_HEAL_AMOUNT: int = 10
var heal_amount: int = NORMAL_HEAL_AMOUNT

func trigger() -> void:
  health -= plasma_cost
  if health < 10:
    health = 10
    return
  aim_locked = true
  aim_lock_timer.start()
  fire_locked_timer.start(fire_time)
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

@onready var body: MeshInstance3D = %body
var material: StandardMaterial3D = StandardMaterial3D.new()
var skin_color: Color
func update_color(new_color: Color) -> void:
  skin_color = new_color
  update_material_color(new_color)

func update_material_color(new_color: Color) -> void:
  material.albedo_color = new_color
  body.material_override = material
  (body.get_node("front") as MeshInstance3D).material_override = material

func flash(color: Color, loops: int, time: float) -> void:
  var tween: Tween = create_tween().set_loops(loops)
  var saved_color: Color = skin_color
  tween.tween_callback(update_material_color.bind(color))
  tween.tween_interval(time)
  tween.tween_callback(update_material_color.bind(saved_color))
  tween.tween_interval(time)

@onready var health_label: Label = %health_label
const LOW_HEALTH_POINT: int = 200

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
  debug_value("FPS", Engine.get_frames_per_second())
  debug_field("velocity")
  debug_field("current_speed")
  debug_value("state", State.keys()[state])
  debug_field("state_ticks")
  debug_field("grounded")
  debug_field("dot")
  debug_field("touching_plasma")
  debug_field("can_dash")
  debug_field("super_dash")
  debug_field("hyper_dash")
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
  update_color(Team.RealColor.get_from_team_color(team_color).lightened(0.25))

func _init() -> void:
  health = 1000
