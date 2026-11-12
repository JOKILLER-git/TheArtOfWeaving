class_name ScreenMapper2D
extends RefCounted
## 像素 ↔ 织物坐标。按关卡的列数、行数自动缩放：线圈宽有上限，高尽量占满画布，织物居中。
## 四周预留边距：左右各留出绕线提示圆伸出织物边缘的部分，上方留给进度珠和图纸卡，下方留给剪刀，
## 保证锚点、静止线头和提示圆在每一关都完整显示在画布内。
## 线圈宽 = 列宽 × FabricLayout.loop_width：线圈的大小（和线粗、行高）按线圈宽算，列宽更大，线圈之间留出空隙。
## T007：画布按 canvas_items + expand 缩放，可视区域随窗口比例变大（宽屏更宽、4:3 更高），
## fit 按实际可视区域（view，画布坐标）计算；CANVAS 只是设计基准尺寸（可视区域的最小值）。

const CANVAS := Vector2(1280, 800)  # 设计基准尺寸（project.godot 的 viewport 尺寸）
const LOOP_WIDTH := 0.72    # 2D 画面里线圈占列宽的比例（传给 FabricLayout），见 T006「加大列间距」
const MAX_COL_PX := 260.0   # 单个线圈宽度上限
const PAD_X := 24.0         # 左右画布边距（像素）
const PAD_TOP := 84.0       # 上方留给进度珠与图纸卡（像素）
const PAD_BOTTOM := 56.0    # 下方留给剪刀（像素）
const SIDE_UNITS := WrapGesture.HINT_RADIUS + 0.12  # 织物左右边缘外还要容纳的宽度（列宽）：提示圆 + 笔触
const TAIL_UNITS := 0.5     # 起始行线尾伸到沉降弧下方的长度（列宽），见 FabricView2D._row_strand
const REF_COL_PX := 84.0    # 参考线圈宽：线粗、抓取半径、提示等按 loop_px() / REF_COL_PX 等比放大
const SETTLE_SQUEEZE := 0.02

var col_px: float = REF_COL_PX
var loop_width: float = 1.0 # 线圈占列宽的比例（fit 时从 FabricLayout 读取）
var row_px: float = 70.0
var origin := Vector2.ZERO  # 织物坐标 (0, 0) 的像素位置
var settle: float = 0.0      # 一行完成时布面轻微收紧的动画量


## 关卡画面：放进可视区域 view 去掉边距后的区域，左右再留出提示圆的余量。
func fit(layout: FabricLayout, view := Rect2(Vector2.ZERO, CANVAS)) -> void:
	var area := Rect2(view.position + Vector2(PAD_X, PAD_TOP),
		view.size - Vector2(2.0 * PAD_X, PAD_TOP + PAD_BOTTOM))
	fit_in(layout, area, SIDE_UNITS)


## 把织物（左右各加 side_units 个列宽的余量）缩放后居中放进 area。
func fit_in(layout: FabricLayout, area: Rect2, side_units: float = 0.0) -> void:
	var cols := float(layout.columns())
	var span := layout.vertical_span()
	loop_width = layout.loop_width
	col_px = minf(MAX_COL_PX, area.size.x / (cols + 2.0 * side_units))
	# 行高按线圈宽限定比例，保证线圈形状不随列间距变化。
	row_px = clampf((area.size.y - TAIL_UNITS * col_px) / span, 0.75 * loop_px(), 1.05 * loop_px())
	# 行高被下限撑大、纵向放不下时，行高和列宽一起等比缩小。
	var height := span * row_px + TAIL_UNITS * col_px
	if height > area.size.y:
		var k := area.size.y / height
		row_px *= k
		col_px *= k
		height = area.size.y
	var center := area.get_center()
	var bottom := center.y + height * 0.5
	origin = Vector2(center.x - cols * col_px * 0.5 + 0.5 * col_px,
		bottom - TAIL_UNITS * col_px - FabricLayout.LOOP_BOT * row_px)


## 线圈宽（像素）。
func loop_px() -> float:
	return col_px * loop_width


## 相对参考线圈宽的缩放倍数。
func scale_k() -> float:
	return loop_px() / REF_COL_PX


func yarn_width() -> float:
	return 0.115 * loop_px()


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
