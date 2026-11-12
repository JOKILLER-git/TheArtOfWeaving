class_name StarRatingView2D
extends Node2D
## 星级结算画面：画面中央依次出现 3 个五角星位置；获得的星用线的颜色「织」出来（沿轮廓描边），
## 未获得的是浅色铅笔虚线。播完停留片刻后发出 finished。没有文字和按钮。

signal finished

const CENTER_UP := 8.0     # 星条中心比可视区域中心略高（像素）
const SPACING := 150.0
const OUTER_R := 50.0
const INNER_R := 21.0
const DELAY := 0.5          # 织物收紧之后再出现
const STAR_TIME := 0.42     # 每颗星织出来的时间
const STAGGER := 0.32
const HOLD := 0.75          # 全部织完后停留

var earned: int = 0
var _veil: float = 0.0
var _slots: float = 0.0
var _progress: Array[float] = [0.0, 0.0, 0.0]
var _tween: Tween
var _sound: SoundBank


func setup(sound: SoundBank) -> void:
	_sound = sound


## 播放 stars 颗星的结算动画（1..3）。
func play(stars: int) -> void:
	stop()
	earned = clampi(stars, 0, StarRating.MAX_STARS)
	show()
	_tween = create_tween()
	_tween.tween_interval(DELAY)
	_tween.tween_method(_set_veil, 0.0, 1.0, 0.25)
	_tween.parallel().tween_method(_set_slots, 0.0, 1.0, 0.35)
	for i in earned:
		if _sound != null:
			_tween.tween_callback(_sound.play_star.bind(i))
		_tween.tween_method(_set_progress.bind(i), 0.0, 1.0, STAR_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if i < earned - 1:
			_tween.tween_interval(STAGGER - STAR_TIME * 0.5)
	_tween.tween_interval(HOLD)
	_tween.tween_callback(finished.emit)


func stop() -> void:
	if _tween:
		_tween.kill()
	_tween = null
	_veil = 0.0
	_slots = 0.0
	_progress = [0.0, 0.0, 0.0]
	hide()
	queue_redraw()


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


func _set_veil(v: float) -> void:
	_veil = v
	queue_redraw()


func _set_slots(v: float) -> void:
	_slots = v
	queue_redraw()


func _set_progress(v: float, i: int) -> void:
	_progress[i] = v
	queue_redraw()


func _draw() -> void:
	if _veil <= 0.0:
		return
	# 一块柔和的纸色底，让星在织物上清楚可见。
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("fbf7ee"), 0.88 * _veil)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0.2, 0.15, 0.05, 0.08 * _veil)
	sb.shadow_size = 14
	var half := Vector2(SPACING + OUTER_R + 44.0, OUTER_R + 36.0)
	var center := get_viewport_rect().get_center() - Vector2(0, CENTER_UP)
	draw_style_box(sb, Rect2(center - half, half * 2.0))
	for i in StarRating.MAX_STARS:
		var c := center + Vector2((i - 1) * SPACING, 0)
		var outline := star_outline(c, OUTER_R * lerpf(0.85, 1.0, _slots))
		_draw_dashed(outline, Color(StrandPainter2D.INK, 0.32 * _slots))
		if i < earned and _progress[i] > 0.0:
			_draw_yarn_part(outline, _progress[i])


## 五角星轮廓（10 个顶点，闭合），顶点朝上，从顶点出发。选关卡片、织片墙的小星也用它（T008）。
static func star_outline(c: Vector2, r_out: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r_in := r_out * INNER_R / OUTER_R
	for k in 11:
		var a := -PI * 0.5 + PI * k / 5.0
		var r := r_out if k % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_dashed(pts: PackedVector2Array, color: Color) -> void:
	for k in pts.size() - 1:
		draw_dashed_line(pts[k], pts[k + 1], color, 2.0, 6.0, true, true)


## 沿轮廓画出前 t（0..1）长度的一根线，画法与织物的线相同。
func _draw_yarn_part(pts: PackedVector2Array, t: float) -> void:
	var total := 0.0
	for k in pts.size() - 1:
		total += pts[k].distance_to(pts[k + 1])
	var want := total * t
	var part := PackedVector2Array([pts[0]])
	var acc := 0.0
	for k in pts.size() - 1:
		var d := pts[k].distance_to(pts[k + 1])
		if acc + d >= want:
			part.append(pts[k].move_toward(pts[k + 1], want - acc))
			break
		part.append(pts[k + 1])
		acc += d
	if part.size() < 2:
		return
	var st := Strand2D.new(Strand2D.Kind.ROPE, -1, StrandPainter2D.YARN, 9.0)
	st.points = part
	st.tones.resize(part.size())
	st.tones.fill(0.1)
	var layer: Array[Strand2D] = [st]
	StrandPainter2D.draw_layer(self, layer)
	if t >= 1.0:
		# 织完：中间轻轻填上一层线色。
		draw_colored_polygon(pts.slice(0, pts.size() - 1), Color(StrandPainter2D.YARN, 0.22))
