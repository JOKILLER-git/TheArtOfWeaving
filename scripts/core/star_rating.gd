class_name StarRating
extends RefCounted
## 星级规则：失误次数 → 1–3 星。阈值来自 LevelDefinition（可选字段，默认 0 失误 3 星、≤2 失误 2 星、其余 1 星）。

const MAX_STARS := 3

var three_star_max: int
var two_star_max: int


func _init(p_three_star_max: int = 0, p_two_star_max: int = 2) -> void:
	assert(p_three_star_max <= p_two_star_max, "3 星阈值不能比 2 星宽松")
	three_star_max = p_three_star_max
	two_star_max = p_two_star_max


static func for_level(level: LevelDefinition) -> StarRating:
	return StarRating.new(level.three_star_max_mistakes, level.two_star_max_mistakes)


func stars_for(mistakes: int) -> int:
	if mistakes <= three_star_max:
		return 3
	if mistakes <= two_star_max:
		return 2
	return 1
