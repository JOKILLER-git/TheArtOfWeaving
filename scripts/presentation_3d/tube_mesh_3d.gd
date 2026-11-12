class_name TubeMesh3D
extends RefCounted
## 把一条 3D 折线扫成圆截面的管子（线），写进 ArrayMesh 的一个 surface。
## 截面方向用平行移动（parallel transport）沿线传递，避免扭转。每个点可以有自己的半径与颜色。

const SIDES := 8


## pts：折线点；radii、colors 与 pts 等长（radii 可只给一个值表示全程同粗）。
static func add_tube(mesh: ArrayMesh, pts: PackedVector3Array, radii: PackedFloat32Array, colors: PackedColorArray, material: Material) -> void:
	var n := pts.size()
	if n < 2:
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * SIDES)
	normals.resize(n * SIDES)
	cols.resize(n * SIDES)
	var tangent := (pts[1] - pts[0]).normalized()
	var ref := Vector3(0, 0, 1) if absf(tangent.z) < 0.9 else Vector3(1, 0, 0)
	var normal := tangent.cross(ref).normalized()
	for i in n:
		var t: Vector3
		if i == 0:
			t = pts[1] - pts[0]
		elif i == n - 1:
			t = pts[i] - pts[i - 1]
		else:
			t = pts[i + 1] - pts[i - 1]
		if t.length_squared() < 1e-12:
			t = tangent
		t = t.normalized()
		# 平行移动：把上一个法向投影到新切线的垂直面上。
		normal = (normal - t * normal.dot(t))
		if normal.length_squared() < 1e-10:
			normal = t.cross(ref)
		normal = normal.normalized()
		tangent = t
		var binormal := t.cross(normal)
		var r := radii[i] if radii.size() == n else radii[0]
		var c := colors[i] if colors.size() == n else colors[0]
		for s in SIDES:
			var a := TAU * float(s) / SIDES
			var d := normal * cos(a) + binormal * sin(a)
			verts[i * SIDES + s] = pts[i] + d * r
			normals[i * SIDES + s] = d
			cols[i * SIDES + s] = c
	for i in n - 1:
		for s in SIDES:
			var a0 := i * SIDES + s
			var a1 := i * SIDES + (s + 1) % SIDES
			var b0 := a0 + SIDES
			var b1 := a1 + SIDES
			idx.append_array(PackedInt32Array([a0, b0, a1, a1, b0, b1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## 线用的材质：顶点色作底色，粗糙、略带一点边缘光，像毛线。
static func yarn_material(transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true     # 颜色常量是 sRGB（与 2D 相同的色值）
	m.roughness = 0.95
	m.metallic_specular = 0.2
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Catmull-Rom 采样（3D）。
static func catmull(pts: PackedVector3Array, steps: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	if n < 2:
		return pts
	for k in n - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out
