class_name PurlStitch
extends StitchType
## 上针：线在前，新线圈从前往后穿过，旧线圈头横压在前面形成颗粒。


func id() -> String:
	return "P"


func display_name() -> String:
	return "上针"


func chart_symbol() -> String:
	return "-"


func required_side() -> Yarn.Face:
	return Yarn.Face.FRONT


func new_loop_in_front() -> bool:
	return false
