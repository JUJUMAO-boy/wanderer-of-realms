class_name WandererPool
extends RefCounted

## 大地图随机人物（M-E）：39 名可见冒险者（战士/弓手/术师）的人口池。
##
## 与 M-C 的 `WorldSeen`（大地图可见的"物"：遗构/怪物）互为对照，本层落大地图可见的"人"。
## 冒险者**不是**世界模拟那 1600 名居民（`WorldState.npcs`，城市人口指数的具象化、随 `settle_year`
## 增龄死亡、受职业配额管理）。它们是另一群游离在城际、占固定名额、会被玩家招募/放倒的人。
##
## 铁则（守住"能派生就不落盘"，但比纯派生多一层持久名册）：
##   1. 名字/外表/麻烦/卖相等**细节**由世界种子确定性派生（`fill_spec`），同一世界同名额同月份
##      逐位一致。
##   2. 谁占了哪个名额、此刻是 roaming / hospital、谁被雇佣到哪天——这些**生命周期状态**落盘
##      `world.wanderer_roster`（随世界存档），否则"空缺即补、送医回流、走了接替"在结算/读档后
##      无从谈起（D-142）。

const STATUS_ROAMING: String = "roaming"
const STATUS_HOSPITAL: String = "hospital"

const DEFAULT_CAPACITY: int = 39


static func _cfg() -> Dictionary:
	return ContentLoader.get_balance_section("wanderer")


## 名额总数（39）。
static func capacity() -> int:
	return maxi(1, int(_cfg().get("capacity", DEFAULT_CAPACITY)))


## 某个名额第 gen 代客人的确定性派生种子：世界种子 ⊕ 名额 ⊕ 代际（沿袭 DWORLD 系折盐），
## 只取低 32 位。gen 是"这个名额的第几任主人"：在营期间 gen 不变→还是同一个人；
## 永久离开后被新人接替，gen+1→换了一副名头，同一 slot 却不再是同一个人（D-142）。
static func slot_seed(world_seed: int, slot: int, gen: int) -> int:
	return (world_seed ^ (slot * 2654435761) ^ (gen * 40503)) & 0xFFFFFFFF


## 把某个固定名额的第 gen 任主人填满：由 (world_seed, slot, gen) 确定性派生一名冒险者的全部细节。
## 名字从 `givenNames`/`familyNames`池抽、麻烦从 `troubles` 抽、身材按 slot 分到三型——
## 名额编号本身定职业（warrior/archer/mage 循环），保证 39 名里三型都有、类型也确定。
static func fill_spec(world_seed: int, slot: int, gen: int) -> Dictionary:
	var rng := DeterministicRNG.new(slot_seed(world_seed, slot, gen))
	var cfg := _cfg()
	var archetypes: Array = cfg.get("archetypes", ["warrior", "archer", "mage"])
	var given: Array = cfg.get("givenNames", [])
	var family: Array = cfg.get("familyNames", [])
	var troubles: Array = trouble_defs()
	var archetype: String = str(archetypes[slot % archetypes.size()])
	var given_name: String = str(given[rng.next_int(given.size())]) if not given.is_empty() else "无名"
	var fam: String = str(family[rng.next_int(family.size())]) if not family.is_empty() else ""
	var gender: String = "male" if rng.chance(0.5) else "female"
	var age: int = rng.range_int(18, 62)
	var trouble_id: String = ""
	if not troubles.is_empty():
		trouble_id = str(troubles[rng.next_int(troubles.size())].get("id", ""))
	var cost: int = int(cfg.get("hireCost", 150))
	if archetype == "mage":
		cost = int(round(float(cost) * float(cfg.get("hireCostMageMult", 1.3))))
	elif archetype == "archer":
		cost = int(round(float(cost) * float(cfg.get("hireCostArcherMult", 1.1))))
	return {
		"slot": int(slot),
		"gen": int(gen),
		"archetype": archetype,
		"givenName": given_name,
		"familyName": fam,
		"name": _full_name(given_name, fam),
		"gender": gender,
		"age": age,
		"troubleId": trouble_id,
		"hireCost": maxi(1, cost),
	}


## 个人麻烦池（balance.wanderer.troubles）。每条 = 一句可观察的现象，读档后仍由 troubleId 对上。
static func trouble_defs() -> Array:
	return _cfg().get("troubles", []) as Array


## 取某条个人麻烦的文案。找不到返回空字典。
static func trouble_of(trouble_id: String) -> Dictionary:
	for t: Dictionary in trouble_defs():
		if str(t.get("id", "")) == str(trouble_id):
			return t
	return {}


## 雇一名冒险者的契约（战斗侧随从规格）。unitId 带名额号，与模拟居民（unitId=npc_id）隔离（D-143）。
static func hire_contract(slot: int, month: int) -> Dictionary:
	var spec: Dictionary = {}
	return {
		"slot": int(slot),
		"unitId": "wanderer-%03d" % int(slot),
		"daysLeft": int(_cfg().get("hireDays", 7)),
		"hireMonth": int(month),
	}


