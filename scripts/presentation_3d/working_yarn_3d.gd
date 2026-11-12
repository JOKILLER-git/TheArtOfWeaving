class_name WorkingYarn3D
extends Node3D
## 工作线（3D）：世界坐标里的 Verlet 绳，两端固定在锚点（织物上）与线头，扫成管子。
## Yarn.side = BACK 时整根线沉到织物后面（z < 0），FRONT 时浮到前面（z > 0），切换时深度补间、线身甩一下；
## 钩针过程中（HookGesture.is_threading）线头一段穿到另一面——真的从眼里钻过去。
## 线头的屏幕位置与抓取状态放在 YarnHandle 里，与 2D 共用同一套指针输入与叠加层。

const ROPE_N := 18
const FLIP_TIME := 0.38     # 翻面动画时长（秒）
const GRAB_RADIUS := 44.0   # 参考尺寸下的抓取半径（像素）
const SIDE_DEPTH := 0.34    # 工作线离织物平面的深度（世界单位）
const RADIUS := 0.042       # 线的半径（与织物一致）
const GRAVITY := 16.0       # 世界单位 / 秒²
const STEPS := 4

var handle := YarnHandle.new()
var front_v: float = 0.0    # 0 = 后，1 = 前，翻面时补间
var flip_k: float = 1.0     # 翻面动画进度（1 = 静止）

var _session: KnitSession
var _layout: FabricLayout
var _mapper: CameraMapper3D
var _hook: HookGesture
var _rope := PackedVector3Array()
var _rope_prev := PackedVector3Array()
var _flip_tween: Tween
var _time: float = 0.0
var _tube: MeshInstance3D
var _knob: MeshInstance3D
var _material := TubeMesh3D.yarn_material()
var _knob_mat := StandardMaterial3D.new()


func _ready() -> void:
	_tube = MeshInstance3D.new()
	add_child(_tube)
	_knob = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS * 1.9
	sphere.height = RADIUS * 3.8
	sphere.radial_segments = 16
	sphere.rings = 8
	_knob.mesh = sphere
	_knob_mat.roughness = 0.8
	_knob.material_override = _knob_mat
	add_child(_knob)


func setup(session: KnitSession, layout: FabricLayout, mapper: CameraMapper3D, hook: HookGesture) -> void:
	_session = session
	_layout = layout
	_mapper = mapper
	_hook = hook
	if _flip_tween:
		_flip_tween.kill()
	handle.held = false
	front_v = 1.0 if session.yarn.is_front() else 0.0
	flip_k = 1.0
	handle.tip = _rest_tip()
	_rope = PackedVector3Array()
	_sync_handle()


func is_front() -> bool:
	return front_v >= 0.5


func anchor_px() -> Vector2:
	return _mapper.to_screen(_layout.anchor())


