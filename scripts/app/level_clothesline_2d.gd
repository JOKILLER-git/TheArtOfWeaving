class_name LevelClothesline2D
extends Node2D
## 选关（T008）：顶部进度珠子串的中间垂下一小段线头（带一个小线环）。抓住线环往下拉，
## 珠子串像窗帘拉绳一样被拉下、展开成横跨屏幕的晾衣绳（两根，带下垂弧度），关卡画面变暗；
## 每一关是一张夹在绳上的卡片（LevelCard2D）。点卡片 → 发出 level_chosen 并收回。
## 关闭：把线环往上推回、点空白处或 Esc。只拉一点就松手会弹回去；在线环上单击也可以打开 / 关闭。
## openness（0 收起 … 1 展开）驱动全部画面；active_changed 告诉 GameApp 什么时候暂停关卡输入。
## 本类只管选关的画面和交互，不改进度、不切关（由 GameApp 处理）。

signal level_chosen(index: int)
## 是否挡住关卡（拉动中、展开中、已展开、收回中 = true；完全收起 = false）。
signal active_changed(active: bool)

enum State { CLOSED, DRAGGING, ANIMATING, OPEN }

const PER_LINE := 6
const EDGE := 34.0              # 绳两端离可视区域左右边的距离
const SAG := 24.0               # 绳中间下垂量
const LINE_GAP := 58.0          # 上一根绳的卡片底到下一根绳
const MAX_CARD := 150.0
const TASSEL_LEN := 30.0        # 垂下的线头长度
const TASSEL_RING := 7.0        # 线环半径
const TASSEL_GRAB := 28.0
const OPEN_AT := 0.3            # 从收起往下拉，超过这个比例松手就展开
const CLOSE_AT := 0.75          # 从展开往上推，低于这个比例松手就收回
const CLICK_PX := 5.0           # 松手时移动不到这个距离算单击
const VEIL := Color(0.2, 0.15, 0.09, 0.42)
const CORD := Color("b9b19a")

var state: State = State.CLOSED
var openness: float = 0.0
var current_index: int = 0
var _catalog: LevelCatalog
var _progress: PlayerProgress
var _beads: ProgressBeads2D
var _cards: Array[LevelCard2D] = []
var _card_size := Vector2(MAX_CARD, MAX_CARD)
var _line_y: Array[float] = []
var _grab_from: float = 0.0     # 抓住时的 openness
var _grab_pos := Vector2.ZERO
var _tween: Tween
var _laid_out_for := Vector2.ZERO
var _time: float = 0.0


## 进度珠子串（收起时线头挂在它中间）、关卡目录和玩家进度。
func setup(beads: ProgressBeads2D, catalog: LevelCatalog, progress: PlayerProgress) -> void:
	_beads = beads
	_catalog = catalog
	_progress = progress


func set_current(index: int) -> void:
	current_index = index


func is_active() -> bool:
	return state != State.CLOSED


func is_open() -> bool:
	return state == State.OPEN


func cards() -> Array[LevelCard2D]:
	return _cards


## 展开（动画）。
func open() -> void:
	if state == State.CLOSED:
		_begin()
	_animate_to(1.0)


## 收回（动画）。
func close() -> void:
	if state == State.CLOSED:
		return
	_animate_to(0.0)


## 立刻收起，不播动画（离开关卡时用）。
func force_close() -> void:
	if _tween:
		_tween.kill()
	openness = 0.0
	_set_state(State.CLOSED)


## 选中第 index 关：发出 level_chosen 并收回。点的是当前关时只收回（保留本关状态）。
func choose(index: int) -> void:
	if index != current_index:
		level_chosen.emit(index)
	close()


## 收起时线环的位置（画布坐标）。
func tassel_tip() -> Vector2:
	return _tassel_anchor() + Vector2(0, TASSEL_LEN)


# ---------------------------------------------------------------- 状态