## 给被雇佣的冒险者出一份战斗随从规格（仿 `NpcInteractionSystem.follower_combat_spec`，但按
## 冒险者三型给武器，而不是模拟居民的职业类别）。spec 是 fill_spec 的产出。
static func combat_spec(spec: Dictionary) -> Dictionary:
	var cfg := _cfg()
	var archetype: String = str(spec.get("archetype", "warrior"))
	var weapon: Dictionary = (cfg.get("weaponByArchetype", {}) as Dictionary).get(
		archetype, {"attack": 6, "range": 1})
	var skill_id: String = str(cfg.get("skillByArchetype", {}).get(archetype, "guard"))
	var tendency: String = str(cfg.get("tendencyByArchetype", {}).get(
		archetype, str(cfg.get("tendencyDefault", "guard"))))
	return {
		"unitId": "wanderer-%03d" % int(spec.get("slot", 0)),
		"name": str(spec.get("name", "无名冒险者")),
		"side": Combat.SIDE_PLAYER,
		"controlled": "auto",
		"isHero": false,
		"aiTendency": tendency,
		"attributes": {"str": 12, "dex": 12, "con": 12, "int": 8, "wil": 8},
		"skills": {skill_id: 40},
		"weaponAttack": int(weapon.get("attack", 6)),
		"weaponRange": int(weapon.get("range", 1)),
		"armor": int(cfg.get("armor", 3)),
		"luck": 5,
		"position": [1, 0],
		"threatLevel": 1,
	}


## 名册前进一趟（月度结算调用）：处理住院到期的回流/永久离开、腾出的名额立刻补新。
## gen 是各名额的"代际"：只在永久离开换人时 +1，在营期间身份稳定。rng 由调用方给
## （决定永久离开掷点）。返回 `[roster, events]`，events 供世界纪年。
## roster 是 `world.wanderer_roster`（Array[Dictionary]），每条：{ slot, gen, archetype, name, ...,
## status, hospitalUntil }。
static func advance(roster: Array, world_seed: int, month: int, rng: DeterministicRNG) -> Array:
	var events: Array = []
	var leave_pct: float = float(_cfg().get("leavePct", 0.25))
	var out: Array = []
	for entry: Dictionary in roster:
		var slot: int = int(entry.get("slot", 0))
		var gen: int = int(entry.get("gen", 0))
		var spec: Dictionary = fill_spec(world_seed, slot, gen)
		var cur := entry.duplicate()
		# 名字/职业/麻烦按本代派生补齐（存档里合法但可能与派生不符时以派生为准）
		cur["gen"] = gen
		cur["name"] = spec.get("name")
		cur["archetype"] = spec.get("archetype")
		cur["troubleId"] = spec.get("troubleId")
		cur["hireCost"] = spec.get("hireCost")
		cur["gender"] = spec.get("gender")
		var status: String = str(cur.get("status", STATUS_ROAMING))
		if status == STATUS_HOSPITAL and int(cur.get("hospitalUntil", 0)) <= month:
			# 送医到期：掷一次是"养好了回来"还是"就此走了、由新人接替"
			if rng.chance(leave_pct):
				events.append("%s 没熬过重伤，永弃了这条路" % str(cur.get("name", "某冒险者")))
				# 空缺即补：同一名额换一代新人顶替（gen+1 → 新身份）
				cur = _fresh_entry(spec, slot, gen + 1)
				events.append("%s 接替了他的位置" % str(cur.get("name", "一名新人")))
			else:
				cur["status"] = STATUS_ROAMING
				cur.erase("hospitalUntil")
				events.append("%s 伤愈回队，又上了路" % str(cur.get("name", "某冒险者")))
		out.append(cur)
	# 空缺即补：名册永远满员（capacity 条）
	while out.size() < capacity():
		var slot: int = out.size()
		out.append(_fresh_entry(fill_spec(world_seed, slot, 0), slot, 0))
	return [out, events]


## 用一份填充 spec 建一条新的名册条目（健康、在野、可被雇佣）。
static func _fresh_entry(spec: Dictionary, slot: int, gen: int) -> Dictionary:
	return {
		"slot": int(slot),
		"gen": int(gen),
		"archetype": str(spec.get("archetype", "warrior")),
		"name": str(spec.get("name", "无名冒险者")),
		"gender": str(spec.get("gender", "male")),
		"age": int(spec.get("age", 20)),
		"troubleId": str(spec.get("troubleId", "")),
		"hireCost": int(spec.get("hireCost", 150)),
		"status": STATUS_ROAMING,
	}


static func _full_name(given: String, family: String) -> String:
	if family.is_empty():
		return given
	return "%s · %s" % [family, given]