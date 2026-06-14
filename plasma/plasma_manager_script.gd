class_name PlasmaManager extends Node3D

@export var player_scene: PackedScene

var game: Game

@onready var players: Node3D = %players
@onready var projectiles: Node3D = %projectiles
@onready var particles: Node3D = %particles
var world: World

var world_spawn_gpos: Vector3 = Vector3.ZERO

var blocks: GridMap
var grid: Dictionary[Vector3i, Team.TeamColor]

func _ready() -> void:
  assert(self.player_scene != null, "Should provide player scene to PlasmaManager")

func setup(world_reference: World) -> void:
  self.world = world_reference
  self.add_child(self.world)
  self.world_spawn_gpos = self.world.spawn_point_global_position
  # for some reason there is a nested "world" node inside plasma_manager node...
  self.blocks = self.world.get_node("world/blocks")
  if self.blocks == null:
    print("Couldn't find world blocks (GridMap)")
  self.spawn_new_player(Team.TeamColor.BLUE)

func _process(_delta: float) -> void:
  pass

func spawn_new_player(color: Team.TeamColor, spawn_position: Vector3 = self.world_spawn_gpos) -> void:
  var player: Player = self.player_scene.instantiate()
  player.visible = false
  player.id = self.players.get_child_count()
  player.plasma_manager = self
  player.name = "player_" + str(player.id)
  player.team_color = color
  self.players.add_child(player)
  player.global_position = spawn_position
  player.visible = true

func spawn_new_projectile(
    id: int, scene: PackedScene,
    color: Team.TeamColor, direction: Vector3) \
-> int:
  var bullet: PlasmaProjectile = scene.instantiate()
  bullet.setup(id, self.projectiles.get_child_count(), color, direction, self)
  var player: Player = self.players.get_child(bullet.owner_id)
  var spawn_position = player.bullet_point.global_position
  self.projectiles.add_child(bullet)
  bullet.global_position = spawn_position
  return bullet.id

func spawn_new_bullet(
    id: int, color: Team.TeamColor,
    bullet_instance: PlasmaProjectile,
    direction: Vector3) \
-> int:
  bullet_instance.setup(id, self.projectiles.get_child_count(), color, direction, self)
  var player: Player = self.players.get_child(bullet_instance.owner_id)
  var spawn_position = player.pivot.global_position + bullet_instance.direction
  self.projectiles.add_child(bullet_instance)
  bullet_instance.global_position = spawn_position
  return bullet_instance.id

func spawn_new_particle(particle_instance: Node3D, particle_global_position: Vector3) \
-> void:
  self.particles.add_child(particle_instance)
  particle_instance.global_position = particle_global_position

func paint(exact_position: Vector3, normal: Vector3, color: Team.TeamColor, offsets: Array[Vector3i] = []) -> void:
  var point: Vector3 = exact_position - 0.1 * normal
  var block_position: Vector3i = self.blocks.local_to_map(point)
  self.grid.set(block_position, color)
  self.blocks.set_cell_item(block_position, Team.team_to_block_color(color))
  for offset: Vector3i in offsets:
    if self.blocks.get_cell_item(block_position + offset) == GridMap.INVALID_CELL_ITEM:
      continue
    self.blocks.set_cell_item(block_position + offset, Team.team_to_block_color(color))

func can_join(player: Player) -> bool:
  var cell_position: Vector3i = self.blocks.local_to_map(player.feet_ray.get_collision_point() + Vector3.DOWN)
  var block_color: Team.BlockColor = self.blocks.get_cell_item(cell_position) as Team.BlockColor
  var player_block_color: Team.BlockColor = Team.team_to_block_color(player.team_color)
  return block_color == player_block_color
