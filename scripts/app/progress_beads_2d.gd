class_name ProgressBeads2D
extends Node2D
## 画面顶部的一串小珠子表示关卡进度：完成过的是线色，当前的一颗发光，其余是浅色空心珠。
## T008：「完成过」来自玩家进度（选关后可以跳着玩），由 GameApp 通过 set_completed() 传入；
## 珠子串的几何（bead_center / string_span）和单颗珠子的画法（draw_bead）公开，
## 选关晾衣绳（LevelClothesline2D）在展开动画里接着画同一串珠子。

const Y := 30.0
const SPACING := 24.0
const R := 6.5
const STRING_OVERHANG := 18.0   # 穿珠线伸出两端珠子的长度

var count: int = 0
var current: int = 0
var current_done: bool = false
var completed: Array[bool] = []   # 每关是否完成过（玩家进度）
var _time: float = 0.0


func set_progress(p_count: int, p_current: int, p_current_done: bool) -> void:
	count = p_count
	current = p_current
	current_done = p_current_done
	queue_redraw()


## 每关是否完成过（来自 PlayerProgress）。
func set_completed(flags: Array[bool]) -> void:
	completed = flags
	queue_redraw()


func is_done(i: int) -> bool:
	if i == current and current_done:
		return true
	return i < completed.size() and completed[i]


## 第 i 颗珠子的中心（画布坐标）。
func bead_center(i: int) -> Vector2:
	var view := get_viewport_rect()
	var x0 := view.get_center().x - (count - 1) * SPACING * 0.5
	return Vector2(x0 + i * SPACING, view.position.y + Y)


## 穿珠线的左右两端。
func string_span() -> Array[Vector2]:
	var a := bead_center(0) - Vector2(STRING_OVERHANG, 0)
	var b := bead_center(maxi(0, count - 1)) + Vector2(STRING_OVERHANG, 0)
	return [a, b]


func pulse() -> float:
	return 0.5 + 0.5 * sin(_time * 3.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if count <= 0:
		return
	var span := string_span()
	draw_line(span[0], span[1], Color(StrandPainter2D.BASE_YARN, 0.7), 2.0, true)
	for i in count:
		draw_bead(self, bead_center(i), is_done(i), i == current and not current_done, pulse(), 1.0)


## 画一颗珠子：current 发光；done 线色实心；其余浅色空心。alpha 用于淡出。
static func draw_bead(ci: CanvasItem, c: Vector2, done: bool, is_current: bool, p_pulse: float, alpha: float) -> void:
	if is_current:
		ci.draw_circle(c, R + 5.0 + 2.0 * p_pulse, Color(1.0, 0.9, 0.7, (0.35 + 0.25 * p_pulse) * alpha))
		ci.draw_circle(c, R, Color(Color("fffaf0"), alpha))
		ci.draw_arc(c, R, 0, TAU, 24, Color(StrandPainter2D.YARN, alpha), 2.0, true)
	elif done:
		ci.draw_circle(c, R, Color(StrandPainter2D.YARN, alpha))
		ci.draw_circle(c + Vector2(-2, -2), 2.0, Color(StrandPainter2D.YARN.lightened(0.4), alpha))
	else:
		ci.draw_circle(c, R - 1.0, Color(Color("f6f1e6"), alpha))
		ci.draw_arc(c, R - 1.0, 0, TAU, 24, Color(StrandPainter2D.INK, 0.3 * alpha), 1.4, true)
