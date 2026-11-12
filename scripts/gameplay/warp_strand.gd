@tool
class_name WarpStrand
extends Node2D
## 一根经线。Body 负责整体美术，Crossing 只负责交错处的前景遮挡。

@export var passes_over: bool = false
## 线头越过经线多少距离后显示遮挡，避免遮住正在拖动的线头。
@export_range(0.0, 32.0) var crossing_clearance: float = 8.0

@onready var crossing: Sprite2D = $Crossing


func update_crossing(global_tip: Vector2) -> void:
	var local_tip := to_local(global_tip)
	crossing.position.y = local_tip.y
	crossing.visible = passes_over and local_tip.x > crossing_clearance
