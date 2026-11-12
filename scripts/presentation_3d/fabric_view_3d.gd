class_name FabricView3D
extends Node3D
## 织物画面（3D）：每一行线（行首折返弧 + 已织线圈）扫成一根管子；下一针的眼是一块发光的圆片；
## 针法不对时滑脱的虚影是一根半透明的管子。
## 深度：与 FabricView2D 的分段前后规则相同——线圈头 z = 0；StitchType.new_loop_in_front() 为真时
## 腿在前（z > 0）、沉降弧在后（z < 0），否则相反。相邻两行在交叉处于是真的前后穿过。

const STEPS := 6                # 每段样条采样数
const DEPTH := 0.12             # 腿 / 沉降弧离织物平面的深度（世界单位）
const RADIUS := 0.042           # 线的半径（世界单位）
const Z_SMOOTH := 3             # z 沿线平滑的窗口（采样点）
const EYE_GLOW_RADIUS := 0.26   # 眼的光圈半径（线圈宽）

var _session: KnitSession
var _layout: FabricLayout
var _mapper: CameraMapper3D
var _hook: HookGesture
var _yarn: WorkingYarn3D
var _rows: Array[MeshInstance3D] = []
var _dirty: Dictionary[int, bool] = {}
var _forms: Dictionary[Vector2i, float] = {}    # 新线圈的成形进度（列, 行）→ 0..1
var _ghost_cell := Vector2i(-1, -1)
var _ghost_form: float = 0.0
var _ghost_tween: Tween
var _eye_flash: float = 0.0
var _time: float = 0.0
var _material := TubeMesh3D.yarn_material()
var _ghost_material := TubeMesh3D.yarn_material(true)
var _ghost: MeshInstance3D
var _eye: MeshInstance3D
var _eye_ring: MeshInstance3D
var _eye_mat := StandardMaterial3D.new()
var _ring_mat := StandardMaterial3D.new()


