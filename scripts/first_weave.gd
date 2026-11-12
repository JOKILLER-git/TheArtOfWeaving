class_name WeaveLevel
extends Control
## 组合根：编织表现、UI 和关卡资源之间的状态协调。
signal lesson_completed
signal next_level_requested
## 由选关入口管理时，导航顺序来自目录，独立 F6 仍兼容 next_lesson。
var navigation_managed := false
var next_level_available := false
@export var lesson: WeaveLesson
@onready var loom: LoomView = $Loom
@onready var thread: DraggableThread = $Loom/Thread
@onready var hud: WeaveHUD = $HUD
@onready var surface: WeaveSurface = $Loom/WeaveSurface
var completed := false
var configured := false
var rows: Array[String] = []

func _ready() -> void:
	hud.restart_requested.connect(restart)
	hud.confirm_requested.connect(confirm_pick)
	hud.undo_requested.connect(undo_row)
	hud.next_requested.connect(next_lesson)
	surface.selection_changed.connect(_refresh_hud)
	surface.pick_finished.connect(_on_pick_finished)
	restart()

func restart() -> void:
	completed = false
	configured = false
	rows.clear()
	thread.set_enabled(false)
	thread.hide()
	surface.reset()
	loom.warps.hide()
	loom.show_completed(false)
	loom.get_node("Guide").hide()
	loom.get_node("Finish/Target").hide()
	if lesson == null or not loom.is_layout_valid() or not lesson.is_valid(surface.warp_count()) or not surface.is_layout_valid(lesson.target_rows.size()):
		surface.set_locked(true)
		hud.show_configuration_error()
		return
	configured = true
	hud.configure(lesson)
	hud.has_next_level = next_level_available if navigation_managed else lesson.next_lesson is WeaveLesson
	hud.reset()
	_refresh_hud()

func confirm_pick() -> void:
	if not configured or completed or surface.busy or rows.size() >= lesson.target_rows.size():
		return
	surface.insert_pick()
	_refresh_hud()

func _on_pick_finished(pattern: String) -> void:
	rows.append(pattern)
	completed = lesson.matches(rows)
	surface.set_locked(rows.size() == lesson.target_rows.size())
	if completed:
		loom.show_completed(true)
		lesson_completed.emit()
	_refresh_hud()

func undo_row() -> void:
	if not configured or surface.busy or rows.is_empty():
		return
	rows.pop_back()
	completed = false
	loom.show_completed(false)
	loom.get_node("Guide").hide()
	loom.get_node("Finish/Target").hide()
	surface.undo_row()
	_refresh_hud()

func next_lesson() -> void:
	if navigation_managed:
		if completed and next_level_available:
			next_level_requested.emit()
		return
	if completed and lesson.next_lesson is WeaveLesson:
		lesson = lesson.next_lesson as WeaveLesson
		restart()

func _refresh_hud() -> void:
	if configured:
		hud.update_state(rows, surface.selection_pattern(), surface.busy, completed)
