class_name DisguiseGate
extends RefCounted

## 变装绕过规则层（M-B 收口，9.32 节 D-137）。
##
## 罪犯态橱窗的后手：披上「改头换面」斗篷后，一段自然白昼内 Cappella 巷子的店主
## 认不出你，商铺照常交易——这是 M27 里 Keystone 在 criminal_state.gd 留的
## 「变装绕过是 M-B 后手」的原处；Economy.get_price 的 refused 由此从「业力已恶」
## 收紧成「业力已恶且此刻未变装」。
##
## 关键设计：**这里不读 Clock、不确定当天**。伪装时效落成一个绝对日
## （`avatar.disguise_until_day`），而「此刻算不算伪装」收敛成单一布尔
## （`avatar.is_disguised`），由 main 在每日边界调 `sync(world, today)` 派生。
## Economy 只查 `is_active(world)`（一个布尔），规则层对时间零耦合、可无头钉测。
##
## 伪装放化身上而非灵魂上是有意的：它是「身体这件皮」的事，转世换体自然清零，
## 不需要额外的清理逻辑。

const _SECTION: String = "disguise"
const _ITEM_TEMPLATE: String = "consumable_disguise"


## 「改头换面」斗篷的模板 id（items.json）。
static func item_template() -> String:
	return _ITEM_TEMPLATE


## 伪装长度（自然白昼数），读 balance.disguise.durationDays。
static func balance_duration() -> int:
	var section: Dictionary = ContentLoader.get_balance_section(_SECTION)
	return maxi(1, int(section.get("durationDays", 3)))


## 背包里披没披着能用的那件斗篷。
static func has_disguise_item(world: WorldState) -> bool:
	if world == null or world.avatar == null:
		return false
	for instance_id in world.avatar.inventory:
		var inst: Dictionary = world.avatar.item_instances.get(instance_id, {})
		if str(inst.get("templateId", "")) == _ITEM_TEMPLATE:
			return true
	return false


## 披上斗篷：扣一件、设时效与「伪装中」标志。today 是当前自然日（来自 Clock.now().day）。
static func apply(world: WorldState, today: int) -> Dictionary:
	if world == null or world.avatar == null:
		return {"ok": false, "reason": "还没有化身"}
	if not has_disguise_item(world):
		return {"ok": false, "reason": "你身上没带「改头换面」斗篷"}
	var avatar: PlayerAvatar = world.avatar
	for index in range(avatar.inventory.size()):
		var instance_id: String = str(avatar.inventory[index])
		if str(avatar.item_instances.get(instance_id, {}).get("templateId", "")) != _ITEM_TEMPLATE:
			continue
		avatar.inventory.remove_at(index)
		avatar.item_instances.erase(instance_id)
		break
	var duration: int = balance_duration()
	avatar.disguise_until_day = today + duration
	avatar.is_disguised = true
	return {"ok": true, "untilDay": avatar.disguise_until_day, "duration": duration}


## 主动脱下（一般用不到，留作玩家反悔/被掀穿时的出口）。
static func remove(world: WorldState) -> void:
	if world != null and world.avatar != null:
		world.avatar.is_disguised = false
		world.avatar.disguise_until_day = -1


## 每日边界调用：对照 today 判定伪装是否过期，过期自动剥下。today 来自 Clock.now().day。
static func sync(world: WorldState, today: int) -> void:
	if world == null or world.avatar == null:
		return
	var avatar: PlayerAvatar = world.avatar
	if avatar.disguise_until_day >= 0 and avatar.disguise_until_day >= today:
		avatar.is_disguised = true
	else:
		avatar.is_disguised = false
		avatar.disguise_until_day = -1


## Economy 只用这个布尔：此刻是不是伪装中。不含 Clock。
static func is_active(world: WorldState) -> bool:
	if world == null or world.avatar == null:
		return false
	return world.avatar.is_disguised