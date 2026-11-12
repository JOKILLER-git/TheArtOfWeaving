class_name HintView2D
extends Node2D
## 铅笔草图式提示。线状态不对时，锚点周围画虚线圆（提示时加深并带方向箭头，方向随行镜像）；
## 线状态对时，画钩针路径（一串点 + 方向箭头）。长时间没有进展会自动出现。
## 织物需要剪断时，用铅笔圈出与图纸不符的线圈（一直显示，钩针被拒时加深一下）。

var hint_on: bool = false
var _alpha: float = 0.0
var _idle: float = 0.0
var _idle_limit: float = 8.0
var _session: KnitSession
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _mistake_flash: float = 0.0
var _time: float = 0.0


func setup(session: KnitSession, layout: FabricLayout, mapper: ScreenMapper2D, level: LevelDefinition) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	_idle_limit = level.idle_hint_seconds
	hint_on = false
	_alpha = 0.0
	_idle = 0.0
	_mistake_flash = 0.0


func toggle() -> void:
	hint_on = not hint_on
	_idle = 0.0


func show_hint() -> void:
	hint_on = true


## 需要剪断时又去钩针：圈加深一下。
func flash_mistakes() -> void:
	create_tween().tween_method(func(v: float) -> void: _mistake_flash = v, 1.0, 0.0, 0.8)


func reset_idle() -> void:
	_idle = 0.0


## 玩家有进展：重新计时，提示收起。
func note_progress() -> void:
	_idle = 0.0
	hint_on = false


func _process(delta: float) -> void:
	if _session == null:
		return
	_time += delta
	if not _session.completed:
		_idle += delta
		if _idle > _idle_limit:
			hint_on = true
	_alpha = move_toward(_alpha, 1.0 if hint_on and not _session.completed else 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if _session == null:
		return
	if _session.needs_cut:
		for cell in _session.mistake_cells():
			_draw_mistake_circle(cell)
		return
	var col := _session.next_column()
	if col < 0:
		return
	if not _session.is_yarn_ready():
		_draw_wind_circle(0.28 + 0.45 * _alpha, _alpha)
	elif _alpha > 0.01:
		_draw_hook_path(col)


## 铅笔虚线圆：每一笔粗细、浓淡略有不同；strong > 0 时加上表示绕行的箭头。
func _draw_wind_circle(alpha: float, strong: float) -> void:
	var a := _mapper.to_screen(_layout.anchor())
	var ks := _mapper.scale_k()
	var radius := WrapGesture.HINT_RADIUS * _mapper.col_px
	var n := 36
	for k in range(0, n, 2):
		var a0 := TAU * k / n + 0.05 * sin(k * 1.7)
		var a1 := a0 + TAU / n * (0.75 + 0.2 * sin(k * 2.3))
		var rr := radius * (1.0 + 0.015 * sin(k * 3.1))
		var c := Color(StrandPainter2D.INK, alpha * (0.75 + 0.25 * sin(k * 1.3)))
		draw_arc(a, rr, a0, a1, 6, c, (1.6 + 0.5 * sin(k * 0.9)) * ks * 0.6, true)
	if strong > 0.01:
		# 绕行方向按行方向镜像：从静止线头出发先离开下一针的眼，最后才经过它。
		# 奇数行（左→右）画面上顺时针，偶数行（右→左）逆时针。
		var spin := float(KnitSession.row_direction(_session.current_row))
		var arrow_color := Color(StrandPainter2D.INK, 0.6 * strong)
		for theta: float in [PI * 0.5, PI * 1.5]:
			_draw_arrow_on_circle(a, radius, theta, spin, ks, arrow_color)


## 圆上 theta 处画一个沿绕行方向的小箭头（spin > 0 画面上顺时针）。
func _draw_arrow_on_circle(center: Vector2, radius: float, theta: float, spin: float, ks: float, color: Color) -> void:
	var p := center + Vector2(cos(theta), sin(theta)) * radius
	var fwd := Vector2(-sin(theta), cos(theta)) * spin
	var side := fwd.orthogonal()
	var h := 9.0 * ks * 0.6
	draw_polyline(PackedVector2Array([p - fwd * h + side * h, p, p - fwd * h - side * h]), color, 2.2 * ks * 0.6, true)


## 钩针路径：从下方进眼、从上方出来再落下。
func _draw_hook_path(col: int) -> void:
	var ks := _mapper.scale_k()
	var ec := _mapper.to_screen(_layout.eye_center(col, _session.current_row - 1))
	var d := float(KnitSession.row_direction(_session.current_row))
	var keys: Array[Vector2] = [
		ec + Vector2(-d * 44.0, 46.0) * ks,
		ec + Vector2(-d * 10.0, 14.0) * ks,
		ec + Vector2(d * 2.0, -34.0) * ks,
		ec + Vector2(d * 20.0, -30.0) * ks,
		ec + Vector2(d * 40.0, 46.0) * ks,
	]
	var path := Strand2D.catmull(keys, 12)
	var c := Color(StrandPainter2D.INK, 0.6 * _alpha)
	var acc := 0.0
	for k in range(1, path.size()):
		acc += path[k].distance_to(path[k - 1])
		if acc >= 9.0 * ks:
			acc = 0.0
			draw_circle(path[k], 2.4 * ks, c)
	draw_polyline(PackedVector2Array([ec + Vector2(-7, 9) * ks, ec, ec + Vector2(7, 9) * ks]), c, 2.5 * ks, true)


## 铅笔把一个错的线圈圈起来：两圈略错开的手绘椭圆。
func _draw_mistake_circle(cell: Vector2i) -> void:
	var ks := _mapper.scale_k()
	var center := _mapper.to_screen(Vector2(cell.x, cell.y - 0.1))
	var radii := Vector2(0.62 * _mapper.loop_px(), 0.82 * _mapper.row_px)
	var alpha := 0.55 + 0.1 * sin(_time * 2.5) + 0.35 * _mistake_flash
	for pass_i in 2:
		var pts := PackedVector2Array()
		var n := 40
		var start := -0.4 + 0.5 * pass_i
		for k in n + 4:
			var a := start + TAU * k / n
			var wobble := 1.0 + 0.04 * sin(k * 1.9 + pass_i * 2.0) + 0.03 * pass_i
			pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble)
		draw_polyline(pts, Color(StrandPainter2D.INK, alpha * (0.9 - 0.35 * pass_i)), (2.2 - 0.6 * pass_i) * ks * 0.7, true)
