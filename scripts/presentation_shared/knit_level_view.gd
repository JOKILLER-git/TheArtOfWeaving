@abstract
class_name KnitLevelView
extends Control
## 「一关针织」的视图接口（GameApp 只依赖它）。实现：KnitLevel2D、KnitLevel3D。
## 两个实现都用同一套 core：KnitSession（规则）、LevelScore（成绩）、HookGesture / WrapGesture（手势）。
## 暂停：GameApp 把 process_mode 设为 DISABLED（Node 自带，无需额外方法）。

## 本关织完（星级动画开始）。
signal level_finished(level: LevelDefinition)
## 星级动画播完（或按 N 跳过）：请求下一关。
signal next_requested

## 单独运行本场景时使用的关卡。
@export var default_level: LevelDefinition

var session: KnitSession
var score: LevelScore


## 开始一关（新的会话、新的成绩）。加入场景树之前调用也可以。
@abstract func play(level: LevelDefinition) -> void


## 剪断重来（R 键与剪刀共用）。
@abstract func restart() -> void


@abstract func current_level() -> LevelDefinition


func is_completed() -> bool:
	return session != null and session.completed


## 本关当前的星级（按目前的失误次数）。
func stars_earned() -> int:
	return score.stars() if score != null else 0
