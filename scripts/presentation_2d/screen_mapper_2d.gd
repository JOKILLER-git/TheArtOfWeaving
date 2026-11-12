class_name ScreenMapper2D
extends RefCounted
## 像素 ↔ 织物坐标。按关卡的列数、行数自动缩放：线圈宽有上限，高尽量占满画布，织物居中。

const CANVAS := Vector2(1280, 800)
const MAX_COL_PX := 260.0   # 单个线圈宽度上限
const FILL_W := 0.80        # 织物宽度最多占画布的比例
const FILL_H := 0.78        # 织物高度的目标比例
const REF_COL_PX := 84.0    # 参考列宽：判定半径、绳子等按 col_px / REF_COL_PX 等比放大
const SETTLE_SQUEEZE := 0.02

var col_px: float = REF_COL_PX
var row_px: float = 70.0
var origin := Vector2.ZERO  # 织物坐标 (0, 0) 的像素位置
var settle: float = 0.0     # 一行完成时布面轻微收紧的动画量


func fit(layout: FabricLayout) -> void:
	var cols := float(layout.columns())
	var span := layout.vertical_span()
	col_px = minf(MAX_COL_PX, CANVAS.x * FILL_W / cols)
	row_px = clampf(CANVAS.y * FILL_H / span, 0.75 * col_px, 1.05 * col_px)
	origin = Vector2((CANVAS.x - cols * col_px) * 0.5 + 0.5 * col_px,
		(CANVAS.y + span * row_px) * 0.5 - FabricLayout.LOOP_BOT * row_px)


## 相对参考列宽的缩放倍数。
func scale_k() -> float:
	return col_px / REF_COL_PX


func yarn_width() -> float:
	return 0.115 * col_px


func to_screen(fabric_point: Vector2) -> Vector2:
	var y := origin.y - fabric_point.y * row_px
	return Vector2(origin.x + fabric_point.x * col_px, origin.y + (y - origin.y) * _squeeze())


func to_fabric(screen_point: Vector2) -> Vector2:
	var y := origin.y + (screen_point.y - origin.y) / _squeeze()
	return Vector2((screen_point.x - origin.x) / col_px, (origin.y - y) / row_px)


func to_screen_all(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		out.append(to_screen(p))
	return out


func _squeeze() -> float:
	return 1.0 - SETTLE_SQUEEZE * settle
