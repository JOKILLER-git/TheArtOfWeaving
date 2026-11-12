extends RefCounted
## app 层测试：LevelSequence 的顺序推进与重置（纯逻辑），以及 GameApp 的界面流程（需要场景树）。
## T006：Next 按钮去掉了（改为星级动画后自动进入下一关），相应断言改为检查进度珠；新增剪断流程与拉线物件的测试。
## T008：GameApp 的进度存储换成只在内存里的 ProgressStore（不读写 user:// 存档，测试互不影响）；
## 新增选关（晾衣绳）、进度存储、开始界面剪刀退出的测试。
## 入口：run() 返回 {passed, checks, failures}；命令行见 run_app_tests.gd。

const CATALOG_PATH := "res://resources/levels/level_catalog.tres"
const APP_SCENE := "res://scenes/app/game_app.tscn"

var checks: int = 0
var failures: Array[String] = []


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


func load_catalog() -> LevelCatalog:
	return load(CATALOG_PATH) as LevelCatalog


## 测试用 GameApp：进度只放内存，退出动作只计数（不真的退出）。quits[0] 为退出次数。
func make_app(quits: Array = [0]) -> GameApp:
	var app := (load(APP_SCENE) as PackedScene).instantiate() as GameApp
	app.progress_store = ProgressStore.new("")
	app.quit_handler = func() -> void: quits[0] += 1
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


## 用规则层把当前这关织完（需要时切换线状态）；织物需要剪断时先用关卡的剪断（同剪刀）。
func finish_level(view: KnitLevelView) -> void:
	if view.session.needs_cut:
		view.restart()
	var session := view.session
	while not session.completed:
		if not session.is_yarn_ready():
			session.toggle_yarn()
		session.try_hook(session.next_column())


# ---------------------------------------------------------------- LevelSequence

func test_sequence_starts_at_first_level() -> void:
	var catalog := load_catalog()
	var seq := LevelSequence.new(catalog)
	check(seq.index == 0 and seq.current() == catalog.get_level(0), "序列从第 1 关开始")
	check(seq.count() == catalog.count(), "关卡数与目录一致")
	check(seq.progress_text() == "1 / %d" % catalog.count(), "进度文字 1 / N")


func test_sequence_advances_in_catalog_order_without_wrap() -> void:
	var catalog := load_catalog()
	var seq := LevelSequence.new(catalog)
	for i in range(1, catalog.count()):
		check(seq.advance(), "第 %d 关之后还有下一关" % i)
		check(seq.current() == catalog.get_level(i), "推进后是目录第 %d 关" % (i + 1))
	check(seq.is_last(), "到达最后一关")
	check(seq.progress_text() == "%d / %d" % [catalog.count(), catalog.count()], "进度文字 N / N")
	check(not seq.advance(), "最后一关之后 advance 返回 false（本轮结束）")
	check(seq.index == catalog.count() - 1, "最后一关之后不回绕")


func test_sequence_reset_for_replay() -> void:
	var seq := LevelSequence.new(load_catalog())
	seq.advance()
	seq.advance()
	seq.reset()
	check(seq.index == 0 and not seq.is_last(), "reset 回到第 1 关")


# ---------------------------------------------------------------- GameApp 流程

func test_game_app_full_flow() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		check(false, "需要场景树才能测 GameApp")
		return
	var app := make_app()
	var catalog := app.catalog
	check(app.screen == GameApp.Screen.TITLE, "启动后是开始界面")
	check(app.level_view == null, "开始界面没有关卡")

	app.start_game()
	check(app.screen == GameApp.Screen.PLAYING and app.level_view != null, "Start 后进入关卡")
	check(app.level_view.current_level() == catalog.get_level(0), "从第 1 关开始")

	app.advance()
	check(app.sequence.index == 0, "关卡未完成时不能进入下一关")

	for i in catalog.count():
		check(app.level_view.current_level() == catalog.get_level(i), "第 %d 关按目录顺序加载" % (i + 1))
		check(not app.is_current_bead_done(), "第 %d 关未完成时当前进度珠未完成" % (i + 1))
		finish_level(app.level_view)
		check(app.level_view.is_completed() and app.is_current_bead_done(), "第 %d 关完成后进度珠标为完成" % (i + 1))
		check(app.level_view.stars_earned() == 3, "第 %d 关无失误 3 星" % (i + 1))
		app.advance()
	check(app.screen == GameApp.Screen.FINISHED, "最后一关之后进入结束界面")
	check(app.level_view == null, "结束界面释放关卡")
	check(app.progress.completed_count() == catalog.count(), "T008：每关的成绩都记进玩家进度")

	app.start_game()
	check(app.screen == GameApp.Screen.PLAYING and app.sequence.index == 0, "Play again 回到第 1 关")
	var s := app.level_view.session
	check(not s.completed and s.current_row == 1 and s.stitches_in_row == 0, "重玩时关卡状态是新的")

	app.show_title()
	check(app.screen == GameApp.Screen.TITLE and app.level_view == null, "回到开始界面并释放关卡")
	app.queue_free()



