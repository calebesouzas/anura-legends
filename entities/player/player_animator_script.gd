class_name PlayerAnimator extends AnimationTree

@onready var state_machine: AnimationNodeStateMachinePlayback = \
  self.get("parameters/playback")

@onready var root: Node3D = self.get_node(self.root_node)
@onready var head: Node3D = self.root.get_node("body/head")
@onready var hands: Array[Marker3D] = [
  self.root.get_node("body/arms/left_arm/left_hand"),
  self.root.get_node("body/arms/right_arm/right_hand")
]
var current_hand: Marker3D
var current_hand_index: int = 0:
  set(value):
    current_hand_index = value
    self.current_hand = self.hands[current_hand_index]

func play(animation: StringName) -> void:
  self.state_machine.travel(animation)

func lock_head_at_angle(head_global_rotation: Vector3) -> void:
  self.head.global_rotation = head_global_rotation
