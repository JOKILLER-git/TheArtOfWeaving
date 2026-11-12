class_name WeaveSurface
extends Node2D
## 提经按钮只作用于下一梭，已织行不可点击修改。
signal selection_changed
signal pick_finished(pattern: String)
@export var warp_color := Color("b3b39b")
@export var weft_color := Color("bd8067")
@export var insertion_seconds := 0.85
@export var beat_seconds := 0.35
@export var selector_theme: Theme = preload("res://resources/ui/weave_theme.tres")
var selected: Array[bool] = []
var woven_rows: Array[String] = []
var busy := false
var locked := false
var _xs: Array[float] = []
var _lift: Array[float] = []
var _buttons: Array[Button] = []
var _selection_tweens: Array[Tween] = []
var _pick_tween: Tween
var _progress := 0.0
var _beat := 0.0
var _pending := ""
@onready var loom: LoomView = get_parent()

func _ready() -> void:
	for warp in loom.get_node("Warps").get_children():
		if warp is WarpStrand:
			_xs.append(loom.to_local(warp.global_position).x)
	_xs.sort()
	for i in _xs.size():
		selected.append(false)
		_lift.append(0.0)
		_selection_tweens.append(null)
		var button := Button.new()
		button.theme = selector_theme
		button.position = Vector2(_xs[i] - 23, -35)
		button.size = Vector2(46, 42)
		button.toggle_mode = true
		button.text = str(i + 1) + " ↓"
		button.tooltip_text = "抬起 / 放下第 %d 根经线（仅影响下一梭）" % (i + 1)
		button.toggled.connect(_select.bind(i))
		add_child(button)
		_buttons.append(button)
	queue_redraw()

func warp_count() -> int:
	return _xs.size()

func is_layout_valid(row_count: int) -> bool:
	var top: float = loom.get_node("TopRail").position.y
	var bottom: float = loom.get_node("BottomRail").position.y
	if loom.start_point.y <= top + 40 or _row_y(row_count - 1) >= bottom - 12:
		return false
	for i in _xs.size():
		if _xs[i] <= loom.start_point.x or _xs[i] >= loom.finish_x:
			return false
		if i > 0 and _xs[i] - _xs[i - 1] < 24:
			return false
	return true

func selection_pattern() -> String:
	var pattern := ""
	for value in selected:
		pattern += "1" if value else "0"
	return pattern

func _select(value: bool, index: int) -> void:
	if busy or locked:
		_buttons[index].set_pressed_no_signal(selected[index])
		return
	selected[index] = value
	_buttons[index].text = str(index + 1) + (" ↑" if value else " ↓")
	if _selection_tweens[index] != null:
		_selection_tweens[index].kill()
	_selection_tweens[index] = create_tween()
	_selection_tweens[index].tween_method(_animate_lift.bind(index), _lift[index], 1.0 if value else 0.0, 0.18)
	selection_changed.emit()

func _animate_lift(value: float, index: int) -> void:
	_lift[index] = value
	queue_redraw()

func set_locked(value: bool) -> void:
	locked = value
	for button in _buttons:
		button.disabled = busy or locked

func reset() -> void:
	if _pick_tween != null:
		_pick_tween.kill()
	busy = false
	woven_rows.clear()
	_pending = ""
	for i in selected.size():
		if _selection_tweens[i] != null:
			_selection_tweens[i].kill()
		selected[i] = false
		_lift[i] = 0.0
		_buttons[i].set_pressed_no_signal(false)
		_buttons[i].text = str(i + 1) + " ↓"
	set_locked(false)
	queue_redraw()

func insert_pick() -> void:
	if busy or locked:
		return
	busy = true
	_pending = selection_pattern()
	for i in selected.size():
		if _selection_tweens[i] != null:
			_selection_tweens[i].kill()
		_lift[i] = 1.0 if selected[i] else 0.0
	_progress = 0.0
	_beat = 0.0
	set_locked(locked)
	_pick_tween = create_tween()
	_pick_tween.tween_method(_animate_insertion, 0.0, 1.0, insertion_seconds)
	_pick_tween.tween_method(_animate_beat, 0.0, 1.0, beat_seconds)
	_pick_tween.tween_callback(_finish_pick)

