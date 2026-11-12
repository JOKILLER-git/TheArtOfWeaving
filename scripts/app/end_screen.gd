class_name EndScreen
extends Control
## 结束界面：全部关卡织完后显示一面织片墙（每关一块）。把线头拉到线轴 → 从第 1 关重新开始；Esc 回开始界面（由 GameApp 处理）。

signal play_again_requested

const WALL_OFFSET := Vector2(0, -25)   # 织片墙相对画面中心

@onready var _wall: SwatchWall2D = %Wall
@onready var _pull: YarnPull2D = %Pull


func _ready() -> void:
	_pull.pulled.connect(_on_pulled)
	resized.connect(_layout)
	_layout()


## 元素随可视区域居中（T007）。
func _layout() -> void:
	var view := Rect2(Vector2.ZERO, size)
	_wall.position = view.get_center() + WALL_OFFSET
	_pull.fit_to(view)


## 用关卡目录和玩家进度拼出织片墙（T008：与选关共用同一份进度）。
func open(catalog: LevelCatalog, progress: PlayerProgress) -> void:
	_wall.build(catalog, progress)
	_pull.reset()
	show()


func close() -> void:
	hide()


func _on_pulled() -> void:
	if visible:
		play_again_requested.emit()
