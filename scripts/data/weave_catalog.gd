class_name WeaveCatalog
extends Resource
## 数组顺序就是章节、关卡及“下一关”的顺序，不需要修改脚本。
@export var chapters: Array[WeaveChapter] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var chapter_ids := {}
	var stage_ids := {}
	for chapter in chapters:
		if chapter == null:
			errors.append("目录存在空章节。")
			continue
		if chapter.id.is_empty() or chapter_ids.has(chapter.id):
			errors.append("章节 ID 为空或重复：" + chapter.id)
		chapter_ids[chapter.id] = true
		for stage in chapter.stages:
			if stage == null:
				errors.append(chapter.title + " 中存在空关卡。")
				continue
			if stage.id.is_empty() or stage_ids.has(stage.id):
				errors.append("关卡 ID 为空或重复：" + stage.id)
			stage_ids[stage.id] = true
			if stage.lesson == null:
				errors.append(stage.title + " 未配置 Lesson。")
	return errors
