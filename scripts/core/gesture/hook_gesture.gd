class_name HookGesture
extends GestureRecognizer
## 钩针：线头从下方进入下面一行某个线圈的眼、再从上方离开 = 请求在该列钩针。
## 是否是下一针、针法对不对由 KnitSession 判定。

signal hook_requested(col: int)

const ENTER_RADIUS := 0.26          # 进入眼的半径（列宽）
const EXIT_RADIUS := 0.36           # 离开眼的半径（滞回，防抖）
const EXIT_ABOVE := 0.35            # 离开点需高于眼中心 EXIT_RADIUS 的这个比例

var active_col: int = -1            # 线头正在穿过的眼所在列；-1 表示不在眼里
var entered_below: bool = false
var _session: KnitSession
var _layout: FabricLayout
var _guard: WrapGesture


## guard 不为空时，绕线进行到一定程度会暂停钩针判定。
func _init(session: KnitSession, layout: FabricLayout, guard: WrapGesture = null) -> void:
	_session = session
	_layout = layout
	_guard = guard


func feed(point: Vector2) -> void:
	if _session.completed:
		reset()
		return
	var eye_row := _session.current_row - 1
	if active_col < 0:
		if _guard != null and _guard.blocks_hook():
			return
		for col in _session.width():
			var ec := _layout.eye_center(col, eye_row)
			if point.distance_to(ec) < ENTER_RADIUS:
				active_col = col
				entered_below = point.y < ec.y
				return
		return
	var center := _layout.eye_center(active_col, eye_row)
	if point.distance_to(center) <= EXIT_RADIUS:
		return
	var col := active_col
	var from_below := entered_below
	reset()
	if from_below and point.y > center.y + EXIT_RADIUS * EXIT_ABOVE:
		hook_requested.emit(col)


func reset() -> void:
	active_col = -1
	entered_below = false


## 线头正从下方穿过 col 列的眼（画面层据此让工作线压到该线圈头后面或前面）。
func is_threading(col: int) -> bool:
	return active_col >= 0 and active_col == col and entered_below
