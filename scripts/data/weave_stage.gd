class_name WeaveStage
extends Resource
## 目录中的一关。相同玩法只需更换 lesson；不同布局可指定独立场景。
@export var id: String = ""
@export var title: String = ""
@export var lesson: WeaveLesson
## 留空使用 GameBrowser 的默认关卡场景，指定时根节点必须是 WeaveLevel。
@export var scene: PackedScene
