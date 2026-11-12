class_name Strand2D
extends RefCounted
## 一根要画的线（像素坐标）：织物的一行，或工作线。每段带 z（前后）与所属列，每点带明暗。

enum Kind { FABRIC, ROPE }

const STEPS := 8            # 每段样条的采样数

var kind: Kind
var row: int                # 织物行号；工作线为 -1
var base_color: Color
var width: float
var shadow: float = 0.10
var points := PackedVector2Array()
var tones := PackedFloat32Array()   # 每点明暗：> 0 偏亮（在前），< 0 偏暗（在后）
var z := PackedFloat32Array()       # 每段的前后
var cols := PackedInt32Array()      # 每段属于哪一列；-1 表示不属于线圈


func _init(p_kind: Kind, p_row: int, p_color: Color, p_width: float) -> void:
	kind = p_kind
	row = p_row
	base_color = p_color
	width = p_width


func is_drawable() -> bool:
	return points.size() >= 2


## 把关键点按 Catmull-Rom 采样后接到线尾（首点与上一段末点重合时丢掉）。
## seg_z 每段一个，key_tone 每个关键点一个。
func append_spline(keys: Array[Vector2], seg_z: Array[float], key_tone: Array[float], col: int) -> void:
	var drop := 1 if points.size() > 0 else 0
	var n := keys.size()
	for k in n - 1:
		var p0 := keys[maxi(k - 1, 0)]
		var p1 := keys[k]
		var p2 := keys[k + 1]
		var p3 := keys[mini(k + 2, n - 1)]
		for s in STEPS:
			var u := float(s) / STEPS
			if drop > 0:
				drop -= 1
			else:
				points.append(catmull_point(p0, p1, p2, p3, u))
				tones.append(lerpf(key_tone[k], key_tone[k + 1], u))
			z.append(seg_z[k])
			cols.append(col)
	points.append(keys[n - 1])
	tones.append(key_tone[n - 1])


static func catmull_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


static func catmull(pts: Array[Vector2], steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for k in n - 1:
		for s in steps:
			out.append(catmull_point(pts[maxi(k - 1, 0)], pts[k], pts[k + 1], pts[mini(k + 2, n - 1)], float(s) / steps))
	out.append(pts[n - 1])
	return out
