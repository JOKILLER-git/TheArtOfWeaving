extends SceneTree
var app: GameBrowser
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func click(button: Button) -> void:
	var point := root.get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func solve() -> void:
	var level := app.active_level
	level.surface.insertion_seconds = 0.02
	level.surface.beat_seconds = 0.02
	for pattern in level.lesson.target_rows:
		for i in pattern.length():
			if level.surface.selected[i] != (pattern[i] == "1"):
				click(level.surface._buttons[i])
		click(level.hud.confirm_button)
		await create_timer(0.08).timeout

func capture() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local"))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.local/level-selection.png")

func run() -> void:
	app = load("res://scenes/game_browser.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.catalog.validation_errors().is_empty(), "Catalog is valid")
	check(app.selection.visible and app.active_level == null, "Boot opens selection")
	check(app.selection.stage_grid.get_child_count() == 2, "Existing lessons appear")
	await capture()
	click(app.selection.stage_grid.get_child(1))
	check(app.active_stage == 1 and app.active_level.lesson == load("res://resources/lessons/second_weave.tres"), "Direct selection opens second lesson")
	check(not app.active_level.next_level_available, "Last stage has no next")
	app.open_next()
	check(app.active_stage == 1, "Incomplete lesson cannot advance")
	click(app.back_button)
	await process_frame
	check(app.active_level == null and app.selection.visible, "Back returns to selection")
	click(app.selection.stage_grid.get_child(0))
	await process_frame
	await solve()
	check(app.active_level.completed and app.completed_stages.has("chapter_01_plain"), "Completion tracked by stable stage ID")
	click(app.active_level.hud.next_button)
	await process_frame
	check(app.active_stage == 1 and app.active_level.rows.is_empty(), "Next creates a fresh stage")
	app.show_selection()
	await process_frame
	check("✓" in app.selection.stage_grid.get_child(0).text, "Selection displays completion mark")
	# Runtime-only fixtures prove new chapters require data changes only.
	var original := app.catalog
	app.catalog = WeaveCatalog.new()
	app.catalog.chapters.assign(original.chapters)
	var empty := WeaveChapter.new()
	empty.id = "empty"
	empty.title = "空章节"
	app.catalog.chapters.append(empty)
	var chapter := WeaveChapter.new()
	chapter.id = "extra"
	chapter.title = "第二章"
	var stage := WeaveStage.new()
	stage.id = "extra_01"
	stage.title = "新增关卡"
	stage.lesson = load("res://resources/lessons/first_weave.tres")
	chapter.stages.append(stage)
	app.catalog.chapters.append(chapter)
	app.show_selection()
	await process_frame
	check(app.selection.chapter_list.get_child_count() == 3, "New chapters automatically appear")
	click(app.selection.chapter_list.get_child(1))
	await process_frame
	check(app.selection.empty_message.visible, "Empty chapter has safe placeholder")
	click(app.selection.chapter_list.get_child(2))
	await process_frame
	check(app.selection.stage_grid.get_child_count() == 1, "New stage automatically appears")
	click(app.selection.stage_grid.get_child(0))
	await process_frame
	check(app.active_chapter == 2 and app.active_level.configured, "New chapter stage is playable")
	app.open_stage(0, 1)
	await process_frame
	await solve()
	click(app.active_level.hud.next_button)
	await process_frame
	check(app.active_chapter == 2, "Next crosses chapters and skips empty chapters")
	check(not app.active_level.next_level_available, "Catalog order overrides legacy next_lesson link")
	app.active_level.confirm_pick()
	click(app.back_button)
	await create_timer(1.3).timeout
	check(app.active_level == null and app.selection.visible, "Return during animation disposes old gameplay safely")
	stage.id = "chapter_01_plain"
	check(not app.catalog.validation_errors().is_empty(), "Duplicate IDs rejected")
	app.show_selection()
	check(app.selection.stage_grid.get_child_count() == 0, "Invalid catalog does not expose playable cards")
	app.catalog = WeaveCatalog.new()
	app.show_selection()
	check(app.selection.empty_message.visible, "Empty catalog is safe")
	app.catalog = original
	app.show_selection()
	await process_frame
	app.selection._select_chapter(0)
	await process_frame
	await capture()
	print("Selection checks: ", checks, " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
