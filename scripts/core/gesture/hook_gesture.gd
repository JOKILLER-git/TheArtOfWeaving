class_name HookGesture
extends GestureRecognizer
## 钩针：线头路径（相邻两个采样点之间的线段）从下往上穿过下面一行线圈的眼的水平中线，
## 且穿过点在眼的半径内 = 请求在该列钩针。「在半径内」：穿过点离眼中心不超过 HIT_RADIUS 列宽，
## 或（低角度斜穿时）这一段路径所在的直线离眼中心不超过 HIT_RADIUS——斜着穿过眼时穿过中线的点可能稍远。
## 是否是下一针、针法对不对由 KnitSession 判定。
## T007：由「进圈 / 出圈」状态改为「线段穿过中线」，避免高速、斜进、出眼偏平时漏判；
## 线头先要到中线下方 ARM_DEPTH 以下才算「从下面来」（防止在中线附近抖动反复触发）。

signal hook_requested(col: int)
## 一次从下往上的穿越没有变成钩针请求（调试用）。detail：穿过点（或路径直线）离最近眼中心的距离（列宽）。
signal hook_ignored(reason: IgnoreReason, col: int, detail: float)

## 穿越被忽略的原因。
enum IgnoreReason { NONE, OFF_EYE, GUARD }

const HIT_RADIUS := 0.32            # 穿过点离眼中心的横向距离上限（列宽）；比画出来的眼大，也避开提示圆（0.9）
const ARM_DEPTH := 0.06             # 线头需先低于中线这么多（行高）才算从下面来

var active_col: int = -1            # 线头正在眼下方、准备穿过的那一列；-1 表示没有
var last_ignored: IgnoreReason = IgnoreReason.NONE
var _session: KnitSession
var _layout: FabricLayout
var _guard: WrapGesture
var _armed: bool = false
var _prev := Vector2.ZERO
var _has_prev: bool = false


## guard 不为空时，确实在绕圈（见 WrapGesture.blocks_hook）时忽略钩针。
func _init(session: KnitSession, layout: FabricLayout, guard: WrapGesture = null) -> void:
	_session = session
	_layout = layout
	_guard = guard


func feed(point: Vector2) -> void:
	if _session.completed:
		reset()
		return
	var line := eye_line_y()
	if _has_prev and _armed and _prev.y < line and point.y >= line:
		_armed = false
		var x := lerpf(_prev.x, point.x, (line - _prev.y) / (point.y - _prev.y))
		_on_cross(Vector2(x, line), point - _prev)
	if point.y <= line - ARM_DEPTH:
		_armed = true
	active_col = -1
	if _armed and point.y < line:
		var col := nearest_col(point.x)
		if absf(point.x - col) <= HIT_RADIUS:
			active_col = col
	_prev = point
	_has_prev = true


func reset() -> void:
	active_col = -1
	_armed = false
	_has_prev = false


## 线头正从下方穿过 col 列的眼（画面层据此让工作线压到该线圈头后面或前面）。
func is_threading(col: int) -> bool:
	return active_col >= 0 and active_col == col


## 线头已经在眼的中线下方（下一次向上穿过中线会被判定）。
func is_armed() -> bool:
	return _armed


## 当前要穿过的眼所在的水平中线（织物坐标 y）。
func eye_line_y() -> float:
	return _layout.eye_center(0, _session.current_row - 1).y


## 离 x 最近的列（限制在织物范围内）。
func nearest_col(x: float) -> int:
	return clampi(roundi(x), 0, _session.width() - 1)


## 在 at 处向上穿过中线，dir 为这一段路径的方向。
func _on_cross(at: Vector2, dir: Vector2) -> void:
	var col := nearest_col(at.x)
	var to_eye := Vector2(float(col), at.y) - at
	var off := absf(to_eye.x)
	var d := dir.normalized()
	if absf(d.y) < absf(d.x):
		# 低角度（离水平不到 45°）斜着穿：按路径直线离眼中心的距离算（绕圈时路径很陡，不走这里）。
		off = minf(off, absf(d.cross(to_eye)))
	if off > HIT_RADIUS or absf(to_eye.x) > 0.5:
		_ignore(IgnoreReason.OFF_EYE, col, off)
	elif _guard != null and _guard.blocks_hook():
		_ignore(IgnoreReason.GUARD, col, off)
	else:
		last_ignored = IgnoreReason.NONE
		hook_requested.emit(col)


func _ignore(reason: IgnoreReason, col: int, detail: float) -> void:
	last_ignored = reason
	hook_ignored.emit(reason, col, detail)
