class_name ProgressStore
extends RefCounted
## 玩家进度的存储（app 层，T008）：把 PlayerProgress 以 JSON 存到 user:// 文件。
## 规则（只保留最好成绩）在 core 的 PlayerProgress 里，本类只管读写。path 为空 = 只在内存里（测试用）。

const DEFAULT_PATH := "user://progress.json"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## 读取进度；文件不存在或内容损坏时返回空进度。
func load_progress() -> PlayerProgress:
	if path.is_empty() or not FileAccess.file_exists(path):
		return PlayerProgress.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return PlayerProgress.new()
	var data: Variant = json.data
	if not (data is Dictionary):
		return PlayerProgress.new()
	var best: Variant = (data as Dictionary).get("best_stars", {})
	return PlayerProgress.from_dict(best if best is Dictionary else {})


## 保存进度；成功返回 true。
func save(progress: PlayerProgress) -> bool:
	if path.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("进度无法保存：%s" % path)
		return false
	file.store_string(JSON.stringify({"version": 1, "best_stars": progress.to_dict()}, "\t"))
	return true
