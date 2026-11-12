class_name SwatchWall2D
extends Node2D
## 结束界面的奖励画面：每一关一块小缩略图（LevelThumb2D），排成一面织片墙。
## T008：与选关晾衣绳用同一份 PlayerProgress：完成过的关显示织片和最好星数，没完成的显示铅笔草图。

const CELL := Vector2(176, 122)
const GAP := 14.0
const PER_ROW := 6

var _cells: Array[Rect2] = []


func build(catalog: LevelCatalog, progress: PlayerProgress) -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	var n := catalog.count()
	var rows := ceili(float(n) / PER_ROW)
	for i in n:
		var row := floori(float(i) / PER_ROW)
		var in_row := mini(PER_ROW, n - row * PER_ROW)
		var col := i % PER_ROW
		var row_w := in_row * CELL.x + (in_row - 1) * GAP
		var x := -row_w * 0.5 + col * (CELL.x + GAP)
		var y := -(rows * CELL.y + (rows - 1) * GAP) * 0.5 + row * (CELL.y + GAP)
		var rect := Rect2(Vector2(x, y), CELL)
		_cells.append(rect)
		var level := catalog.get_level(i)
		var thumb := LevelThumb2D.new()
		thumb.position = rect.get_center()
		add_child(thumb)
		thumb.setup(level, progress.best_stars(level.id), CELL - Vector2(30, 18))
	queue_redraw()


func _draw() -> void:
	for rect in _cells:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fffdf7")
		sb.set_corner_radius_all(10)
		sb.border_color = Color("e4ddcc")
		sb.set_border_width_all(1)
		sb.shadow_color = Color(0.2, 0.15, 0.05, 0.07)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 2)
		draw_style_box(sb, rect)
