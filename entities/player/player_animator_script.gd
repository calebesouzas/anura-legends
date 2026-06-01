class_name PlayerAnimator extends AnimationTree

@onready var state_machine: AnimationNodeStateMachinePlayback = \
  self.get("parameters/playback")

@onready var root: Node3D = self.get_node(self.root_node)
@onready var head: Node3D = self.root.get_node("body/head")

@onready var arms: Array[Node3D] = [
  self.root.get_node("body/arms/left_arm"),
  self.root.get_node("body/arms/right_arm")
]
var other_arm: Node3D
var other_arm_index: int = 1
var current_arm: Node3D
var current_arm_index: int = 0:
  set(value):
    current_arm_index = value
    self.other_arm_index = not current_arm_index
    self.other_arm = self.arms[self.other_arm_index]
    self.current_arm = self.arms[current_arm_index]

func play(animation: StringName) -> void:
  self.state_machine.travel(animation)

func lock_head_at_angle(head_global_rotation: Vector3) -> void:
  self.head.global_rotation = head_global_rotation
