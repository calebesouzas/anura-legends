class_name Dummy extends AliveEntity

@onready var mesh: MeshInstance3D = %mesh

#@perf this is not a very good approach... but it's what i could do
func _ready() -> void:
  var reference: Node3D = self.get_parent_node_3d()
  while reference != null:
    if reference is PlasmaManager:
      self.plasma_manager = reference
      break
    reference = reference.get_parent_node_3d()

func play_damage_success_effect(amount: int) -> void:
  var particle: ParticleLabel = ParticleLabel.new(str(amount))
  self.plasma_manager.spawn_new_particle(
    particle,
    self.global_position + Vector3.UP * 2.25
  )
  var tween: Tween = particle.create_tween()
  tween.tween_property(
    particle, "position",
    particle.position + Vector3.UP * 2.5,
    1.0
  )
