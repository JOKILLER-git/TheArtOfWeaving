class_name KnitStitch
extends StitchType
## 下针：线在后，新线圈从后往前穿出，腿压在旧线圈头前面。


func id() -> String:
	return "K"


func display_name() -> String:
	return "下针"


func chart_symbol() -> String:
	return "V"


func required_side() -> Yarn.Face:
	return Yarn.Face.BACK


func new_loop_in_front() -> bool:
	return true
