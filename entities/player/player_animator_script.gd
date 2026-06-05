class_name PlayerAnimator extends AnimationTree

@onready var state_machine: AnimationNodeStateMachinePlayback = \
  self.get("parameters/playback")

@onready var root: Node3D = self.get_node(self.root_node)
@onready var head: Node3D = self.root.get_node("body/head")

@onready var arms: Array[Node3D] = [
  self.root.get_node("body/arms/left_arm"),
  self.root.get_node("body/arms/right_arm")
]
var current_arm: int = 0

@onready var legs: Array[Node3D] = [
  self.root.get_node("legs/left_leg"),
  self.root.get_node("legs/right_leg")
]
var current_leg: int = 0

func play(animation: StringName) -> void:
  self.state_machine.travel(animation)

func walk(delta: float) -> void:
  var player: Player = self.get_parent()
  var angle: float = sin(player.time) * deg_to_rad(45.0)
  var final_angle: float = move_toward(
    self.legs[self.current_leg].rotation.x,
    angle,
    player.speed * delta
  )
  self.legs[self.current_leg].rotation.x = final_angle
  self.legs[not self.current_leg as int].rotation.x = -final_angle
  self.current_leg = not self.current_leg

func lock_head_at_angle(head_global_rotation: Vector3) -> void:
  self.head.global_rotation = head_global_rotation

func shoot(fire_time: float) -> void:
  var shoulder_angle_direction: float = -1 if self.current_arm == 0 else 1
  var current_rotation: Vector3 = \
    Vector3.RIGHT * 90 + Vector3(0.0, 0.0, shoulder_angle_direction) * 60
  var tween: Tween = self.create_tween()
  tween.tween_property(self.arms[self.current_arm], "rotation_degrees", current_rotation, fire_time * 0.5)
  self.current_arm = not self.current_arm
