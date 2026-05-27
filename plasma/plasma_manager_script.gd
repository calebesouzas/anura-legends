class_name PlasmaManager extends Node3D

@export var player_scene: PackedScene

@onready var players: Node3D = %players
@onready var entities: Node3D = %entities

var world_spawn_gpos: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  assert(self.player_scene != null, "Should provide player scene to PlasmaManager")
  self.spawn_player()

func setup(world_spawn_global_position: Vector3) -> void:
  self.world_spawn_gpos = world_spawn_global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func spawn_player(spawn_position: Vector3 = self.world_spawn_gpos) -> void:
  var player: Player = self.player_scene.instantiate()
  player.visible = false
  player.id = self.players.get_child_count()
  player.name = "player_" + str(player.id)
  self.players.add_child(player)
  player.global_position = spawn_position
  player.visible = true
