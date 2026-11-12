class_name LevelSelection
extends Control
signal stage_selected(chapter_index: int, stage_index: int)

@export var chapter_button_scene: PackedScene
@export var stage_button_scene: PackedScene
@onready var chapter_list: VBoxContainer = %Chapters
@onready var stage_grid: GridContainer = %Stages
@onready var chapter_title: Label = %ChapterTitle
@onready var empty_message: Label = %EmptyMessage

var selected_chapter: int = 0
var _catalog: WeaveCatalog
var _completed: Dictionary = {}

func refresh(catalog: WeaveCatalog, completed: Dictionary) -> void:
	_catalog = catalog
	_completed = completed
	_clear(chapter_list)
	_clear(stage_grid)
	if catalog == null or catalog.chapters.is_empty():
		chapter_title.text = ""
		empty_message.text = "暂无章节"
		empty_message.show()
		return
	selected_chapter = clampi(selected_chapter, 0, catalog.chapters.size() - 1)
	for i in catalog.chapters.size():
		var button: Button = chapter_button_scene.instantiate()
		button.text = catalog.chapters[i].title
		button.tooltip_text = catalog.chapters[i].title
		button.toggle_mode = true
		button.button_pressed = i == selected_chapter
		button.pressed.connect(_select_chapter.bind(i))
		chapter_list.add_child(button)
	_refresh_stages()

func show_error(message: String) -> void:
	_clear(chapter_list)
	_clear(stage_grid)
	chapter_title.text = "目录配置需要检查"
	empty_message.text = message
	empty_message.show()

func _select_chapter(index: int) -> void:
	selected_chapter = index
	refresh(_catalog, _completed)

func _refresh_stages() -> void:
	_clear(stage_grid)
	var chapter := _catalog.chapters[selected_chapter]
	chapter_title.text = chapter.title
	empty_message.text = "暂无关卡"
	empty_message.visible = chapter.stages.is_empty()
	for i in chapter.stages.size():
		var stage := chapter.stages[i]
		var button: Button = stage_button_scene.instantiate()
		var mark := "  ✓" if _completed.has(stage.id) else ""
		button.text = "%02d%s\n%s" % [i + 1, mark, stage.title]
		button.tooltip_text = stage.title + "\n" + stage.lesson.intro_title
		button.pressed.connect(_choose_stage.bind(i))
		stage_grid.add_child(button)

func _choose_stage(index: int) -> void:
	stage_selected.emit(selected_chapter, index)

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
