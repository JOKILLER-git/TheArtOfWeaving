extends Control
## 针织手势原型（独立场景，F6 运行）。
## 钩针手势只有一种：从下方进入上一行线圈的「眼」、从上方离开 = 成针。
## 针法由工作线的状态决定：线在织物后面 → 下针，线在织物前面 → 上针。
## 切换线的前后有两种方案（M 键切换对比）：A 绕线（线头绕锚点转一圈），B 工具（把小织针拖到线上）。
## 线圈尺寸按关卡的列数、行数自动缩放，织物尽量占满画面；交叉点逐个判定前后。

const CANVAS := Vector2(1280, 800)
const MAX_SX := 260.0       # 单个线圈宽度上限
const FILL_W := 0.80        # 织物宽度最多占画布的比例
const FILL_H := 0.78        # 织物高度的目标比例
const REF_SX := 84.0        # 旧版列宽：判定半径、绳子等按 sx / REF_SX 等比放大
const ROPE_N := 18
const IDLE_HINT_SECONDS := 8.0
const STEPS := 8            # 每段样条的采样数
const WIND_TURN := 5.76     # 方案 A：绕锚点累计转角达到约 330° 切换一次
const WIND_BLOCK := 3.5     # 绕到约 200° 以后暂停钩针判定，避免绕圈时误穿眼
const WIND_MIN := 0.3       # 绕圈时线头离锚点的距离范围（列宽倍数）
const WIND_MAX := 1.4
const WIND_HINT_R := 0.9    # 提示虚线圆的半径（列宽倍数），避开眼
const TOOL_HOME := Vector2(640, 764)
const TOOL_LEN := 124.0
const TOOL_ANGLE := -0.3
const FLIP_TIME := 0.38     # 翻面动画时长（秒）

## 线圈左半边的关键点（x 以列宽、y 以行高为单位，相对线圈中心），右半边镜像。
## 段 0-1 沉降弧（C），段 2 下腿（B，穿过下一行线圈的头），段 3-5 上腿和头（A）。
const LOOP_HALF := [
	Vector2(-0.50, 0.78),
	Vector2(-0.40, 0.78),
	Vector2(-0.16, 0.70),
	Vector2(-0.13, 0.20),
	Vector2(-0.36, -0.22),
	Vector2(-0.28, -0.52),
	Vector2(0.0, -0.62),
]
const LOOP_TOP := 0.62      # 线圈头顶在中心上方多少行高
const LOOP_BOT := 0.78      # 沉降弧在中心下方多少行高
const EYE_UP := 0.42        # 眼的中心在线圈中心上方多少行高

const KIND_FABRIC := 0
const KIND_ROPE := 1

const BASE_YARN := Color("a9ad94")
const YARN := Color("c27c63")
const INK := Color("5b5446")
const GAP := Color("e9e2d4")    # 交叉处的间隙描边，比背景略深
const SCALE := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]

const LEVELS := [
	{"title": "第一针", "cols": 2, "rows": ["KK"]},
	{"title": "一行下针", "cols": 4, "rows": ["KKKK"]},
	{"title": "上针", "cols": 4, "rows": ["PPPP"]},
	{"title": "罗纹", "cols": 4, "rows": ["KPKP", "KPKP"]},
]

var level_index := 0
var target := PackedStringArray()
var grid: Array = []        # grid[r][i] = {"t": "K"/"P", "form": float} 或 null；第 0 行是给定的起始行
var row := 1                # 正在织的行
var done_count := 0         # 本行已完成的针数
var completed := false

# 随关卡变化的尺寸（_layout 计算）。
var cols := 2
var sx := 84.0              # 列宽
var sy := 70.0              # 行高
var x0 := 0.0               # 第 0 列的 x
var base_y := 0.0           # 第 0 行（起始行）的中心 y
var ks := 1.0               # 相对旧版的缩放倍数
var yarn_w := 10.0          # 线宽
var eye_r_in := 22.0        # 进入眼的半径
var eye_r_out := 30.0       # 离开眼的半径（滞回，防抖）
var grab_r := 44.0

var dragging := false
var tip := Vector2.ZERO
var rope := PackedVector2Array()
var rope_prev := PackedVector2Array()

var in_eye := false
var entry_below := false
var hint_on := false
var hint_alpha := 0.0
var idle_time := 0.0
var reject := {}            # 手势对、针法错时，滑脱的虚影线圈
var settle := 0.0           # 一行完成时布面的轻微收紧
var _time := 0.0
var _last_mouse := Vector2.ZERO
var _hover := Vector2(-1000, -1000)
var _tones := {}

var scheme := 0             # 0 = 方案 A 绕线，1 = 方案 B 工具
var yarn_front := false     # 工作线在织物前面（钩 = 上针）还是后面（钩 = 下针）
var front_v := 0.0          # 显示用：0 = 后，1 = 前，翻面时补间
var flip_k := 1.0           # 翻面动画进度（1 = 静止）
var wind := 0.0             # 方案 A：线头绕锚点的累计转角（弧度，带符号）
var wind_prev := Vector2.ZERO
var wind_valid := false
var wind_anchor := Vector2.ZERO
var tool_pos := TOOL_HOME
var tool_drag := false
var tool_off := Vector2.ZERO
var _flip_tw: Tween
var _tool_tw: Tween
var _swish := {}

var _title: Label
var _keys: Label
var _done_label: Label


func _ready() -> void:
	var theme_res := load("res://resources/ui/weave_theme.tres")
	_title = _make_label(Vector2(32, 20), 26, INK)
	_keys = _make_label(Vector2(32, CANVAS.y - 44), 17, Color(INK, 0.6))
	_keys.text = "R 重来      H 提示      N 下一关      M 切换方案"
	_done_label = _make_label(Vector2(0, 24), 24, YARN.darkened(0.2))
	_done_label.size = Vector2(CANVAS.x, 40)
	_done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done_label.text = "织好了  ·  按 N 继续"
	if theme_res is Theme:
		theme = theme_res
	_start_level(0)


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _start_level(index: int) -> void:
	level_index = index
	target = PackedStringArray(LEVELS[index]["rows"])
	cols = int(LEVELS[index]["cols"])
	_layout()
	grid.clear()
	for r in target.size() + 1:
		var line: Array = []
		for i in cols:
			# 分开写，避免三元运算符两侧类型不兼容的警告。
			if r == 0:
				line.append({"t": "K", "form": 1.0})
			else:
				line.append(null)
		grid.append(line)
	row = 1
	done_count = 0
	completed = false
	dragging = false
	in_eye = false
	hint_on = false
	hint_alpha = 0.0
	idle_time = 0.0
	reject = {}
	settle = 0.0
	tip = _rest_tip()
	rope = PackedVector2Array()
	# 每关开始线在后面。
	if _flip_tw:
		_flip_tw.kill()
	yarn_front = false
	front_v = 0.0
	flip_k = 1.0
	_reset_wind()
	_tool_home(false)
	_update_title()
	_done_label.visible = false


