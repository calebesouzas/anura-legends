class_name World extends Node3D

var plasma_manager: PlasmaManager
var spawn_point_global_position: Vector3 = Vector3.ZERO
var scene: Node3D

# Had to use `new_world` name because `new` is like a keyword and also a reserved static function
func _init(scene_path: StringName, plasma_manager_reference: PlasmaManager) -> void:
  assert(plasma_manager_reference != null, "Should provide a non-null plasma manager reference")
  plasma_manager = plasma_manager_reference

  assert(scene_path.ends_with(".tscn"), "Should provide a scene file to World")
  scene = (load(scene_path) as PackedScene).instantiate()
  add_child(scene)

var astars: Array[AStar3D]

func _ready() -> void:
  var spawn_point_node: Marker3D = scene.get_node("spawn_point")
  if spawn_point_node != null:
    spawn_point_global_position = spawn_point_node.global_position
