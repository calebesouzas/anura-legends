class_name AliveEntity extends Entity

var vulnerable: bool = true

@export var initial_health: int = 1000

var health: int = self.initial_health

@export var respawn_delay_seconds: float = 3.0
@export var respawn_timer: Timer:
  get:
    assert(respawn_timer != null, "Should provide respawn Timer node in Inspector")
    return respawn_timer
  set(value):
    respawn_timer = value
    self.respawn_timer.timeout.connect(self.respawn)

@onready var respawn_global_position: Vector3 = self.global_position

func damage(amount: int) -> void:
  self.branch_damage_effect(amount)
  if not self.vulnerable: return
  self.health -= amount
  if self.health <= 0:
    self.kill()

func branch_damage_effect(amount: int) -> void:
  if self.vulnerable:
    self.play_damage_success_effect(amount)
  else:
    self.play_damage_failure_effect(amount)

func play_damage_success_effect(amount: int) -> void:
  print("Damaged: ", amount)

func play_damage_failure_effect(amount: int) -> void:
  print("Could damage: ", amount)

func kill() -> void:
  self.play_kill_effect()
  self.vulnerable = false # so we don't get killed again without even respawning
  self.respawn_timer.start(self.respawn_delay_seconds)

func play_kill_effect() -> void:
  self.visible = false

func respawn() -> void:
  self.global_position = self.respawn_global_position
  self.health = self.initial_health
  self.vulnerable = true
  self.play_respawn_effect()

func play_respawn_effect() -> void:
  self.visible = true

func toggle_vulnerability() -> void:
  self.vulnerable = not self.vulnerable
  self.branch_vulnerability_effect()

func set_vulnerability(value: bool) -> void:
  self.vulnerable = value
  self.branch_vulnerability_effect()

func branch_vulnerability_effect() -> void:
  if self.vulnerable:
    self.play_vulnerability_effect()
  else:
    self.play_invincibility_effect()

func play_vulnerability_effect() -> void:
  print("Vulnerable")

func play_invincibility_effect() -> void:
  print("Invincible")
