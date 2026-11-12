class_name CameraMapper3D
extends FabricScreenMapper
## FabricScreenMapper 的 3D 实现：织物平面是世界坐标 z = 0 的平面，x = 列 × COL_W，y = 行 × ROW_H。
## 织物 → 屏幕：Camera3D.unproject_position；屏幕 → 织物：鼠标射线与 z = 0 平面求交。
## fit 时按关卡大小调整相机距离与对准点，使织物（含绕线提示圆的余量）放进去掉叠加层边距后的区域。
## 相机轻微俯视（TILT_DEG）并带透视；orbit 为右键拖动的额外转动（度），由 KnitLevel3D 设置。

const LOOP_WIDTH := 0.72    # 线圈占列宽的比例（与 2D 一致，传给 FabricLayout）
const COL_W := 1.0          # 一列的世界宽度
const ROW_H := 0.65         # 一行的世界高度（与 2D 行高 ≈ 0.9 × 线圈宽一致）
const TILT_DEG := 18.0      # 俯视角
const FOV_DEG := 30.0
const MAX_COL_PX := 260.0   # 单个线圈宽度上限（像素），小关卡不至于放得过大
const PAD_X := 24.0         # 叠加层边距（像素），同 2D：上方进度珠与图纸卡，下方剪刀
const PAD_TOP := 84.0
const PAD_BOTTOM := 56.0
const SIDE_UNITS := WrapGesture.HINT_RADIUS + 0.12  # 织物左右要容纳提示圆（列宽）
const TAIL_UNITS := 0.6     # 起始行线尾（列宽）
const FIT_ITERATIONS := 8

var camera: Camera3D
## 额外转动（度）：x = 绕竖轴偏航，y = 俯仰。
var orbit := Vector2.ZERO:
	set(v):
		orbit = v
		_apply_camera()
var _target := Vector3.ZERO
var _distance: float = 12.0


func _init(p_camera: Camera3D) -> void:
	camera = p_camera
	camera.fov = FOV_DEG
	loop_width = LOOP_WIDTH


## 织物坐标 + 离织物平面的深度 z → 世界坐标。
static func to_world(fabric_point: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(fabric_point.x * COL_W, fabric_point.y * ROW_H, z)


static func from_world(p: Vector3) -> Vector2:
	return Vector2(p.x / COL_W, p.y / ROW_H)


func to_screen(fabric_point: Vector2) -> Vector2:
	return camera.unproject_position(to_world(fabric_point))


func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


func to_fabric(screen_point: Vector2) -> Vector2:
	return from_world(screen_to_world(screen_point, 0.0))


## 鼠标射线与平面 z = depth 的交点（世界坐标）。射线与平面平行时返回射线起点附近的点。
func screen_to_world(screen_point: Vector2, depth: float) -> Vector3:
	var origin := camera.project_ray_origin(screen_point)
	var dir := camera.project_ray_normal(screen_point)
	if absf(dir.z) < 1e-5:
		return origin
	var t := (depth - origin.z) / dir.z
	return origin + dir * t


func fit(layout: FabricLayout, view: Rect2) -> void:
	loop_width = layout.loop_width
	var area := Rect2(view.position + Vector2(PAD_X, PAD_TOP),
		view.size - Vector2(2.0 * PAD_X, PAD_TOP + PAD_BOTTOM))
	var lo := Vector2(layout.edge_x(-1) - SIDE_UNITS, layout.sinker_y(0) - TAIL_UNITS / ROW_H * COL_W)
	var hi := Vector2(layout.edge_x(1) + SIDE_UNITS, float(layout.session.last_row()) + FabricLayout.LOOP_TOP)
	var corners: Array[Vector3] = [to_world(lo), to_world(Vector2(hi.x, lo.y)), to_world(hi), to_world(Vector2(lo.x, hi.y))]
	_target = (corners[0] + corners[2]) * 0.5
	_distance = maxf(hi.x - lo.x, (hi.y - lo.y) * ROW_H) * 2.0
	var saved := orbit
	orbit = Vector2.ZERO
	# 透视下屏幕大小 ≈ 与距离成反比：反复按比例缩放距离，并把投影中心挪到区域中心。
	for _i in FIT_ITERATIONS:
		_apply_camera()
		var rect := _screen_bounds(corners)
		var k := maxf(rect.size.x / area.size.x, rect.size.y / area.size.y)
		_distance *= k
		_apply_camera()
		_update_scale(layout)
		var shift := area.get_center() - _screen_bounds(corners).get_center()
		_target -= camera.global_transform.basis * Vector3(shift.x / col_px * COL_W, -shift.y / col_px * COL_W, 0.0)
	# 小关卡：线圈不要放得过大。
	if col_px > MAX_COL_PX:
		_distance *= col_px / MAX_COL_PX
		for _i in 3:
			_apply_camera()
			_update_scale(layout)
			var shift := area.get_center() - _screen_bounds(corners).get_center()
			_target -= camera.global_transform.basis * Vector3(shift.x / col_px * COL_W, -shift.y / col_px * COL_W, 0.0)
	orbit = saved
	_update_scale(layout)


func _apply_camera() -> void:
	if camera == null:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(-TILT_DEG - orbit.y), deg_to_rad(orbit.x), 0.0))
	camera.global_transform = Transform3D(basis, _target + basis.z * _distance)


## 织物中心附近一列、一行在屏幕上的像素数（叠加层的线粗、提示圆大小按它算）。
func _update_scale(layout: FabricLayout) -> void:
	var c := Vector2((layout.edge_x(-1) + layout.edge_x(1)) * 0.5, layout.vertical_span() * 0.5 - FabricLayout.LOOP_BOT)
	col_px = to_screen(c + Vector2(0.5, 0.0)).distance_to(to_screen(c - Vector2(0.5, 0.0)))
	row_px = to_screen(c + Vector2(0.0, 0.5)).distance_to(to_screen(c - Vector2(0.0, 0.5)))
	if col_px < 1e-3:
		col_px = REF_COL_PX


func _screen_bounds(points: Array[Vector3]) -> Rect2:
	var rect := Rect2(camera.unproject_position(points[0]), Vector2.ZERO)
	for q in points:
		rect = rect.expand(camera.unproject_position(q))
	return rect
