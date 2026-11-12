class_name GameBrowser
extends Control
## 应用入口：选关、关卡实例生命周期、目录顺序和会话内完成记录。
@export var catalog: WeaveCatalog
@export var default_level_scene: PackedScene

@onready var selection: LevelSelection = $Selection
@onready var level_host: Control = $LevelHost
@onready var back_button: Button = $Back

var active_level: WeaveLevel
var active_chapter: int = -1
var active_stage: int = -1
var completed_stages: Dictionary = {}

func _ready() -> void:
	selection.stage_selected.connect(open_stage)
	back_button.pressed.connect(show_selection)
	show_selection()

func show_selection() -> void:
	_dispose_level()
	level_host.hide()
	back_button.hide()
	selection.show()
	if catalog == null:
		selection.show_error("请在 GameBrowser 上指定 Catalog 资源。")
		return
	var errors := catalog.validation_errors()
	if not errors.is_empty():
		selection.show_error("\n".join(errors))
		return
	selection.refresh(catalog, completed_stages)

func open_stage(chapter_index: int, stage_index: int) -> void:
	if catalog == null or not catalog.validation_errors().is_empty():
		return
	if chapter_index < 0 or chapter_index >= catalog.chapters.size():
		return
	var chapter := catalog.chapters[chapter_index]
	if stage_index < 0 or stage_index >= chapter.stages.size():
		return
	var entry := chapter.stages[stage_index]
	var packed := entry.scene if entry.scene != null else default_level_scene
	if packed == null:
		selection.show_error("请配置默认关卡场景或此关的独立场景。")
		return
	var instance := packed.instantiate()
	if not instance is WeaveLevel:
		instance.free()
		selection.show_error("关卡场景根节点必须使用 WeaveLevel 脚本。")
		return
	_dispose_level()
	active_chapter = chapter_index
	active_stage = stage_index
	selection.selected_chapter = chapter_index
	active_level = instance as WeaveLevel
	active_level.lesson = entry.lesson
	active_level.navigation_managed = true
	active_level.next_level_available = _next_address() != Vector2i(-1, -1)
	active_level.lesson_completed.connect(_on_completed.bind(entry.id))
	active_level.next_level_requested.connect(open_next)
	selection.hide()
	level_host.show()
	back_button.show()
	level_host.add_child(active_level)

func open_next() -> void:
	if not is_instance_valid(active_level) or not active_level.completed:
		return
	var address := _next_address()
	if address.x >= 0:
		open_stage(address.x, address.y)

func _next_address() -> Vector2i:
	if active_chapter < 0:
		return Vector2i(-1, -1)
	for chapter_index in range(active_chapter, catalog.chapters.size()):
		var first := active_stage + 1 if chapter_index == active_chapter else 0
		if first < catalog.chapters[chapter_index].stages.size():
			return Vector2i(chapter_index, first)
	return Vector2i(-1, -1)

func _on_completed(stage_id: String) -> void:
	completed_stages[stage_id] = true

func _dispose_level() -> void:
	if is_instance_valid(active_level):
		# 立即离开树，防止旧物体继续接收输入；Tween 随节点销毁。
		level_host.remove_child(active_level)
		active_level.queue_free()
	active_level = null
