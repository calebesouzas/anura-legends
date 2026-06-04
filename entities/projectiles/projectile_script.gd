class_name PlasmaProjectile extends Entity

var direction: Vector3
var owner_id: int

@export var speed: float
@export var damage: int
@export var reach: float:
  set(value):
    reach = value
    self.reach_squared = self.reach * self.reach
var reach_squared: float
var travelled_distance_squared: float

var gravity: float = 0.0

func setup(shooter_id: int, my_id: int, direction_to_go: Vector3) -> void:
  self.owner_id = shooter_id
  self.id = my_id
  self.direction = direction_to_go

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
    if entity != null:
      entity.damage(self.damage)
    self.queue_free()
  if self.travelled_distance_squared >= self.reach_squared:
    # self.speed -= delta * 1000
    # self.gravity -= delta * 9.8
    self.queue_free()
