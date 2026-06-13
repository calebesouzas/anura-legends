class_name Player extends AliveEntity

func _init() -> void:
  self.health = 1000

enum State {IDLE, RUN, JUMP, FALL, SWIM, DASH}
enum Flags {
  MOVE_LOCKED = 1, TRIGGER_LOCKED = 2,
  GROUNDED = 4,
  JUMP_PRESSED = 8, SWIM_PRESSED = 16, TRIGGER_PRESSED = 32,
  JUST_MOVE = 64, JUST_JUMP = 128,
}

var state: State
signal state_changed(old_state: State, new_state: State)
var flags: int = 0

var aim_locked: bool = false

@export_group("Physics")
@export var IDLE_SPEED: float = 5.0
@export var RUN_SPEED: float = 7.0
@export var FALL_SPEED: float = 5.0
@export var JUMP_SPEED: float = 8.0
@export var GROUND_ACCELERATION: float = 21.0
@export var AIR_ACCELERATION: float = 10.5
@export var JUMP_FORCE: float = 5.0
@export var JUMP_CURVE: Curve
@export var GRAVITY: float = 12.0
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
    self.fire_time = 1.0 / shots_per_second
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
  self.aim_lock_timer.timeout.connect(func(): self.aim_locked = false)
  self.skin.visibility_changed.connect(func(): self.health_indicator.visible = not self.skin.visible)
  self.health_indicator.visible = false
  for state_key: StringName in State.keys():
    self.state_speeds.append(self[state_key + "_SPEED"])
  # self.state_changed.connect(func(_old: State, new: State): print(State.keys()[new]))

