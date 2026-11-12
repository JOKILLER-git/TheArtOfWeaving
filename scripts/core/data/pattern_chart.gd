class_name PatternChart
extends Resource
## 图纸：rows[0] 是起始行之上的第一行，每个字符是一个针法 id（如 "KPKP"）。

@export var rows: PackedStringArray = PackedStringArray()


func width() -> int:
	return rows[0].length() if not rows.is_empty() else 0


func height() -> int:
	return rows.size()


## 第 row 行（从 0 起，不含起始行）第 col 列的针法 id。
func stitch_at(row: int, col: int) -> String:
	return rows[row][col]


## 每行等宽且所有 id 都已在登记表里注册。
func is_valid(registry: StitchRegistry) -> bool:
	if rows.is_empty() or width() == 0:
		return false
	for line in rows:
		if line.length() != width():
			return false
		for k in line.length():
			if not registry.has(line[k]):
				return false
	return true
