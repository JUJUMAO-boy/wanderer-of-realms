class_name WandererTrouble
extends RefCounted

## 冒险者「个人麻烦」可化解规则层（M33 深化 M-E·C / D-149）。
##
## M31 只把每名冒险者那句话念成背景文本（`_reveal_wanderer` 弹 label 就完事），麻烦
## 永不可了结。本层把它变成一小笔可介入的支线：掏一笔钱替他问了结这一桩，他的麻烦
## 清了，对你记一份谢礼 + 雇佣打折——「世界记代价不记恨，人记你的好」的一条生命周期。
##
## 口径与 WandererPool 一致：**身份与麻烦细节纯派生**（`world_seed⊕slot⊕gen`），唯一
## 新增的落盘只是一个布尔标记「这份麻烦已化解」，绑 `(slot,gen)`（D-149）——换了代
## 新人来了，麻烦是新人自己的，上一代的化解作废。化解是基于代价的纯规则，无随机，
## 可无头钉测。

static func _cfg() -> Dictionary:
	return ContentLoader.get_balance_section("wanderer")


## 化解标记的存档键：`"{slot}-{gen}"`。代际换人即新键，天然作废旧化解。
static func key(slot: int, gen: int) -> String:
	return "%d-%d" % [int(slot), int(gen)]


## 这位冒险者（本代）的麻烦是否已化解。
static func resolved(world: WorldState, slot: int, gen: int) -> bool:
	if world == null:
		return false
	return bool(world.wanderer_troubles_resolved.get(key(slot, gen), false))


## 化解这一桩的价码（balance.wanderer.troubles[].resolveCost）。
static func resolve_cost(trouble: Dictionary) -> int:
	return maxi(0, int(trouble.get("resolveCost", 0)))


## 化解成功的谢礼铜（0 表示这件麻烦不给铜，只给一件物或只记人情）。
static func reward_copper(trouble: Dictionary) -> int:
	return maxi(0, int(trouble.get("rewardCopper", 0)))


## 化解成功附带的谢礼物 templateId（没有则空串）。
static func reward_item(trouble: Dictionary) -> String:
	return str(trouble.get("rewardItem", ""))


## 化解后招募价打折（已化解 ×resolveHireDiscountMult，否则原价）。
static func hire_discount(world: WorldState, slot: int, gen: int) -> float:
	if not resolved(world, slot, gen):
		return 1.0
	return float(_cfg().get("resolveHireDiscountMult", 0.65))


## 尝试化解：扣 `resolveCost` 铜 → 记 `(slot,gen)` 已化解 → 掉谢礼。
##   world   世界（死者有 avatar/钱的账本）。
##   spec    `WandererPool.fill_spec` 的产出（含 slot/gen/troubleId）。
##   trouble `WandererPool.trouble_of(spec.troubleId)` 的文案（含 resolveCost/resolveLine）。
## 返回 { ok, reason | line, rewardCopper, rewardItem, moneyAfter }。
## 幂等：已化解 → { ok:false, reason:"……" }；钱不够 → { ok:false, reason:"……" }。
static func resolve_step(
	world: WorldState, spec: Dictionary, trouble: Dictionary
) -> Dictionary:
	if world == null or world.avatar == null:
		return _fail("还没有化身，化不了这一桩。")
	var slot: int = int(spec.get("slot", 0))
	var gen: int = int(spec.get("gen", 0))
	var k: String = key(slot, gen)
	if bool(world.wanderer_troubles_resolved.get(k, false)):
		return _fail("他已经把这事放下了，再插手就多余了。")
	var cost: int = resolve_cost(trouble)
	if world.avatar.money < cost:
		return _fail("钱不够：这一桩要 %d 铜，你只有 %d 铜。" % [cost, world.avatar.money])
	# 当场了结：扣钱、记化解、掉谢礼（物品用确定性来源实例化，走既有物品账）。
	world.avatar.money -= cost
	world.wanderer_troubles_resolved[k] = true
	var name: String = str(spec.get("name", "这位冒险者"))
	var result: Dictionary = {
		"ok": true,
		"line": str(trouble.get("resolveLine", "%s 朝你郑重道了谢。" % name)),
		"cost": cost,
		"moneyAfter": world.avatar.money,
		"rewardCopper": 0,
		"rewardItem": "",
		"name": name,
	}
	var copper: int = reward_copper(trouble)
	var item_id: String = reward_item(trouble)
	if copper > 0:
		world.avatar.money += copper
		result["rewardCopper"] = copper
		result["moneyAfter"] = world.avatar.money
	if not item_id.is_empty():
		var inst: String = CharacterCreation.add_item(
			world.avatar, item_id, "%s-tt-%d-%d" % [world.avatar.avatar_id, slot, gen],
			"wanderer-trouble-%d-%d" % [slot, gen]
		)
		result["rewardItem"] = item_id
		result["rewardInstanceId"] = inst
	return result


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}