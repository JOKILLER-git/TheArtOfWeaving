class_name PlayerProgress
extends RefCounted
## 玩家进度（T008）：每关的最好星数（按 LevelDefinition.id 记录）。纯规则与数据，不读写文件。
## 规则：只保留最好成绩；星数必须在 1..StarRating.MAX_STARS 之间，0 或越界的记录被忽略。
## 存取格式无关：to_dict / from_dict 只做 Dictionary 转换，真正的存储由 app 层（ProgressStore）负责。

## 某关的最好成绩提高了（含第一次完成）。
signal improved(level_id: StringName, stars: int)

var _best: Dictionary[StringName, int] = {}


## 记录一次完成。成绩比已有的好（或第一次完成）时更新并返回 true。
func record(level_id: StringName, stars: int) -> bool:
	if level_id == &"" or stars < 1 or stars > StarRating.MAX_STARS:
		return false
	if stars <= best_stars(level_id):
		return false
	_best[level_id] = stars
	improved.emit(level_id, stars)
	return true


## 最好星数；没完成过为 0。
func best_stars(level_id: StringName) -> int:
	return _best.get(level_id, 0)


func is_completed(level_id: StringName) -> bool:
	return best_stars(level_id) > 0


func completed_count() -> int:
	return _best.size()


func clear() -> void:
	_best.clear()


## 转成可序列化的 Dictionary：{ "关卡 id": 星数 }。
func to_dict() -> Dictionary:
	var out := {}
	for id in _best:
		out[String(id)] = _best[id]
	return out


## 从 Dictionary 恢复；不合规的条目（非数字、越界）按 record 的规则忽略。
static func from_dict(data: Dictionary) -> PlayerProgress:
	var progress := PlayerProgress.new()
	for key in data:
		var value: Variant = data[key]
		if value is int or value is float:
			progress.record(StringName(str(key)), int(value))
	return progress
