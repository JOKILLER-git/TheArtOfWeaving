class_name WrapGesture
extends GestureRecognizer
## 绕线：线头在锚点周围一定距离内连续绕行，累计转角够一圈 = 请求切换线的前后。

signal wrap_completed

const FULL_TURN := 5.76             # 约 330° 算一圈
const HOOK_BLOCK_TURN := PI * 0.5   # 累计超过约 90° 时暂停钩针判定
const MIN_RADIUS := 0.3             # 绕圈时线头离锚点的距离范围（列宽）
const MAX_RADIUS := 1.4
const HINT_RADIUS := 0.9            # 提示虚线圆的半径（列宽），避开眼

var turn: float = 0.0               # 累计转角（弧度，带符号）
var _layout: FabricLayout
var _prev := Vector2.ZERO
var _has_prev := false
var _anchor := Vector2.INF


func _init(layout: FabricLayout) -> void:
	_layout = layout


func feed(point: Vector2) -> void:
	var a := _layout.anchor()
	if not a.is_equal_approx(_anchor):
		_anchor = a
		_clear_turn()
	var v := point - a
	var r := v.length()
	if r < MIN_RADIUS or r > MAX_RADIUS:
		_clear_turn()
		return
	if _has_prev:
		turn += _prev.angle_to(v)
	_prev = v
	_has_prev = true
	if absf(turn) >= FULL_TURN:
		_clear_turn()
		wrap_completed.emit()


func reset() -> void:
	_clear_turn()


## 正在绕圈（累计转角超过约 90°）时，钩针手势应暂停。
func blocks_hook() -> bool:
	return absf(turn) > HOOK_BLOCK_TURN


func _clear_turn() -> void:
	turn = 0.0
	_has_prev = false
