class_name FabricView2D
extends Node2D
## 织物画面（2D）：下一针的眼、已织线圈（逐行连成一根线）、与工作线的交叉分层、针法不对时滑脱的虚影。
## 每个线圈各部分的前后关系从 StitchType.new_loop_in_front() 读取。

var _session: KnitSession
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _hook: HookGesture
var _yarn: WorkingYarn2D
var _forms: Dictionary[Vector2i, float] = {}    # 新线圈的成形进度（列, 行）→ 0..1
var _ghost_cell := Vector2i(-1, -1)
var _ghost_form: float = 0.0
var _eye_flash: float = 0.0
var _ghost_tween: Tween
var _time: float = 0.0


func setup(session: KnitSession, layout: FabricLayout, mapper: ScreenMapper2D, hook: HookGesture, yarn: WorkingYarn2D) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	_hook = hook
	_yarn = yarn
	_forms.clear()
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_form = 0.0
	_eye_flash = 0.0


## 新线圈从钩出点「长」出来。
func grow_stitch(row: int, col: int) -> void:
	var cell := Vector2i(col, row)
	_forms[cell] = 0.25
	create_tween().tween_method(func(v: float) -> void: _forms[cell] = v, 0.25, 1.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 针法不对：线圈成形一下又滑脱（不惩罚）。
func show_rejected(row: int, col: int) -> void:
	_ghost_cell = Vector2i(col, row)
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.tween_method(_set_ghost_form, 0.2, 0.9, 0.12)
	_ghost_tween.tween_method(_set_ghost_form, 0.9, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 穿错了眼：下一针的眼闪一下。
func flash_next_eye() -> void:
	create_tween().tween_method(func(v: float) -> void: _eye_flash = v, 1.0, 0.0, 0.6)


func _set_ghost_form(v: float) -> void:
	_ghost_form = v


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _session == null:
		return
	_draw_next_eye()
	var strands: Array[Strand2D] = []
	for r in _layout.rows():
		if r == 0 or r <= _session.current_row:
			strands.append(_row_strand(r))
	var rope := _yarn.build_strand()
	strands.append(rope)

	var crossings: Array[StrandPainter2D.Crossing] = []
	for a in strands.size():
		for b in range(a + 1, strands.size()):
			var sa := strands[a]
			var sb := strands[b]
			if sa.kind == Strand2D.Kind.FABRIC and sb.kind == Strand2D.Kind.FABRIC and absi(sa.row - sb.row) != 1:
				continue
			StrandPainter2D.find_crossings(sa, sb, _over_rule, crossings)

	# 工作线在后面时整根先画（被织物盖住），在前面时最后画（压在织物上）。
	var fabric: Array[Strand2D] = []
	for st in strands:
		if st.kind == Strand2D.Kind.FABRIC and st.is_drawable():
			fabric.append(st)
	var rope_layer: Array[Strand2D] = []
	if rope.is_drawable():
		rope_layer.append(rope)
	if not _yarn.is_front():
		StrandPainter2D.draw_layer(self, rope_layer)
	StrandPainter2D.draw_layer(self, fabric)
	if _yarn.is_front():
		StrandPainter2D.draw_layer(self, rope_layer)
	for x in crossings:
		StrandPainter2D.draw_under(self, x)
	# 先重画织物在前的交叉，再重画工作线在前的交叉。
	for x in crossings:
		if x.over.kind == Strand2D.Kind.FABRIC:
			StrandPainter2D.draw_over(self, x)
	for x in crossings:
		if x.over.kind == Strand2D.Kind.ROPE:
			StrandPainter2D.draw_over(self, x)
	_draw_ghost()


## 眼：靠近时透出亮光，告诉玩家「这里可以穿过去」。
func _draw_next_eye() -> void:
	var col := _session.next_column()
	if col < 0:
		return
	var ks := _mapper.scale_k()
	var r := HookGesture.ENTER_RADIUS * _mapper.col_px
	var ec := _mapper.to_screen(_layout.eye_center(col, _session.current_row - 1))
	var near := 0.0
	if _yarn.held:
		near = clampf(1.0 - (_yarn.tip.distance_to(ec) - 20.0 * ks) / (140.0 * ks), 0.0, 1.0)
	var pulse := 0.25 + 0.15 * sin(_time * 3.0)
	var glow := maxf(maxf(near, pulse), _eye_flash)
	draw_circle(ec, r, Color(1, 1, 0.95, 0.35 + 0.5 * glow))
	draw_arc(ec, r + 3.0 * ks, 0, TAU, 48, Color(StrandPainter2D.YARN, 0.25 + 0.5 * maxf(near, _eye_flash)), 1.5 * ks, true)


func _draw_ghost() -> void:
	if _ghost_form <= 0.01:
		return
	var f := _ghost_form
	draw_set_transform(Vector2(sin(_time * 70.0) * 3.0 * _mapper.scale_k() * f, 0), 0.0, Vector2.ONE)
	var keys := _mapper.to_screen_all(_layout.loop_keys(_ghost_cell.x, _ghost_cell.y, f))
	draw_polyline(Strand2D.catmull(keys, Strand2D.STEPS), Color(StrandPainter2D.YARN, 0.55 * f), _mapper.yarn_width() * 0.9, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 一行线：行首折返弧 + 已织好的线圈（起始行再加线尾），作为一根连续的线。
func _row_strand(r: int) -> Strand2D:
	var color := StrandPainter2D.BASE_YARN if r == 0 else StrandPainter2D.YARN
	var st := Strand2D.new(Strand2D.Kind.FABRIC, r, color, _mapper.yarn_width())
	var flat_z: Array[float] = [0.0, 0.0]
	var flat_t: Array[float] = [0.0, 0.0, 0.0]
	var side := 0
	var arc: Array[Vector2] = []
	# 正在织、还没起针的这一行：折返弧算作工作线的一部分。
	if r >= 1 and not _layout.is_turn_loose(r):
		side = _layout.turn_side(r)
		arc = _mapper.to_screen_all(_layout.turn_arc(r))
	if side < 0:
		st.append_spline(arc, flat_z, flat_t, -1)
	for col in _layout.columns():
		if not _session.fabric.has_stitch(r, col):
			continue
		var keys := _mapper.to_screen_all(_layout.loop_keys(col, r, _forms.get(Vector2i(col, r), 1.0)))
		var seg_z: Array[float] = []
		var tones: Array[float] = []
		_loop_attrs(col, r, seg_z, tones)
		st.append_spline(keys, seg_z, tones, col)
	if side > 0:
		st.append_spline(arc, flat_z, flat_t, -1)
	if r == 0:
		var sx := _mapper.col_px
		var t0 := _mapper.to_screen(Vector2(_layout.edge_x(1), _layout.sinker_y(0)))
		var tail: Array[Vector2] = [t0, t0 + Vector2(0.2, 0.15) * sx, t0 + Vector2(0.26, 0.4) * sx]
		st.append_spline(tail, flat_z, flat_t, -1)
	return st


## 一个线圈每段的 z 和每个关键点的明暗。
## 新线圈腿在前（下针）：腿 z=+1，沉降弧 z=-1；腿在后（上针）相反。线圈头恒为 z=0，
## 所以相邻两行的每个交叉点都能直接比出前后。
func _loop_attrs(col: int, r: int, seg_z: Array[float], tones: Array[float]) -> void:
	var stitch := _session.fabric.stitch_at(r, col)
	var above := _session.fabric.stitch_at(r + 1, col)
	var leg_front := stitch.new_loop_in_front()
	var zb := 1.0 if leg_front else -1.0
	var tb := 0.3 if leg_front else -0.8
	var tc := -0.55 if leg_front else 0.35
	if r == 0:
		tb = 0.0
		tc = 0.0
	var th := 0.0
	if above != null:
		# 上一行的腿压在前面时本线圈头偏暗；上一行腿在后面时，本线圈头横压在前面成为颗粒。
		th = -0.35 if above.new_loop_in_front() else 0.4
	var half: Array[float] = [tc, tc, (tb + tc) * 0.5, tb, 0.0, th, th]
	tones.assign(half)
	for k in range(half.size() - 2, -1, -1):
		tones.append(half[k])
	for seg in FabricLayout.LOOP_SEGMENTS:
		match FabricLayout.loop_part(seg):
			FabricLayout.LoopPart.HEAD:
				seg_z.append(0.0)
			FabricLayout.LoopPart.LEG:
				seg_z.append(zb)
			_:
				seg_z.append(-zb)


## 交叉点上 a 在前返回 1，b 在前返回 -1，无所谓返回 0。
func _over_rule(a: Strand2D, sa: int, b: Strand2D, sb: int) -> int:
	var rope_a := a.kind == Strand2D.Kind.ROPE
	if rope_a or b.kind == Strand2D.Kind.ROPE:
		var fab := b if rope_a else a
		var col := fab.cols[sb if rope_a else sa]
		# 工作线整体在织物前或后；正在钩的那个旧线圈例外：
		# 线在后 → 新线从后往前穿出，旧线圈头在线后面；线在前 → 旧线圈头压在线前面。
		var front := _yarn.is_front()
		if fab.row == _session.current_row - 1 and col >= 0 and _hook.is_threading(col):
			front = not front
		return 1 if rope_a == front else -1
	var za := a.z[sa]
	var zb := b.z[sb]
	if is_equal_approx(za, zb):
		return 0
	return 1 if za > zb else -1
