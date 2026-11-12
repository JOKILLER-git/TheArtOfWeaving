class_name Yarn
extends RefCounted
## 工作线：记录它在织物的哪一面（前 / 后）。

enum Face { BACK, FRONT }

signal side_changed(side: Yarn.Face)

var side: Yarn.Face = Yarn.Face.BACK


func is_front() -> bool:
	return side == Yarn.Face.FRONT


func toggle() -> void:
	side = Yarn.Face.BACK if side == Yarn.Face.FRONT else Yarn.Face.FRONT
	side_changed.emit(side)


func reset() -> void:
	side = Yarn.Face.BACK
