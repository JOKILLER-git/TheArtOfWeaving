class_name StrandPainter2D
extends RefCounted
## 线的绘制工具：先把所有线按「阴影 → 描边 → 填充 → 高光」分层画一遍；
## 再求出交叉点并判定谁在前：后面的线在交叉处局部压暗，前面的线先画一圈
## 间隙色描边再重画自己，于是后面的线看起来在交叉处断开、被压住。

const BASE_YARN := Color("a9ad94")
const YARN := Color("c27c63")
const INK := Color("5b5446")
const GAP := Color("e9e2d4")    # 交叉处的间隙描边，比背景略深
const SHADOW := Color(0.25, 0.2, 0.1)


## 一个交叉点：over 在前，under 在后。
class Crossing:
	var over: Strand2D
	var over_seg: int
	var under: Strand2D
	var under_seg: int
	var point: Vector2

	func _init(p_over: Strand2D, p_over_seg: int, p_under: Strand2D, p_under_seg: int, p_point: Vector2) -> void:
		over = p_over
		over_seg = p_over_seg
		under = p_under
		under_seg = p_under_seg
		point = p_point


## 明暗：t > 0 偏亮（在前），t < 0 偏暗（在后）。
static func shade(base: Color, t: float) -> Color:
	if t >= 0.0:
		return base.lightened(t * 0.25)
	return base.darkened(-t * 0.32)


## 求 a、b 两根线的交叉点。over_rule(a, seg_a, b, seg_b) 返回 1（a 在前）、-1（b 在前）或 0（不画）。
static func find_crossings(a: Strand2D, b: Strand2D, over_rule: Callable, out: Array[Crossing]) -> void:
	if not a.is_drawable() or not b.is_drawable():
		return
	var pa := a.points
	var pb := b.points
	var ca := _chunks(pa)
	var cb := _chunks(pb)
	var ends: Array[Vector2] = [pa[0], pa[pa.size() - 1], pb[0], pb[pb.size() - 1]]
	var has_rope := a.kind == Strand2D.Kind.ROPE or b.kind == Strand2D.Kind.ROPE
	var w := a.width if a.kind == Strand2D.Kind.FABRIC else b.width
	var end_gap := (0.8 if has_rope else 0.6) * w
	for ia in ca.size():
		for ib in cb.size():
			if not ca[ia].intersects(cb[ib], true):
				continue
			for sa in range(ia * Strand2D.STEPS, mini((ia + 1) * Strand2D.STEPS, pa.size() - 1)):
				for sb in range(ib * Strand2D.STEPS, mini((ib + 1) * Strand2D.STEPS, pb.size() - 1)):
					var hit: Variant = Geometry2D.segment_intersects_segment(pa[sa], pa[sa + 1], pb[sb], pb[sb + 1])
					if hit == null:
						continue
					var p: Vector2 = hit
					# 线与线首尾相接处不算交叉；工作线刚离开织物的一小段也不算。
					if _near_any(p, ends, end_gap) or _near_crossing(p, out, 0.3 * w):
						continue
					var o: int = over_rule.call(a, sa, b, sb)
					if o > 0:
						out.append(Crossing.new(a, sa, b, sb, p))
					elif o < 0:
						out.append(Crossing.new(b, sb, a, sa, p))


## 画一层线（同一层内的线按顺序叠放）。
static func draw_layer(ci: CanvasItem, strands: Array[Strand2D]) -> void:
	for st in strands:
		var w := st.width
		ci.draw_polyline(_offset(st.points, Vector2(0.08, 0.16) * w * (1.0 + 6.0 * maxf(0.0, st.shadow - 0.1))), Color(SHADOW, st.shadow), w * 1.15, true)
	for st in strands:
		var edge := _colors(st, 0.22)
		ci.draw_polyline_colors(st.points, edge, st.width * 1.16, true)
		_draw_caps(ci, st.points, edge, st.width * 0.58)
	for st in strands:
		var fill := _colors(st, 0.0)
		ci.draw_polyline_colors(st.points, fill, st.width, true)
		_draw_caps(ci, st.points, fill, st.width * 0.5)
	for st in strands:
		ci.draw_polyline_colors(_offset(st.points, Vector2(-0.1, -0.15) * st.width), _colors(st, -0.28), st.width * 0.25, true)


