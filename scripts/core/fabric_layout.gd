class_name FabricLayout
extends RefCounted
## 织物坐标里的几何：单位为列宽 / 行高，x = 列（第 0 列中心为 0），y = 行（向上为正，第 0 行中心为 0）。
## 2D 和 3D 共用：眼中心、锚点、沉降弧、折返弧、线圈关键点都在这里算。

## 线圈左半边的关键点（相对线圈中心，y 向上），右半边镜像。
## 段 0-1 沉降弧，段 2 下腿（穿过下一行线圈的头），段 3-5 上腿和头。
const LOOP_HALF: Array[Vector2] = [
	Vector2(-0.50, -0.78),
	Vector2(-0.40, -0.78),
	Vector2(-0.16, -0.70),
	Vector2(-0.13, -0.20),
	Vector2(-0.36, 0.22),
	Vector2(-0.28, 0.52),
	Vector2(0.0, 0.62),
]
const LOOP_SEGMENTS := 12
const LOOP_TOP := 0.62      # 线圈头顶在中心上方多少行
const LOOP_BOT := 0.78      # 沉降弧在中心下方多少行
const EYE_UP := 0.42        # 眼的中心在线圈中心上方多少行
const REST_OFFSET := Vector2(0.48, -0.8)  # 线头静止时相对锚点的位置（x 随行方向翻转）

enum LoopPart { HEAD, LEG, SINKER }

var session: KnitSession
## 线圈主体（腿和头）占列宽的比例。1.0 = 相邻线圈紧挨（默认，旧行为）；
## 小于 1 时线圈形状不变、只是变窄，相邻线圈之间露出一段沉降弧，眼之间更宽松。
var loop_width: float = 1.0


func _init(p_session: KnitSession, p_loop_width: float = 1.0) -> void:
	session = p_session
	loop_width = p_loop_width


func columns() -> int:
	return session.width()


## 含起始行的总行数。
func rows() -> int:
	return session.fabric.height


## 织物在纵向上占多少行高（含顶部线圈头与底部沉降弧）。
func vertical_span() -> float:
	return float(session.last_row()) + LOOP_TOP + LOOP_BOT


func sinker_y(row: int) -> float:
	return float(row) - LOOP_BOT


## side < 0 为左边缘，side > 0 为右边缘。
func edge_x(side: int) -> float:
	return -0.5 if side < 0 else float(columns()) - 0.5


## 第 row 行第 col 列线圈的眼（钩针从这里穿过）。
func eye_center(col: int, row: int) -> Vector2:
	return Vector2(float(col), float(row) + EYE_UP)


## 工作线当前固定在织物上的那一点。
func anchor() -> Vector2:
	var row := session.current_row
	if session.completed:
		var last := session.last_row()
		return Vector2(edge_x(KnitSession.row_direction(last)), sinker_y(last))
	var dir := KnitSession.row_direction(row)
	var col := session.last_made_column()
	if col < 0:
		return Vector2(edge_x(-dir), sinker_y(row))
	return Vector2(float(col) + dir * 0.5, sinker_y(row))


## 线头静止时的位置：垂向前进方向，压过（或藏在）下面的线圈。
func rest_tip() -> Vector2:
	var dir := KnitSession.row_direction(session.current_row)
	return anchor() + Vector2(REST_OFFSET.x * dir, REST_OFFSET.y)


## 第 row 行起针前的折返弧（从下一行的沉降弧绕到本行），按从左到右排列。
func turn_arc(row: int) -> Array[Vector2]:
	var side := -KnitSession.row_direction(row)
	var ex := edge_x(side)
	var from := Vector2(ex, sinker_y(row - 1))
	var to := Vector2(ex, sinker_y(row))
	var mid := (from + to) * 0.5 + Vector2(side * 0.2, 0.0)
	var arc: Array[Vector2] = [from, mid, to]
	if side > 0:
		arc.reverse()
	return arc


## 折返弧在行的哪一侧：-1 左，+1 右。
func turn_side(row: int) -> int:
	return -KnitSession.row_direction(row)


## 折返弧是否还属于工作线（正在织的这行还没起针）。
func is_turn_loose(row: int) -> bool:
	return row == session.current_row and session.stitches_in_row == 0 and not session.completed


## 线圈的 13 个关键点（从左到右）。form 0..1 为成形进度：以沉降弧为基准纵向生长。
func loop_keys(col: int, row: int, form: float = 1.0) -> Array[Vector2]:
	var x := float(col)
	var c := float(row)
	var base := sinker_y(row)
	var keys: Array[Vector2] = []
	for k in LOOP_HALF.size():
		keys.append(Vector2(x + _half_x(k), c + LOOP_HALF[k].y))
	for k in range(LOOP_HALF.size() - 2, -1, -1):
		keys.append(Vector2(x - _half_x(k), c + LOOP_HALF[k].y))
	var f := clampf(form, 0.0, 1.0)
	var squash := lerpf(0.7, 1.0, f)
	for k in range(1, keys.size() - 1):
		var p := keys[k]
		keys[k] = Vector2(x + (p.x - x) * squash, base + (p.y - base) * f)
	return keys


## 第 k 个左半边关键点的横坐标：首点留在列边界（与相邻线圈相接），其余按 loop_width 收窄。
func _half_x(k: int) -> float:
	var hx := LOOP_HALF[k].x
	return hx if k == 0 else hx * loop_width


## 线圈第 seg 段属于哪一部分。
static func loop_part(seg: int) -> LoopPart:
	if seg <= 1 or seg >= 10:
		return LoopPart.SINKER
	if seg == 2 or seg == 9:
		return LoopPart.LEG
	return LoopPart.HEAD