## 线翻到另一面：深度补间（线身穿过织物平面），中段沿深度方向甩一下。
func flip_to(side: Yarn.Face) -> void:
	var front := side == Yarn.Face.FRONT
	if _flip_tween:
		_flip_tween.kill()
	_flip_tween = create_tween().set_parallel(true)
	_flip_tween.tween_property(self, "front_v", 1.0 if front else 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_property(self, "flip_k", 1.0, FLIP_TIME).from(0.0)
	if _rope.size() == ROPE_N:
		var s := 1.0 if front else -1.0
		for k in range(1, ROPE_N - 1):
			var f := sin(PI * float(k) / (ROPE_N - 1))
			_rope_prev[k] -= Vector3(0, 0, 0.12 * f * s)


## 工作线投影到屏幕上的点（剪刀命中判定与剪断效果用）。
func screen_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _rope:
		out.append(_mapper.world_to_screen(p))
	return out


## 当前一面的深度：-SIDE_DEPTH（后）… +SIDE_DEPTH（前）。
func side_depth() -> float:
	return lerpf(-SIDE_DEPTH, SIDE_DEPTH, front_v)


func _sync_handle() -> void:
	handle.enabled = not _session.completed
	handle.grab_radius = GRAB_RADIUS * _mapper.scale_k()


func _rest_tip() -> Vector2:
	return _mapper.to_screen(_layout.rest_tip())


## 线头那一端的深度：钩针穿眼时到另一面。
func _tip_depth() -> float:
	var d := side_depth()
	var col := _session.next_column()
	if handle.held and col >= 0 and _hook != null and _hook.is_threading(col):
		d = -d
	return d


func _process(delta: float) -> void:
	if _session == null:
		return
	_time += delta
	_sync_handle()
	if not handle.held:
		handle.tip = handle.tip.lerp(_rest_tip(), 1.0 - exp(-10.0 * delta))
	_step_rope(delta)
	_build_mesh()


func _step_rope(delta: float) -> void:
	var a := CameraMapper3D.to_world(_layout.anchor())
	var b := _mapper.screen_to_world(handle.tip, _tip_depth())
	if _rope.size() != ROPE_N:
		_rope.resize(ROPE_N)
		for k in ROPE_N:
			_rope[k] = a.lerp(b, float(k) / (ROPE_N - 1))
			_rope[k].z = side_depth() if k > 0 else 0.0
		_rope_prev = _rope.duplicate()
	var seg := maxf(a.distance_to(b) * 1.08, 0.5) / (ROPE_N - 1)
	var g := Vector3(0, -GRAVITY, 0) * delta * delta
	var depth := side_depth()
	var tip_depth := _tip_depth()
	for k in range(1, ROPE_N - 1):
		var p := _rope[k]
		var v := (p - _rope_prev[k]) * 0.95
		_rope_prev[k] = p
		p += v + g
		# 线身靠向它所在的那一面：离锚点越远越完全；线头附近跟随线头的深度。
		var u := float(k) / (ROPE_N - 1)
		var want := lerpf(depth, tip_depth, smoothstep(0.7, 1.0, u)) * smoothstep(0.0, 0.18, u)
		p.z = lerpf(p.z, want, 0.25)
		_rope[k] = p
	_rope[0] = a
	_rope[ROPE_N - 1] = b
	for _it in 12:
		for k in ROPE_N - 1:
			var p1 := _rope[k]
			var p2 := _rope[k + 1]
			var dv := p2 - p1
			var dist := dv.length()
			if dist <= seg or dist < 0.0001:
				continue
			var diff := (dist - seg) / dist
			if k == 0:
				_rope[k + 1] = p2 - dv * diff
			elif k + 1 == ROPE_N - 1:
				_rope[k] = p1 + dv * diff
			else:
				_rope[k] = p1 + dv * diff * 0.5
				_rope[k + 1] = p2 - dv * diff * 0.5
		_rope[0] = a
		_rope[ROPE_N - 1] = b


func _build_mesh() -> void:
	var mesh := ArrayMesh.new()
	_tube.mesh = mesh
	_knob.visible = not _session.completed
	# 用本地副本：窗口改变大小时 setup() 可能在本帧中途清空 _rope。
	var rope := _rope
	if _session.completed or rope.size() != ROPE_N:
		return
	var pts := TubeMesh3D.catmull(rope, STEPS)
	var row := _session.current_row
	if row >= 1 and _layout.is_turn_loose(row):
		# 还没起针：行首折返弧也是工作线的一部分（从下一行的沉降弧接到锚点）。
		var arc := _layout.turn_arc(row)
		if _layout.turn_side(row) > 0:
			arc.reverse()
		var arc3 := PackedVector3Array()
		for p in arc:
			arc3.append(CameraMapper3D.to_world(p))
		var joined := TubeMesh3D.catmull(arc3, STEPS)
		joined.append_array(pts.slice(1))
		pts = joined
	var w := RADIUS * lerpf(0.8, 1.0, front_v) * (1.0 + 0.3 * sin(PI * flip_k))
	var color := StrandPainter2D.YARN.darkened(lerpf(0.25, 0.0, front_v)).lightened(0.06 * front_v)
	TubeMesh3D.add_tube(mesh, pts, PackedFloat32Array([w]), PackedColorArray([color]), _material)
	# 线头：一颗小球；没抓住时轻轻呼吸，提示可以抓。
	_knob.position = rope[ROPE_N - 1]
	var pulse := 1.0 if handle.held else 1.0 + 0.12 * sin(_time * 3.0)
	_knob.scale = Vector3.ONE * pulse * (0.8 if handle.held else 1.0)
	_knob_mat.albedo_color = StrandPainter2D.YARN.darkened(0.1 + 0.2 * (1.0 - front_v))