func _animate_insertion(value: float) -> void:
	_progress = value
	queue_redraw()

func _animate_beat(value: float) -> void:
	_beat = value
	queue_redraw()

func _finish_pick() -> void:
	woven_rows.append(_pending)
	busy = false
	set_locked(locked)
	queue_redraw()
	pick_finished.emit(_pending)

func undo_row() -> void:
	if busy or woven_rows.is_empty():
		return
	var pattern: String = woven_rows.pop_back()
	set_locked(false)
	for i in selected.size():
		_buttons[i].set_pressed_no_signal(pattern[i] == "1")
		_select(pattern[i] == "1", i)
	queue_redraw()

func _row_y(index: int) -> float:
	return loom.start_point.y + 37.0 + index * 16.0

func _warp_path(index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var top: float = loom.get_node("TopRail").position.y
	var end: float = loom.start_point.y + 26.0
	for step in 25:
		var t := step / 24.0
		# 两端固定，中段弯曲；阴影留在原位形成高度差。
		points.append(Vector2(_xs[index] - sin(t * PI) * 13.0 * _lift[index], lerpf(top, end, t)))
	return points

func _yarn(points: PackedVector2Array, color: Color, width: float = 7.0) -> void:
	draw_polyline(points, color.darkened(0.18), width + 2.0, true)
	draw_polyline(points, color, width, true)
	draw_polyline(points, color.lightened(0.25), 2.0, true)

func _draw() -> void:
	if not is_node_ready():
		return
	var top: float = loom.get_node("TopRail").position.y
	var bottom: float = loom.get_node("BottomRail").position.y
	var left := loom.start_point.x
	var right := loom.finish_x
	var shed_y := loom.start_point.y
	# 放下的经线在纬线和梭子下方。
	for i in _xs.size():
		var x := _xs[i]
		if _lift[i] < 0.01:
			_yarn(PackedVector2Array([Vector2(x, top), Vector2(x, bottom)]), warp_color)
		else:
			draw_line(Vector2(x + 3, top), Vector2(x + 3, shed_y + 26), Color(0.2, 0.2, 0.15, 0.16), 10, true)
			_yarn(PackedVector2Array([Vector2(x, shed_y + 26), Vector2(x, bottom)]), warp_color)
	for r in woven_rows.size():
		_draw_row(woven_rows[r], _row_y(r), left, right)
	if busy:
		var tip_x := lerpf(left, right, _progress)
		var y := lerpf(shed_y, _row_y(woven_rows.size()), _beat)
		_draw_row(_pending, y, left, tip_x, _beat > 0.0)
		if _beat == 0.0:
			var shuttle := PackedVector2Array([Vector2(tip_x - 26, y), Vector2(tip_x - 10, y - 10), Vector2(tip_x + 26, y), Vector2(tip_x - 10, y + 10)])
			draw_colored_polygon(shuttle, Color("87654e"))
			draw_line(Vector2(tip_x - 12, y), Vector2(tip_x + 9, y), weft_color.lightened(0.3), 4, true)
	else:
		draw_dashed_line(Vector2(left, shed_y), Vector2(right, shed_y), Color(0.5, 0.5, 0.4, 0.25), 1.0, 6.0)
	# 抬起经线最后绘制，同时遮住新纬线及移动中的梭子。
	for i in _xs.size():
		if _lift[i] >= 0.01:
			_yarn(_warp_path(i), warp_color.lightened(0.18 * _lift[i]))
	if busy and _beat > 0.0:
		var reed_y := lerpf(shed_y + 10, _row_y(woven_rows.size()) + 8, _beat)
		draw_line(Vector2(left - 12, reed_y), Vector2(right + 12, reed_y), Color(0.48, 0.43, 0.34, 0.65), 4, true)

func _draw_row(pattern: String, y: float, left: float, right: float, crossings: bool = true) -> void:
	_yarn(PackedVector2Array([Vector2(left, y), Vector2(maxf(left + 0.01, right), y)]), weft_color, 8)
	if crossings:
		for i in _xs.size():
			if pattern[i] == "1" and _xs[i] <= right:
				_yarn(PackedVector2Array([Vector2(_xs[i], y - 6), Vector2(_xs[i], y + 6)]), warp_color)
