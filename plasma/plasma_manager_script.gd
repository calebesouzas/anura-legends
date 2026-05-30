class_name PlasmaManager extends Node3D

@export var player_scene: PackedScene

var game: Game

@onready var players: Node3D = %players
@onready var projectiles: Node3D = %projectiles
@onready var particles: Node3D = %particles
var world: World

var world_spawn_gpos: Vector3 = Vector3.ZERO

func _ready() -> void:
  assert(self.player_scene != null, "Should provide player scene to PlasmaManager")

func setup(world_reference: World) -> void:
  self.world = world_reference
  self.world_spawn_gpos = self.world.spawn_point_global_position
  self.add_child(self.world)
  self.spawn_new_player()

func _process(_delta: float) -> void:
  pass

func spawn_new_player(spawn_position: Vector3 = self.world_spawn_gpos) -> void:
  var player: Player = self.player_scene.instantiate()
  player.visible = false
  player.id = self.players.get_child_count()
  player.plasma_manager = self
  player.name = "player_" + str(player.id)
  self.players.add_child(player)
  player.global_position = spawn_position
  player.visible = true

func spawn_new_projectile(id: int, scene: PackedScene, direction: Vector3) -> int:
  var bullet: PlasmaProjectile = scene.instantiate()
  bullet.setup(id, self.projectiles.get_child_count(), direction)
  var player: Player = self.players.get_child(bullet.owner_id)
  var spawn_position = player.pivot.global_position + bullet.direction
  self.projectiles.add_child(bullet)
  bullet.global_position = spawn_position
  return bullet.id

func spawn_new_particle(particle_instance: Node3D, particle_global_position: Vector3) \
-> void:
  self.particles.add_child(particle_instance)
  particle_instance.global_position = particle_global_position