func _ready() -> void:
	_ghost = MeshInstance3D.new()
	add_child(_ghost)
	for m: StandardMaterial3D in [_eye_mat, _ring_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eye = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.height = 0.004
	disc.radial_segments = 32
	disc.rings = 1
	_eye.mesh = disc
	_eye.material_override = _eye_mat
	_eye.rotation.x = PI * 0.5
	add_child(_eye)
	_eye_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.rings = 32
	torus.ring_segments = 6
	_eye_ring.mesh = torus
	_eye_ring.material_override = _ring_mat
	_eye_ring.rotation.x = PI * 0.5
	add_child(_eye_ring)


func setup(session: KnitSession, layout: FabricLayout, mapper: CameraMapper3D, hook: HookGesture, yarn: WorkingYarn3D) -> void:
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
	for mi in _rows:
		mi.queue_free()
	_rows.clear()
	for r in layout.rows():
		var mi := MeshInstance3D.new()
		add_child(mi)
		_rows.append(mi)
		_dirty[r] = true


## 新线圈从钩出点「长」出来。
func grow_stitch(row: int, col: int) -> void:
	var cell := Vector2i(col, row)
	_forms[cell] = 0.25
	_mark_row(row)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_forms[cell] = v
		_mark_row(row), 0.25, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 针法不对：线圈成形一下又滑脱。
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


## 剪断时用：第 min_row 行及以上每个线圈投影到屏幕上的折线（给 2D 散开效果）。
func snapshot_loops(min_row: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if _session == null:
		return out
	for r in range(min_row, _layout.rows()):
		for col in _layout.columns():
			if _session.fabric.has_stitch(r, col):
				out.append(Strand2D.catmull(_mapper.to_screen_all(_layout.loop_keys(col, r)), 6))
	return out


## 线圈之间相邻的行（上一行决定本行线圈头的明暗）也要重建。
func _mark_row(row: int) -> void:
	_dirty[row] = true
	if row > 0:
		_dirty[row - 1] = true


func _set_ghost_form(v: float) -> void:
	_ghost_form = v
	_build_ghost()


func _process(delta: float) -> void:
	if _session == null:
		return
	_time += delta
	# 还没起针的行首折返弧属于工作线：起针 / 换行时重建相关行。
	for r in _dirty.keys():
		if r < _rows.size():
			_build_row(r)
	_dirty.clear()
	_update_eye()


func _update_eye() -> void:
	var col := _session.next_column()
	_eye.visible = col >= 0
	_eye_ring.visible = col >= 0
	if col < 0:
		return
	var ec := _layout.eye_center(col, _session.current_row - 1)
	var r := EYE_GLOW_RADIUS * _layout.loop_width * CameraMapper3D.COL_W
	var near := 0.0
	if _yarn != null and _yarn.handle.held:
		var ks := _mapper.scale_k()
		near = clampf(1.0 - (_yarn.handle.tip.distance_to(_mapper.to_screen(ec)) - 20.0 * ks) / (140.0 * ks), 0.0, 1.0)
	var pulse := 0.25 + 0.15 * sin(_time * 3.0)
	var glow := maxf(maxf(near, pulse), _eye_flash)
	var pos := CameraMapper3D.to_world(ec, -0.02)
	_eye.position = pos
	(_eye.mesh as CylinderMesh).top_radius = r
	(_eye.mesh as CylinderMesh).bottom_radius = r
	_eye_mat.albedo_color = Color(1, 1, 0.95, 0.35 + 0.5 * glow)
	_eye_ring.position = pos
	var torus := _eye_ring.mesh as TorusMesh
	torus.inner_radius = r * 1.08
	torus.outer_radius = r * 1.16
	_ring_mat.albedo_color = Color(StrandPainter2D.YARN, 0.25 + 0.5 * maxf(near, _eye_flash))


func _build_ghost() -> void:
	var mesh := ArrayMesh.new()
	if _ghost_form > 0.01:
		var f := _ghost_form
		var keys := _layout.loop_keys(_ghost_cell.x, _ghost_cell.y, f)
		var pts := PackedVector3Array()
		for k in keys:
			pts.append(CameraMapper3D.to_world(k, DEPTH * 0.5))
		var shake := Vector3(sin(_time * 70.0) * 0.03 * f, 0, 0)
		var samples := TubeMesh3D.catmull(pts, STEPS)
		for i in samples.size():
			samples[i] += shake
		TubeMesh3D.add_tube(mesh, samples, PackedFloat32Array([RADIUS * 0.9]), PackedColorArray([Color(StrandPainter2D.YARN, 0.55 * f)]), _ghost_material)
	_ghost.mesh = mesh


## 一行线：行首折返弧 + 已织好的线圈（起始行再加线尾），作为一根连续的管子。
func _build_row(r: int) -> void:
	var mesh := ArrayMesh.new()
	_rows[r].mesh = mesh
	if not (r == 0 or r <= _session.current_row):
		return
	var color := StrandPainter2D.BASE_YARN if r == 0 else StrandPainter2D.YARN
	# 借用 Strand2D 做样条采样与分段属性（这里装的是织物坐标，不是像素）。
	var st := Strand2D.new(Strand2D.Kind.FABRIC, r, color, RADIUS)
	var flat_z: Array[float] = [0.0, 0.0]
	var flat_t: Array[float] = [0.0, 0.0, 0.0]
	var side := 0
	var arc: Array[Vector2] = []
	if r >= 1 and not _layout.is_turn_loose(r):
		side = _layout.turn_side(r)
		arc = _layout.turn_arc(r)
	if side < 0:
		st.append_spline(arc, flat_z, flat_t, -1)
	for col in _layout.columns():
		if not _session.fabric.has_stitch(r, col):
			continue
		var keys := _layout.loop_keys(col, r, _forms.get(Vector2i(col, r), 1.0))
		var seg_z: Array[float] = []
		var tones: Array[float] = []
		_loop_attrs(col, r, seg_z, tones)
		st.append_spline(keys, seg_z, tones, col)
	if side > 0:
		st.append_spline(arc, flat_z, flat_t, -1)
	if r == 0:
		var t0 := Vector2(_layout.edge_x(1), _layout.sinker_y(0))
		var tail: Array[Vector2] = [t0, t0 + Vector2(0.2, -0.22), t0 + Vector2(0.26, -0.6)]
		st.append_spline(tail, flat_z, flat_t, -1)
	if not st.is_drawable():
		return
	var n := st.points.size()
	# 每点的 z：取两侧分段的平均，再沿线平滑，交叉点附近接近满深度、转折处平滑过渡。
	var z := PackedFloat32Array()
	z.resize(n)
	for i in n:
		var a := st.z[clampi(i - 1, 0, st.z.size() - 1)]
		var b := st.z[clampi(i, 0, st.z.size() - 1)]
		z[i] = (a + b) * 0.5
	z = _smooth(z, Z_SMOOTH)
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	pts.resize(n)
	cols.resize(n)
	for i in n:
		pts[i] = CameraMapper3D.to_world(st.points[i], z[i] * DEPTH)
		cols[i] = StrandPainter2D.shade(color, st.tones[i] * 0.5)
	TubeMesh3D.add_tube(mesh, pts, PackedFloat32Array([RADIUS]), cols, _material)


static func _smooth(v: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(v.size())
	for i in v.size():
		var acc := 0.0
		var cnt := 0
		for j in range(i - radius, i + radius + 1):
			if j >= 0 and j < v.size():
				acc += v[j]
				cnt += 1
		out[i] = acc / cnt
	return out


## 一个线圈每段的 z 和每个关键点的明暗（规则同 FabricView2D._loop_attrs）。
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