func _update_title() -> void:
	var scheme_name := "方案 A · 绕线" if scheme == 0 else "方案 B · 工具"
	_title.text = "针织原型  %d / %d  ·  %s        %s" % [level_index + 1, LEVELS.size(), LEVELS[level_index]["title"], scheme_name]


## 按列数、行数算线圈尺寸：宽受上限约束，高尽量占满画布，织物居中。
func _layout() -> void:
	var span := float(target.size()) + LOOP_TOP + LOOP_BOT
	sx = minf(MAX_SX, CANVAS.x * FILL_W / cols)
	sy = clampf(CANVAS.y * FILL_H / span, 0.75 * sx, 1.05 * sx)
	ks = sx / REF_SX
	yarn_w = 0.115 * sx
	eye_r_in = 22.0 * ks
	eye_r_out = 30.0 * ks
	grab_r = 44.0 * ks
	x0 = (CANVAS.x - cols * sx) * 0.5 + 0.5 * sx
	base_y = (CANVAS.y + span * sy) * 0.5 - LOOP_BOT * sy


# ---------------------------------------------------------------- 几何

func col_x(i: int) -> float:
	return x0 + i * sx

func row_c(r: int) -> float:
	return base_y - r * sy

func sinker_y(r: int) -> float:
	return row_c(r) + LOOP_BOT * sy

## 奇数行从左往右，偶数行从右往左（真实织片每行翻面，来回往返）。
func dir_of(r: int) -> int:
	return 1 if r % 2 == 1 else -1

func edge_x(side: int) -> float:
	return col_x(0) - 0.5 * sx if side < 0 else col_x(cols - 1) + 0.5 * sx

func col_at(r: int, k: int) -> int:
	return k if dir_of(r) > 0 else cols - 1 - k

func next_col() -> int:
	if completed or done_count >= cols:
		return -1
	return col_at(row, done_count)

func eye_center(i: int, r: int) -> Vector2:
	return Vector2(col_x(i), row_c(r) - EYE_UP * sy)

## 工作线当前固定在织物上的那一点。
func anchor() -> Vector2:
	if completed:
		var last := target.size()
		return Vector2(edge_x(dir_of(last)), sinker_y(last))
	if done_count == 0:
		return Vector2(edge_x(-dir_of(row)), sinker_y(row))
	var c := col_at(row, done_count - 1)
	return Vector2(col_x(c) + dir_of(row) * 0.5 * sx, sinker_y(row))

func _rest_tip() -> Vector2:
	var d := dir_of(mini(row, target.size())) if not completed else dir_of(target.size())
	# 线头垂向前进方向，让工作线压过（或藏在）下面的线圈，一眼看出线在前还是在后。
	return anchor() + Vector2(d * 40.0, 66.0) * ks


func _loop_keys(i: int, r: int, form: float) -> Array:
	var x := col_x(i)
	var c := row_c(r)
	var base := sinker_y(r)
	var keys: Array = []
	for k in LOOP_HALF.size():
		var h: Vector2 = LOOP_HALF[k]
		keys.append(Vector2(x + h.x * sx, c + h.y * sy))
	for k in range(LOOP_HALF.size() - 2, -1, -1):
		var h: Vector2 = LOOP_HALF[k]
		keys.append(Vector2(x - h.x * sx, c + h.y * sy))
	# 新线圈从钩出点「长」出来：以沉降弧为基准纵向缩放，两端衔接点不动。
	var squash := lerpf(0.7, 1.0, clampf(form, 0.0, 1.0))
	for k in range(1, keys.size() - 1):
		var p: Vector2 = keys[k]
		keys[k] = Vector2(x + (p.x - x) * squash, base + (p.y - base) * form)
	return keys

func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)