## 后面的线：交叉处附近压暗。
static func draw_under(ci: CanvasItem, x: Crossing) -> void:
	var w := x.under.width
	var wu := _window(x.under.points, x.under_seg, x.point, 2.0 * w)
	ci.draw_polyline_colors(wu, _fade(wu, x.point, Color(0.16, 0.09, 0.03, 0.22), 0.5 * w, 2.0 * w), w * 1.02, true)


## 前面的线：投一点短阴影，外圈画间隙色（两端渐隐），再把自己重画一遍。
static func draw_over(ci: CanvasItem, x: Crossing) -> void:
	var o := x.over
	var w := o.width
	var p := x.point
	var c := shade(o.base_color, o.tones[x.over_seg])
	var wg := _window(o.points, x.over_seg, p, 1.5 * w)
	var wf := _window(o.points, x.over_seg, p, 2.1 * w)
	var shadow_offset := Vector2(0.12, 0.3) * w
	var ws := _offset(wg, shadow_offset)
	ci.draw_polyline_colors(ws, _fade(ws, p + shadow_offset, Color(0.2, 0.12, 0.05, 0.18), 0.6 * w, 1.5 * w), w * 1.25, true)
	ci.draw_polyline_colors(wg, _fade(wg, p, GAP, 0.75 * w, 1.5 * w), w * 1.6, true)
	# 重画的这一小段两端渐隐，和底层同色的线自然衔接，不留接缝。
	ci.draw_polyline_colors(wf, _fade(wf, p, c.darkened(0.22), 1.3 * w, 2.1 * w), w * 1.16, true)
	ci.draw_polyline_colors(wf, _fade(wf, p, c, 1.3 * w, 2.1 * w), w, true)
	var light_offset := Vector2(-0.1, -0.15) * w
	var wh := _offset(wf, light_offset)
	ci.draw_polyline_colors(wh, _fade(wh, p + light_offset, c.lightened(0.28), 1.3 * w, 2.1 * w), w * 0.25, true)


static func _near_any(p: Vector2, pts: Array[Vector2], r: float) -> bool:
	for e in pts:
		if p.distance_to(e) < r:
			return true
	return false


static func _near_crossing(p: Vector2, found: Array[Crossing], r: float) -> bool:
	for x in found:
		if p.distance_to(x.point) < r:
			return true
	return false


## 每 STEPS 段一个包围盒，用于快速排除不相交的段。
static func _chunks(pts: PackedVector2Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var k := 0
	while k < pts.size() - 1:
		var e := mini(k + Strand2D.STEPS, pts.size() - 1)
		var rect := Rect2(pts[k], Vector2.ZERO)
		for j in range(k + 1, e + 1):
			rect = rect.expand(pts[j])
		out.append(rect.grow(1.0))
		k = e
	return out


static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for k in pts.size():
		out[k] = pts[k] + d
	return out


## dark > 0 压暗，dark < 0 提亮。
static func _colors(st: Strand2D, dark: float) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(st.tones.size())
	for k in st.tones.size():
		var c := shade(st.base_color, st.tones[k])
		out[k] = c.darkened(dark) if dark >= 0.0 else c.lightened(-dark)
	return out


## 线的两端画圆头：两根线首尾相接处不留缺口。
static func _draw_caps(ci: CanvasItem, pts: PackedVector2Array, colors: PackedColorArray, r: float) -> void:
	ci.draw_circle(pts[0], r, colors[0], true, -1.0, true)
	ci.draw_circle(pts[pts.size() - 1], r, colors[colors.size() - 1], true, -1.0, true)


## 线上以交叉点为中心、沿线前后各 r 长度的一小段。
static func _window(pts: PackedVector2Array, seg: int, p: Vector2, r: float) -> PackedVector2Array:
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
static func _fade(pts: PackedVector2Array, p: Vector2, color: Color, r0: float, r1: float) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(pts.size())
	for k in pts.size():
		var f := 1.0 - clampf((pts[k].distance_to(p) - r0) / (r1 - r0), 0.0, 1.0)
		out[k] = Color(color, color.a * f)
	return out
