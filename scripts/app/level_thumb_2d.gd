class_name LevelThumb2D
extends Node2D
## 一关的小缩略图（T008，选关卡片和结束界面织片墙共用）：
## 完成过 → 织好的织片（TitleSwatch2D）+ 下方 1–3 颗星（线色实心，没得到的为铅笔虚线）；
## 没完成 → 图纸的浅色铅笔草图（空的线圈轮廓，几何来自 FabricLayout，与关卡里一致）。
## 节点原点为缩略图中心；size 为可用区域。静态画面，只在 setup 时画。

const STAR_ROW_H := 22.0    # 星的一行高度（像素）
const STAR_R := 8.0
const STAR_GAP := 20.0
const PENCIL := Color(StrandPainter2D.INK, 0.42)
const SWATCH_FILL := Vector2(0.86, 0.94)   # 织片比可用区域略小：起始行的线尾会伸出织物右下角

var best_stars: int = 0
var size := Vector2(140, 110)
var _chart: PatternChart
var _sketch: Array[PackedVector2Array] = []
var _sketch_base_rows: int = 0     # _sketch 前多少条属于起始行（画得更淡）
var _swatch: TitleSwatch2D


func setup(level: LevelDefinition, p_best_stars: int, p_size: Vector2) -> void:
	_chart = level.chart
	best_stars = p_best_stars
	size = p_size
	if _swatch != null:
		_swatch.queue_free()
		_swatch = null
	_sketch.clear()
	if is_completed():
		_swatch = TitleSwatch2D.new()
		_swatch.chart_rows = _chart.rows
		_swatch.area_size = _art_rect().size * SWATCH_FILL
		_swatch.position = _art_rect().get_center()
		add_child(_swatch)
	else:
		_build_sketch()
	queue_redraw()


func is_completed() -> bool:
	return best_stars > 0


## 织片 / 草图所占区域（完成时下方留出星的一行）。
func _art_rect() -> Rect2:
	var h := size.y - (STAR_ROW_H if is_completed() else 0.0)
	return Rect2(-size * 0.5, Vector2(size.x, h))


## 草图：用规则层的图纸建一个空会话，取每个线圈的关键点（不织，只要几何）。
func _build_sketch() -> void:
	var session := KnitSession.new(_chart, StitchRegistry.create_default())
	var layout := FabricLayout.new(session, ScreenMapper2D.LOOP_WIDTH)
	var mapper := ScreenMapper2D.new()
	mapper.fit_in(layout, _art_rect())
	for r in layout.rows():
		for col in layout.columns():
			_sketch.append(Strand2D.catmull(mapper.to_screen_all(layout.loop_keys(col, r)), 6))
		if r == 0:
			_sketch_base_rows = _sketch.size()


func _draw() -> void:
	if is_completed():
		_draw_stars()
		return
	for k in _sketch.size():
		var c := Color(PENCIL, PENCIL.a * (0.55 if k < _sketch_base_rows else 1.0))
		draw_polyline(_sketch[k], c, 1.3, true)


func _draw_stars() -> void:
	var y := size.y * 0.5 - STAR_ROW_H * 0.5 + 1.0
	for i in StarRating.MAX_STARS:
		var c := Vector2((i - 1) * STAR_GAP, y)
		var outline := StarRatingView2D.star_outline(c, STAR_R)
		if i < best_stars:
			draw_colored_polygon(outline.slice(0, outline.size() - 1), StrandPainter2D.YARN)
			draw_polyline(outline, StrandPainter2D.YARN.darkened(0.25), 1.2, true)
		else:
			for k in outline.size() - 1:
				draw_dashed_line(outline[k], outline[k + 1], PENCIL, 1.0, 3.0, true, true)
