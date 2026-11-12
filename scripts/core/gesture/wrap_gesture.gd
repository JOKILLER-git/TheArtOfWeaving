class_name WrapGesture
extends GestureRecognizer
## 绕线：线头在锚点周围一定距离内连续绕行，累计转角够一圈 = 请求切换线的前后。
## 判定较宽松（T006）：约 270° 即算一圈；半径范围宽；线头短暂向外离开范围不立即清零。
## 绕线守卫（T007 收紧）：只有「确实正在绕圈」时才暂停钩针——同一方向连续转过 SPIN_BLOCK 以上、
## 且绕锚点的平均角速度不低于 SPIN_MIN_RATE。普通移动来回改变方向，不会挡住钩针。
## 刚绕完一圈后：只在 COOLDOWN_SECONDS 内挡住与绕线同方向的继续绕行；之后要再绕满一圈才重新挡。

signal wrap_completed

const FULL_TURN := PI * 1.5         # 约 270° 算一圈
const SPIN_BLOCK := PI * 2.0 / 3.0  # 同方向连续转过约 120° 才算「正在绕圈」
const SPIN_MIN_RATE := PI * 2.0 / 3.0  # 且平均角速度不低于约 120°/秒
const REVERSE_TOLERANCE := PI / 15.0   # 反方向累计超过约 12° 才算换方向（容忍抖动）
const MIN_RADIUS := 0.2             # 绕圈时线头离锚点的距离范围（列宽）
const MAX_RADIUS := 2.0
const CLEAR_RADIUS := 2.5           # 超出这个距离立即清零
const GRACE_SECONDS := 0.3          # 在范围外停留超过这个时间才清零
const COOLDOWN_SECONDS := 0.15      # 完成一圈后，同方向继续绕时暂停钩针的时间
const HINT_RADIUS := 0.9            # 提示虚线圆的半径（列宽），避开眼

var turn: float = 0.0               # 本圈累计转角（弧度，带符号），够 FULL_TURN 完成一次绕线
var spin: float = 0.0               # 同一方向连续转过的角度（弧度，带符号）
## 时钟（秒）。默认用引擎时间；测试可替换成可控的时钟。
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var _layout: FabricLayout
var _prev := Vector2.ZERO
var _has_prev := false
var _anchor := Vector2.INF
var _out_since: float = -1.0        # 进入范围外的时刻；-1 表示在范围内
var _cooldown_until: float = -INF
var _spin_since: float = 0.0        # 本段连续绕行开始的时刻
var _back: float = 0.0              # 与 spin 相反方向的累计（未超过容差前不算换方向）
var _after_wrap: bool = false       # 本段连续绕行是从上一次完成的绕线接着来的
var _wrap_sign: float = 0.0         # 上一次完成的绕线方向


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
		_leave_range(r)
		return
	_out_since = -1.0
	if _has_prev:
		var d := _prev.angle_to(v)
		turn += d
		_track_spin(d)
	_prev = v
	_has_prev = true
	if absf(turn) >= FULL_TURN:
		_wrap_sign = signf(turn)
		turn = 0.0
		spin = 0.0
		_back = 0.0
		_spin_since = _now()
		_after_wrap = true
		_cooldown_until = _now() + COOLDOWN_SECONDS
		wrap_completed.emit()


func reset() -> void:
	_clear_turn()
	_cooldown_until = -INF


## 钩针手势是否应暂停：正在绕圈，或刚绕完一圈且还在同方向继续绕。
func blocks_hook() -> bool:
	return is_spinning() or in_cooldown()


## 确实在绕圈：同方向连续转角够大且角速度明显（刚绕完一圈后要再转满一圈）。
func is_spinning() -> bool:
	var limit := FULL_TURN if _after_wrap else SPIN_BLOCK
	return absf(spin) >= limit and spin_rate() >= SPIN_MIN_RATE


## 刚完成绕线、并且仍朝同一方向转。
func in_cooldown() -> bool:
	return _now() < _cooldown_until and spin != 0.0 and signf(spin) == _wrap_sign


## 本段连续绕行的平均角速度（弧度/秒）。时长为 0（测试里一次喂完）时视为很快。
func spin_rate() -> float:
	var dt := _now() - _spin_since
	return absf(spin) / dt if dt > 0.001 else INF


## 同方向累加；反方向先记在 _back，超过容差才视为换方向、重新开始一段。
func _track_spin(d: float) -> void:
	if spin == 0.0 or signf(d) == signf(spin):
		if spin == 0.0 and _back == 0.0:
			_spin_since = _now()
		spin += d
		_back = 0.0
		return
	_back += d
	if absf(_back) > REVERSE_TOLERANCE:
		spin = _back
		_back = 0.0
		_spin_since = _now()
		_after_wrap = false


## 线头在范围外：穿过锚点中心（不是在绕）或太远立即清零；向外短暂离开给一小段宽限时间，回到范围内可以接着绕。
func _leave_range(r: float) -> void:
	if r < MIN_RADIUS or r > CLEAR_RADIUS:
		_clear_turn()
		return
	var now := _now()
	if _out_since < 0.0:
		_out_since = now
	elif now - _out_since > GRACE_SECONDS:
		_clear_turn()


func _clear_turn() -> void:
	turn = 0.0
	spin = 0.0
	_back = 0.0
	_after_wrap = false
	_has_prev = false
	_out_since = -1.0


func _now() -> float:
	return clock.call()
