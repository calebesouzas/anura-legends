class_name PlasmaProjectile extends Entity

var direction: Vector3
var owner_id: int

@export var speed: float
@export var damage: int
@export var paint_radius: int
@export var reach: float:
  set(value):
    reach = value
    self.reach_squared = self.reach * self.reach
var reach_squared: float
var travelled_distance_squared: float

var gravity: float = 0.0

func _enter_tree() -> void:
  assert(
    self.get_parent().get_parent() is PlasmaManager,
    "Bullet is not grandchild of Plasma Manager"
  )

func setup(
  shooter_id: int, my_id: int, color: Team.TeamColor,
  direction_to_go: Vector3,
  plasma_manager_reference: PlasmaManager) \
-> void:
  self.owner_id = shooter_id
  self.id = my_id
  self.team_color = color
  self.direction = direction_to_go
  self.plasma_manager = plasma_manager_reference

func _physics_process(delta: float) -> void:
  self.velocity = self.velocity.move_toward(self.direction * self.speed, self.speed * delta)
  # self.velocity.y += self.gravity
  self.travelled_distance_squared += self.velocity.length_squared()
  if self.move_and_slide():
    var collision: KinematicCollision3D = self.get_last_slide_collision()
    var collider: Object = collision.get_collider()
    var entity: AliveEntity = null
    if collider is AliveEntity:
      entity = collider as AliveEntity
      if entity != null and entity.team_color != self.team_color:
        entity.damage(self.damage)
    else:
      self.plasma_manager.paint(
        collision.get_position(), collision.get_normal(),
        self.team_color,
        self.generate_paint_offsets()
      )
    self.queue_free()
  elif self.travelled_distance_squared >= self.reach_squared:
    # self.speed -= delta * 1000
    # self.gravity -= delta * 9.8
    self.queue_free()

func generate_paint_offsets() -> Array[Vector3i]:
  var offsets: Array[Vector3i] = []
  # this one is going to be badly slow
  for x: int in range(-self.paint_radius, self.paint_radius + 1):
    for y: int in range(-self.paint_radius, self.paint_radius + 1):
      for z: int in range(-self.paint_radius, self.paint_radius + 1):
        offsets.append(Vector3i(x, y, z))
  return offsets
