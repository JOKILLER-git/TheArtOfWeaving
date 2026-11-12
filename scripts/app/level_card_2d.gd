class_name LevelCard2D
extends Node2D
## 晾衣绳上的一张关卡卡片（T008）：一张小纸片，用小木夹夹在绳上；里面是该关的缩略图（LevelThumb2D）。
## 节点原点 = 夹子夹在绳上的那一点，卡片挂在下方。当前关轻轻发光；鼠标悬停时轻轻摆动。

const CLIP_DROP := 8.0          # 卡片上沿在夹点下方多少像素
const INSET := Vector2(12, 12)  # 缩略图离卡片边缘的距离
const SWAY := 0.07              # 悬停摆动幅度（弧度）
const WOOD := Color("caa77a")
const WOOD_DARK := Color("8c6c47")

var index: int = -1
var is_current: bool = false
var hovered: bool = false
var size := Vector2(150, 150)
var _swing: float = 0.0
var _time: float = 0.0
var _thumb: LevelThumb2D


func setup(p_index: int, level: LevelDefinition, best_stars: int, p_is_current: bool, p_size: Vector2) -> void:
	index = p_index
	is_current = p_is_current
	size = p_size
	_time = 0.37 * p_index      # 每张卡片的轻微晃动错开
	if _thumb == null:
		_thumb = LevelThumb2D.new()
		add_child(_thumb)
	_thumb.position = card_rect().get_center()
	_thumb.setup(level, best_stars, size - INSET * 2.0)
	queue_redraw()


## 卡片在本地坐标里的矩形（夹点下方）。
func card_rect() -> Rect2:
	return Rect2(Vector2(-size.x * 0.5, CLIP_DROP), size)


## 画布坐标 p 是否落在卡片上（考虑摆动的旋转）。
func contains(p: Vector2) -> bool:
	return card_rect().grow(4.0).has_point(get_global_transform().affine_inverse() * p)


func set_hovered(value: bool) -> void:
	if value and not hovered:
		_swing = 1.0
	hovered = value


func _process(delta: float) -> void:
	_time += delta
	var want := 0.6 if hovered else 0.0
	_swing = move_toward(_swing, want, delta * 0.8)
	rotation = SWAY * _swing * sin(_time * 5.0) + 0.008 * sin(_time * 1.3)
	queue_redraw()


func _draw() -> void:
	var rect := card_rect()
	if is_current:
		var pulse := 0.5 + 0.5 * sin(_time * 2.6)
		for k in 4:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(1.0, 0.88, 0.62, (0.2 - 0.045 * k) * (0.6 + 0.4 * pulse))
			glow.set_corner_radius_all(14 + 5 * k)
			draw_style_box(glow, rect.grow(5.0 + 6.0 * k + 2.0 * pulse))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf7") if not hovered else Color("fffef9")
	sb.set_corner_radius_all(8)
	sb.border_color = Color(StrandPainter2D.YARN, 0.75) if is_current else Color("e4ddcc")
	sb.set_border_width_all(2 if is_current else 1)
	sb.shadow_color = Color(0.2, 0.15, 0.05, 0.16 if hovered else 0.1)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, rect)
	_draw_peg()


## 小木夹：两片木条夹住绳子和卡片上沿，中间一圈小弹簧。
func _draw_peg() -> void:
	var w := 11.0
	var top := -12.0
	var bottom := CLIP_DROP + 20.0
	var body := Rect2(Vector2(-w * 0.5, top), Vector2(w, bottom - top))
	draw_rect(Rect2(body.position + Vector2(1.5, 2.0), body.size), Color(StrandPainter2D.SHADOW, 0.15))
	draw_rect(body, WOOD)
	draw_line(Vector2(0, top + 1.0), Vector2(0, bottom - 1.0), WOOD_DARK.lightened(0.2), 1.0, true)
	draw_rect(body, WOOD_DARK, false, 1.2, true)
	var spring_y := CLIP_DROP + 4.0
	draw_line(Vector2(-w * 0.5 - 1.5, spring_y), Vector2(w * 0.5 + 1.5, spring_y), Color("8d8a82"), 2.4, true)
	draw_line(Vector2(-w * 0.5 + 1.0, top + 3.0), Vector2(-w * 0.5 + 1.0, bottom - 3.0), Color(1, 1, 1, 0.35), 1.0, true)
