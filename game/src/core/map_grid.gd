class_name MapGrid
extends RefCounted

## 世界地图网格（M6.1）。
##
## 世界抽象为 120×120 的俯视角网格（《世界模拟量化规则》9.1）。城市占据
## 各自坐标，玩家按格移动。这里只管"能不能站在这格"与"这格是哪座城"，
## 不涉及渲染——渲染由表现层读位置后自己画。

var width: int = 120
var height: int = 120
var _city_by_coord: Dictionary = {}  ## "x,y" -> cityId


func _init(grid_width: int = 120, grid_height: int = 120) -> void:
	width = maxi(1, grid_width)
	height = maxi(1, grid_height)


func register_city(city: City) -> void:
	_city_by_coord[_coord_key(city.coord_x, city.coord_y)] = city.city_id


func is_inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## 该坐标上的城市 ID，没有则返回空串。
func get_city_id_at(x: int, y: int) -> String:
	return str(_city_by_coord.get(_coord_key(x, y), ""))


## 目标格是否可通行：必须在网格内。城市格可通行（进城）。
func can_enter(x: int, y: int) -> bool:
	return is_inside(x, y)


## 尝试把坐标移动一格。返回移动后的坐标；若目标格不可通行则原地不动。
func step(x: int, y: int, dx: int, dy: int) -> Vector2i:
	var tx: int = x + dx
	var ty: int = y + dy
	if not can_enter(tx, ty):
		return Vector2i(x, y)
	return Vector2i(tx, ty)


func clamp_to_bounds(x: int, y: int) -> Vector2i:
	return Vector2i(clampi(x, 0, width - 1), clampi(y, 0, height - 1))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _coord_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
