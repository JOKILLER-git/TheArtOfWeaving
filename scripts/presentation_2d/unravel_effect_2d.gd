class_name UnravelEffect2D
extends Node2D
## 剪断动画（一次性）：工作线在剪口处断成两截落下；本关新织的线圈各自松开、飘散、消失。
## 只是画面效果：规则层在动画开始时已经回到起始行。播完自动释放。

const DURATION := 0.85

var _loops: Array[PackedVector2Array] = []
var _vel: Array[Vector2] = []
var _spin: Array[float] = []
var _rope_parts: Array[PackedVector2Array] = []
var _rope_vel: Array[Vector2] = []
var _width: float = 8.0
var _t: float = 0.0


## loops：要散开的线圈（像素折线）；rope：工作线（像素点）；cut_point：剪口。
func start(loops: Array[PackedVector2Array], rope: PackedVector2Array, cut_point: Vector2, width: float) -> void:
	_loops = loops
	_width = width
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for loop in loops:
		var c := _centroid(loop)
		var away := (c - cut_point).normalized() if c.distance_to(cut_point) > 1.0 else Vector2.UP
		_vel.append(away * rng.randf_range(60.0, 140.0) + Vector2(rng.randf_range(-40.0, 40.0), -rng.randf_range(80.0, 160.0)))
		_spin.append(rng.randf_range(-2.5, 2.5))
	if rope.size() >= 2:
		var k := _nearest_index(rope, cut_point)
		k = clampi(k, 1, rope.size() - 1)
		_rope_parts = [rope.slice(0, k + 1), rope.slice(k)]
		_rope_vel = [Vector2(-60, -40), Vector2(60, -40)]


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var u := clampf(_t / DURATION, 0.0, 1.0)
	var fade := 1.0 - u * u
	var g := Vector2(0, 900.0)
	for i in _loops.size():
		var loop := _loops[i]
		var c := _centroid(loop)
		var offset := _vel[i] * _t + 0.5 * g * _t * _t
		# 线圈慢慢松开：纵向拉平、横向变宽。
		var relax := Vector2(1.0 + 0.6 * u, 1.0 - 0.6 * u)
		var xf := Transform2D(_spin[i] * _t, relax, 0.0, c + offset) * Transform2D(0.0, -c)
		draw_polyline(xf * loop, Color(StrandPainter2D.YARN, 0.9 * fade), _width * (1.0 - 0.3 * u), true)
	for j in _rope_parts.size():
		var off := _rope_vel[j] * _t + 0.5 * g * _t * _t
		var pts := _rope_parts[j].duplicate()
		for k in pts.size():
			pts[k] += off * (float(k) / pts.size() if j == 0 else 1.0 - float(k) / pts.size())
		draw_polyline(pts, Color(StrandPainter2D.YARN.darkened(0.15), fade), _width, true)
	# 剪口处的一点小火花线头
	if _rope_parts.size() == 2 and u < 0.4:
		var p := _rope_parts[1][0]
		for k in 5:
			var a := TAU * k / 5.0 + 0.4
			draw_line(p + Vector2(cos(a), sin(a)) * (6.0 + 30.0 * u), p + Vector2(cos(a), sin(a)) * (12.0 + 40.0 * u), Color(StrandPainter2D.INK, 0.6 * (1.0 - u / 0.4)), 2.0, true)


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / maxf(1.0, float(pts.size()))


static func _nearest_index(pts: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for k in pts.size():
		var d := pts[k].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best
