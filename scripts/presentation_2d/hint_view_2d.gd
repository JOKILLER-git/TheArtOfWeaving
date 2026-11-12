class_name HintView2D
extends Node2D
## 铅笔草图式提示。线状态不对时，锚点周围画虚线圆（提示时加深并带箭头）；
## 线状态对时，画钩针路径（一串点 + 方向箭头）。长时间没有进展会自动出现。

var hint_on: bool = false
var _alpha: float = 0.0
var _idle: float = 0.0
var _idle_limit: float = 8.0
var _session: KnitSession
var _layout: FabricLayout
var _mapper: ScreenMapper2D


func setup(session: KnitSession, layout: FabricLayout, mapper: ScreenMapper2D, level: LevelDefinition) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	_idle_limit = level.idle_hint_seconds
	hint_on = false
	_alpha = 0.0
	_idle = 0.0


func toggle() -> void:
	hint_on = not hint_on
	_idle = 0.0


func show_hint() -> void:
	hint_on = true


func reset_idle() -> void:
	_idle = 0.0


## 玩家有进展：重新计时，提示收起。
func note_progress() -> void:
	_idle = 0.0
	hint_on = false


func _process(delta: float) -> void:
	if _session == null:
		return
	if not _session.completed:
		_idle += delta
		if _idle > _idle_limit:
			hint_on = true
	_alpha = move_toward(_alpha, 1.0 if hint_on and not _session.completed else 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if _session == null:
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
		# 顶部一个顺时针方向的小箭头（逆时针绕同样有效）。
		var top := a + Vector2(0, -radius)
		var h := 9.0 * ks * 0.6
		draw_polyline(PackedVector2Array([top + Vector2(-h, -h), top, top + Vector2(-h, h)]), Color(StrandPainter2D.INK, 0.6 * strong), 2.2 * ks * 0.6, true)


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