func _begin() -> void:
	_rebuild_cards()
	_set_state(State.ANIMATING)


func _set_state(s: State) -> void:
	var was_active := is_active()
	state = s
	if is_active() != was_active:
		active_changed.emit(is_active())
	if _beads != null:
		_beads.self_modulate.a = 0.0 if is_active() else 1.0
	for card in _cards:
		card.visible = is_active()
	queue_redraw()


func _animate_to(target: float) -> void:
	if _tween:
		_tween.kill()
	_set_state(State.ANIMATING)
	_tween = create_tween()
	var dur := 0.45 * absf(target - openness) + 0.12
	_tween.tween_property(self, "openness", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_set_state.bind(State.OPEN if target >= 1.0 else State.CLOSED))


func _rebuild_cards() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	if _catalog == null:
		return
	for i in _catalog.count():
		var card := LevelCard2D.new()
		card.visible = false
		add_child(card)
		_cards.append(card)
	_laid_out_for = Vector2.ZERO
	_layout()


## 按可视区域决定卡片大小和每根绳的高度，并给卡片填内容。
func _layout() -> void:
	var view := get_viewport_rect()
	if view.size == _laid_out_for or _catalog == null:
		return
	_laid_out_for = view.size
	var n := _catalog.count()
	var lines := ceili(float(n) / PER_LINE)
	var slot := (view.size.x - 2.0 * EDGE) / PER_LINE
	var w := minf(MAX_CARD, slot - 26.0)
	var h := w
	# 纵向放不下时按高度收缩（留出上方珠子和下方剪刀的位置）。
	var room := view.size.y - 200.0
	var block := lines * (LevelCard2D.CLIP_DROP + h + SAG) + (lines - 1) * LINE_GAP
	if block > room:
		var k := (room - (lines - 1) * LINE_GAP) / (lines * (LevelCard2D.CLIP_DROP + h + SAG))
		w *= k
		h *= k
		block = room
	_card_size = Vector2(w, h)
	var y0 := view.get_center().y - block * 0.5 + 10.0
	_line_y.clear()
	for k in lines:
		_line_y.append(y0 + k * (LevelCard2D.CLIP_DROP + h + SAG + LINE_GAP))
	for i in _cards.size():
		var level := _catalog.get_level(i)
		var best := _progress.best_stars(level.id) if _progress != null else 0
		_cards[i].setup(i, level, best, i == current_index, _card_size)


# ---------------------------------------------------------------- 几何（随 openness 变化）

## 第 line 根绳在 openness e 下的两端。第 0 根从珠子串展开；后面的从第 0 根往下落。
func _line_ends(line: int, e: float) -> Array[Vector2]:
	var view := get_viewport_rect()
	var final_ends: Array[Vector2] = [Vector2(view.position.x + EDGE, _line_y[line]), Vector2(view.end.x - EDGE, _line_y[line])]
	if line == 0:
		# 纵向随 e 线性下移（线环跟着手），横向更快地展开。
		var from := _bead_span()
		var sx := _ease_out(clampf(e / 0.75, 0.0, 1.0))
		var a := Vector2(lerpf(from[0].x, final_ends[0].x, sx), lerpf(from[0].y, final_ends[0].y, e))
		var b := Vector2(lerpf(from[1].x, final_ends[1].x, sx), lerpf(from[1].y, final_ends[1].y, e))
		return [a, b]
	var top := _line_ends(0, e)
	var s2 := _drop(e)
	return [top[0].lerp(final_ends[0], s2), top[1].lerp(final_ends[1], s2)]


func _line_sag(e: float) -> float:
	return SAG * e


## 绳上 u（0..1）处的点（抛物线下垂）。
func _line_point(line: int, u: float, e: float) -> Vector2:
	var ends := _line_ends(line, e)
	return ends[0].lerp(ends[1], u) + Vector2(0, _line_sag(e) * 4.0 * u * (1.0 - u))


