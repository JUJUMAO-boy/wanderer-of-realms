class_name NpcInteractionSystem
extends RefCounted

## NPC 人格与好感交互规则层（M18，接口 D-94 ~ D-99）。
##
## 把一个只有静态关系图、只会老死的"背景板 NPC"升级为玩家认得、能聊得上话、
## 可以送礼、还能雇上战场当随从的活人。三个守则：
##
## 1. **玩家侧活关系**。好感（`world.player_relations`）只写在这里，统一钳制
##    [-affMin, affMax]，档位由 `band()` 判定。它是随世界落盘的，不随灵魂——
##    换一世你还认得上一世交下的人。
## 2. **规则层不改城市**。talk/gift 只动好感与玩家背包，hire 动 `active_hires`
##    与玩家钱包。随从的每月契约消耗由 WorldSim 落账，这里不碰城市六维。
## 3. **可无头钉测**。每个方法就地改 world/avatar 并返回 `{ok, error, ...}`。
##
## CHA（魅力）借着这一次首次落地：同一份礼，魅力高的人送出去更讨人喜欢
## （giftChaScaling 缩放）；雇佣价随 CHA 打折（hirePriceChaDiv）。呼应《游戏
## 设计文档》给 CHA 定的「交易折扣、好感、说服」——交易折扣与说服不归本模块，
## 本轮只落「好感受影响」。

const BAND_HOSTILE: String = "hostile"  ## 敌对（< -bandHostile）
const BAND_COLD: String = "cold"        ## 冷淡（< -bandCold）
const BAND_NEUTRAL: String = "neutral"  ## 中立
const BAND_FRIENDLY: String = "friendly"## 友善（> bandFriendly）
const BAND_CLOSE: String = "close"      ## 亲密（> bandClose）

## 交谈意项：志向 / 传闻 / 信仰（`personality.json` 的 talkLines 按这三项给主句）。
const INTENT_AMBITION: String = "ambition"
const INTENT_RUMOR: String = "rumor"
const INTENT_FAITH: String = "faith"

const BAND_LABELS: Dictionary = {
	BAND_HOSTILE: "敌对", BAND_COLD: "冷淡", BAND_NEUTRAL: "中立",
	BAND_FRIENDLY: "友善", BAND_CLOSE: "亲密",
}


static func _cfg() -> Dictionary:
	return ContentLoader.get_balance_section("npcInteraction")


static func aff_min() -> int:
	return int(_cfg().get("affMin", -100))


static func aff_max() -> int:
	return int(_cfg().get("affMax", 100))


## 好感读写统一入口。不存在的 NPC 读作 0，写入一律钳制。
static func affinity(world: WorldState, npc_id: String) -> int:
	if world == null or npc_id.is_empty():
		return 0
	return int(world.player_relations.get(npc_id, 0))


static func set_affinity(world: WorldState, npc_id: String, value: int) -> void:
	if world == null or npc_id.is_empty():
		return
	world.player_relations[npc_id] = clampi(value, aff_min(), aff_max())


## 好感的档位键。用 balance 的四条分界判定，闭区间划分：值越大越亲近。
static func band(value: int) -> String:
	var cfg := _cfg()
	var hostile: int = int(cfg.get("bandHostile", -50))
	var cold: int = int(cfg.get("bandCold", -15))
	var friendly: int = int(cfg.get("bandFriendly", 15))
	var close: int = int(cfg.get("bandClose", 50))
	if value >= close:
		return BAND_CLOSE
	if value >= friendly:
		return BAND_FRIENDLY
	if value >= cold:
		return BAND_NEUTRAL
	if value >= hostile:
		return BAND_COLD
	return BAND_HOSTILE


static func band_label(band_value: String) -> String:
	return str(BAND_LABELS.get(band_value, band_value))


