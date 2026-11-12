extends RefCounted
## 可从独立 SceneTree 或编辑器启动的全新游戏进程执行。
var checks := 0
var failures: Array[String] = []
var level: WeaveLevel
var tree: SceneTree
var capture_enabled := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func click(button: Button, touch := false) -> void:
	var point := tree.root.get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func choose(pattern: String) -> void:
	for i in pattern.length():
		if level.surface.selected[i] != (pattern[i] == "1"):
			click(level.surface._buttons[i])

func pick(pattern: String) -> void:
	choose(pattern)
	click(level.hud.confirm_button)
	await tree.create_timer(0.15).timeout

func capture(filename: String) -> void:
	if capture_enabled:
		await RenderingServer.frame_post_draw
		level.get_viewport().get_texture().get_image().save_png("res://.local/" + filename + ".png")

func run(subject: WeaveLevel, screenshots := false) -> Dictionary:
	level = subject
	tree = level.get_tree()
	capture_enabled = screenshots
	var original := level.lesson
	level.restart()
	level.surface.insertion_seconds = 0.05
	level.surface.beat_seconds = 0.04
	await tree.process_frame
	check(level.configured and not level.completed, "Valid initial configuration")
	check(level.surface.warp_count() == 10, "Ten selectable warps")
	check(level.surface.selection_pattern() == "0000000000", "No automatic alternating selection")
	check(not level.hud.next_button.visible, "No next level before completion")
	click(level.surface._buttons[0])
	check(level.surface.selected[0], "Mouse selects a warp")
	click(level.surface._buttons[0])
	check(not level.surface.selected[0], "Selection is reversible before insertion")
	click(level.surface._buttons[1], true)
	check(level.surface.selected[1], "Touch selects a warp")
	click(level.surface._buttons[1], true)
	check(not level.surface.selected[1], "Touch releases selection")
	choose(original.target_rows[0])
	await tree.create_timer(0.25).timeout
	check(level.surface._warp_path(0)[0].x == level.surface._xs[0], "Lift top endpoint stays fixed")
	check(level.surface._warp_path(0)[12].x < level.surface._xs[0] - 10, "Raised middle visibly bends")
	check(level.surface._warp_path(0)[24].x == level.surface._xs[0], "Lift lower endpoint stays fixed")
	await capture("weave-lift")
	level.surface.insertion_seconds = 0.8
	click(level.hud.confirm_button)
	check(level.surface.busy and level.hud.confirm_button.disabled, "Confirm locks animation")
	click(level.surface._buttons[0])
	level.confirm_pick()
	check(level.surface.selection_pattern() == original.target_rows[0], "Selection frozen during insertion")
	level.undo_row()
	check(level.rows.is_empty(), "Cannot undo uncommitted animation")
	await tree.create_timer(0.35).timeout
	await capture("weave-shuttle")
	await tree.create_timer(0.6).timeout
	check(level.rows.size() == 1, "Repeated confirm inserts only once")
	check(level.rows[0] == original.target_rows[0], "Confirmed pattern saved")
	check(not level.completed, "One correct row does not finish target")
	choose(original.target_rows[1])
	check(level.surface.woven_rows[0] == original.target_rows[0], "Changing next shed preserves cloth")
	click(level.hud.undo_button)
	check(level.rows.is_empty() and level.surface.woven_rows.is_empty(), "Undo removes one row from model and view")
	check(level.surface.selection_pattern() == original.target_rows[0], "Undo restores original combination for correction")
	level.surface.insertion_seconds = 0.05
	for i in original.target_rows.size():
		await pick("0000000000" if i == 3 else original.target_rows[i])
	check(not level.completed and not level.hud.next_button.visible, "Wrong final pattern blocks next level")
	check(level.hud.confirm_button.disabled and not level.hud.undo_button.disabled, "Failed full segment offers correction")
	var before := level.lesson
	level.next_lesson()
	check(level.lesson == before, "Next action cannot bypass failure")
	await capture("weave-mismatch")
	click(level.hud.undo_button)
	await pick(original.target_rows[3])
	check(level.completed and level.hud.next_button.visible, "Correct full target unlocks next")
	check(level.rows.size() == 4 and level.surface.woven_rows == level.rows, "All four rows preserved")
	await capture("weave-complete")
	click(level.hud.next_button)
	check(level.lesson == original.next_lesson and level.rows.is_empty(), "Next loads fresh lesson resource")
	check(not level.completed and not level.hud.next_button.visible, "New lesson requires its own solution")
	for pattern in level.lesson.target_rows:
		await pick(pattern)
	check(level.completed and not level.hud.next_button.visible, "Last lesson completes without a dead next button")
	click(level.hud.restart_button)
	check(not level.completed and level.rows.is_empty(), "Restart button resets completed level")
	level.surface.insertion_seconds = 0.8
	level.confirm_pick()
	level.restart()
	await tree.create_timer(1.0).timeout
	check(level.rows.is_empty() and not level.surface.busy, "Restart cancels in-flight callback")
	level.lesson = original.duplicate()
	level.lesson.target_rows = PackedStringArray(["10x"])
	level.restart()
	level.confirm_pick()
	check(not level.configured and level.hud.error_message.visible and not level.surface.busy, "Malformed target disables play")
	level.lesson = original
	level.loom.finish_x = level.loom.start_point.x
	level.restart()
	check(not level.configured, "Invalid track disables play")
	level.loom.finish_x = 780
	level.loom.start_point.y = 220
	level.restart()
	check(not level.configured, "Cloth cannot extend beyond bottom rail")
	level.loom.start_point.y = 129
	level.restart()
	check(level.configured and not level.hud.error_message.visible, "Valid setup recovers")
	level.surface.insertion_seconds = 0.85
	level.surface.beat_seconds = 0.35
	return {"checks": checks, "failures": failures, "passed": failures.is_empty()}
