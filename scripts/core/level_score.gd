class_name LevelScore
extends RefCounted
## 一关的成绩：统计失误次数，按 StarRating 给出星级。
## 失误 = 线在错的一面钩针（WRONG_SIDE）；钩错眼（NOT_NEXT）、需要剪断时钩针（BLOCKED）不算。
## 同一关里剪断重来不清零（换关时由管理者新建或 reset）。

var mistakes: int = 0
var rating: StarRating


func _init(p_rating: StarRating = StarRating.new()) -> void:
	rating = p_rating


## 开始统计一个会话的失误（可多次调用，例如同一关换了新的会话）。
func track(session: KnitSession) -> void:
	session.stitch_rejected.connect(_on_rejected)


func reset() -> void:
	mistakes = 0


func stars() -> int:
	return rating.stars_for(mistakes)


static func counts_as_mistake(result: HookResult) -> bool:
	return result.status == HookResult.Status.WRONG_SIDE


func _on_rejected(result: HookResult) -> void:
	if counts_as_mistake(result):
		mistakes += 1
