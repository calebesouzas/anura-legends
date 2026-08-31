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

var astars: Dictionary[Team.TeamColor, AStar3D]

func _ready() -> void:
  assert(player_scene != null, "Should provide player scene to PlasmaManager")

func setup(world_reference: World) -> void:
  world = world_reference
  add_child(world)
  world_spawn_gpos = world.spawn_point_global_position
  # for some reason there is a nested "world" node inside plasma_manager node...
  blocks = world.get_node("world/blocks")
  if blocks == null:
    print("Couldn't find world blocks (GridMap)")

  setup_astars()

  spawn_new_player(Team.TeamColor.BLUE)

func setup_astars() -> void:
  astars[Team.TeamColor.BLUE] = AStar3D.new()
  astars[Team.TeamColor.RED] = AStar3D.new()

  var directions: Array[Vector3] = [
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,

    Vector3.FORWARD + Vector3.LEFT,
    Vector3.FORWARD + Vector3.RIGHT,
    Vector3.BACK + Vector3.LEFT,
    Vector3.BACK + Vector3.RIGHT,

    Vector3.UP,

    Vector3.UP + Vector3.LEFT,
    Vector3.UP + Vector3.RIGHT,
    Vector3.UP + Vector3.FORWARD,
    Vector3.UP + Vector3.BACK,

    Vector3.DOWN,

    Vector3.DOWN + Vector3.LEFT,
    Vector3.DOWN + Vector3.RIGHT,
    Vector3.DOWN + Vector3.FORWARD,
    Vector3.DOWN + Vector3.BACK,
  ]

  for cell: Vector3i in blocks.get_used_cells():
    for astar: AStar3D in astars.values():
      var id: int = astar.get_available_point_id()
      var block_position: Vector3 = blocks.to_global(blocks.map_to_local(cell))

      astar.add_point(id, block_position)

      for direction: Vector3 in directions:
        var neighbor_id: int = astar.get_available_point_id()
        var neighbor_position: Vector3 = block_position + direction

        astar.add_point(neighbor_id, neighbor_position)
        astar.connect_points(id, neighbor_id)

func _process(_delta: float) -> void:
  pass

func spawn_new_player(color: Team.TeamColor, spawn_position: Vector3 = world_spawn_gpos) -> void:
  var player: Player = player_scene.instantiate()
  player.visible = false
  player.id = players.get_child_count()
  player.plasma_manager = self
  player.name = "player_" + str(player.id)
  player.team_color = color
  players.add_child(player)
  player.global_position = spawn_position
  player.respawn_global_position = spawn_position
  player.visible = true

func spawn_new_projectile(
    id: int, scene: PackedScene,
    color: Team.TeamColor, direction: Vector3) \
-> int:
  var bullet: PlasmaProjectile = scene.instantiate()
  bullet.setup(id, projectiles.get_child_count(), color, direction, self)
  var player: Player = players.get_child(bullet.owner_id)
  var spawn_position = player.bullet_point.global_position
  projectiles.add_child(bullet)
  bullet.global_position = spawn_position
  return bullet.id

func spawn_new_bullet(
    id: int, color: Team.TeamColor,
    bullet_instance: PlasmaProjectile,
    direction: Vector3) \
-> int:
  bullet_instance.setup(id, projectiles.get_child_count(), color, direction, self)
  var player: Player = players.get_child(bullet_instance.owner_id)
  var spawn_position = player.pivot.global_position + bullet_instance.direction
  projectiles.add_child(bullet_instance)
  bullet_instance.global_position = spawn_position
  return bullet_instance.id

func spawn_new_particle(particle_instance: Node3D, particle_global_position: Vector3) \
-> void:
  particles.add_child(particle_instance)
  particle_instance.global_position = particle_global_position

func paint(exact_position: Vector3, normal: Vector3, color: Team.TeamColor, offsets: Array[Vector3i] = []) -> void:
  var point: Vector3 = exact_position - 0.1 * normal
  var block_position: Vector3i = blocks.local_to_map(point)

  grid.set(block_position, color)
  blocks.set_cell_item(block_position, Team.team_to_block_color(color))

  var this_astar: AStar3D = astars.get(color)
  var other_astar: AStar3D = astars.get(
    Team.TeamColor.RED if color == Team.TeamColor.BLUE \
    else Team.TeamColor.BLUE)


  var id: int = world.block_position_to_index(block_position)
  this_astar.set_point_weight_scale(id, 0.5)
  other_astar.set_point_weight_scale(id, 5.0)

  for offset: Vector3i in offsets:
    if blocks.get_cell_item(block_position + offset) != GridMap.INVALID_CELL_ITEM:
      blocks.set_cell_item(block_position + offset, Team.team_to_block_color(color))
      grid.set(block_position + offset, color)

      var neighbor_id: int = world.block_position_to_index(block_position + offset)
      this_astar.set_point_weight_scale(neighbor_id, 0.5)
      other_astar.set_point_weight_scale(neighbor_id, 5.0)

func can_join(player: Player) -> bool:
  if not player.feet_ray.is_colliding(): return false
  var cell_position: Vector3i = blocks.local_to_map(player.feet_ray.get_collision_point() + Vector3.DOWN)
  var block_color: Team.BlockColor = blocks.get_cell_item(cell_position) as Team.BlockColor
  player.ground_color = block_color
  if block_color == blocks.INVALID_CELL_ITEM: return false
  var player_block_color: Team.BlockColor = Team.team_to_block_color(player.team_color)
  return block_color == player_block_color
