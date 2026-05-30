class_name ParticleLabel extends Label3D

@export var life_time_secs: float = 1.0
var lived_time_secs: float = 0.0

func _init(label_text: String, text_color: Color) -> void:
  self.text = label_text
  self.modulate = text_color
  self.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  self.font_size = 72

func _process(delta: float) -> void:
  self.lived_time_secs += delta
  if self.lived_time_secs >= self.life_time_secs:
    self.queue_free()
