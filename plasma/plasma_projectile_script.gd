class_name PlasmaProjectile extends Entity

var direction: Vector3
var owner_id: int

@export var speed: float
@export var damage: int

func _init() -> void:
  self.kind = Kind.BULLET

func setup(shooter_id: int, my_id: int, direction_to_go: Vector3) -> void:
  self.owner_id = shooter_id
  self.id = my_id
  self.direction = direction_to_go

func _physics_process(delta: float) -> void:
  self.velocity = self.direction * self.speed * delta
  if self.move_and_slide():
    var collision: KinematicCollision3D = self.get_last_slide_collision()
    self.queue_free()