## 一张详情卡片，一次成型。界面照此摆右栏；无好感/有人格都给出稳定形状。
static func resident_card(avatar: PlayerAvatar, world: WorldState, npc: SimNpc) -> Dictionary:
	if npc == null:
		return {}
	var personality: Dictionary = ContentLoader.get_personality(npc.personality_id)
	var faith: Dictionary = ContentLoader.get_faith(npc.faith_id)
	var profession: Dictionary = ContentLoader.get_profession(npc.profession_id)
	var race: Dictionary = ContentLoader.get_race(npc.race_id)
	var aff: int = affinity(world, npc.npc_id)
	var band_key: String = band(aff)
	var hireable: bool = _is_hireable(npc)
	return {
		"npcId": npc.npc_id,
		"name": _full_name(npc),
		"givenName": npc.given_name,
		"raceName": str(race.get("displayName", npc.race_id)),
		"age": npc.age,
		"professionId": npc.profession_id,
		"professionName": str(profession.get("displayName", npc.profession_id)),
		"category": str(profession.get("category", "")),
		"isNamed": npc.is_named,
		"position": npc.position_id,
		"personalityId": npc.personality_id,
		"personalityName": str(personality.get("displayName", "")),
		"personalityLine": str(personality.get("short", "")),
		"faithId": npc.faith_id,
		"faithName": str(faith.get("displayName", "")),
		"affinity": aff,
		"band": band_key,
		"bandLabel": band_label(band_key),
		"hireable": hireable,
		"hireCost": hire_cost(avatar, world) if hireable else 0,
	}


## 某城可交互 NPC 的详情卡片列表，按 npcId 排序。供左列名单用。
static func list_residents(world: WorldState, avatar: PlayerAvatar, city_id: String) -> Array:
	var out: Array = []
	if world == null:
		return out
	for npc in world.get_city_npcs(city_id):
		out.append(resident_card(avatar, world, npc))
	return out


## 交谈：按人格主句 + 好感档位润色的台词，附小幅好感变化。intent 缺省志向。
## month 用于冷却判定：距上次 < talkCooldownMonths 则拒绝。month < 0 跳过冷却（供测试）。
static func talk(avatar: PlayerAvatar, world: WorldState, npc: SimNpc, intent: String, month: int) -> Dictionary:
	if npc == null:
		return {"ok": false, "error": "NOT_FOUND", "reason": "查无此人"}
	intent = intent if not intent.is_empty() else INTENT_AMBITION
	var personality: Dictionary = ContentLoader.get_personality(npc.personality_id)
	if personality.is_empty():
		return {"ok": false, "error": "NO_PERSONALITY", "reason": "这位居民没有可交谈的人格"}
	if not personality.get("talkLines", {}).has(intent):
		return {"ok": false, "error": "NO_INTENT", "reason": "没有这条谈资"}

	var aff: int = affinity(world, npc.npc_id)
	var band_key: String = band(aff)

	if month >= 0:
		var cds: Dictionary = world.npc_talk_cooldowns.get(npc.npc_id, {})
		var last: int = int(cds.get(intent, -1))
		var cooldown: int = maxi(1, int(_cfg().get("talkCooldownMonths", 1)))
		if last >= 0 and last + cooldown > month:
			return {"ok": false, "error": "COOLDOWN", "reason": "刚说过，稍后再谈", "line": "", "band": band_key}

	# 台词：主句 + 档位后缀（敌对/亲密的口吻由 toneByAffinity 给）
	var line: String = str(personality["talkLines"][intent])
	var tone: Dictionary = personality.get("toneByAffinity", {})
	if band_key == BAND_HOSTILE and tone.has("hostile"):
		line = "%s%s" % [line, tone["hostile"]]
	elif (band_key == BAND_FRIENDLY or band_key == BAND_CLOSE) and tone.has("friendly"):
		line = "%s%s" % [line, tone["friendly"]]

	if month >= 0:
		var cds_map: Dictionary = world.npc_talk_cooldowns.get(npc.npc_id, {})
		cds_map[intent] = month
		world.npc_talk_cooldowns[npc.npc_id] = cds_map

	var delta: int = int(_cfg().get("talkDelta", {}).get(band_key, 0))
	set_affinity(world, npc.npc_id, aff + delta)
	return {
		"ok": true, "line": line, "band": band_key, "bandLabel": band_label(band_key),
		"affDelta": delta, "affinity": affinity(world, npc.npc_id),
	}


