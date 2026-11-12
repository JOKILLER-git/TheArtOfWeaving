class_name GestureDebugOverlay2D
extends Node2D
## 手势调试层（F3 开关，T007）：画出每个眼的钩针判定区、眼的中线、锚点的绕线范围、线头轨迹，
## 并列出守卫状态（绕线转角、连续转角、角速度、冷却）和最近的钩针 / 绕线事件（被拒或被忽略的原因）。
## 只读：不改任何规则或手势状态。默认隐藏；隐藏时仍记录事件，打开即可看到刚才发生了什么。

const MAX_EVENTS := 8
const TRAIL := 90
const OK_COLOR := Color(0.15, 0.6, 0.25)
const BAD_COLOR := Color(0.85, 0.2, 0.15)
const INFO_COLOR := Color(0.15, 0.35, 0.8)

var _session: KnitSession
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _hook: HookGesture
var _wrap: WrapGesture
var _yarn: WorkingYarn2D
var _events: Array[String] = []
var _marks: Array[Dictionary] = []    # {at: 像素, color}
var _trail := PackedVector2Array()


func setup(session: KnitSession, layout: FabricLayout, mapper: ScreenMapper2D, hook: HookGesture, wrap_gesture: WrapGesture, yarn: WorkingYarn2D) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	_hook = hook
	_wrap = wrap_gesture
	_yarn = yarn
	_marks.clear()
	_trail.clear()
	_connect(hook.hook_ignored, _on_hook_ignored)
	_connect(wrap_gesture.wrap_completed, _on_wrap_completed)
	_connect(session.stitch_made, _on_stitch_made)
	_connect(session.stitch_rejected, _on_stitch_rejected)


func toggle() -> void:
	visible = not visible


## 最近的事件（新的在后）。
func events() -> Array[String]:
	return _events


func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _log(text: String, color: Color) -> void:
	_events.append("%.2f  %s" % [Time.get_ticks_msec() / 1000.0, text])
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	if _yarn != null:
		_marks.append({"at": _yarn.tip, "color": color})
		if _marks.size() > MAX_EVENTS:
			_marks.pop_front()


func _on_hook_ignored(reason: HookGesture.IgnoreReason, col: int, detail: float) -> void:
	match reason:
		HookGesture.IgnoreReason.OFF_EYE:
			_log("忽略：穿过点离第 %d 列眼 %.2f 列宽 > %.2f" % [col, detail, HookGesture.HIT_RADIUS], BAD_COLOR)
		HookGesture.IgnoreReason.GUARD:
			_log("忽略：绕线守卫（连续 %d°，%d°/s%s）" % [roundi(rad_to_deg(absf(_wrap.spin))), _rate_deg(), "，冷却中" if _wrap.in_cooldown() else ""], BAD_COLOR)


func _on_wrap_completed() -> void:
	_log("绕线完成 → 换面", INFO_COLOR)


func _on_stitch_made(row: int, col: int, stitch: StitchType) -> void:
	_log("成针 第 %d 行第 %d 列 %s" % [row, col, stitch.chart_symbol()], OK_COLOR)


func _on_stitch_rejected(result: HookResult) -> void:
	_log("规则拒绝：%s（第 %d 列）" % [HookResult.Status.keys()[result.status], result.col], BAD_COLOR)


func _rate_deg() -> int:
	var r := _wrap.spin_rate()
	return 9999 if is_inf(r) else roundi(rad_to_deg(r))


func _process(_delta: float) -> void:
	if _yarn != null and _yarn.held:
		_trail.append(_yarn.tip)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	elif not _trail.is_empty() and _yarn != null and not _yarn.held:
		_trail.clear()
	if visible:
		queue_redraw()


func _draw() -> void:
	if _session == null or _mapper == null:
		return
	_draw_eyes()
	_draw_anchor()
	if _trail.size() >= 2:
		draw_polyline(_trail, Color(INFO_COLOR, 0.5), 1.5, true)
	for m in _marks:
		draw_circle(m["at"], 6.0, Color(m["color"], 0.8))
	_draw_panel()


## 每个眼：中线上的判定段（±HIT_RADIUS 列宽）和判定椭圆；下一针加粗，线头已在中线下方（armed）时为绿色。
func _draw_eyes() -> void:
	if _session.completed:
		return
	var row := _session.current_row - 1
	var line_y := _hook.eye_line_y()
	var left := _mapper.to_screen(Vector2(_layout.edge_x(-1) - 0.5, line_y))
	var right := _mapper.to_screen(Vector2(_layout.edge_x(1) + 0.5, line_y))
	draw_dashes(left, right, Color(StrandPainter2D.INK, 0.35))
	var armed := _hook.is_armed()
	for col in _session.width():
		var ec := _mapper.to_screen(_layout.eye_center(col, row))
		var next := col == _session.next_column()
		var color := OK_COLOR if armed else Color(0.4, 0.4, 0.4)
		if not next:
			color = Color(color, 0.45)
		var rx := HookGesture.HIT_RADIUS * _mapper.col_px
		var ry := HookGesture.HIT_RADIUS * _mapper.row_px
		_draw_ellipse(ec, Vector2(rx, ry), color, 2.5 if next else 1.2)
		draw_line(ec - Vector2(rx, 0), ec + Vector2(rx, 0), color, 4.0 if next else 2.0)
		if _hook.is_threading(col):
			draw_circle(ec, 6.0, OK_COLOR)


## 锚点与绕线范围（MIN_RADIUS、MAX_RADIUS），正在绕圈时变红。
func _draw_anchor() -> void:
	var a := _layout.anchor()
	var ap := _mapper.to_screen(a)
	var color := BAD_COLOR if _wrap.blocks_hook() else Color(INFO_COLOR, 0.6)
	draw_circle(ap, 4.0, color)
	for r: float in [WrapGesture.MIN_RADIUS, WrapGesture.MAX_RADIUS]:
		_draw_ellipse(ap, Vector2(r * _mapper.col_px, r * _mapper.row_px), Color(color, 0.5), 1.0)


func _draw_panel() -> void:
	var font := ThemeDB.fallback_font
	var lines: Array[String] = [
		"F3 调试  armed=%s  active_col=%d  下一针=%d  线=%s" % [_hook.is_armed(), _hook.active_col, _session.next_column(), "前" if _session.yarn.is_front() else "后"],
		"绕线 turn=%d°  连续 spin=%d°  角速度=%d°/s" % [roundi(rad_to_deg(_wrap.turn)), roundi(rad_to_deg(_wrap.spin)), _rate_deg()],
		"守卫：绕圈中=%s  冷却中=%s  挡钩针=%s" % [_wrap.is_spinning(), _wrap.in_cooldown(), _wrap.blocks_hook()],
	]
	lines.append_array(_events)
	var pos := get_viewport_rect().position + Vector2(16, 60)
	var box := Rect2(pos - Vector2(8, 18), Vector2(470, 20.0 * lines.size() + 12))
	draw_rect(box, Color(1, 1, 1, 0.85))
	for i in lines.size():
		draw_string(font, pos + Vector2(0, 20.0 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))


func _draw_ellipse(c: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for k in 41:
		var t := TAU * k / 40.0
		pts.append(c + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	draw_polyline(pts, color, width, true)


func draw_dashes(from: Vector2, to: Vector2, color: Color) -> void:
	var n := int(from.distance_to(to) / 10.0)
	for k in range(0, n, 2):
		draw_line(from.lerp(to, float(k) / n), from.lerp(to, float(k + 1) / n), color, 1.0)