func _catmull(pts: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for k in n - 1:
		var p0: Vector2 = pts[maxi(k - 1, 0)]
		var p1: Vector2 = pts[k]
		var p2: Vector2 = pts[k + 1]
		var p3: Vector2 = pts[mini(k + 2, n - 1)]
		for s in steps:
			out.append(_cr(p0, p1, p2, p3, float(s) / steps))
	out.append(pts[n - 1])
	return out


# ---------------------------------------------------------------- 输入与手势

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_start_level(level_index)
			KEY_H:
				hint_on = not hint_on
				idle_time = 0.0
			KEY_N:
				if completed:
					_start_level((level_index + 1) % LEVELS.size())
			KEY_M:
				scheme = 1 - scheme
				_reset_wind()
				_tool_home(false)
				_update_title()
		return
	var local := make_input_local(event)
	if local is InputEventMouseMotion:
		_hover = local.position
	if local is InputEventMouseButton and local.button_index == MOUSE_BUTTON_LEFT:
		if local.pressed:
			# 工具和线头的抓取互不干扰，一次只拖一个；两者都够得着时取更近的那个。
			var tip_d: float = local.position.distance_to(tip)
			var on_tool: bool = _tool_hit(local.position) and _tool_dist(local.position) < tip_d
			if not completed and tip_d <= grab_r and not on_tool:
				dragging = true
				_last_mouse = local.position
				_reset_wind()
			elif on_tool:
				if _tool_tw:
					_tool_tw.kill()
				tool_drag = true
				tool_off = tool_pos - local.position
		else:
			if tool_drag:
				_drop_tool()
			dragging = false
			in_eye = false
	elif local is InputEventMouseMotion:
		if dragging:
			_drag_to(local.position)
		elif tool_drag:
			tool_pos = local.position + tool_off


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		in_eye = false
		if tool_drag:
			_tool_home(true)


## 鼠标事件可能跳过很小的眼，所以按 4px 步长补采样。
func _drag_to(p: Vector2) -> void:
	var dist := _last_mouse.distance_to(p)
	var steps := maxi(1, int(ceil(dist / 4.0)))
	for s in range(1, steps + 1):
		var q := _last_mouse.lerp(p, float(s) / steps)
		tip = q
		if scheme == 0:
			_wind_step(q)
		_gesture(q)
		if not dragging:
			break
	_last_mouse = p


func _gesture(q: Vector2) -> void:
	var col := next_col()
	if col < 0:
		return
	var ec := eye_center(col, row - 1)
	var d := q.distance_to(ec)
	if not in_eye:
		if d < eye_r_in and absf(wind) < WIND_BLOCK:
			in_eye = true
			entry_below = q.y > ec.y
		return
	if d <= eye_r_out:
		return
	in_eye = false
	# 唯一的成针手势：从下方进眼、从上方离开。针法由线的前后决定。
	if entry_below and q.y < ec.y - eye_r_out * 0.35:
		_make_stitch(col, "P" if yarn_front else "K")


## 下一针要的线状态和当前一致吗（P 要线在前，K 要线在后）。
func _state_ok(col: int) -> bool:
	if col < 0:
		return true
	return (target[row - 1][col] == "P") == yarn_front


# ---------------------------------------------------------------- 线的前后切换

func _reset_wind() -> void:
	wind = 0.0
	wind_valid = false


## 方案 A：线头在锚点周围一定距离内连续绕行，累计转角够一圈就切换。
func _wind_step(q: Vector2) -> void:
	var a := anchor()
	if a.distance_to(wind_anchor) > 1.0:
		wind_anchor = a
		_reset_wind()
	var v := q - a
	var r := v.length() / sx
	if r < WIND_MIN or r > WIND_MAX:
		_reset_wind()
		return
	if wind_valid:
		wind += wind_prev.angle_to(v)
	wind_prev = v
	wind_valid = true
	if absf(wind) >= WIND_TURN:
		_reset_wind()
		_toggle_yarn()


func _toggle_yarn() -> void:
	if completed:
		return
	yarn_front = not yarn_front
	idle_time = 0.0
	if hint_on and _state_ok(next_col()):
		hint_on = false
	if _flip_tw:
		_flip_tw.kill()
	_flip_tw = create_tween().set_parallel(true)
	_flip_tw.tween_property(self, "front_v", 1.0 if yarn_front else 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tw.tween_property(self, "flip_k", 1.0, FLIP_TIME).from(0.0)
	# 绳子中段甩一下，像翻过织物边。
	if rope.size() == ROPE_N:
		var n := (rope[ROPE_N - 1] - rope[0]).orthogonal().normalized()
		var s := 1.0 if yarn_front else -1.0
		for k in range(1, ROPE_N - 1):
			var f := sin(PI * float(k) / (ROPE_N - 1))
			rope_prev[k] = rope_prev[k] - n * f * 10.0 * ks * s
	_play_wav(_swish_wav(yarn_front))


## 工具的两端：圆头一端和针尖一端。
func _tool_ends() -> Array:
	var ang := TOOL_ANGLE
	if not tool_drag and not _state_ok(next_col()) and not completed:
		# 状态不对时轻轻晃动，一阵一阵的。
		ang += 0.12 * sin(_time * 9.0) * maxf(0.0, sin(_time * 2.2))
	var d := Vector2.from_angle(ang) * TOOL_LEN * 0.5
	return [tool_pos - d, tool_pos + d]


func _tool_dist(p: Vector2) -> float:
	var e := _tool_ends()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, e[0], e[1]))


func _tool_hit(p: Vector2) -> bool:
	if scheme != 1 or completed:
		return false
	return _tool_dist(p) <= 26.0


## 工具到工作线（任意一段）的最近距离。
func _tool_rope_dist() -> float:
	if rope.size() < 2:
		return 1e6
	var e := _tool_ends()
	var best := 1e6
	for k in rope.size() - 1:
		var a := rope[k]
		var b := rope[k + 1]
		if Geometry2D.segment_intersects_segment(a, b, e[0], e[1]) != null:
			return 0.0
		best = minf(best, a.distance_to(Geometry2D.get_closest_point_to_segment(a, e[0], e[1])))
		best = minf(best, e[0].distance_to(Geometry2D.get_closest_point_to_segment(e[0], a, b)))
		best = minf(best, e[1].distance_to(Geometry2D.get_closest_point_to_segment(e[1], a, b)))
	return best


func _tool_snap() -> float:
	return maxf(24.0, 0.12 * sx)


func _drop_tool() -> void:
	tool_drag = false
	if _tool_rope_dist() <= _tool_snap():
		_toggle_yarn()
	_tool_home(true)