## 送礼：按人格 giftTaste 判定偏好，消耗物品，CHA 缩放好感变化。
## item_instance_id 是 avatar.inventory 里的实例 id。month 同 talk（用于碰都不碰冷却）。
static func gift(avatar: PlayerAvatar, world: WorldState, npc: SimNpc, item_instance_id: String, _month: int) -> Dictionary:
	if npc == null:
		return {"ok": false, "error": "NOT_FOUND", "reason": "查无此人"}
	if not avatar.inventory.has(item_instance_id):
		return {"ok": false, "error": "NO_ITEM", "reason": "你没有这件物品"}
	var inst: Dictionary = avatar.item_instances.get(item_instance_id, {})
	if inst.is_empty():
		return {"ok": false, "error": "NO_ITEM", "reason": "这件物品不存在"}
	var item: Dictionary = ContentLoader.get_item(str(inst.get("templateId", "")))
	var category: String = str(item.get("category", ""))
	var personality: Dictionary = ContentLoader.get_personality(npc.personality_id)
	var taste: Dictionary = personality.get("giftTaste", {})
	var delta: int
	var verb: String
	if (taste.get("love", []) as Array).has(category):
		delta = int(_cfg().get("giftDelta", {}).get("love", 12))
		verb = "喜欢"
	elif (taste.get("hate", []) as Array).has(category):
		delta = int(_cfg().get("giftDelta", {}).get("hate", -5))
		verb = "嫌弃"
	else:
		delta = int(_cfg().get("giftDelta", {}).get("neutral", 3))
		verb = "收下"

	# CHA 首次落地：魅力越高，同一份礼越讨喜（正向放大、负向加深）
	var cha: int = avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA)
	var scaling: int = maxi(1, int(_cfg().get("giftChaScaling", 2)))
	if delta > 0:
		delta += int(floor(float(cha) / float(scaling)))
	elif delta < 0:
		delta -= int(floor(float(cha) / float(scaling)))

	# 消耗物品（从背包与实例表同时移除）
	avatar.inventory.erase(item_instance_id)
	avatar.item_instances.erase(item_instance_id)

	var aff: int = affinity(world, npc.npc_id)
	set_affinity(world, npc.npc_id, aff + delta)
	var new_band: String = band(aff + delta)
	return {
		"ok": true, "line": "%s%s了你的%s。" % [npc.given_name, verb, str(item.get("displayName", category))],
		"band": new_band, "bandLabel": band_label(new_band), "affDelta": delta,
		"affinity": affinity(world, npc.npc_id), "consumed": item_instance_id,
	}


## 是否可被雇佣：职业类别属可雇佣集 + 好感 ≥ 门槛 + 非具名锚点。
static func _is_hireable(npc: SimNpc) -> bool:
	if npc == null or npc.is_named or not npc.position_id.is_empty():
		return false
	var profession: Dictionary = ContentLoader.get_profession(npc.profession_id)
	var cat: String = str(profession.get("category", ""))
	return (_cfg().get("hireableCategories", []) as Array).has(cat)


static func hire_min_affinity() -> int:
	return int(_cfg().get("hireMinAffinity", 15))


## 雇佣价格：PL × factor / (CHAScaler + CHA)。魅力越高越便宜，回应「CHA 影响好感/交易」。
static func hire_cost(avatar: PlayerAvatar, world: WorldState) -> int:
	var cfg := _cfg()
	var factor: int = int(cfg.get("hirePricePLFactor", 20))
	var cha_div: int = maxi(1, int(cfg.get("hirePriceChaDiv", 30)))
	var power: int = DerivedStats.new().power_level(avatar.attributes, avatar.skills)
	var base: int = int(floor(float(power) * float(factor) / float(cha_div)))
	var cha: int = avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA)
	return maxi(1, int(floor(float(base) * float(cha_div) / float(cha_div + cha))))


## 当前在效的随从契约，没有则返回空字典。
static func current_hire(world: WorldState) -> Dictionary:
	if world == null or world.active_hires.is_empty():
		return {}
	var key: Array = world.active_hires.keys()
	key.sort()
	return world.active_hires[str(key[0])]


