class_name AliveEntity extends Entity

var vulnerable: bool = true

var health: int

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
  self.queue_free()

func play_kill_effect() -> void:
  return

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

