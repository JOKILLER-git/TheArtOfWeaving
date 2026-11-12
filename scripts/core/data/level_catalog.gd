class_name LevelCatalog
extends Resource
## 关卡顺序。

@export var levels: Array[LevelDefinition] = []


func count() -> int:
	return levels.size()


func get_level(index: int) -> LevelDefinition:
	return levels[index]


## 下一关的序号，最后一关之后回到第一关。
func next_index(index: int) -> int:
	return (index + 1) % levels.size()
