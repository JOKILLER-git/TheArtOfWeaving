@tool
class_name LoomView
extends Node2D
## 轨道参数是唯一布局来源。编辑器预览与运行时使用同一套同步方法。

@export_group("水平轨道")
## 织框局部坐标；会同步起点标记、线尾、线头和引导线。
@export var start_point: Vector2 = Vector2(120, 129):
	set(value):
		start_point = value
		_refresh_layout()
## 终点横坐标，必须大于 start_point.x；高度自动沿用起点。
@export var finish_x: float = 780.0:
	set(value):
		finish_x = value
		_refresh_layout()

@onready var start: Marker2D = $Start
@onready var finish: Marker2D = $Finish
@onready var warps: Node2D = $Warps
@onready var completed_mark: Sprite2D = $Finish/Completed
@onready var completion_animation: AnimationPlayer = $AnimationPlayer
@onready var _thread: Node2D = $Thread
@onready var _guide: Line2D = $Guide


func _ready() -> void:
	_refresh_layout()


func is_layout_valid() -> bool:
	return start_point.is_finite() and is_finite(finish_x) and finish_x > start_point.x


func _get_configuration_warnings() -> PackedStringArray:
	if not is_layout_valid():
		return PackedStringArray(["轨道必须使用有限坐标，Finish X 必须大于 Start Point.x。"])
	return PackedStringArray()


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	update_configuration_warnings()
	if not is_layout_valid():
		return
	start.position = start_point
	finish.position = Vector2(finish_x, start_point.y)
	_guide.points = PackedVector2Array([start.position, finish.position])
	if Engine.is_editor_hint():
		# 编辑器只更新原生视觉节点，不执行输入或关卡逻辑。
		var preview_start := _thread.to_local(start.global_position)
		_thread.get_node("Tip").position = preview_start
		_thread.get_node("Tail").position = preview_start
		_thread.get_node("Strand").points = PackedVector2Array([preview_start, preview_start])
		update_weave(start.global_position)


func update_weave(global_tip: Vector2) -> void:
	_guide.points = PackedVector2Array([to_local(global_tip), finish.position])
	for child: Node in warps.get_children():
		if child is WarpStrand:
			child.update_crossing(global_tip)


func show_completed(value: bool) -> void:
	completed_mark.visible = value
	_guide.visible = not value
	$Finish/Target.visible = not value
	if value:
		completion_animation.play("complete")
	else:
		# 从动画 RESET 恢复美术尺寸，不在代码中写死缩放值。
		completion_animation.play("RESET")
		completion_animation.advance(0.0)
		completion_animation.stop()

