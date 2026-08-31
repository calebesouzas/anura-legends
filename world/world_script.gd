class_name World extends Node3D

var plasma_manager: PlasmaManager
var spawn_point_global_position: Vector3 = Vector3.ZERO
var scene: Node3D

var width: int
var height: int
var depth: int

var astars: Array[AStar3D]

# Had to use `new_world` name because `new` is like a keyword and also a reserved static function
func _init(scene_path: StringName, plasma_manager_reference: PlasmaManager) -> void:
  assert(plasma_manager_reference != null, "Should provide a non-null plasma manager reference")
  plasma_manager = plasma_manager_reference

  assert(scene_path.ends_with(".tscn"), "Should provide a scene file to World")
  scene = (load(scene_path) as PackedScene).instantiate()
  add_child(scene)

func _ready() -> void:
  var spawn_point_node: Marker3D = scene.get_node("spawn_point")
  if spawn_point_node != null:
    spawn_point_global_position = spawn_point_node.global_position

  var min_x: int
  var min_y: int
  var min_z: int

  var max_x: int
  var max_y: int
  var max_z: int

  var blocks: GridMap = scene.get_node("blocks")
  for block_position: Vector3i in blocks.get_used_cells():
    if block_position.x < 0:
      printerr("Vector %s contains negative X" % [str(block_position)])
      assert(false)
    elif block_position.x < min_x:
      min_x = block_position.x
    elif block_position.x > max_x:
      max_x = block_position.x

    if block_position.y < 0:
      printerr("Vector %s contains negative Y" % [str(block_position)])
      assert(false)
    elif block_position.y < min_y:
      min_y = block_position.y
    elif block_position.y > max_y:
      max_y = block_position.y

    if block_position.z < 0:
      printerr("Vector %s contains negative Z" % [str(block_position)])
      assert(false)
    elif block_position.z < min_z:
      min_z = block_position.z
    elif block_position.z > max_z:
      max_z = block_position.z

  width = min_x + max_x
  height = min_y + max_y
  depth = min_z + max_z

func block_position_to_index(block_position: Vector3i) -> int:
  return block_position.x \
      + block_position.z * width \
      + block_position.y * width * height

func index_to_block_position(index: int) -> Vector3i:
  var x: int = index % width
  var y: int = index / (width * height)
  var z: int = index / (width * depth) - y - x
  return Vector3i(x, y, z)
