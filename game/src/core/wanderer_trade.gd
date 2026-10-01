class_name WandererTrade
extends RefCounted

## 冒险者随身买卖规则层（M33 深化 M-E·B / D-148）。
##
## M31 的冒险者只有雇佣价与战斗随从规格，身上没有「货」。本层让他们带一小批在城际
## 倒手的东西：走近可掏钱买他带的（药/干粮/旧兵刃），也能把背包里的货折价卖给他。
##
## 口径与 WandererPool 一致：**货品与价全部由 `(slot,gen)` 确定性派生**，不落盘——同一
## 位冒险者同一代永远带同一批货、报同价；买卖是当场结清（`avatar.money`/`inventory`），
## 不进变更队列（与主场景既有买卖 `_enter_trade` 同口径，D-148）。纯规则、可无头钉测。

static func _cfg() -> Dictionary:
	return ContentLoader.get_balance_section("wanderer")


static func _trade() -> Dictionary:
	var cfg: Dictionary = _cfg()
	return cfg.get("trade", {}) if cfg is Dictionary else {}


## 这位冒险者随手带的货（由 slot 盐派生，批次内不重复）。返回
##   [{ templateId, displayName, unitPrice, sellPrice }, ...]。
## rng 由调用方给（通常按 slot_seed 派生）——价格本身不随机，批次随机只决定挑了哪几件。
static func stall(spec: Dictionary, rng: DeterministicRNG) -> Array:
	var trade: Dictionary = _trade()
	var palette: Array = trade.get("palette", []) as Array
	var count: int = clampi(int(trade.get("stockCount", 4)), 1, palette.size())
	if palette.is_empty() or rng == null:
		return []
	var picked: Array = []
	var used: Dictionary = {}
	while picked.size() < count:
		var choice: Dictionary = _pick_weighted(palette, rng)
		if choice.is_empty():
			break
		var tid: String = str(choice.get("templateId", ""))
		if tid.is_empty() or used.has(tid):
			continue
		used[tid] = true
		var template: Dictionary = ContentLoader.get_item(tid)
		var display: String = str(template.get("displayName", tid))
		var unit: int = unit_price(tid)
		picked.append({
			"templateId": tid,
			"displayName": display,
			"unitPrice": unit,
			"sellPrice": sell_price(tid),
		})
	return picked


## 卖件（vendor）报价：货架价 = 模板 base price × magMult（冒险者倒手要加点水）。
static func unit_price(template_id: String) -> int:
	var base: int = maxi(0, int(ContentLoader.get_item(template_id).get("price", 0)))
	var mag: float = float(_trade().get("magMult", 1.15))
	return maxi(1, int(round(float(base) * mag)))


## 回收价：他再收你的货，按货架价 × sellDiscountBp 折算。
static func sell_price(template_id: String) -> int:
	var unit: int = unit_price(template_id)
	var bp: int = clampi(int(_trade().get("sellDiscountBp", 7000)), 0, 10000)
	return maxi(1, int(round(float(unit) * float(bp) / 10000.0)))


## 掏钱买他货架上的第 goods_index 件。当场扣钱、落实例进背包。
##   world 世界（avatar 的钱与物品账）。
##   spec  fill_spec 产出（定这条买卖的身份与实例种子）。
##   goods_index  stall 的索引。
## 返回 { ok, reason | displayName, unitPrice, instanceId, money, moneyAfter }。
static func buy(
	world: WorldState, spec: Dictionary, goods_index: int, goods: Array, rng: DeterministicRNG
) -> Dictionary:
	if world == null or world.avatar == null:
		return _fail("还没有化身，做不了这笔买卖。")
	if goods_index < 0 or goods_index >= goods.size():
		return _fail("他没有那件货。")
	var row: Dictionary = goods[goods_index]
	var tid: String = str(row.get("templateId", ""))
	var price: int = int(row.get("unitPrice", 0))
	if world.avatar.money < price:
		return _fail("钱不够：「%s」要 %d 铜，你只有 %d 铜。" % [
			str(row.get("displayName", tid)), price, world.avatar.money])
	var slot: int = int(spec.get("slot", 0))
	var gen: int = int(spec.get("gen", 0))
	# 实例按身份盐派生：同一批货同一代到手永远同一件，价目与货对得上（D-148）。
	var inst: String = CharacterCreation.add_item(
		world.avatar, tid, "%s-wb-%d-%d-%d" % [world.avatar.avatar_id, slot, gen, goods_index],
		"wanderer-buy-%d-%d-%d" % [slot, gen, goods_index]
	)
	world.avatar.money -= price
	return {
		"ok": true,
		"displayName": str(row.get("displayName", tid)),
		"unitPrice": price,
		"instanceId": inst,
		"money": price,
		"moneyAfter": world.avatar.money,
	}


## 把背包里的一件货折价卖给他。身上的（装备槽）拒收，须先脱下。
##   world 世界（avatar 的钱与物品账）。
##   instance_id  要卖的实例 id。
## 返回 { ok, reason | displayName, money, moneyAfter, instanceId }。
static func sell_item(world: WorldState, instance_id: String) -> Dictionary:
	if world == null or world.avatar == null:
		return _fail("还没有化身，做不了这笔买卖。")
	var avatar: PlayerAvatar = world.avatar
	if not avatar.item_instances.has(instance_id) or not avatar.inventory.has(instance_id):
		return _fail("背包里没有这件货。")
	if avatar.equipment.values().has(instance_id):
		return _fail("身上的东西不能卖：先把「%s」脱下。" % _name_of(avatar, instance_id))
	var tid: String = str(avatar.item_instances[instance_id].get("templateId", ""))
	var gained: int = sell_price(tid)
	avatar.money += gained
	avatar.inventory.erase(instance_id)
	avatar.item_instances.erase(instance_id)
	return {
		"ok": true,
		"displayName": _name_of(avatar, instance_id, tid),
		"money": gained,
		"moneyAfter": avatar.money,
		"instanceId": instance_id,
	}


static func _name_of(avatar: PlayerAvatar, instance_id: String, fallback: String = "") -> String:
	var tid: String = fallback
	if avatar.item_instances.has(instance_id):
		tid = str(avatar.item_instances[instance_id].get("templateId", fallback))
	return str(ContentLoader.get_item(tid).get("displayName", tid))


## 按权重抽一项（weightBp 之和不必为 10000；不命中返回 {} 由调用方重抽）。
static func _pick_weighted(pool: Array, rng: DeterministicRNG) -> Dictionary:
	var total: int = 0
	for p in pool:
		total += maxi(0, int((p as Dictionary).get("weightBp", 0)) if p is Dictionary else 0)
	if total <= 0 or rng == null:
		return {}
	var roll: int = rng.next_int(total)
	for p in pool:
		if not (p is Dictionary):
			continue
		var w: int = maxi(0, int((p as Dictionary).get("weightBp", 0)))
		roll -= w
		if roll < 0:
			return p
	return {}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}