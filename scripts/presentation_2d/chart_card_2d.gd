class_name ChartCard2D
extends Node2D
## 右上角的图纸卡：按 StitchType.chart_symbol() 画符号（V = 下针，— = 上针）。
## 当前行高亮，下一针圈出；鼠标或线头靠近时变淡。

const CELL := 20.0
const MARGIN := 20.0

var _session: KnitSession
var _yarn: YarnHandle


func setup(session: KnitSession, yarn: YarnHandle) -> void:
	_session = session
	_yarn = yarn


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _session == null:
		return
	var cols := _session.width()
	var n_rows := _session.last_row() + 1
	var card_size := Vector2(cols * CELL + 44, n_rows * CELL + 32)
	var view := get_viewport_rect()
	var rect := Rect2(Vector2(view.end.x - MARGIN - card_size.x, view.position.y + MARGIN), card_size)
	var dist := _rect_dist(rect, get_local_mouse_position())
	if _yarn.held:
		dist = minf(dist, _rect_dist(rect, _yarn.tip))
	var a := clampf((dist - 10.0) / 110.0, 0.2, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("fffdf7"), 0.94 * a)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(Color("e4ddcc"), a)
	sb.shadow_color = Color(0.2, 0.15, 0.05, 0.08 * a)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, rect)
	var gx := rect.position.x + 22.0
	var gy := rect.end.y - 16.0
	var cur_col := _session.next_column()
	var cur_row := _session.current_row
	var accent := StrandPainter2D.YARN
	for r in n_rows:
		var cy := gy - (r + 0.5) * CELL
		var is_current := r == cur_row and not _session.completed
		if is_current:
			draw_rect(Rect2(gx - 5, cy - CELL * 0.5, cols * CELL + 10, CELL), Color(accent, 0.14 * a))
			var ad := float(KnitSession.row_direction(r))
			var ax := gx - 12.0 if ad > 0 else gx + cols * CELL + 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(ax + ad * 4, cy), Vector2(ax - ad * 3, cy - 4), Vector2(ax - ad * 3, cy + 4)]), Color(accent, 0.8 * a))
		for i in cols:
			var center := Vector2(gx + (i + 0.5) * CELL, cy)
			var color: Color
			if r == 0:
				color = StrandPainter2D.BASE_YARN
			elif _session.fabric.has_stitch(r, i):
				color = accent
			elif is_current:
				color = StrandPainter2D.INK
			else:
				color = Color(StrandPainter2D.INK, 0.3)
			color.a *= a
			_draw_symbol(_session.expected_stitch(r, i).chart_symbol(), center, color)
			if is_current and i == cur_col:
				draw_arc(center, 8.5, 0, TAU, 24, Color(accent, 0.85 * a), 1.4, true)


func _draw_symbol(symbol: String, c: Vector2, color: Color) -> void:
	match symbol:
		"V":
			draw_polyline(PackedVector2Array([c + Vector2(-4.5, -4.5), c + Vector2(0, 4.5), c + Vector2(4.5, -4.5)]), color, 2.2, true)
		"-":
			draw_line(c + Vector2(-5.5, 0), c + Vector2(5.5, 0), color, 2.6, true)
		_:
			draw_circle(c, 3.0, color)


func _rect_dist(rect: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(q)
