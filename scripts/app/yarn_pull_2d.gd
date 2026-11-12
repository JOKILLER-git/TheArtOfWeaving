class_name YarnPull2D
extends Node2D
## 「拉线开始」的物件：一段线从画面左边伸进来，线头可以拖；拉到右边的小线轴（轻轻发光）附近，
## 线被拉直、发出声音，然后发出 pulled。开始界面和结束界面（重新开始）共用。
## T008：线可以被剪断（cut()，开始界面用剪刀剪断 = 退出游戏）：剪断后线不再画、也不能拉；reset() 恢复。

signal pulled

const GRAB_RADIUS := 46.0
const SNAP_RADIUS := 64.0       # 线头进入目标这个范围内就算拉到
const SAG := 0.1               # 线的下垂量（相对起点到线头的距离），拉到目标后拉直
const WIDTH := 10.0
const POINTS := 28
const CUT_HIT_PX := 24.0        # 剪刀离线多近算剪到（像素）

## 以下三个位置按 1280×800 的设计画布填写；fit_to() 按可视区域换算：
## 左半边的点贴左边、右半边的点贴右边，纵向贴底边（T007）。
@export var origin := Vector2(-30, 640)     # 线从画布左边外伸进来
@export var rest_tip := Vector2(190, 676)
@export var target := Vector2(1130, 640)

var tip := Vector2.ZERO
var held: bool = false
var done: bool = false
var is_cut: bool = false
var _straight: float = 0.0      # 1 = 完全拉直
var _time: float = 0.0
var _sound: SoundBank
var _design: Array[Vector2] = []    # fit_to 之前的设计位置


func _ready() -> void:
	_sound = SoundBank.new()
	add_child(_sound)
	reset()


## 按可视区域 view（画布坐标）重新摆放线的起点、线头静止位置和线轴。
func fit_to(view: Rect2) -> void:
	if _design.is_empty():
		_design = [origin, rest_tip, target]
	origin = _place(_design[0], view)
	rest_tip = _place(_design[1], view)
	target = _place(_design[2], view)
	if not held and not done:
		tip = rest_tip


func _place(p: Vector2, view: Rect2) -> Vector2:
	var base := ScreenMapper2D.CANVAS
	var x := view.position.x + p.x if p.x < base.x * 0.5 else view.end.x - (base.x - p.x)
	return Vector2(x, view.end.y - (base.y - p.y))


func reset() -> void:
	held = false
	done = false
	is_cut = false
	_straight = 0.0
	tip = rest_tip


func can_grab(p: Vector2) -> bool:
	return not done and not is_cut and p.distance_to(tip) <= GRAB_RADIUS


## 抓住线头（p 在线头附近时返回 true）。
func grab_at(p: Vector2) -> bool:
	held = can_grab(p)
	return held


## 拖动线头到 p；进入目标范围即完成。
func drag_to(p: Vector2) -> void:
	if not held or done:
		return
	tip = p
	if p.distance_to(target) <= SNAP_RADIUS:
		_finish()


func release() -> void:
	held = false


## p 是否落在线上（线头到起点之间）。已剪断或已拉到时为 false。
func hits_strand(p: Vector2, radius: float = CUT_HIT_PX) -> bool:
	if is_cut or done:
		return false
	for q in strand_points():
		if q.distance_to(p) <= radius:
			return true
	return false


## 剪断：线和线头不再画，也不能再拉。
func cut() -> void:
	held = false
	is_cut = true
	queue_redraw()


## 线的折线（像素）：起点到线头的一段下垂的线（越接近拉直下垂越小）。
func strand_points() -> PackedVector2Array:
	var chord := origin.distance_to(tip)
	var sag := clampf(SAG * chord, 14.0, 48.0) * (1.0 - _straight)
	var mid := (origin + tip) * 0.5 + Vector2(0, 2.0 * sag)
	var pts := PackedVector2Array()
	for k in POINTS + 1:
		var u := float(k) / POINTS
		pts.append(origin.lerp(mid, u).lerp(mid.lerp(tip, u), u))
	return pts


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouse) or not is_visible_in_tree():
		return
	var local := make_input_local(event)
	var button := local as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and grab_at(button.position):
			get_viewport().set_input_as_handled()
		elif not button.pressed and held:
			release()
			get_viewport().set_input_as_handled()
		return
	var motion := local as InputEventMouseMotion
	if motion != null and held:
		drag_to(motion.position)
		get_viewport().set_input_as_handled()


func _finish() -> void:
	done = true
	held = false
	_sound.play_pull()
	var tw := create_tween()
	tw.tween_property(self, "tip", target, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_straight", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_callback(pulled.emit)


func _process(delta: float) -> void:
	_time += delta
	if not held and not done and not is_cut:
		tip = tip.lerp(rest_tip, 1.0 - exp(-8.0 * delta))
	queue_redraw()


func _draw() -> void:
	_draw_target()
	if is_cut:
		return
	if not held and not done:
		_draw_guide()
	_draw_strand()
	_draw_tip()


func _draw_strand() -> void:
	var pts := strand_points()
	var st := Strand2D.new(Strand2D.Kind.ROPE, -1, StrandPainter2D.YARN, WIDTH)
	st.points = pts
	st.tones.resize(pts.size())
	st.tones.fill(0.05)
	var layer: Array[Strand2D] = [st]
	StrandPainter2D.draw_layer(self, layer)


func _draw_tip() -> void:
	var kr := 0.8 * WIDTH
	var kc := StrandPainter2D.YARN.darkened(0.15)
	if not held and not done:
		draw_arc(tip, kr * (1.8 + 0.25 * sin(_time * 3.0)), 0, TAU, 48, Color(StrandPainter2D.YARN, 0.4), 1.6, true)
	draw_circle(tip, kr, kc)
	draw_circle(tip + Vector2(-0.28, -0.28) * kr, 0.33 * kr, kc.lightened(0.4))


## 目标：一个小线轴，周围有柔和的光。
func _draw_target() -> void:
	var glow := 0.5 + 0.5 * sin(_time * 2.4)
	if done:
		glow = 1.0
	for k in 4:
		draw_circle(target, 30.0 + 9.0 * k + 4.0 * glow, Color(1.0, 0.93, 0.78, (0.16 - 0.035 * k) * (0.6 + 0.4 * glow)))
	var body := Rect2(target - Vector2(15, 22), Vector2(30, 44))
	draw_rect(body, Color("e7dcc6"))
	# 绕在线轴上的线
	for k in 7:
		var y := body.position.y + 6.0 + k * 5.2
		draw_line(Vector2(body.position.x + 1, y), Vector2(body.end.x - 1, y + 2.5), StrandPainter2D.YARN.darkened(0.05 * (k % 2)), 4.4, true)
	for s: float in [-1.0, 1.0]:
		var flange := Rect2(target + Vector2(-21, 22.0 * s - 4.0), Vector2(42, 8))
		draw_rect(flange, Color("d8c7a6"))
		draw_rect(flange, StrandPainter2D.INK, false, 1.4, true)


## 线头到目标的一串淡淡的铅笔点：告诉玩家往哪里拉。
func _draw_guide() -> void:
	var a := 0.12 + 0.08 * sin(_time * 2.0)
	var from := tip + (target - tip).normalized() * 30.0
	var to := target - (target - tip).normalized() * 50.0
	var n := int(from.distance_to(to) / 22.0)
	for k in n:
		var u := float(k) / maxf(1.0, float(n))
		draw_circle(from.lerp(to, u) + Vector2(0, -10.0 * sin(PI * u)), 2.2, Color(StrandPainter2D.INK, a))
