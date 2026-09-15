class_name WorldFactory
extends RefCounted

## 世界的构造入口：从配置开新档，或把存档的可变状态合并到配置骨架上。
##
## 这个类存在的核心理由是"配置不进存档"：城市名称、坐标、黑市渠道都留在
## cities.json 里，存档只写六维与 NPC 列表。读档时必须以**配置为骨架**，
## 再把存档的可变字段覆盖上去；反过来做的话，存档里会留着一份陈旧的配置
## 副本，改配置就对老存档不生效。

## 新建世界。city_configs 来自 ContentLoader。
static func create_new(
	world_seed: int, city_configs: Array, grid_width: int, grid_height: int
) -> Dictionary:
	var world: WorldState = WorldState.create(world_seed)
	var grid: MapGrid = MapGrid.new(grid_width, grid_height)
	for cfg in city_configs:
		var city: City = City.from_config(cfg)
		world.add_city(city)
		grid.register_city(city)
	return {"world": world, "grid": grid}


## 从存档构造：先按配置建骨架，再覆盖可变状态。
static func from_save(
	world_data: Dictionary, city_configs: Array, grid_width: int, grid_height: int
) -> Dictionary:
	var seed_value: int = int(world_data.get("worldSeed", 0))
	var built: Dictionary = create_new(seed_value, city_configs, grid_width, grid_height)
	var world: WorldState = built["world"]
	world.apply_dict(world_data)
	return built
