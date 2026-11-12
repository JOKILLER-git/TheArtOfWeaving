extends RefCounted
## core 层规则测试：只用 RefCounted / Resource，不需要场景，可无头运行。
## 入口：run() 返回 {passed, checks, failures}；命令行见 run_core_tests.gd。

var checks: int = 0
var failures: Array[String] = []
var _registry := StitchRegistry.create_default()


func run() -> Dictionary:
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			call(method_name)
	return {"passed": failures.is_empty(), "checks": checks, "failures": failures}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FAIL: " + message)


## 按元素比较（不区分类型化数组与普通数组）。
func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


func make_session(rows: PackedStringArray) -> KnitSession:
	var chart := PatternChart.new()
	chart.rows = rows
	return KnitSession.new(chart, _registry)


## 按顺序把本行剩下的针都织完（自动切换线状态）。
func knit_rest_of_row(session: KnitSession) -> void:
	var row := session.current_row
	while not session.completed and session.current_row == row:
		if not session.is_yarn_ready():
			session.toggle_yarn()
		session.try_hook(session.next_column())


# ---------------------------------------------------------------- 规则

func test_knit_with_yarn_back_is_accepted() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var made: Array[StitchType] = []
	s.stitch_made.connect(func(_r: int, _c: int, st: StitchType) -> void: made.append(st))
	var result := s.try_hook(s.next_column())
	check(result.status == HookResult.Status.ACCEPTED, "线在后钩下针目标应被接受")
	check(result.stitch is KnitStitch, "钩出的是下针")
	check(s.fabric.stitch_at(1, 0) is KnitStitch, "织物 (1,0) 记录为下针")
	check(made.size() == 1, "发出 stitch_made")


func test_yarn_front_on_knit_target_is_wrong_side() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var rejected: Array[HookResult] = []
	s.stitch_rejected.connect(func(r: HookResult) -> void: rejected.append(r))
	s.toggle_yarn()
	var result := s.try_hook(s.next_column())
	check(result.status == HookResult.Status.WRONG_SIDE, "线在前钩下针目标应为 WRONG_SIDE")
	check(result.stitch is PurlStitch and result.expected is KnitStitch, "结果附带钩出的针法与要求的针法")
	check(not s.fabric.has_stitch(1, 0), "WRONG_SIDE 不改动织物")
	check(rejected.size() == 1, "发出 stitch_rejected")


func test_purl_with_yarn_front_is_accepted() -> void:
	var s := make_session(PackedStringArray(["PP"]))
	check(not s.is_yarn_ready(), "上针目标、线在后：线状态不对")
	check(s.toggle_yarn(), "可以切换线状态")
	check(s.yarn.side == Yarn.Face.FRONT, "切换后线在前")
	var result := s.try_hook(s.next_column())
	check(result.is_accepted() and result.stitch is PurlStitch, "线在前钩上针目标被接受")


func test_hook_other_eye_is_not_next() -> void:
	var s := make_session(PackedStringArray(["KKKK"]))
	check(s.next_column() == 0, "第 1 行从左往右，下一针在第 0 列")
	var result := s.try_hook(2)
	check(result.status == HookResult.Status.NOT_NEXT, "钩非下一针的眼应为 NOT_NEXT")
	check(s.stitches_in_row == 0, "NOT_NEXT 不推进")


func test_direction_reverses_after_row() -> void:
	var s := make_session(PackedStringArray(["KKK", "KKK"]))
	var finished: Array[int] = []
	s.row_completed.connect(func(r: int) -> void: finished.append(r))
	check(s.next_column() == 0, "奇数行从左边开始")
	knit_rest_of_row(s)
	check(same(finished, [1]), "第 1 行完成时发出 row_completed(1)")
	check(s.current_row == 2, "进入第 2 行")
	check(s.next_column() == 2, "偶数行从右边开始（方向反转）")
	s.try_hook(2)
	check(s.next_column() == 1, "偶数行向左推进")


func test_level_completed_once_and_then_level_done() -> void:
	var s := make_session(PackedStringArray(["KP", "KP"]))
	var done_count := [0]
	s.level_completed.connect(func() -> void: done_count[0] += 1)
	knit_rest_of_row(s)
	check(done_count[0] == 0, "还没织完不发 level_completed")
	knit_rest_of_row(s)
	check(s.completed, "全部织完后 completed")
	check(done_count[0] == 1, "整关完成发出一次 level_completed")
	check(s.try_hook(0).status == HookResult.Status.LEVEL_DONE, "完成后再钩为 LEVEL_DONE")
	check(not s.toggle_yarn(), "完成后不再切换线状态")
	check(s.fabric.stitch_at(2, 1) is PurlStitch, "罗纹第 2 行第 1 列为上针")