func _tool_home(animate: bool) -> void:
	tool_drag = false
	if _tool_tw:
		_tool_tw.kill()
	if not animate:
		tool_pos = TOOL_HOME
		return
	_tool_tw = create_tween()
	_tool_tw.tween_property(self, "tool_pos", TOOL_HOME, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_stitch(col: int, t: String) -> void:
	var want := target[row - 1][col]
	if t != want:
		# 不惩罚：线圈成形一下又滑脱，同时出现铅笔提示。
		var ghost := {"col": col, "row": row, "t": t, "form": 0.0}
		reject = ghost
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: ghost["form"] = v, 0.2, 0.9, 0.12)
		tw.tween_method(func(v: float) -> void: ghost["form"] = v, 0.9, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_play(196.0, 0.22, 0.25, 16.0)
		hint_on = true
		return
	var cell := {"t": t, "form": 0.25}
	grid[row][col] = cell
	create_tween().tween_method(func(v: float) -> void: cell["form"] = v, 0.25, 1.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var freq: float = SCALE[done_count % SCALE.size()]
	_play(freq if t == "K" else freq * 0.5, 0.4, 0.3)
	done_count += 1
	idle_time = 0.0
	hint_on = false
	if done_count >= cols:
		_finish_row()


func _finish_row() -> void:
	in_eye = false
	_pulse_settle(1.0)
	var finished_row := row
	row += 1
	done_count = 0
	if finished_row >= target.size():
		completed = true
		dragging = false
		row = target.size()
		_done_label.visible = true
		var tw := create_tween()
		for k in 4:
			tw.tween_callback(_play.bind(SCALE[k * 2 % SCALE.size()] * (1.0 if k < 3 else 2.0), 0.6, 0.25))
			tw.tween_interval(0.11)
		_pulse_settle(2.2)
	else:
		_play(523.25, 0.55, 0.18)
		_play(783.99, 0.55, 0.14)


func _pulse_settle(amount: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: settle = v, 0.0, amount, 0.07)
	tw.tween_method(func(v: float) -> void: settle = v, amount, 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 绳子与声音

func _process(delta: float) -> void:
	_time += delta
	if not completed:
		idle_time += delta
		if idle_time > IDLE_HINT_SECONDS:
			hint_on = true
	hint_alpha = move_toward(hint_alpha, 1.0 if hint_on and not completed else 0.0, delta * 3.0)
	if not dragging:
		tip = tip.lerp(_rest_tip(), 1.0 - exp(-10.0 * delta))
	_step_rope(delta)
	queue_redraw()


## 简单 Verlet 绳：两端固定，只约束拉伸，让线自然下垂。
func _step_rope(delta: float) -> void:
	var a := anchor()
	var b := tip
	if rope.size() != ROPE_N:
		rope.resize(ROPE_N)
		for k in ROPE_N:
			rope[k] = a.lerp(b, float(k) / (ROPE_N - 1))
		rope_prev = rope.duplicate()
	var seg := maxf(a.distance_to(b) * 1.08, 40.0 * ks) / (ROPE_N - 1)
	var g := Vector2(0, 1400.0 * ks) * delta * delta
	for k in range(1, ROPE_N - 1):
		var p := rope[k]
		var v := (p - rope_prev[k]) * 0.95
		rope_prev[k] = p
		rope[k] = p + v + g
	rope[0] = a
	rope[ROPE_N - 1] = b
	for _it in 12:
		for k in ROPE_N - 1:
			var p1 := rope[k]
			var p2 := rope[k + 1]
			var dv := p2 - p1
			var dist := dv.length()
			if dist <= seg or dist < 0.001:
				continue
			var diff := (dist - seg) / dist
			if k == 0:
				rope[k + 1] = p2 - dv * diff
			elif k + 1 == ROPE_N - 1:
				rope[k] = p1 + dv * diff
			else:
				rope[k] = p1 + dv * diff * 0.5
				rope[k + 1] = p2 - dv * diff * 0.5
		rope[0] = a
		rope[ROPE_N - 1] = b


func _play(freq: float, dur: float = 0.35, vol: float = 0.3, decay: float = 9.0) -> void:
	var key := "%d_%d_%d_%d" % [int(freq), int(dur * 100), int(vol * 100), int(decay)]
	if not _tones.has(key):
		_tones[key] = _make_tone(freq, dur, vol, decay)
	_play_wav(_tones[key])


func _play_wav(wav: AudioStreamWAV) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## 运行时合成的柔和拨弦音，原型阶段不依赖音频资源。
func _make_tone(freq: float, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for s in n:
		var t := float(s) / rate
		var env := exp(-t * decay) * minf(1.0, t * 300.0)
		var v := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t) + 0.08 * sin(TAU * freq * 3.0 * t)) * env * vol
		data.encode_s16(s * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## 翻面的轻音：一声短促的「嗖」（滤波噪声 + 滑音），翻到前面往上滑，翻到后面往下滑。
func _swish_wav(up: bool) -> AudioStreamWAV:
	if _swish.has(up):
		return _swish[up]
	var rate := 22050
	var dur := 0.2
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var phase := 0.0
	for s in n:
		var u := float(s) / n
		var g := u if up else 1.0 - u
		var env := sin(PI * u) * sin(PI * u)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.06, 0.25, g)
		phase += TAU * lerpf(620.0, 1240.0, g) / rate
		var v := (0.9 * lp + 0.07 * sin(phase)) * env * 0.5
		data.encode_s16(s * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_swish[up] = wav
	return wav


# ---------------------------------------------------------------- 绘制
# 做法：先把所有线（织物每一行 + 工作线）按「阴影 → 描边 → 填充 → 高光」分层画一遍；
# 再求出所有交叉点并判定谁在前：后面的线在交叉处局部压暗，前面的线先画一圈
# 间隙色描边再重画自己，于是后面的线看起来在交叉处断开、被压住。

func _row_color(r: int) -> Color:
	return BASE_YARN if r == 0 else YARN

## 明暗：t > 0 偏亮（在前），t < 0 偏暗（在后）。
func _shade(base: Color, t: float) -> Color:
	if t >= 0.0:
		return base.lightened(t * 0.25)
	return base.darkened(-t * 0.32)

func _settle_y(y: float) -> float:
	return base_y + (y - base_y) * (1.0 - 0.02 * settle)

## 每段属于线圈的哪一部分：0 = 头和上腿（A），1 = 下腿（B），2 = 沉降弧（C）。
func _part(seg: int) -> int:
	if seg <= 1 or seg >= 10:
		return 2
	if seg == 2 or seg == 9:
		return 1
	return 0

## 一个线圈每段的 z 和每个关键点的明暗。
## 下针：新线圈的下腿在旧线圈头前面（z=+1），沉降弧在旧线圈后面（z=-1）；上针相反。
## 线圈头（A）恒为 z=0，所以相邻两行的每个交叉点都能直接比出前后。
func _loop_attrs(i: int, r: int) -> Array:
	var t := "K"
	if r > 0:
		t = String(grid[r][i]["t"])
	var up := ""
	if r + 1 < grid.size() and grid[r + 1][i] != null:
		up = String(grid[r + 1][i]["t"])
	var zb := 1.0 if t == "K" else -1.0
	var tb := 0.3 if t == "K" else -0.8
	var tc := -0.55 if t == "K" else 0.35
	if r == 0:
		tb = 0.0
		tc = 0.0
	var th := 0.0
	if up == "K":
		th = -0.35     # 被上一行下针的腿压在后面
	elif up == "P":
		th = 0.4       # 上针：头横压在前面，成为颗粒
	var half: Array = [tc, tc, (tb + tc) * 0.5, tb, 0.0, th, th]
	var tones: Array = half.duplicate()
	for k in range(half.size() - 2, -1, -1):
		tones.append(half[k])
	var zs: Array = []
	for seg in 12:
		var part := _part(seg)
		if part == 0:
			zs.append(0.0)
		elif part == 1:
			zs.append(zb)
		else:
			zs.append(-zb)
	return [zs, tones]

## 关键点按 Catmull-Rom 采样成折线，同时带上每段的 z、所属列和每个点的明暗。
func _sample(keys: Array, seg_z: Array, key_tone: Array, col: int) -> Array:
	var p := PackedVector2Array()
	var t := PackedFloat32Array()
	var z := PackedFloat32Array()
	var c := PackedInt32Array()
	var n := keys.size()
	for k in n - 1:
		var p0: Vector2 = keys[maxi(k - 1, 0)]
		var p1: Vector2 = keys[k]
		var p2: Vector2 = keys[k + 1]
		var p3: Vector2 = keys[mini(k + 2, n - 1)]
		var ta: float = key_tone[k]
		var tb: float = key_tone[k + 1]
		var zk: float = seg_z[k]
		for s in STEPS:
			var u := float(s) / STEPS
			p.append(_cr(p0, p1, p2, p3, u))
			t.append(lerpf(ta, tb, u))
			z.append(zk)
			c.append(col)
	p.append(keys[n - 1])
	t.append(key_tone[n - 1])
	return [p, t, z, c]

## 把一段接到线的末尾（首点与上一段末点重合，丢掉）。
func _merge(acc: Array, part: Array) -> void:
	var p: PackedVector2Array = acc[0]
	var t: PackedFloat32Array = acc[1]
	var z: PackedFloat32Array = acc[2]
	var c: PackedInt32Array = acc[3]
	var pp: PackedVector2Array = part[0]
	var pt: PackedFloat32Array = part[1]
	var pz: PackedFloat32Array = part[2]
	var pc: PackedInt32Array = part[3]
	var drop := 1 if p.size() > 0 else 0
	p.append_array(pp.slice(drop))
	t.append_array(pt.slice(drop))
	z.append_array(pz)
	c.append_array(pc)
	acc[0] = p
	acc[1] = t
	acc[2] = z
	acc[3] = c

## 一行线：行首折返弧 + 已织好的线圈（起始行再加线尾），作为一根连续的线。
func _row_strand(r: int) -> Dictionary:
	var acc: Array = [PackedVector2Array(), PackedFloat32Array(), PackedFloat32Array(), PackedInt32Array()]
	var flat_z: Array = [0.0, 0.0]
	var flat_t: Array = [0.0, 0.0, 0.0]
	var arc: Array = []
	var side := 0
	# 正在织、还没起针的这一行：折返弧算作工作线的一部分（随线的前后状态绘制）。
	if r >= 1 and not _arc_is_rope(r):
		side = -dir_of(r)
		var ex := edge_x(side)
		var from := Vector2(ex, sinker_y(r - 1))
		var to := Vector2(ex, sinker_y(r))
		var mid := (from + to) * 0.5 + Vector2(side * 0.2 * sx, 0)
		arc = [from, mid, to] if side < 0 else [to, mid, from]
	if side < 0:
		_merge(acc, _sample(arc, flat_z, flat_t, -1))
	for i in cols:
		if grid[r][i] == null:
			continue
		var attrs := _loop_attrs(i, r)
		_merge(acc, _sample(_loop_keys(i, r, float(grid[r][i]["form"])), attrs[0], attrs[1], i))
	if side > 0:
		_merge(acc, _sample(arc, flat_z, flat_t, -1))
	if r == 0:
		var t0 := Vector2(edge_x(1), sinker_y(0))
		_merge(acc, _sample([t0, t0 + Vector2(0.2, 0.15) * sx, t0 + Vector2(0.26, 0.4) * sx], flat_z, flat_t, -1))
	var pts: PackedVector2Array = acc[0]
	for k in pts.size():
		pts[k] = Vector2(pts[k].x, _settle_y(pts[k].y))
	return {"kind": KIND_FABRIC, "row": r, "base": _row_color(r), "pts": pts, "tone": acc[1], "z": acc[2], "col": acc[3], "w": yarn_w}

func _arc_is_rope(r: int) -> bool:
	return r == row and done_count == 0 and not completed


func _rope_strand() -> Dictionary:
	var pts := _catmull(Array(rope), 4)
	if row >= 1 and _arc_is_rope(row):
		var side := -dir_of(row)
		var ex := edge_x(side)
		var from := Vector2(ex, _settle_y(sinker_y(row - 1)))
		var to := Vector2(ex, sinker_y(row))
		var mid := (from + to) * 0.5 + Vector2(side * 0.2 * sx, 0)
		var arc := _catmull([from, mid, to], STEPS)
		arc.append_array(pts.slice(1))
		pts = arc
	var tone := PackedFloat32Array()
	tone.resize(pts.size())
	tone.fill(0.0)
	var z := PackedFloat32Array()
	z.resize(pts.size() - 1)
	z.fill(5.0)
	var c := PackedInt32Array()
	c.resize(pts.size() - 1)
	c.fill(-1)
	# 线在后面：偏暗、略细；在前面：明亮。翻面途中略微变粗，像从边上翻过来。
	var base := YARN.darkened(lerpf(0.4, 0.0, front_v)).lightened(0.08 * front_v)
	var w := yarn_w * lerpf(0.72, 1.0, front_v) * (1.0 + 0.3 * sin(PI * flip_k))
	return {"kind": KIND_ROPE, "row": -1, "base": base, "pts": pts, "tone": tone, "z": z, "col": c, "w": w, "sh": lerpf(0.04, 0.2, front_v)}


## 交叉点上 a 在前返回 1，b 在前返回 -1，无所谓返回 0。
func _over(a: Dictionary, sa: int, b: Dictionary, sb: int) -> int:
	var rope_a := int(a["kind"]) == KIND_ROPE
	if rope_a or int(b["kind"]) == KIND_ROPE:
		var fab: Dictionary = b if rope_a else a
		var fs := sb if rope_a else sa
		var fc: PackedInt32Array = fab["col"]
		# 工作线整体在织物前或后；正在钩的那个旧线圈例外：
		# 线在后 → 新线从后往前穿出，旧线圈头在线后面（下针）；线在前 → 旧线圈头压在线前面（上针）。
		var front := front_v >= 0.5
		if in_eye and entry_below and int(fab["row"]) == row - 1 and fc[fs] >= 0 and fc[fs] == next_col():
			front = not front
		return 1 if rope_a == front else -1
	var za: float = (a["z"] as PackedFloat32Array)[sa]
	var zb: float = (b["z"] as PackedFloat32Array)[sb]
	if is_equal_approx(za, zb):
		return 0
	return 1 if za > zb else -1

func _chunks(pts: PackedVector2Array) -> Array:
	var out: Array = []
	var k := 0
	while k < pts.size() - 1:
		var e := mini(k + STEPS, pts.size() - 1)
		var rect := Rect2(pts[k], Vector2.ZERO)
		for j in range(k + 1, e + 1):
			rect = rect.expand(pts[j])
		out.append(rect.grow(1.0))
		k = e
	return out

func _find_crossings(a: Dictionary, b: Dictionary, out: Array) -> void:
	var pa: PackedVector2Array = a["pts"]
	var pb: PackedVector2Array = b["pts"]
	if pa.size() < 2 or pb.size() < 2:
		return
	var ca := _chunks(pa)
	var cb := _chunks(pb)
	var ends: Array = [pa[0], pa[pa.size() - 1], pb[0], pb[pb.size() - 1]]
	var has_rope := int(a["kind"]) == KIND_ROPE or int(b["kind"]) == KIND_ROPE
	for ia in ca.size():
		var ra: Rect2 = ca[ia]
		for ib in cb.size():
			if not ra.intersects(cb[ib], true):
				continue
			for sa in range(ia * STEPS, mini((ia + 1) * STEPS, pa.size() - 1)):
				for sb in range(ib * STEPS, mini((ib + 1) * STEPS, pb.size() - 1)):
					var hit: Variant = Geometry2D.segment_intersects_segment(pa[sa], pa[sa + 1], pb[sb], pb[sb + 1])
					if hit == null:
						continue
					var p: Vector2 = hit
					# 线与线首尾相接处不算交叉；工作线刚离开织物的一小段也不算。
					var skip := false
					for e in ends:
						if p.distance_to(e) < (0.8 if has_rope else 0.6) * yarn_w:
							skip = true
					for x in out:
						if p.distance_to(x["p"]) < 0.3 * yarn_w:
							skip = true
					if skip:
						continue
					var o := _over(a, sa, b, sb)
					if o == 0:
						continue
					if o > 0:
						out.append({"o": a, "os": sa, "u": b, "us": sb, "p": p})
					else:
						out.append({"o": b, "os": sb, "u": a, "us": sa, "p": p})


func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for k in pts.size():
		out[k] = pts[k] + d
	return out

## dark > 0 压暗，dark < 0 提亮。
func _strand_colors(st: Dictionary, dark: float) -> PackedColorArray:
	var tone: PackedFloat32Array = st["tone"]
	var base: Color = st["base"]
	var out := PackedColorArray()
	out.resize(tone.size())
	for k in tone.size():
		var c := _shade(base, tone[k])
		out[k] = c.darkened(dark) if dark >= 0.0 else c.lightened(-dark)
	return out

## 工作线在后面时整根先画（被织物完全盖住），在前面时最后画（整根压在织物上）。
func _draw_strands(strands: Array) -> void:
	var back: Array = []
	var fabric: Array = []
	var front: Array = []
	for st in strands:
		if (st["pts"] as PackedVector2Array).size() < 2:
			continue
		if int(st["kind"]) == KIND_ROPE:
			if front_v >= 0.5:
				front.append(st)
			else:
				back.append(st)
		else:
			fabric.append(st)
	_draw_layer(back)
	_draw_layer(fabric)
	_draw_layer(front)

func _draw_layer(valid: Array) -> void:
	for st in valid:
		var w: float = st["w"]
		var sh: float = st.get("sh", 0.10)
		draw_polyline(_offset(st["pts"], Vector2(0.08, 0.16) * w * (1.0 + 6.0 * maxf(0.0, sh - 0.1))), Color(0.25, 0.2, 0.1, sh), w * 1.15, true)
	for st in valid:
		var w: float = st["w"]
		var edge := _strand_colors(st, 0.22)
		draw_polyline_colors(st["pts"], edge, w * 1.16, true)
		_draw_caps(st["pts"], edge, w * 0.58)
	for st in valid:
		var w: float = st["w"]
		var fill := _strand_colors(st, 0.0)
		draw_polyline_colors(st["pts"], fill, w, true)
		_draw_caps(st["pts"], fill, w * 0.5)
	for st in valid:
		var w: float = st["w"]
		draw_polyline_colors(_offset(st["pts"], Vector2(-0.1, -0.15) * w), _strand_colors(st, -0.28), w * 0.25, true)

## 线的两端画圆头：两根线首尾相接处（折返弧、工作线起点）不留缺口。
func _draw_caps(pts: PackedVector2Array, colors: PackedColorArray, r: float) -> void:
	draw_circle(pts[0], r, colors[0], true, -1.0, true)
	draw_circle(pts[pts.size() - 1], r, colors[colors.size() - 1], true, -1.0, true)

## 线上以交叉点为中心、沿线前后各 r 长度的一小段。
func _window(pts: PackedVector2Array, seg: int, p: Vector2, r: float) -> PackedVector2Array:
	var back := PackedVector2Array()
	var prev := p
	var acc := 0.0
	var k := seg
	while k >= 0:
		var d := prev.distance_to(pts[k])
		if acc + d >= r:
			back.append(prev.move_toward(pts[k], r - acc))
			break
		if d > 0.01:
			back.append(pts[k])
			acc += d
			prev = pts[k]
		k -= 1
	var out := PackedVector2Array()
	for j in range(back.size() - 1, -1, -1):
		out.append(back[j])
	out.append(p)
	prev = p
	acc = 0.0
	k = seg + 1
	while k < pts.size():
		var d := prev.distance_to(pts[k])
		if acc + d >= r:
			out.append(prev.move_toward(pts[k], r - acc))
			break
		if d > 0.01:
			out.append(pts[k])
			acc += d
			prev = pts[k]
		k += 1
	return out

## 以交叉点为中心向两端渐隐的颜色：r0 以内不透明，r1 处完全透明。
func _fade_colors(pts: PackedVector2Array, p: Vector2, color: Color, r0: float, r1: float) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(pts.size())
	for k in pts.size():
		var f := 1.0 - clampf((pts[k].distance_to(p) - r0) / (r1 - r0), 0.0, 1.0)
		out[k] = Color(color, color.a * f)
	return out

## 后面的线：交叉处附近压暗。
func _draw_under(x: Dictionary) -> void:
	var u: Dictionary = x["u"]
	var pts: PackedVector2Array = u["pts"]
	var s: int = x["us"]
	var p: Vector2 = x["p"]
	var w: float = u["w"]
	var wu := _window(pts, s, p, 2.0 * w)
	draw_polyline_colors(wu, _fade_colors(wu, p, Color(0.16, 0.09, 0.03, 0.22), 0.5 * w, 2.0 * w), w * 1.02, true)

## 前面的线：投一点短阴影，外圈画间隙色（两端渐隐），再把自己重画一遍。
func _draw_over(x: Dictionary) -> void:
	var o: Dictionary = x["o"]
	var w: float = o["w"]
	var pts: PackedVector2Array = o["pts"]
	var s: int = x["os"]
	var p: Vector2 = x["p"]
	var tone: PackedFloat32Array = o["tone"]
	var c := _shade(o["base"], tone[s])
	var wg := _window(pts, s, p, 1.5 * w)
	var wf := _window(pts, s, p, 2.1 * w)
	var ws := _offset(wg, Vector2(0.12, 0.3) * w)
	draw_polyline_colors(ws, _fade_colors(ws, p + Vector2(0.12, 0.3) * w, Color(0.2, 0.12, 0.05, 0.18), 0.6 * w, 1.5 * w), w * 1.25, true)
	draw_polyline_colors(wg, _fade_colors(wg, p, GAP, 0.75 * w, 1.5 * w), w * 1.6, true)
	# 重画的这一小段两端渐隐，和底层同色的线自然衔接，不留接缝。
	draw_polyline_colors(wf, _fade_colors(wf, p, c.darkened(0.22), 1.3 * w, 2.1 * w), w * 1.16, true)
	draw_polyline_colors(wf, _fade_colors(wf, p, c, 1.3 * w, 2.1 * w), w, true)
	var wh := _offset(wf, Vector2(-0.1, -0.15) * w)
	draw_polyline_colors(wh, _fade_colors(wh, p + Vector2(-0.1, -0.15) * w, c.lightened(0.28), 1.3 * w, 2.1 * w), w * 0.25, true)


func _draw() -> void:
	if grid.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := next_col()

	# 眼：靠近时透出亮光，告诉玩家「这里可以穿过去」。
	if col >= 0:
		var ec := eye_center(col, row - 1)
		ec.y = _settle_y(ec.y)
		var near := clampf(1.0 - (tip.distance_to(ec) - 20.0 * ks) / (140.0 * ks), 0.0, 1.0) if dragging else 0.0
		var pulse := 0.25 + 0.15 * sin(_time * 3.0)
		draw_circle(ec, eye_r_in, Color(1, 1, 0.95, 0.35 + 0.5 * maxf(near, pulse)))
		draw_arc(ec, eye_r_in + 3.0 * ks, 0, TAU, 48, Color(YARN, 0.25 + 0.5 * near), 1.5 * ks, true)

	var strands: Array = []
	for r in grid.size():
		if r == 0 or r <= row:
			strands.append(_row_strand(r))
	if rope.size() >= 2:
		strands.append(_rope_strand())

	var crossings: Array = []
	for a in strands.size():
		for b in range(a + 1, strands.size()):
			var sa: Dictionary = strands[a]
			var sb: Dictionary = strands[b]
			if int(sa["kind"]) == KIND_FABRIC and int(sb["kind"]) == KIND_FABRIC and absi(int(sa["row"]) - int(sb["row"])) != 1:
				continue
			_find_crossings(sa, sb, crossings)

	_draw_strands(strands)
	for x in crossings:
		_draw_under(x)
	# 先重画织物在前的交叉，再重画工作线在前的交叉。
	for x in crossings:
		if int(x["o"]["kind"]) == KIND_FABRIC:
			_draw_over(x)
	for x in crossings:
		if int(x["o"]["kind"]) == KIND_ROPE:
			_draw_over(x)

	# 针法不对时滑脱的虚影。
	if not reject.is_empty() and float(reject["form"]) > 0.01:
		var f: float = reject["form"]
		draw_set_transform(Vector2(sin(_time * 70.0) * 3.0 * ks * f, 0), 0.0, Vector2.ONE)
		var ghost := _catmull(_loop_keys(int(reject["col"]), int(reject["row"]), f), STEPS)
		draw_polyline(ghost, Color(YARN, 0.55 * f), yarn_w * 0.9, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 翻面时锚点处的一圈涟漪。
	if flip_k < 1.0 and not completed:
		var rr := yarn_w * (1.0 + 3.0 * flip_k)
		draw_arc(anchor(), rr, 0, TAU, 48, Color(YARN, 0.5 * (1.0 - flip_k)), 2.0 * ks, true)

	# 方案 A：线状态和下一针不一致时，锚点周围淡淡的铅笔虚线圆。
	if scheme == 0 and col >= 0 and not _state_ok(col):
		_draw_wind_circle(0.28 + 0.45 * hint_alpha, hint_alpha)

	if hint_alpha > 0.01 and col >= 0:
		_draw_hint(col)

	# 线头（可抓取）。
	if not completed:
		var kr := (0.6 if dragging else 0.8) * yarn_w
		var kc := YARN.darkened(0.15 + 0.25 * (1.0 - front_v))
		if not dragging:
			var halo := kr * (1.7 + 0.25 * sin(_time * 3.0))
			draw_arc(tip, halo, 0, TAU, 48, Color(YARN, 0.35), 1.5 * ks, true)
		draw_circle(tip + Vector2(0.1, 0.3) * kr, kr, Color(0.25, 0.2, 0.1, 0.12))
		draw_circle(tip, kr, kc)
		draw_circle(tip + Vector2(-0.28, -0.28) * kr, 0.33 * kr, kc.lightened(0.4))

	_draw_tool()
	_draw_card()


## 铅笔虚线圆：每一笔粗细、浓淡略有不同；strong > 0 时加上表示绕行的箭头。
func _draw_wind_circle(alpha: float, strong: float) -> void:
	var a := anchor()
	var R := WIND_HINT_R * sx
	var n := 36
	for k in n:
		if k % 2 == 1:
			continue
		var a0 := TAU * k / n + 0.05 * sin(k * 1.7)
		var a1 := a0 + TAU / n * (0.75 + 0.2 * sin(k * 2.3))
		var rr := R * (1.0 + 0.015 * sin(k * 3.1))
		var c := Color(INK, alpha * (0.75 + 0.25 * sin(k * 1.3)))
		draw_arc(a, rr, a0, a1, 6, c, (1.6 + 0.5 * sin(k * 0.9)) * ks * 0.6, true)
	if strong > 0.01:
		# 顶部一个顺时针方向的小箭头（逆时针绕同样有效）。
		var tipp := a + Vector2(0, -R)
		var c2 := Color(INK, 0.6 * strong)
		var h := 9.0 * ks * 0.6
		draw_polyline(PackedVector2Array([tipp + Vector2(-h, -h), tipp, tipp + Vector2(-h, h)]), c2, 2.2 * ks * 0.6, true)


## 方案 B 的工具：一根带圆头的小织针，画法和线一致（阴影 → 描边 → 填充 → 高光）。
func _draw_tool() -> void:
	if scheme != 1 or completed:
		return
	var e := _tool_ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var dir := (b - a).normalized()
	var w := 11.0
	var shaft := Color("b9a07a")
	var near := tool_drag and _tool_rope_dist() <= _tool_snap()
	if near:
		draw_circle(tool_pos, TOOL_LEN * 0.62, Color(YARN, 0.12))
		draw_arc(tool_pos, TOOL_LEN * 0.62, 0, TAU, 48, Color(YARN, 0.45), 1.5, true)
	var lift := Vector2(2, 5) if tool_drag else Vector2(1, 3)
	var tipp := b - dir * 14.0
	draw_line(a + lift, tipp + lift, Color(0.25, 0.2, 0.1, 0.14), w * 1.2, true)
	draw_line(a, tipp, shaft.darkened(0.25), w * 1.16, true)
	var nrm := dir.orthogonal() * w * 0.58
	draw_colored_polygon(PackedVector2Array([tipp + nrm, b + dir * 1.5, tipp - nrm]), shaft.darkened(0.25))
	draw_line(a, tipp, shaft, w, true)
	draw_colored_polygon(PackedVector2Array([tipp + nrm * 0.86, b, tipp - nrm * 0.86]), shaft)
	draw_line(a - nrm * 0.3, b - dir * 6.0 - nrm * 0.3, shaft.lightened(0.3), w * 0.25, true)
	# 圆头：用线的颜色。
	var kr := 12.0
	draw_circle(a + lift, kr, Color(0.25, 0.2, 0.1, 0.14))
	draw_circle(a, kr * 1.1, YARN.darkened(0.25))
	draw_circle(a, kr, YARN)
	draw_circle(a + Vector2(-0.3, -0.3) * kr, 0.32 * kr, YARN.lightened(0.35))


## 铅笔草图式提示。线状态不对时指向切换动作；状态对时画钩针路径（一串点 + 方向箭头）。
func _draw_hint(col: int) -> void:
	if not _state_ok(col):
		if scheme == 1:
			_draw_tool_hint()
		return     # 方案 A 的提示由虚线圆承担（hint 时加深并带箭头）
	var ec := eye_center(col, row - 1)
	var d := float(dir_of(row))
	var s := 1.0
	var path := _catmull([
		ec + Vector2(-d * 44.0, s * 46.0) * ks,
		ec + Vector2(-d * 10.0, s * 14.0) * ks,
		ec + Vector2(d * 2.0, -s * 34.0) * ks,
		ec + Vector2(d * 20.0, -s * 30.0) * ks,
		ec + Vector2(d * 40.0, s * 46.0) * ks,
	], 12)
	var c := Color(INK, 0.6 * hint_alpha)
	var acc := 0.0
	for k in range(1, path.size()):
		acc += path[k].distance_to(path[k - 1])
		if acc >= 9.0 * ks:
			acc = 0.0
			draw_circle(path[k], 2.4 * ks, c)
	draw_polyline(PackedVector2Array([ec + Vector2(-7, s * 9) * ks, ec, ec + Vector2(7, s * 9) * ks]), c, 2.5 * ks, true)


## 方案 B：从工具到工作线中段的一串铅笔点，末端一个箭头。
func _draw_tool_hint() -> void:
	if rope.size() < 2 or tool_drag:
		return
	var to := rope[rope.size() >> 1]
	var from := TOOL_HOME + Vector2(0, -24)
	var mid := (from + to) * 0.5 + Vector2(-60, 0)
	var path := _catmull([from, mid, to], 16)
	var c := Color(INK, 0.6 * hint_alpha)
	var acc := 0.0
	for k in range(1, path.size()):
		acc += path[k].distance_to(path[k - 1])
		if acc >= 12.0:
			acc = 0.0
			draw_circle(path[k], 2.6, c)
	var dv := (path[path.size() - 1] - path[path.size() - 4]).normalized()
	var nv := dv.orthogonal()
	draw_polyline(PackedVector2Array([to - dv * 12.0 + nv * 8.0, to, to - dv * 12.0 - nv * 8.0]), c, 2.5, true)


func _rect_dist(rect: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(q)

## 右上角的图纸：V = 下针，— = 上针。当前行高亮，下一针圈出。鼠标或线头靠近时变淡。
func _draw_card() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cell := 20.0
	var n_rows := target.size() + 1
	var card_size := Vector2(cols * cell + 44, n_rows * cell + 32)
	var rect := Rect2(Vector2(CANVAS.x - 20.0 - card_size.x, 20.0), card_size)
	var dist := minf(_rect_dist(rect, _hover), _rect_dist(rect, tip) if dragging else 1e6)
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
	var cur_col := next_col()
	for r in n_rows:
		var cy := gy - (r + 0.5) * cell
		if r == row and not completed:
			draw_rect(Rect2(gx - 5, cy - cell * 0.5, cols * cell + 10, cell), Color(YARN, 0.14 * a))
			var ax := gx - 12.0 if dir_of(r) > 0 else gx + cols * cell + 12.0
			var ad := float(dir_of(r))
			draw_colored_polygon(PackedVector2Array([Vector2(ax + ad * 4, cy), Vector2(ax - ad * 3, cy - 4), Vector2(ax - ad * 3, cy + 4)]), Color(YARN, 0.8 * a))
		for i in cols:
			var cx := gx + (i + 0.5) * cell
			var t := "K" if r == 0 else target[r - 1][i]
			var color: Color
			if r == 0:
				color = BASE_YARN
			elif grid[r][i] != null:
				color = YARN
			elif r == row and not completed:
				color = INK
			else:
				color = Color(INK, 0.3)
			color.a *= a
			if t == "K":
				draw_polyline(PackedVector2Array([Vector2(cx - 4.5, cy - 4.5), Vector2(cx, cy + 4.5), Vector2(cx + 4.5, cy - 4.5)]), color, 2.2, true)
			else:
				draw_line(Vector2(cx - 5.5, cy), Vector2(cx + 5.5, cy), color, 2.6, true)
			if r == row and i == cur_col:
				draw_arc(Vector2(cx, cy), 8.5, 0, TAU, 24, Color(YARN, 0.85 * a), 1.4, true)
