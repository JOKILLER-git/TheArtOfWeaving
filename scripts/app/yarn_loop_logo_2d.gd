class_name YarnLoopLogo2D
extends Node2D
## 开始界面中央的 logo（T008）：一个放大的单独线圈，带两段短线尾。
## 形状取自 FabricLayout 的线圈关键点（与关卡里的线圈同一几何），画法用 StrandPainter2D（阴影 + 描边 + 填充 + 高光）。
## 轻轻呼吸（缩放）和摆动（旋转）。节点原点为线圈中心。

@export var loop_px := 150.0        # 线圈宽（列宽 × LOOP_WIDTH）的像素
@export var breathe := 0.025        # 呼吸幅度（缩放）
@export var sway := 0.045           # 摆动幅度（弧度）

var _strand: Strand2D
var _time: float = 0.0


func _ready() -> void:
	_strand = build_strand(loop_px)
	queue_redraw()


## 线圈 + 两段线尾，作为一根线（像素，原点在线圈中心）。
static func build_strand(p_loop_px: float) -> Strand2D:
	var chart := PatternChart.new()
	chart.rows = PackedStringArray(["K"])
	var layout := FabricLayout.new(KnitSession.new(chart, StitchRegistry.create_default()), ScreenMapper2D.LOOP_WIDTH)
	var col_px := p_loop_px / ScreenMapper2D.LOOP_WIDTH
	var row_px := 0.9 * p_loop_px    # 与关卡里的行高比例一致（ScreenMapper2D：0.75–1.05 × 线圈宽）
	var keys := layout.loop_keys(0, 0)
	# 两端各接一段向外、略下垂的线尾。
	keys.push_front(Vector2(-0.8, -0.74))
	keys.push_front(Vector2(-1.05, -0.98))
	keys.push_back(Vector2(0.8, -0.74))
	keys.push_back(Vector2(1.05, -0.98))
	var center := Vector2(0.0, (FabricLayout.LOOP_TOP - FabricLayout.LOOP_BOT) * 0.5)
	var px: Array[Vector2] = []
	for k in keys:
		px.append(Vector2((k.x - center.x) * col_px, -(k.y - center.y) * row_px))
	# 明暗：线尾和沉降弧偏暗（在后），腿偏亮（在前），线圈头居中。
	var tones: Array[float] = [-0.3, -0.45, -0.55, -0.55, -0.1, 0.3, 0.15, 0.1, 0.1]
	for k in range(tones.size() - 2, -1, -1):
		tones.append(tones[k])
	var seg_z: Array[float] = []
	seg_z.resize(px.size() - 1)
	seg_z.fill(0.0)
	var st := Strand2D.new(Strand2D.Kind.ROPE, -1, StrandPainter2D.YARN, 0.12 * p_loop_px)
	st.shadow = 0.14
	st.append_spline(px, seg_z, tones, -1)
	return st


func _process(delta: float) -> void:
	_time += delta
	scale = Vector2.ONE * (1.0 + breathe * sin(_time * 1.6))
	rotation = sway * sin(_time * 0.9)


func _draw() -> void:
	if _strand == null:
		return
	var layer: Array[Strand2D] = [_strand]
	StrandPainter2D.draw_layer(self, layer)