func test_registry_and_chart() -> void:
	check(_registry.for_side(Yarn.Face.BACK) is KnitStitch, "线在后 → 下针")
	check(_registry.for_side(Yarn.Face.FRONT) is PurlStitch, "线在前 → 上针")
	check(_registry.by_id("P") is PurlStitch, "按 id 查针法")
	var bad := PatternChart.new()
	bad.rows = PackedStringArray(["KK", "K"])
	check(not bad.is_valid(_registry), "行宽不一致的图纸无效")


## T006：目录扩展为 11 关（原断言为 4 关，按任务卡更新）。
func test_level_catalog_resources() -> void:
	var catalog := load("res://resources/levels/level_catalog.tres") as LevelCatalog
	check(catalog != null and catalog.count() == 11, "目录里有 11 关")
	if catalog == null:
		return
	var expected := [["KK"], ["KKKK"], ["KKKK"], ["PP"], ["PPPP"], ["KKK", "KKK"], ["KPKP"],
		["KPKP", "KPKP"], ["KPKP", "PKPK"], ["KKKKK", "PPPPP", "KKKKK"],
		["KKPPKK", "KKPPKK", "PPKKPP", "PPKKPP"]]
	var ids := [&"first_stitch", &"a_row", &"snip", &"first_purl", &"purl_row", &"turn", &"rib_row", &"rib", &"seed", &"ridges", &"basket"]
	for i in catalog.count():
		var level := catalog.get_level(i)
		check(level.chart.is_valid(_registry), "第 %d 关图纸有效" % (i + 1))
		check(same(Array(level.chart.rows), expected[i]), "第 %d 关图纸内容" % (i + 1))
		check(level.id == ids[i], "第 %d 关 id" % (i + 1))
		check(level.has_preset() == (i == 2), "只有第 3 关有预置织物（第 %d 关）" % (i + 1))


# ---------------------------------------------------------------- 手势

## 下针关第 1 行：锚点 (-0.5, 0.22)，下一针的眼 (0, 0.42)。
func make_gestures(rows: PackedStringArray) -> Dictionary:
	var s := make_session(rows)
	var layout := FabricLayout.new(s)
	var wrap_gesture := WrapGesture.new(layout)
	var hook := HookGesture.new(s, layout, wrap_gesture)
	var hooks: Array[int] = []
	var wraps := [0]
	hook.hook_requested.connect(func(c: int) -> void: hooks.append(c))
	wrap_gesture.wrap_completed.connect(func() -> void: wraps[0] += 1)
	return {"session": s, "layout": layout, "wrap": wrap_gesture, "hook": hook, "hooks": hooks, "wraps": wraps}


## 把一串织物坐标点按 0.05 列宽补采样后喂给识别器（与 PointerInput2D 相同）。
func feed_path(recognizers: Array[GestureRecognizer], pts: Array[Vector2]) -> void:
	for k in range(1, pts.size()):
		var steps := maxi(1, ceili(pts[k - 1].distance_to(pts[k]) / 0.05))
		for s in range(1, steps + 1):
			var q := pts[k - 1].lerp(pts[k], float(s) / steps)
			for r in recognizers:
				r.feed(q)


func circle_path(center: Vector2, radius: float, from_deg: float, to_deg: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var n := 72
	for k in n + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(k) / n))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func test_hook_gesture_below_to_above_triggers() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var recognizers: Array[GestureRecognizer] = [g["hook"]]
	var path: Array[Vector2] = [eye + Vector2(0, -0.8), eye + Vector2(0, 0.8)]
	feed_path(recognizers, path)
	check(same(g["hooks"], [0]), "下进上出触发钩针（第 0 列）")


func test_hook_gesture_above_to_below_does_not_trigger() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var recognizers: Array[GestureRecognizer] = [g["hook"]]
	var path: Array[Vector2] = [eye + Vector2(0, 0.8), eye + Vector2(0, -0.8)]
	feed_path(recognizers, path)
	var side_path: Array[Vector2] = [eye + Vector2(-0.8, 0), eye + Vector2(0.8, 0)]
	feed_path(recognizers, side_path)
	check((g["hooks"] as Array).is_empty(), "上进下出、横穿都不触发")