## 第 i 张卡片在绳上的 u：每根绳按同样的格宽居中排列（第一根 6 张，中间留出线头的位置）。
func _card_u(i: int) -> Vector2:
	var line := floori(float(i) / PER_LINE)
	var in_line := mini(PER_LINE, _cards.size() - line * PER_LINE)
	var j := i - line * PER_LINE
	var u := 0.5 + (float(j) - (in_line - 1) * 0.5) / PER_LINE
	return Vector2(u, line)


func _drop(e: float) -> float:
	return smoothstep(0.4, 1.0, e)


func _bead_span() -> Array[Vector2]:
	if _beads != null and _beads.count > 0:
		return _beads.string_span()
	var c := get_viewport_rect().get_center()
	return [Vector2(c.x - 40, 30), Vector2(c.x + 40, 30)]


func _tassel_anchor() -> Vector2:
	if openness <= 0.0 or _line_y.is_empty():
		var span := _bead_span()
		return (span[0] + span[1]) * 0.5 + Vector2(0, ProgressBeads2D.R)
	return _line_point(0, 0.5, openness) + Vector2(0, lerpf(ProgressBeads2D.R, 2.0, openness))


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventMouse):
		return
	var local := make_input_local(event)
	var button := local as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(button.position)
		elif state == State.DRAGGING:
			_release(button.position)
			get_viewport().set_input_as_handled()
		return
	var motion := local as InputEventMouseMotion
	if motion == null:
		return
	if state == State.DRAGGING:
		_drag(motion.position)
		get_viewport().set_input_as_handled()
	elif is_active():
		_update_hover(motion.position)
		get_viewport().set_input_as_handled()


func _press(p: Vector2) -> void:
	var on_tassel := p.distance_to(tassel_tip()) <= TASSEL_GRAB
	if state == State.CLOSED:
		if not on_tassel:
			return
		_rebuild_cards()
		_start_drag(p)
	elif state == State.OPEN and on_tassel:
		_start_drag(p)
	elif state == State.OPEN:
		var card := card_at(p)
		if card != null:
			choose(card.index)
		else:
			close()
	get_viewport().set_input_as_handled()


func _start_drag(p: Vector2) -> void:
	if _tween:
		_tween.kill()
	_grab_from = openness
	_grab_pos = p
	_set_state(State.DRAGGING)


func _drag(p: Vector2) -> void:
	openness = clampf(_grab_from + (p.y - _grab_pos.y) / pull_distance(), 0.0, 1.0)


## 线环从收起到完全展开移动的距离（像素）：拉线时线环跟着鼠标。
func pull_distance() -> float:
	if _line_y.is_empty():
		return 200.0
	var closed_tip := (_bead_span()[0].y) + ProgressBeads2D.R + TASSEL_LEN
	var open_tip := _line_y[0] + SAG + 2.0 + TASSEL_LEN
	return maxf(60.0, open_tip - closed_tip)


func _release(p: Vector2) -> void:
	if p.distance_to(_grab_pos) < CLICK_PX:
		_animate_to(0.0 if _grab_from >= 1.0 else 1.0)
	elif _grab_from >= 1.0:
		_animate_to(0.0 if openness < CLOSE_AT else 1.0)
	else:
		_animate_to(1.0 if openness >= OPEN_AT else 0.0)


## 画布坐标 p 下的卡片（只在完全展开时可点）。
func card_at(p: Vector2) -> LevelCard2D:
	for k in range(_cards.size() - 1, -1, -1):
		if _cards[k].contains(p):
			return _cards[k]
	return null


func _update_hover(p: Vector2) -> void:
	var hit := card_at(p) if state == State.OPEN else null
	for card in _cards:
		card.set_hovered(card == hit)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_ESCAPE and is_active():
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------------- 画面

func _process(delta: float) -> void:
	_time += delta
	if is_active():
		_layout()
		_place_cards()
	queue_redraw()


