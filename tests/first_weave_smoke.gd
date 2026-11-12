extends SceneTree
## Godot --headless --path . --script res://tests/first_weave_smoke.gd
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/first_weave.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var suite = load("res://tests/weave_flow_suite.gd").new()
	var result: Dictionary = await suite.run(scene, "--capture" in OS.get_cmdline_user_args())
	print("Weave flow checks: ", result)
	quit(0 if result.passed else 1)