# ---------------------------------------------------------------- 剪刀与拉线（T006）

## 第 3 关：预置织物有错 → 剪刀没剪到不动；剪到织物 → 回到起始行 → 重织完成。
func test_snip_level_cut_flow() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var catalog := load_catalog()
	var view := (load("res://scenes/knit/knit_level_2d.tscn") as PackedScene).instantiate() as KnitLevel2D
	view.play(catalog.get_level(2))
	tree.root.add_child(view)
	check(view.session.needs_cut, "第 3 关开始时需要剪断")
	check(view.session.try_hook(0).status == HookResult.Status.BLOCKED, "剪断前钩针被拒（BLOCKED）")
	check(not view.hits_yarn_or_fabric(Vector2(640, 40)), "剪刀落在空白处不算剪到")
	var center := view.fabric_rect().get_center()
	check(view.hits_yarn_or_fabric(center), "剪刀落在织物上算剪到")
	view.cut_at(center)
	check(not view.session.needs_cut and view.session.current_row == 1 and view.session.stitches_in_row == 0, "剪断后回到起始行")
	finish_level(view)
	check(view.is_completed() and view.stars_earned() == 3, "剪断后重织完成，3 星")
	view.queue_free()


func test_yarn_pull_reaches_target() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var pull := YarnPull2D.new()
	tree.root.add_child(pull)
	check(not pull.grab_at(pull.rest_tip + Vector2(200, 0)), "离线头远处抓不到")
	check(pull.grab_at(pull.rest_tip), "抓住线头")
	pull.drag_to((pull.rest_tip + pull.target) * 0.5)
	check(not pull.done, "拉到一半还没开始")
	pull.drag_to(pull.target + Vector2(20, 10))
	check(pull.done and not pull.held, "拉到线轴附近即完成")
	pull.reset()
	check(not pull.done and pull.tip == pull.rest_tip, "reset 后线头回到原处")
	pull.queue_free()


# ---------------------------------------------------------------- T008：选关、进度存储、开始界面剪刀

func test_t008_sequence_select() -> void:
	var seq := LevelSequence.new(load_catalog())
	check(seq.select(10) and seq.index == 10 and seq.is_last(), "select 跳到第 11 关")
	check(not seq.select(-1) and not seq.select(seq.count()) and seq.index == 10, "越界的 select 不动")
	check(seq.select(3) and seq.advance() and seq.index == 4, "跳关后照常往后走")


func test_t008_progress_store_round_trip() -> void:
	var path := "user://t008_test_progress.json"
	var store := ProgressStore.new(path)
	var p := PlayerProgress.new()
	p.record(&"rib", 2)
	p.record(&"basket", 3)
	check(store.save(p), "进度保存成功")
	var q := store.load_progress()
	check(q.best_stars(&"rib") == 2 and q.best_stars(&"basket") == 3 and q.completed_count() == 2, "读回的进度与保存的一致")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(store.load_progress().completed_count() == 0, "存档损坏时返回空进度")
	var memory := ProgressStore.new("")
	check(not memory.save(p) and memory.load_progress().completed_count() == 0, "路径为空时只在内存里（不读写文件）")


## 记录成绩只保留最好的；织完一关时 GameApp 写入进度、进度珠显示完成过的关。
func test_t008_level_finish_records_best() -> void:
	var app := make_app()
	var catalog := app.catalog
	app.progress.record(catalog.get_level(1).id, 3)
	app.play_level(1)
	app.level_view.score.mistakes = 4
	finish_level(app.level_view)
	check(app.progress.best_stars(catalog.get_level(1).id) == 3, "更差的成绩（1 星）不覆盖已有的 3 星")
	app.play_level(2)
	finish_level(app.level_view)
	check(app.progress.best_stars(catalog.get_level(2).id) == 3, "新完成的关记为 3 星")
	app.play_level(5)
	check(app.is_current_bead_done() == false, "没完成过的当前关进度珠未完成")
	app.play_level(2)
	check(app.is_current_bead_done(), "以前完成过的关进度珠显示完成")
	app.queue_free()


