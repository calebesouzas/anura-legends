class_name Team

enum TeamColor {
  BLUE, RED
}

enum BlockColor {
  NORMAL, BLUE, RED, UNPAINTABLE
}

static func team_to_block_color(team: TeamColor) -> BlockColor:
  assert(0 <= team as int < TeamColor.keys().size(), "Team color is invalid!")
  return (team + 1) as BlockColor
