class_name StitchRegistry
extends RefCounted
## 针法登记表：按 id 查针法，按线的状态查「此时钩出来的是哪种针」。
## 新增针法只需写一个 StitchType 子类并在这里注册。

var _by_id: Dictionary[String, StitchType] = {}
var _order: Array[StitchType] = []


## 默认登记表：下针、上针。第一个注册的针法同时作为起始行的针法。
static func create_default() -> StitchRegistry:
	var registry := StitchRegistry.new()
	registry.register(KnitStitch.new())
	registry.register(PurlStitch.new())
	return registry


func register(stitch: StitchType) -> void:
	assert(not _by_id.has(stitch.id()), "针法 id 重复：%s" % stitch.id())
	_by_id[stitch.id()] = stitch
	_order.append(stitch)


func has(stitch_id: String) -> bool:
	return _by_id.has(stitch_id)


func by_id(stitch_id: String) -> StitchType:
	return _by_id.get(stitch_id, null)


## 线在 side 一侧时钩出来的针法；没有则返回 null。
func for_side(side: Yarn.Face) -> StitchType:
	for stitch in _order:
		if stitch.required_side() == side:
			return stitch
	return null


## 起始行使用的针法。
func base_stitch() -> StitchType:
	return _order[0] if not _order.is_empty() else null