## 选关：打开时关卡暂停；点第 11 关 → 进入第 11 关；关闭后关卡继续、本关状态不变。
func test_t008_clothesline_select_and_close() -> void:
	var app := make_app()
	var catalog := app.catalog
	app.progress.record(catalog.get_level(0).id, 2)
	app.play_level(3)
	var cl := app.clothesline()
	var view := app.level_view
	check(cl.visible and not cl.is_active() and not app.is_level_paused(), "关卡中选关收起，关卡在运行")
	var s := view.session
	if not s.is_yarn_ready():
		s.toggle_yarn()
	s.try_hook(s.next_column())
	var made := s.stitches_in_row

	cl.open()
	check(cl.is_active() and app.is_level_paused(), "打开选关时关卡暂停（处理与输入）")
	check(cl.cards().size() == catalog.count(), "每关一张卡片")
	var c0 := cl.cards()[0]
	check(c0._thumb.is_completed() and c0._thumb.best_stars == 2, "完成过的关：织片 + 最好星数")
	check(not cl.cards()[1]._thumb.is_completed(), "没完成的关：铅笔草图")
	check(cl.cards()[3].is_current and not cl.cards()[0].is_current, "当前关的卡片发光")

	cl.close()
	cl.force_close()
	check(not app.is_level_paused() and app.level_view == view and view.session == s and s.stitches_in_row == made, "关闭后回到本关原状态")

	cl.open()
	cl.choose(3)
	cl.force_close()
	check(app.level_view.session == s, "点当前关只收回，不重置本关")

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	cl.open()
	cl._unhandled_key_input(esc)
	check(cl.state == LevelClothesline2D.State.ANIMATING and app.screen == GameApp.Screen.PLAYING, "Esc 收回选关，不回开始界面")
	cl.force_close()

	cl.open()
	cl.choose(10)
	check(app.sequence.index == 10 and app.level_view.current_level() == catalog.get_level(10), "点第 11 关卡片进入第 11 关")
	var s11 := app.level_view.session
	check(not s11.completed and s11.current_row == 1 and s11.stitches_in_row == 0, "选中的关从头开始")
	cl.force_close()
	check(not app.is_level_paused(), "收回后第 11 关可以操作")
	finish_level(app.level_view)
	app.advance()
	check(app.screen == GameApp.Screen.FINISHED, "第 11 关之后进入结束界面")
	app.queue_free()


## 结束界面的织片墙用同一份进度：完成过的显示织片和星，没完成的是草图。
func test_t008_end_wall_uses_progress() -> void:
	var app := make_app()
	var catalog := app.catalog
	app.progress.record(catalog.get_level(0).id, 1)
	app.play_level(10)
	finish_level(app.level_view)
	app.advance()
	var wall := app.get_node("%EndScreen").get_node("%Wall") as SwatchWall2D
	var thumbs: Array[LevelThumb2D] = []
	for child in wall.get_children():
		if child is LevelThumb2D and not child.is_queued_for_deletion():
			thumbs.append(child)
	check(thumbs.size() == catalog.count(), "织片墙每关一块")
	check(thumbs[0].best_stars == 1 and thumbs[10].best_stars == 3, "织片墙显示每关最好星数")
	check(not thumbs[5].is_completed(), "没完成的关在织片墙上是草图")
	app.queue_free()


## 开始界面：剪刀剪到空白处无反应；剪到拉线 → 线断、请求退出；GameApp 淡出后调用退出动作。
func test_t008_title_scissors_quit() -> void:
	var quits := [0]
	var app := make_app(quits)
	var title := app.get_node("%TitleScreen") as TitleScreen
	var pull := title.get_node("%Pull") as YarnPull2D
	check(not title.cut_at(Vector2(640, 80)), "剪到空白处无反应")
	check(not pull.is_cut, "线没断")
	var on_strand := pull.strand_points()[8]
	check(title.cut_at(on_strand) and pull.is_cut, "剪到拉线：线断了")
	check(not pull.can_grab(pull.tip), "剪断后不能再拉")
	check(not title.cut_at(on_strand), "已剪断的线不再剪")
	app.quit_game()
	check(app.quitting and quits[0] == 0, "退出先淡出（淡出结束才调用退出动作）")
	app.queue_free()


func test_t008_yarn_pull_cut_and_reset() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var pull := YarnPull2D.new()
	tree.root.add_child(pull)
	var pts := pull.strand_points()
	check(pull.hits_strand(pts[14]), "线中间算剪到")
	check(not pull.hits_strand(pull.target), "线轴不算线")
	pull.cut()
	check(pull.is_cut and not pull.hits_strand(pts[14]), "剪断后不再算剪到")
	pull.reset()
	check(not pull.is_cut and pull.can_grab(pull.rest_tip), "reset 后线恢复")
	pull.queue_free()
