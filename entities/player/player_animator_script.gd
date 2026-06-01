class_name PlayerAnimator extends AnimationTree

@onready var state_machine: AnimationNodeStateMachinePlayback = \
  self.get("parameters/playback")

func play(animation: StringName) -> void:
  self.state_machine.travel(animation)
