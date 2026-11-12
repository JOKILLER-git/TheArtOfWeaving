class_name WorkingYarn2D
extends Node2D
## 工作线：Verlet 绳与可抓取的线头。按 Yarn.side 决定整根线在织物前还是后
## （层级由 FabricView2D 合成，因为交叉点需要同时知道织物和工作线）；本节点画线头与翻面涟漪。

const ROPE_N := 18
const FLIP_TIME := 0.38     # 翻面动画时长（秒）
const GRAB_RADIUS := 44.0   # 参考尺寸下的抓取半径（像素）

## 线头的共享状态（指针输入、图纸卡、调试层只依赖它）。
var handle := YarnHandle.new()
## 线头位置（像素），即 handle.tip。
var tip: Vector2:
	get: return handle.tip
	set(v): handle.tip = v
## 玩家正在拖线头，即 handle.held。
var held: bool:
	get: return handle.held
	set(v): handle.held = v
var front_v: float = 0.0    # 显示用：0 = 后，1 = 前，翻面时补间
var flip_k: float = 1.0     # 翻面动画进度（1 = 静止）

var _session: KnitSession
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _rope := PackedVector2Array()
var _rope_prev := PackedVector2Array()
var _flip_tween: Tween
var _time: float = 0.0


func setup(session: KnitSession, layout: FabricLayout, mapper: ScreenMapper2D) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	if _flip_tween:
		_flip_tween.kill()
	held = false
	front_v = 1.0 if session.yarn.is_front() else 0.0
	flip_k = 1.0
	tip = _rest_tip()
	_rope = PackedVector2Array()
	_sync_handle()


func is_front() -> bool:
	return front_v >= 0.5


func anchor_px() -> Vector2:
	return _mapper.to_screen(_layout.anchor())


func can_grab(p: Vector2) -> bool:
	_sync_handle()
	return handle.can_grab(p)


func _sync_handle() -> void:
	handle.enabled = not _session.completed
	handle.grab_radius = GRAB_RADIUS * _mapper.scale_k()


## 线翻到另一面：颜色和粗细补间，绳子中段甩一下，像翻过织物边。
func flip_to(side: Yarn.Face) -> void:
	var front := side == Yarn.Face.FRONT
	if _flip_tween:
		_flip_tween.kill()
	_flip_tween = create_tween().set_parallel(true)
	_flip_tween.tween_property(self, "front_v", 1.0 if front else 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_property(self, "flip_k", 1.0, FLIP_TIME).from(0.0)
	if _rope.size() == ROPE_N:
		var n := (_rope[ROPE_N - 1] - _rope[0]).orthogonal().normalized()
		var s := 1.0 if front else -1.0
		for k in range(1, ROPE_N - 1):
			var f := sin(PI * float(k) / (ROPE_N - 1))
			_rope_prev[k] = _rope_prev[k] - n * f * 10.0 * _mapper.scale_k() * s
	queue_redraw()


## 工作线这根要画的线（含还属于工作线的折返弧）。
func build_strand() -> Strand2D:
	var w := _mapper.yarn_width() * lerpf(0.72, 1.0, front_v) * (1.0 + 0.3 * sin(PI * flip_k))
	var base := StrandPainter2D.YARN.darkened(lerpf(0.4, 0.0, front_v)).lightened(0.08 * front_v)
	var st := Strand2D.new(Strand2D.Kind.ROPE, -1, base, w)
	st.shadow = lerpf(0.04, 0.2, front_v)
	if _rope.size() < 2:
		return st
	var rope_pts: Array[Vector2] = []
	rope_pts.assign(Array(_rope))
	var pts := Strand2D.catmull(rope_pts, 4)
	var row := _session.current_row
	if row >= 1 and _layout.is_turn_loose(row):
		var arc := _layout.turn_arc(row)
		if _layout.turn_side(row) > 0:
			arc.reverse()   # 从下一行的沉降弧开始，接到锚点
		var arc_pts := Strand2D.catmull(_mapper.to_screen_all(arc), Strand2D.STEPS)
		arc_pts.append_array(pts.slice(1))
		pts = arc_pts
	st.points = pts
	st.tones.resize(pts.size())
	st.tones.fill(0.0)
	st.z.resize(pts.size() - 1)
	st.z.fill(5.0)
	st.cols.resize(pts.size() - 1)
	st.cols.fill(-1)
	return st


func _process(delta: float) -> void:
	if _session == null:
		return
	_time += delta
	_sync_handle()
	if not held:
		tip = tip.lerp(_rest_tip(), 1.0 - exp(-10.0 * delta))
	_step_rope(delta)
	queue_redraw()


func _rest_tip() -> Vector2:
	return _mapper.to_screen(_layout.rest_tip())


## 简单 Verlet 绳：两端固定，只约束拉伸，让线自然下垂。
func _step_rope(delta: float) -> void:
	var a := anchor_px()
	var b := tip
	var ks := _mapper.scale_k()
	if _rope.size() != ROPE_N:
		_rope.resize(ROPE_N)
		for k in ROPE_N:
			_rope[k] = a.lerp(b, float(k) / (ROPE_N - 1))
		_rope_prev = _rope.duplicate()
	var seg := maxf(a.distance_to(b) * 1.08, 40.0 * ks) / (ROPE_N - 1)
	var g := Vector2(0, 1400.0 * ks) * delta * delta
	for k in range(1, ROPE_N - 1):
		var p := _rope[k]
		var v := (p - _rope_prev[k]) * 0.95
		_rope_prev[k] = p
		_rope[k] = p + v + g
	_rope[0] = a
	_rope[ROPE_N - 1] = b
	for _it in 12:
		for k in ROPE_N - 1:
			var p1 := _rope[k]
			var p2 := _rope[k + 1]
			var dv := p2 - p1
			var dist := dv.length()
			if dist <= seg or dist < 0.001:
				continue
			var diff := (dist - seg) / dist
			if k == 0:
				_rope[k + 1] = p2 - dv * diff
			elif k + 1 == ROPE_N - 1:
				_rope[k] = p1 + dv * diff
			else:
				_rope[k] = p1 + dv * diff * 0.5
				_rope[k + 1] = p2 - dv * diff * 0.5
		_rope[0] = a
		_rope[ROPE_N - 1] = b


func _draw() -> void:
	if _session == null or _session.completed:
		return
	var ks := _mapper.scale_k()
	var yw := _mapper.yarn_width()
	# 翻面时锚点处的一圈涟漪。
	if flip_k < 1.0:
		draw_arc(anchor_px(), yw * (1.0 + 3.0 * flip_k), 0, TAU, 48, Color(StrandPainter2D.YARN, 0.5 * (1.0 - flip_k)), 2.0 * ks, true)
	# 线头（可抓取）。
	var kr := (0.6 if held else 0.8) * yw
	var kc := StrandPainter2D.YARN.darkened(0.15 + 0.25 * (1.0 - front_v))
	if not held:
		var halo := kr * (1.7 + 0.25 * sin(_time * 3.0))
		draw_arc(tip, halo, 0, TAU, 48, Color(StrandPainter2D.YARN, 0.35), 1.5 * ks, true)
	draw_circle(tip + Vector2(0.1, 0.3) * kr, kr, Color(StrandPainter2D.SHADOW, 0.12))
	draw_circle(tip, kr, kc)
	draw_circle(tip + Vector2(-0.28, -0.28) * kr, 0.33 * kr, kc.lightened(0.4))
