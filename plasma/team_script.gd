class_name Team

class RealColor:
  const INVALID: Color = Color.DIM_GRAY
  const RED: Color = Color.RED
  const BLUE: Color = Color.BLUE
  static func get_from_team_color(team: Team.TeamColor) -> Color:
    if team as int >= 0:
      return [RED, BLUE][team as int]
    return INVALID

enum TeamColor {
  INVALID = -1, RED, BLUE
}

enum BlockColor {
  INVALID = -1, NORMAL, RED, BLUE, UNPAINTABLE
}

static func team_to_block_color(team: TeamColor) -> BlockColor:
  assert(0 <= team as int < TeamColor.keys().size(), "Team color is invalid!")
  return (team + 1) as BlockColor
