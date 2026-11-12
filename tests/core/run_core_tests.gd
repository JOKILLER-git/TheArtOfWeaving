extends SceneTree
## Godot --headless --path . --script res://tests/core/run_core_tests.gd


func _initialize() -> void:
	var suite: RefCounted = load("res://tests/core/core_rules_suite.gd").new()
	var result: Dictionary = suite.call("run")
	print("Core rule checks: ", result)
	quit(0 if result["passed"] else 1)