func test_wrap_gesture_full_circle_triggers() -> void:
	var g := make_gestures(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
	feed_path(recognizers, circle_path(layout.anchor(), 0.9, -90.0, 290.0))
	check(g["wraps"][0] == 1, "绕锚点一圈触发一次切换")
	var clockwise := make_gestures(PackedStringArray(["PPPP"]))
	var cw_rec: Array[GestureRecognizer] = [clockwise["wrap"]]
	feed_path(cw_rec, circle_path(layout.anchor(), 0.9, 270.0, -110.0))
	check(clockwise["wraps"][0] == 1, "顺时针绕一圈同样有效")


func test_wrap_gesture_zigzag_does_not_trigger() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var a := layout.anchor()
	var path: Array[Vector2] = []
	for k in 12:
		path.append(a + Vector2(0.2 + 0.15 * k, -0.6 if k % 2 == 0 else 0.5))
	var recognizers: Array[GestureRecognizer] = [g["wrap"]]
	feed_path(recognizers, path)
	check(g["wraps"][0] == 0, "锯齿路径不触发绕线")


## T003 遗留误触：小圈逆时针绕线顺路从下方穿过下一针的眼，不应被判成钩针。
func test_small_wrap_through_eye_does_not_hook() -> void:
	for radius in [0.45, 0.54, 0.65]:
		var g := make_gestures(PackedStringArray(["KKKK"]))
		var layout: FabricLayout = g["layout"]
		var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
		var start := -120.0
		feed_path(recognizers, circle_path(layout.anchor(), radius, start, start + 360.0))
		check((g["hooks"] as Array).is_empty(), "半径 %.2f 的逆时针小圈不触发钩针" % radius)
		check(g["wraps"][0] == 1, "半径 %.2f 的小圈仍完成绕线" % radius)
	# 对照：没有绕线守卫时同一路径会误触发，说明上面的测试确实覆盖了误触。
	var bare := make_gestures(PackedStringArray(["KKKK"]))
	var s: KnitSession = bare["session"]
	var bare_layout: FabricLayout = bare["layout"]
	var unguarded := HookGesture.new(s, bare_layout)
	var hits: Array[int] = []
	unguarded.hook_requested.connect(func(c: int) -> void: hits.append(c))
	var only_hook: Array[GestureRecognizer] = [unguarded]
	feed_path(only_hook, circle_path(bare_layout.anchor(), 0.54, -120.0, 240.0))
	check(same(hits, [0]), "对照：无守卫时小圈会误触发钩针")


## 正常锯齿钩针（从静止线头出发，下进上出，再落下去钩下一针）不能被守卫误伤。
func test_sawtooth_hooks_still_work_with_guard() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var s: KnitSession = g["session"]
	var layout: FabricLayout = g["layout"]
	var hook: HookGesture = g["hook"]
	var wrap_gesture: WrapGesture = g["wrap"]
	hook.hook_requested.connect(s.try_hook)
	wrap_gesture.wrap_completed.connect(s.toggle_yarn)
	var recognizers: Array[GestureRecognizer] = [wrap_gesture, hook]
	var p := layout.rest_tip()
	for k in 4:
		var eye := layout.eye_center(s.next_column(), 0)
		# 先从旁边落到眼的正下方，再向上穿过，出眼后略向前上方偏。
		var path: Array[Vector2] = [p, eye + Vector2(-0.15, -0.55), eye + Vector2(0.05, 0.1), eye + Vector2(0.3, 0.7)]
		feed_path(recognizers, path)
		p = path[path.size() - 1]
	check(same(g["hooks"], [0, 1, 2, 3]), "连续 4 次锯齿钩针都触发")
	check(s.completed, "一行下针织完")



# ---------------------------------------------------------------- 星级与失误（T006）

func test_star_rating_defaults_and_custom() -> void:
	var r := StarRating.new()
	check(r.stars_for(0) == 3 and r.stars_for(1) == 2 and r.stars_for(2) == 2, "默认：0 失误 3 星，1–2 失误 2 星")
	check(r.stars_for(3) == 1 and r.stars_for(10) == 1, "默认：3 次及以上 1 星")
	var plain := StarRating.for_level(LevelDefinition.new())
	check(plain.stars_for(0) == 3 and plain.stars_for(3) == 1, "LevelDefinition 不填阈值时用默认值")
	var level := LevelDefinition.new()
	level.three_star_max_mistakes = 1
	level.two_star_max_mistakes = 4
	var custom := StarRating.for_level(level)
	check(custom.stars_for(1) == 3 and custom.stars_for(4) == 2 and custom.stars_for(5) == 1, "阈值来自 LevelDefinition")


func test_level_score_counts_wrong_side_only() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var score := LevelScore.new()
	score.track(s)
	s.try_hook(1)
	check(score.mistakes == 0, "钩错眼（NOT_NEXT）不算失误")
	s.toggle_yarn()
	s.try_hook(0)
	check(score.mistakes == 1 and score.stars() == 2, "线在错的一面（WRONG_SIDE）算 1 次失误 → 2 星")
	knit_rest_of_row(s)
	check(s.completed and score.stars() == 2, "完成时仍是 2 星")
	s.try_hook(0)
	check(score.mistakes == 1, "完成后再钩（LEVEL_DONE）不算失误")
	var clean := make_session(PackedStringArray(["KP"]))
	var clean_score := LevelScore.new()
	clean_score.track(clean)
	knit_rest_of_row(clean)
	check(clean.completed and clean_score.stars() == 3, "0 失误 3 星")
	var sloppy := make_session(PackedStringArray(["KKKK"]))
	var sloppy_score := LevelScore.new()
	sloppy_score.track(sloppy)
	sloppy.toggle_yarn()
	for k in 3:
		sloppy.try_hook(sloppy.next_column())
	check(sloppy_score.stars() == 1, "3 次失误 1 星")


# ---------------------------------------------------------------- 预置织物与剪断（T006）

func test_preset_mismatch_needs_cut_then_cut_restores() -> void:
	var s := make_session(PackedStringArray(["KKKK"]))
	var score := LevelScore.new()
	score.track(s)
	var cuts := [0]
	s.fabric_cut.connect(func() -> void: cuts[0] += 1)
	s.set_preset(PackedStringArray(["KKPK"]))
	check(s.needs_cut, "预置与图纸不符 → 需要剪断")
	check(same(s.mistake_cells(), [Vector2i(2, 1)]), "错的线圈在第 1 行第 2 列")
	check(s.next_column() == -1, "需要剪断时没有下一针")
	var result := s.try_hook(0)
	check(result.status == HookResult.Status.BLOCKED, "需要剪断时钩针返回 BLOCKED")
	check(s.fabric.stitch_at(1, 2) is PurlStitch and s.stitches_in_row == 4, "BLOCKED 不改动织物")
	check(not s.toggle_yarn(), "需要剪断时不切换线状态")
	check(score.mistakes == 0, "BLOCKED 不算失误")
	s.cut()
	check(cuts[0] == 1, "剪断发出 fabric_cut")
	check(not s.needs_cut and not s.completed, "剪断后可以继续织")
	check(s.current_row == 1 and s.stitches_in_row == 0 and s.next_column() == 0, "剪断后回到起始行之上的第 1 行")
	check(not s.fabric.has_stitch(1, 0) and s.fabric.has_stitch(0, 0), "剪掉预置行，起始行保留")
	knit_rest_of_row(s)
	check(s.completed and s.mistake_cells().is_empty(), "剪断后重织完成，织物与图纸一致")
	s.restart()
	check(not s.needs_cut and not s.fabric.has_stitch(1, 0), "剪断是永久的：restart 不再放回预置")


func test_preset_matching_continues_and_plain_level_unaffected() -> void:
	var s := make_session(PackedStringArray(["KKK", "PPP"]))
	s.set_preset(PackedStringArray(["KKK"]))
	check(not s.needs_cut, "预置正确不需要剪断")
	check(s.current_row == 2 and s.next_column() == 2, "从预置之后的一行接着织（偶数行从右边开始）")
	knit_rest_of_row(s)
	check(s.completed, "接着织完整关")
	var plain := make_session(PackedStringArray(["KK"]))
	check(not plain.needs_cut and plain.mistake_cells().is_empty(), "没有预置的关卡不受影响")
	check(plain.try_hook(0).is_accepted(), "没有预置的关卡正常钩针")


func test_snip_level_resource_needs_cut() -> void:
	var catalog := load("res://resources/levels/level_catalog.tres") as LevelCatalog
	var level := catalog.get_level(2)
	var s := KnitSession.new(level.chart, _registry)
	s.set_preset(level.preset_rows)
	check(s.needs_cut and same(s.mistake_cells(), [Vector2i(2, 1)]), "第 3 关（snip）一开始就需要剪断")


# ---------------------------------------------------------------- 宽松绕线（T006）

## 可控的时钟：返回 [时钟 Callable, 时间数组]。
func fake_clock(wrap_gesture: WrapGesture) -> Array:
	var t := [0.0]
	wrap_gesture.clock = func() -> float: return t[0]
	return t


func test_wrap_relaxed_turn_threshold() -> void:
	var g := make_gestures(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
	feed_path(recognizers, circle_path(layout.anchor(), 0.9, -90.0, 185.0))
	check(g["wraps"][0] == 1, "约 275° 就算绕了一圈")
	var short := make_gestures(PackedStringArray(["PPPP"]))
	var short_rec: Array[GestureRecognizer] = [short["wrap"]]
	feed_path(short_rec, circle_path(layout.anchor(), 0.9, -90.0, 160.0))
	check(short["wraps"][0] == 0, "250° 还不算一圈")


func test_wrap_wide_radius_range() -> void:
	for radius in [0.25, 1.9]:
		var g := make_gestures(PackedStringArray(["PPPP"]))
		var layout: FabricLayout = g["layout"]
		var rec: Array[GestureRecognizer] = [g["wrap"]]
		feed_path(rec, circle_path(layout.anchor(), radius, -90.0, 190.0))
		check(g["wraps"][0] == 1, "半径 %.2f 列宽的圈有效" % radius)
	var far := make_gestures(PackedStringArray(["PPPP"]))
	var far_layout: FabricLayout = far["layout"]
	var far_rec: Array[GestureRecognizer] = [far["wrap"]]
	feed_path(far_rec, circle_path(far_layout.anchor(), 2.3, -90.0, 270.0))
	check(far["wraps"][0] == 0, "半径 2.3 列宽（超出 2.0）不算绕线")


## 绕到一半线头冲出范围（不超过 2.5 列宽），时间 dt 后回来接着绕。
func wrap_with_excursion(dt: float, out_radius: float) -> int:
	var g := make_gestures(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var wrap_gesture: WrapGesture = g["wrap"]
	var t := fake_clock(wrap_gesture)
	var a := layout.anchor()
	var rec: Array[GestureRecognizer] = [wrap_gesture]
	feed_path(rec, circle_path(a, 0.9, -90.0, 60.0))
	var out := a + Vector2(cos(deg_to_rad(75.0)), sin(deg_to_rad(75.0))) * out_radius
	var back := a + Vector2(0.0, 0.9)
	var excursion: Array[Vector2] = [a + Vector2(cos(deg_to_rad(60.0)), sin(deg_to_rad(60.0))) * 0.9, out]
	feed_path(rec, excursion)
	t[0] += dt
	var ret: Array[Vector2] = [out, back]
	feed_path(rec, ret)
	feed_path(rec, circle_path(a, 0.9, 90.0, 200.0))
	return g["wraps"][0]


func test_wrap_brief_excursion_does_not_reset() -> void:
	check(wrap_with_excursion(0.1, 2.3) == 1, "离开范围 0.1 秒（2.3 列宽内）回来接着绕仍算一圈")
	check(wrap_with_excursion(0.5, 2.3) == 0, "离开范围超过 0.3 秒清零")
	check(wrap_with_excursion(0.0, 2.8) == 0, "冲出 2.5 列宽立即清零")


func test_wrap_cooldown_blocks_hook_briefly() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var wrap_gesture: WrapGesture = g["wrap"]
	var t := fake_clock(wrap_gesture)
	var rec: Array[GestureRecognizer] = [wrap_gesture, g["hook"]]
	feed_path(rec, circle_path(layout.anchor(), 0.9, -90.0, 190.0))
	check(g["wraps"][0] == 1, "绕线完成")
	var eye := layout.eye_center(0, 0)
	var through: Array[Vector2] = [eye + Vector2(0, -0.8), eye + Vector2(0, 0.8)]
	feed_path(rec, through)
	check((g["hooks"] as Array).is_empty(), "刚绕完一圈的短时间内穿过眼不算钩针")
	t[0] += 0.5
	# 先把线头拿远（超出 2.5 列宽，绕线清零），再从下往上穿过眼。
	var again: Array[Vector2] = [eye + Vector2(0, 0.8), eye + Vector2(2.0, -1.5), eye + Vector2(0, -0.8), eye + Vector2(0, 0.8)]
	feed_path(rec, again)
	check(same(g["hooks"], [0]), "冷却过后正常钩针")


## 偶数行（从右往左）：锯齿钩针不误伤，镜像的小圈绕线不误触钩针。
func test_even_row_sawtooth_and_small_wrap() -> void:
	var g := make_gestures(PackedStringArray(["KKKK", "KKKK"]))
	var s: KnitSession = g["session"]
	var layout: FabricLayout = g["layout"]
	knit_rest_of_row(s)
	g["hook"].hook_requested.connect(s.try_hook)
	var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
	var p := layout.rest_tip()
	for k in 4:
		var eye := layout.eye_center(s.next_column(), 1)
		var path: Array[Vector2] = [p, eye + Vector2(0.15, -0.55), eye + Vector2(-0.05, 0.1), eye + Vector2(-0.3, 0.7)]
		feed_path(recognizers, path)
		p = path[path.size() - 1]
	check(same(g["hooks"], [3, 2, 1, 0]), "偶数行连续 4 次锯齿钩针都触发（从右往左）")
	check(s.completed, "偶数行织完")
	for radius in [0.45, 0.54, 0.65]:
		var w := make_gestures(PackedStringArray(["KKKK", "KKKK"]))
		knit_rest_of_row(w["session"])
		var w_layout: FabricLayout = w["layout"]
		var rec: Array[GestureRecognizer] = [w["wrap"], w["hook"]]
		feed_path(rec, circle_path(w_layout.anchor(), radius, 300.0, -60.0))
		check((w["hooks"] as Array).is_empty(), "偶数行半径 %.2f 的顺时针小圈不触发钩针" % radius)
		check(w["wraps"][0] == 1, "偶数行半径 %.2f 的小圈完成绕线" % radius)


func test_loop_width_is_optional() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var wide := FabricLayout.new(s)
	var narrow := FabricLayout.new(s, 0.72)
	check(is_equal_approx(wide.loop_width, 1.0), "loop_width 默认 1.0（旧几何）")
	var kw := wide.loop_keys(0, 0)
	var kn := narrow.loop_keys(0, 0)
	check(kw[0].is_equal_approx(kn[0]) and kw[12].is_equal_approx(kn[12]), "沉降弧端点仍在列边界，与相邻线圈相接")
	check(absf(kn[4].x) < absf(kw[4].x) and is_equal_approx(kn[4].y, kw[4].y), "线圈主体变窄、高度不变")
	check(narrow.eye_center(1, 0) == wide.eye_center(1, 0) and narrow.anchor() == wide.anchor(), "眼与锚点位置不变（判定不受影响）")


# ---------------------------------------------------------------- 钩针可靠性（T007）
# 每条对应 T007 诊断出的一个「穿过但不成针」原因；路径为织物坐标，第 1 行下一针的眼为 eye。

## 同 feed_path，但每个补采样点按线头速度 speed（列宽/秒）推进假时钟 t。
func feed_timed(recognizers: Array[GestureRecognizer], pts: Array[Vector2], t: Array, speed: float) -> void:
	for k in range(1, pts.size()):
		var steps := maxi(1, ceili(pts[k - 1].distance_to(pts[k]) / 0.05))
		for s in range(1, steps + 1):
			t[0] += pts[k - 1].distance_to(pts[k]) / steps / speed
			var q := pts[k - 1].lerp(pts[k], float(s) / steps)
			for r in recognizers:
				r.feed(q)


## 带假时钟的识别器组，钩针请求接到规则层。
func make_timed(rows: PackedStringArray) -> Dictionary:
	var g := make_gestures(rows)
	var s: KnitSession = g["session"]
	g["hook"].hook_requested.connect(s.try_hook)
	g["wrap"].wrap_completed.connect(s.toggle_yarn)
	g["t"] = fake_clock(g["wrap"])
	var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
	g["rec"] = recognizers
	return g


## 原因 1：快速甩过、刚过眼就松手——旧判定要「离开出眼半径」才算，松手时还在圈里就丢了。
func test_t007_flick_and_release_hooks() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var path: Array[Vector2] = [layout.rest_tip(), eye + Vector2(0.22, 0.18)]
	feed_timed(g["rec"], path, g["t"], 25.0)
	g["hook"].reset()
	check(same(g["hooks"], [0]), "快速甩过眼、停在眼里就松手也成针")


## 原因 2：从侧面低角度斜着进——旧判定按进圈那一刻的位置判断「从下面来」，进圈点在中线上方就不算。
func test_t007_low_angle_side_entry_hooks() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var path: Array[Vector2] = [layout.rest_tip(), eye + Vector2(-0.75, -0.12), eye + Vector2(0.7, 0.32)]
	feed_timed(g["rec"], path, g["t"], 6.0)
	check(same(g["hooks"], [0]), "从左侧低角度斜着穿过眼成针")
	var even := make_timed(PackedStringArray(["KKKK", "KKKK"]))
	var es: KnitSession = even["session"]
	knit_rest_of_row(es)
	var el: FabricLayout = even["layout"]
	var eye2 := el.eye_center(es.next_column(), 1)
	var path2: Array[Vector2] = [el.rest_tip(), eye2 + Vector2(0.75, -0.12), eye2 + Vector2(-0.7, 0.32)]
	feed_timed(even["rec"], path2, even["t"], 6.0)
	check(same(even["hooks"], [3]), "偶数行从右侧低角度斜着穿过眼成针")


## 原因 3：向上穿过后马上转向前方——旧判定要求出圈点高于眼中心一段距离，出眼偏平就不算。
func test_t007_flat_exit_hooks() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var path: Array[Vector2] = [layout.rest_tip(), eye + Vector2(-0.05, -0.4), eye + Vector2(0.0, 0.02), eye + Vector2(0.7, 0.1)]
	feed_timed(g["rec"], path, g["t"], 6.0)
	check(same(g["hooks"], [0]), "穿过眼后立即平着向前也成针")


## 原因 4：判定圈太小——偏离眼中心 0.28 列竖直穿过（旧进圈半径 0.26）不算；新半径 0.32 内都算，0.4 仍不算。
func test_t007_wider_eye_radius() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var path: Array[Vector2] = [layout.rest_tip(), eye + Vector2(0.28, -0.5), eye + Vector2(0.28, 0.7)]
	feed_timed(g["rec"], path, g["t"], 6.0)
	check(same(g["hooks"], [0]), "偏离眼中心 0.28 列穿过成针")
	var far := make_timed(PackedStringArray(["KKKK"]))
	var path2: Array[Vector2] = [layout.rest_tip(), eye + Vector2(0.4, -0.5), eye + Vector2(0.4, 0.7)]
	feed_timed(far["rec"], path2, far["t"], 6.0)
	check((far["hooks"] as Array).is_empty(), "偏离 0.4 列（两眼之间）不成针")
	check(far["hook"].last_ignored == HookGesture.IgnoreReason.OFF_EYE, "并记录原因 OFF_EYE")


## 原因 5：绕线守卫按「净转角 > 90°」挡钩针——慢慢从左下兜过来再上穿（不是在绕圈）也被挡。
func test_t007_slow_scoop_not_blocked() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var path: Array[Vector2] = [layout.rest_tip(), eye + Vector2(-0.9, -0.45), eye + Vector2(0.1, -0.5), eye + Vector2(0.05, 0.7)]
	feed_timed(g["rec"], path, g["t"], 0.8)
	check(same(g["hooks"], [0]), "慢速兜过来再上穿（角速度低，不是绕圈）成针")
	check(g["wraps"][0] == 0, "也不算绕线")


## 原因 6：按住不放绕完线、同方向接着兜到眼下方再上穿——旧守卫的转角在绕线完成后重新累计，超过 90° 就挡。
func test_t007_wrap_then_hook_in_one_stroke() -> void:
	var g := make_timed(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var s: KnitSession = g["session"]
	var a := layout.anchor()
	var eye := layout.eye_center(0, 0)
	var start := rad_to_deg((layout.rest_tip() - a).angle())
	var path: Array[Vector2] = [layout.rest_tip()]
	path.append_array(circle_path(a, 0.85, start, start + 290.0))
	path.append_array([eye + Vector2(-0.1, -0.5), eye + Vector2(0.05, 0.7)] as Array[Vector2])
	feed_timed(g["rec"], path, g["t"], 6.0)
	check(g["wraps"][0] == 1, "一笔里先完成绕线")
	check(same(g["hooks"], [0]) and s.fabric.count_in_row(1) == 1, "接着上穿成针（上针）")


## 原因 7：绕线完成后 0.35 秒冷却期挡住所有钩针——绕完停一下（0.2 秒）就去钩，仍在旧冷却期内被挡。
## 新规则：冷却缩短为 0.15 秒，且只挡同方向继续绕；之后要再绕满一圈才重新挡。
func test_t007_hook_soon_after_wrap() -> void:
	var g := make_timed(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var s: KnitSession = g["session"]
	var a := layout.anchor()
	var eye := layout.eye_center(0, 0)
	var wrap_path := circle_path(a, 0.85, -60.0, 212.0)
	feed_timed(g["rec"], wrap_path, g["t"], 6.0)
	var t0: float = g["t"][0]
	g["t"][0] += 0.2
	var path: Array[Vector2] = [wrap_path[wrap_path.size() - 1], eye + Vector2(0.0, -0.3), eye + Vector2(0.0, 0.6)]
	feed_timed(g["rec"], path, g["t"], 20.0)
	check(g["wraps"][0] == 1 and same(g["hooks"], [0]), "绕线后 0.2 秒去钩成针")
	check(g["t"][0] - t0 < 0.35, "（这一笔在旧的 0.35 秒冷却期内）")
	check(s.fabric.count_in_row(1) == 1, "上针成功")


## 守卫仍然有效：正在快速绕小圈时穿过眼不成针（T003 回归），原因记为 GUARD。
func test_t007_guard_reason_recorded() -> void:
	var g := make_timed(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	feed_timed(g["rec"], circle_path(layout.anchor(), 0.54, -120.0, 240.0), g["t"], 4.0)
	check((g["hooks"] as Array).is_empty() and g["wraps"][0] == 1, "快速小圈：不钩针、完成绕线")
	check(g["hook"].last_ignored == HookGesture.IgnoreReason.GUARD, "被忽略的原因为 GUARD")


# ---------------------------------------------------------------- 玩家进度（T008）

func test_t008_progress_records_first_completion() -> void:
	var p := PlayerProgress.new()
	check(p.best_stars(&"rib") == 0 and not p.is_completed(&"rib"), "没完成过的关为 0 星")
	check(p.record(&"rib", 2), "第一次完成记录成功")
	check(p.best_stars(&"rib") == 2 and p.is_completed(&"rib"), "记录后最好成绩为 2 星")
	check(p.completed_count() == 1, "完成关数为 1")


func test_t008_progress_keeps_only_best() -> void:
	var p := PlayerProgress.new()
	var improved: Array[int] = []
	p.improved.connect(func(_id: StringName, stars: int) -> void: improved.append(stars))
	p.record(&"seed", 2)
	check(not p.record(&"seed", 1), "更差的成绩不覆盖")
	check(not p.record(&"seed", 2), "相同的成绩不算提高")
	check(p.best_stars(&"seed") == 2, "仍为 2 星")
	check(p.record(&"seed", 3) and p.best_stars(&"seed") == 3, "更好的成绩覆盖")
	check(same(improved, [2, 3]), "只有提高时发出 improved")


func test_t008_progress_rejects_invalid() -> void:
	var p := PlayerProgress.new()
	check(not p.record(&"rib", 0), "0 星不记录")
	check(not p.record(&"rib", StarRating.MAX_STARS + 1), "超过最多星数不记录")
	check(not p.record(&"", 3), "空 id 不记录")
	check(p.completed_count() == 0, "无效记录不影响进度")


func test_t008_progress_dict_round_trip() -> void:
	var p := PlayerProgress.new()
	p.record(&"first_stitch", 3)
	p.record(&"basket", 1)
	var data := p.to_dict()
	check(data.get("first_stitch") == 3 and data.get("basket") == 1 and data.size() == 2, "to_dict 输出 {id: 星数}")
	var q := PlayerProgress.from_dict(data)
	check(q.best_stars(&"first_stitch") == 3 and q.best_stars(&"basket") == 1 and q.completed_count() == 2, "from_dict 还原")
	var dirty := PlayerProgress.from_dict({"rib": 2.0, "seed": "3", "turn": 9, "ridges": 0})
	check(dirty.best_stars(&"rib") == 2 and dirty.completed_count() == 1, "from_dict 接受 JSON 的浮点数，忽略非数字和越界条目")
	q.clear()
	check(q.completed_count() == 0 and not q.is_completed(&"basket"), "clear 清空")
