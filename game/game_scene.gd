class_name Game extends Node

@export var plasma_manager_scene: PackedScene

var plasma_manager: PlasmaManager

func _ready() -> void:
  assert(self.plasma_manager_scene != null, "Should provide PlasmaManager scene to Game")
  self.plasma_manager = self.plasma_manager_scene.instantiate()
  self.plasma_manager.game = self
  self.add_child(self.plasma_manager)
  const path: StringName = "res://levels/practice/practice_scene.tscn"
  var world: World = World.new(path, self.plasma_manager)
  self.plasma_manager.setup(world)
  Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
  if connected:
    print("Controller connected at index: ", device_id)
    print("Controller name: ", Input.get_joy_name(device_id))
  else:
    print("Controller disconnected from index: ", device_id)