func _physics_process(delta: float) -> void:
  self.time += delta
  self.camera_direction = self.camera.global_position.direction_to(
    self.aim.global_position
  )

  self.ground_speed = Vector2(self.velocity.x, self.velocity.z).length()

  if self.is_on_floor():
    self.flags |= Flags.GROUNDED
    if self.airbone_time > 0: print("Air time ", self.airbone_time)
    self.airbone_time = 0
  else:
    self.flags &= ~Flags.GROUNDED
    self.airbone_time += delta

  if not self.flags & Flags.MOVE_LOCKED:
    self.input_direction = self.get_movement()
    self.prev_move_len = self.move_direction.length_squared()
    self.move_direction = Vector3(self.input_direction.x, 0.0, self.input_direction.y).rotated(Vector3.UP, self.pivot.rotation.y)
    self.curr_move_len = self.move_direction.length_squared()
    if is_equal_approx(self.prev_move_len, 0) and self.curr_move_len > self.MOVE_DEADZONE:
      self.flags |= Flags.JUST_MOVE
    else:
      self.flags &= ~Flags.JUST_MOVE

  self.dot = self.velocity.dot(self.move_direction)

  if Input.is_action_just_pressed("jump"):
    self.flags |= Flags.JUST_JUMP
  elif Input.is_action_pressed("jump"):
    self.flags &= ~Flags.JUST_JUMP
    self.flags |= Flags.JUMP_PRESSED
  else:
    self.flags &= ~Flags.JUMP_PRESSED
    self.flags &= ~Flags.JUST_JUMP

  if Input.is_action_pressed("swim"):
    self.flags |= Flags.SWIM_PRESSED
  else:
    self.flags &= ~Flags.SWIM_PRESSED

  if not self.flags & Flags.TRIGGER_LOCKED:
    if Input.is_action_pressed("trigger"):
      self.flags |= Flags.TRIGGER_PRESSED
    else:
      self.flags &= ~Flags.TRIGGER_PRESSED

  self.speed = self.state_speeds[self.state]
  self.final_speed = lerp(
    speed,
    speed + (self.ground_speed if self.ground_speed > self.ADD_POINT else 0.0),
    delta
  )
  self.handle_state(delta)

  self.move_and_slide()

  self.health_indicator.text = str(self.health)

  if self.flags & Flags.TRIGGER_PRESSED and not self.flags & Flags.TRIGGER_LOCKED \
      and self.fire_locked_timer.is_stopped():
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
      elif self.flags & Flags.JUMP_PRESSED:
        self.set_state(State.JUMP)
      elif self.flags & Flags.SWIM_PRESSED:
        self.set_state(State.SWIM)

    State.RUN:
      self.move_2d(self.move_direction, self.GROUND_ACCELERATION, delta)

      if self.input_direction.length_squared() < self.MOVE_DEADZONE*self.MOVE_DEADZONE:
        self.set_state(State.IDLE)
      elif not self.flags & Flags.GROUNDED:
        self.set_state(State.FALL)
      elif self.flags & Flags.JUMP_PRESSED:
        self.set_state(State.JUMP)
      elif self.flags & Flags.SWIM_PRESSED:
        self.set_state(State.SWIM)

    State.FALL:
      if self.flags & Flags.GROUNDED:
        if self.flags & Flags.SWIM_PRESSED:
          self.set_state(State.SWIM)
        else:
          self.set_state(State.IDLE)
        return

      self.move_2d(self.move_direction, self.AIR_ACCELERATION, delta)
      self.velocity.y -= self.GRAVITY * delta

    State.JUMP:
      if not self.flags & Flags.JUMP_PRESSED or self.jump_force <= 0:
        self.jump_force = self.JUMP_FORCE
        self.set_state(State.FALL)
        return

      self.move_2d(self.move_direction, self.AIR_ACCELERATION, delta)
      self.velocity.y = self.jump_force
      self.jump_force = self.JUMP_CURVE.sample(self.airbone_time) * self.JUMP_FORCE

    State.DASH:
      self.dash_ticks += 1
      if self.dash_ticks > self.DASH_DURATION_IN_TICKS:
        self.set_state(State.SWIM)
        self.dash_ticks = 0
        self.flags &= ~Flags.MOVE_LOCKED
        self.flags &= ~Flags.TRIGGER_LOCKED
        return

      if self.dash_ticks == 1:
        self.flags |= Flags.MOVE_LOCKED
        self.flags |= Flags.TRIGGER_LOCKED
        #@todo effect!

      if self.flags & Flags.GROUNDED:
        self.move_2d(self.move_direction, self.DASH_ACCELERATION, delta)
      else:
        self.move_3d(self.move_direction + Vector3.DOWN, self.DASH_ACCELERATION, delta)

    State.SWIM:
      if not self.plasma_manager.can_swim(self.feet_ray.get_collision_point(), self.team_color) \
          or not self.flags & Flags.SWIM_PRESSED:
        self.flags &= ~Flags.TRIGGER_LOCKED
        self.skin.visible = true
        self.set_state(State.RUN)
        return

      self.flags |= Flags.TRIGGER_LOCKED
      #@todo effect!
      self.skin.visible = false
      self.move_2d(
        self.move_direction,
        self.SWIM_OPPOSITE_ACCELERATION if self.dot < 0.0 else self.SWIM_ACCELERATION,
        delta
      )

      if self.flags & Flags.JUST_MOVE and self.flags & Flags.JUMP_PRESSED:
        self.set_state(State.DASH)
    _:
      assert(false, "Unhandled state: " + State.keys()[self.state])

func set_state(new_state: State) -> void:
  self.state_changed.emit(self.state, new_state)
  self.state = new_state

func move_3d(direction: Vector3, acceleration: float, delta: float) -> void:
  self.velocity = self.velocity.move_toward(direction * self.final_speed, acceleration * delta)

func move_2d(direction: Vector3, acceleration: float, delta: float) -> void:
  self.velocity.x = move_toward(self.velocity.x, direction.x * self.final_speed, acceleration * delta)
  self.velocity.z = move_toward(self.velocity.z, direction.z * self.final_speed, acceleration * delta)

func trigger() -> void:
  self.plasma_manager.spawn_new_projectile(self.id, self.bullet_scene, self.team_color, self.camera_direction)

func get_movement() -> Vector2:
  return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func has_the_dot() -> bool:
  return self.DOT_POINT - self.DOT_RANGE < self.dot and self.dot < self.DOT_POINT + self.DOT_RANGE

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