## 雇佣某 NPC 为随从（限时契约）。换雇须先解约；签下后写 active_hires 并记纪年。
static func hire(avatar: PlayerAvatar, world: WorldState, npc: SimNpc, month: int) -> Dictionary:
	if npc == null:
		return {"ok": false, "error": "NOT_FOUND", "reason": "查无此人"}
	if not _is_hireable(npc):
		return {"ok": false, "error": "NOT_HIREABLE", "reason": "这位居民不愿受雇"}
	if affinity(world, npc.npc_id) < hire_min_affinity():
		return {"ok": false, "error": "NOT_FRIENDLY", "reason": "好感还不够，先多聊聊、送点礼"}
	if world.active_hires.has(npc.npc_id):
		return {"ok": false, "error": "ALREADY_HIRED", "reason": "他已是你的随从"}
	if not current_hire(world).is_empty():
		return {"ok": false, "error": "FULL", "reason": "你已带着一名随从，得先解约"}

	var cost: int = hire_cost(avatar, world)
	if avatar.money < cost:
		return {"ok": false, "error": "POOR", "reason": "钱不够签这份契约"}

	var profession: Dictionary = ContentLoader.get_profession(npc.profession_id)
	avatar.money -= cost
	world.hire_seq += 1
	world.active_hires[npc.npc_id] = {
		"npcId": npc.npc_id,
		"name": _full_name(npc),
		"professionId": npc.profession_id,
		"category": str(profession.get("category", "")),
		"monthsLeft": int(_cfg().get("hireMonths", 6)),
		"contractSeq": world.hire_seq,
	}
	if world.avatar == null:
		world.avatar = avatar
	var chronicle: Chronicle = Chronicle.create()
	chronicle.record(world, chronicle.hire_entry(world, npc, cost, int(_cfg().get("hireMonths", 6)), month))
	return {
		"ok": true, "cost": cost, "months": int(_cfg().get("hireMonths", 6)),
		"contractSeq": world.hire_seq, "hire": world.active_hires[npc.npc_id],
	}


## 解约：把某随从从 active_hires 移除并记纪年。reason 可从战斗战殁或到期提供。
static func dismiss(world: WorldState, npc_id: String, reason: String, month: int) -> Dictionary:
	if world == null or not world.active_hires.has(npc_id):
		return {"ok": false, "error": "NOT_FOUND", "reason": "没有这份契约"}
	var hire: Dictionary = world.active_hires[npc_id]
	var npc: SimNpc = world.get_npc(npc_id)
	world.active_hires.erase(npc_id)
	var chron: Chronicle = Chronicle.create()
	if npc != null:
		var detail: String = reason if not reason.is_empty() else "契约终止。"
		chron.record(world, chron.fallen_entry(world, npc, detail, month))
	return {"ok": true, "dismissed": hire}


## 为一场遭遇产出随从的战斗单元规格（side=player, controlled=auto）。
## 每场现算、不落盘；属性随好感小幅成长，作为"带在身边久了更默契"的补偿。
static func follower_combat_spec(avatar: PlayerAvatar, world: WorldState, hire: Dictionary) -> Dictionary:
	if hire.is_empty():
		return {}
	var cfg := _cfg()
	var category: String = str(hire.get("category", ""))
	var attrs: Dictionary = (cfg.get("followerAttrBase", {}) as Dictionary).duplicate()
	# 与玩家的好感越高，随从战斗里略强一点
	var aff: int = affinity(world, str(hire.get("npcId", "")))
	var scale: float = 1.0 + float(maxi(0, aff)) / 200.0
	for key: String in attrs:
		attrs[key] = maxi(1, int(round(float(int(attrs[key])) * scale)))
	var weapon: Dictionary = cfg.get("followerWeaponByCategory", {}).get(category, {"attack": 6, "range": 1})
	var skill_id: String = str(cfg.get("followerSkill", "guard"))
	return {
		"unitId": "follower_%s" % str(hire.get("npcId", "")),
		"name": str(hire.get("name", "随从")),
		"side": Combat.SIDE_PLAYER,
		"controlled": "auto",
		"isHero": false,
		# M22 随从 AI 行动倾向：按职业类别给一个性格，auto_action 据此分流
		# （战士抢先卡位、刺客守玩家身旁只补刀、射手保持距离放箭）。
		"aiTendency": str(cfg.get("followerTendencyByCategory", {}).get(category,
			str(cfg.get("followerTendencyDefault", "guard")))),
		"attributes": attrs,
		"skills": {skill_id: 40},
		"weaponAttack": int(weapon.get("attack", 6)),
		"weaponRange": int(weapon.get("range", 1)),
		"armor": int(cfg.get("followerArmor", 3)),
		"luck": 5,
		"position": [1, 0],
		"threatLevel": 1,
	}


static func _full_name(npc: SimNpc) -> String:
	var out: String = npc.given_name
	if not npc.family_name.is_empty():
		out = "%s %s" % [npc.family_name, npc.given_name]
	return out