func _place_cards() -> void:
	var alpha := smoothstep(0.55, 1.0, openness)
	for i in _cards.size():
		var uv := _card_u(i)
		var card := _cards[i]
		card.position = _line_point(int(uv.y), uv.x, openness) + Vector2(0, -16.0 * (1.0 - alpha))
		card.modulate.a = alpha


func _draw() -> void:
	if not is_active():
		_draw_tassel(tassel_tip(), 1.0)
		return
	var e := openness
	draw_rect(get_viewport_rect(), Color(VEIL, VEIL.a * smoothstep(0.0, 0.6, e)))
	for line in _line_y.size():
		var alpha := 1.0 if line == 0 else _drop(e)
		if alpha <= 0.01:
			continue
		_draw_line(line, e, alpha)
	_draw_beads(e)
	_draw_tassel(tassel_tip(), 1.0)


## 一根绳：穿珠线的颜色过渡到晾衣绳的颜色，两端各一个小结。
func _draw_line(line: int, e: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		pts.append(_line_point(line, k / 32.0, e))
	var color := Color(StrandPainter2D.BASE_YARN.lerp(CORD, e), lerpf(0.7, 1.0, e) * alpha)
	var width := lerpf(2.0, 3.4, e)
	draw_polyline(pts, Color(StrandPainter2D.SHADOW, 0.12 * alpha * e), width + 1.5, true)
	draw_polyline(pts, color, width, true)
	for knot: Vector2 in [pts[0], pts[pts.size() - 1]]:
		draw_circle(knot, lerpf(2.0, 5.0, e), Color(CORD.darkened(0.2), alpha))


## 展开过程中珠子顺着绳子散开并淡出。
func _draw_beads(e: float) -> void:
	if _beads == null or _beads.count <= 0:
		return
	var alpha := 1.0 - smoothstep(0.25, 0.8, e)
	if alpha <= 0.01:
		return
	var span := _beads.string_span()
	for i in _beads.count:
		var u := inverse_lerp(span[0].x, span[1].x, _beads.bead_center(i).x)
		var is_cur := i == _beads.current and not _beads.current_done
		ProgressBeads2D.draw_bead(self, _line_point(0, u, e), _beads.is_done(i), is_cur, _beads.pulse(), alpha)


## 垂下的线头：从珠子串（或晾衣绳）中间垂下，末端一个小线环，轻轻晃。
func _draw_tassel(tip: Vector2, alpha: float) -> void:
	var anchor := _tassel_anchor()
	var swing := 2.0 * sin(_time * 1.7) if state != State.DRAGGING else 0.0
	var end := tip + Vector2(swing, 0)
	var mid := (anchor + end) * 0.5 + Vector2(swing * 0.5, 0)
	var keys: Array[Vector2] = [anchor, mid, end - Vector2(0, TASSEL_RING)]
	var st := Strand2D.new(Strand2D.Kind.ROPE, -1, StrandPainter2D.YARN, 4.2)
	st.points = Strand2D.catmull(keys, 6)
	st.tones.resize(st.points.size())
	st.tones.fill(0.05)
	var layer: Array[Strand2D] = [st]
	StrandPainter2D.draw_layer(self, layer)
	var c := end
	var glow := 0.5 + 0.5 * sin(_time * 2.4)
	if state == State.CLOSED:
		draw_circle(c, TASSEL_RING + 5.0 + 2.0 * glow, Color(1.0, 0.9, 0.7, 0.22 * alpha))
	draw_arc(c, TASSEL_RING, 0, TAU, 28, StrandPainter2D.YARN.darkened(0.22), 4.6, true)
	draw_arc(c, TASSEL_RING, 0, TAU, 28, StrandPainter2D.YARN, 3.4, true)
	draw_arc(c, TASSEL_RING - 0.6, PI * 1.05, PI * 1.6, 10, StrandPainter2D.YARN.lightened(0.3), 1.2, true)
