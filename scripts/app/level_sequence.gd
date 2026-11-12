class_name LevelSequence
extends RefCounted
## 一轮游戏的关卡顺序：从目录第 1 关依次走到最后一关，不回绕；选关可以直接跳到任意一关（T008），之后从那里继续往后走。纯逻辑，不依赖场景，便于测试。

var catalog: LevelCatalog
var index: int = 0


func _init(p_catalog: LevelCatalog) -> void:
	assert(p_catalog != null and p_catalog.count() > 0, "LevelSequence 需要非空的关卡目录")
	catalog = p_catalog


## 回到第 1 关（开始游戏 / 重玩）。
func reset() -> void:
	index = 0


func count() -> int:
	return catalog.count()


func current() -> LevelDefinition:
	return catalog.get_level(index)


func is_last() -> bool:
	return index >= count() - 1


## 直接跳到第 p_index 关（选关，T008）。越界时不动并返回 false。
func select(p_index: int) -> bool:
	if p_index < 0 or p_index >= count():
		return false
	index = p_index
	return true


## 前进到下一关。已经是最后一关时不动并返回 false（这一轮结束）。
func advance() -> bool:
	if is_last():
		return false
	index += 1
	return true


## 进度文字，如 "2 / 4"。
func progress_text() -> String:
	return "%d / %d" % [index + 1, count()]
