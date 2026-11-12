class_name Scissors2D
extends Node2D
## 左下角的剪刀（代码绘制）：可以拖起来，松手时报告位置，由关卡决定是否剪到了线或织物。
## 剪刀与线头的抓取互不干扰：剪刀节点排在 PointerInput 之后，先收到鼠标事件，抓住时把事件标为已处理。
## wiggle 为 true 时（需要剪断）轻轻晃动，nudge() 时用力晃一下。

## 剪刀在 at（像素）松手。
signal dropped(at: Vector2)

const HOME_INSET := Vector2(84, 72)  # 停放位置：离可视区域左边、下边的距离（像素）
const GRAB_RADIUS := 52.0
const SIZE := 1.0  # 整体缩放
const STEEL := Color("b9b4a8")

var held: bool = false
var wiggle: bool = false
var pos := Vector2(HOME_INSET.x, 800.0 - HOME_INSET.y)
var _open: float = 0.35         # 张开程度 0..1
var _nudge: float = 0.0
var _time: float = 0.0
var _tween: Tween


func reset_home() -> void:
	held = false
	pos = home()
	_open = 0.35


## 停放位置：贴可视区域左下角（随窗口比例变化）。
func home() -> Vector2:
	var view := get_viewport_rect()
	return Vector2(view.position.x + HOME_INSET.x, view.end.y - HOME_INSET.y)


func can_grab(p: Vector2) -> bool:
	return p.distance_to(pos) <= GRAB_RADIUS


## 剪断动作：合拢一下再张开。
func snip() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_open", 0.0, 0.08)
	_tween.tween_property(self, "_open", 0.6, 0.12)
	_tween.tween_property(self, "_open", 0.0, 0.08)
	_tween.tween_property(self, "_open", 0.35, 0.3)


## 提醒：用力晃一下。
func nudge() -> void:
	create_tween().tween_method(func(v: float) -> void: _nudge = v, 1.0, 0.0, 0.7)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouse) or not is_visible_in_tree():
		return
	var local := make_input_local(event)
	var button := local as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and can_grab(button.position):
			held = true
			pos = button.position
			get_viewport().set_input_as_handled()
		elif not button.pressed and held:
			held = false
			get_viewport().set_input_as_handled()
			dropped.emit(button.position)
		return
	var motion := local as InputEventMouseMotion
	if motion != null and held:
		pos = motion.position
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held = false


func _process(delta: float) -> void:
	_time += delta
	if not held:
		pos = pos.lerp(home(), 1.0 - exp(-8.0 * delta))
	var want := 0.75 if held else 0.35
	if _tween == null or not _tween.is_running():
		_open = move_toward(_open, want + (0.08 * sin(_time * 9.0) if held else 0.0), delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var tilt := -0.62     # 刃尖朝右上
	if wiggle and not held:
		tilt += 0.12 * sin(_time * 6.0)
	tilt += 0.35 * _nudge * sin(_time * 28.0)
	var lift := 1.08 if held else 1.0
	draw_set_transform(pos, tilt, Vector2.ONE * SIZE * lift)
	# 阴影
	if held:
		draw_set_transform(pos + Vector2(6, 9), tilt, Vector2.ONE * SIZE * lift)
		_draw_shape(true)
		draw_set_transform(pos, tilt, Vector2.ONE * SIZE * lift)
	_draw_shape(false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 剪刀局部坐标：枢轴在原点，刃朝 +x，握环在 -x。两半绕枢轴各转 ±open。
func _draw_shape(shadow: bool) -> void:
	var a := 0.22 * _open
	for s: float in [-1.0, 1.0]:
		var rot := Transform2D(a * s, Vector2.ZERO)
		var blade := PackedVector2Array([
			Vector2(-4, -3 * s), Vector2(18, -6 * s), Vector2(42, -4 * s), Vector2(58, 0), Vector2(40, 3 * s), Vector2(6, 4 * s),
		])
		var handle_c := Vector2(-30, 13 * s)
		var shank := PackedVector2Array([Vector2(-2, 2 * s), Vector2(-14, 7 * s), Vector2(-20, 10 * s)])
		blade = rot * blade
		shank = rot * shank
		handle_c = rot * handle_c
		if shadow:
			draw_colored_polygon(blade, Color(StrandPainter2D.SHADOW, 0.12))
			draw_arc(handle_c, 12.0, 0, TAU, 32, Color(StrandPainter2D.SHADOW, 0.12), 7.0, true)
			continue
		# 刃：浅钢色，墨色描边，一条高光
		draw_colored_polygon(blade, STEEL)
		var outline := blade.duplicate()
		outline.append(blade[0])
		draw_polyline(outline, StrandPainter2D.INK, 1.6, true)
		draw_line(rot * Vector2(14, -2.5 * s), rot * Vector2(44, -1.5 * s), Color(1, 1, 1, 0.55), 1.4, true)
		# 柄与握环：用线的画法（描边 + 填充 + 高光），像缠了线
		var yarn := StrandPainter2D.YARN
		draw_polyline(shank, yarn.darkened(0.22), 7.6, true)
		draw_polyline(shank, yarn, 6.0, true)
		draw_arc(handle_c, 12.0, 0, TAU, 40, yarn.darkened(0.22), 7.6, true)
		draw_arc(handle_c, 12.0, 0, TAU, 40, yarn, 6.0, true)
		draw_arc(handle_c, 11.0, PI * 1.05, PI * 1.6, 12, yarn.lightened(0.28), 1.6, true)
	if not shadow:
		draw_circle(Vector2.ZERO, 3.2, StrandPainter2D.INK)
		draw_circle(Vector2(-0.8, -0.8), 1.2, Color(1, 1, 1, 0.6))
