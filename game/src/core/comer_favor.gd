class_name ComerFavor
extends RefCounted

## 乱入者好感（第三阶段 B3，D-187~D-188）。纯规则、全静态：好感与"会回应"的核心。
##
## 乱入者是从异界跌进艾尔泽拉的旅人（《时空乱入角色图鉴》），每位只在一座相遇城站着。
## 本类不负责相遇入口（那是主场景接线的事），只负责三件事：
##   1. 好感读写 —— 复用 M18 的同一张表（world.player_relations），键名 'comer_<id>'，
##      好感受 world 落盘、随世界不随灵魂；档位沿用 M18 的 band 分界。
##   2. 会回应 —— 按好感档位给 greeting 台词；对一桩事件作答复（reply）。
##   3. 招募判定接口 —— 好感是否够招募阈值，只给判定，不入队/不战斗（留给后续）。
##
## 一桩事件的"前置属性"（needCha/needStrOrCha/needSoulOrAlchemy/needFireOrForge/needKarma）
## 在事件定义上作为可选字段，不满足就不给这档好感（else 直接走离去/默认回应）。所有数值
## 全在 comers.json，本类不写死任何系数。

const PREFIX: String = "comer_"

## M18 的好感四档名（与 npc_interaction_system.band 一致）。
const BAND_COLD: String = "cold"
const BAND_NEUTRAL: String = "neutral"
const BAND_FRIENDLY: String = "friendly"
const BAND_CLOSE: String = "close"


## 该乱入者的好感键。查不到配置也给稳定键（防 id 拼错时静默读写错表）。
static func key(comer_id: String) -> String:
	return PREFIX + comer_id


## 读好感：按 M18 的 affinity 语义（不存在的键读 0）。id 为空给 0。
static func affinity(world: WorldState, comer_id: String) -> int:
	if world == null or comer_id.is_empty():
		return 0
	return int(world.player_relations.get(key(comer_id), 0))


## 写好感：走 M18 钳制（在 balance 的 afMin..afMax 之间）。
static func set_affinity(world: WorldState, comer_id: String, value: int) -> void:
	if world == null or comer_id.is_empty():
		return
	NpcInteractionSystem.set_affinity(world, key(comer_id), value)


## 好感档位键（复用 M18: hostile/cold/neutral/friendly/close）。
static func band(world: WorldState, comer_id: String) -> String:
	return NpcInteractionSystem.band(affinity(world, comer_id))


## 档位中文名。
static func band_label(band_value: String) -> String:
	return NpcInteractionSystem.band_label(band_value)


## 按当前好感档位取一句开场招呼。查不到该档台词时回退 neutral；没有 neutral 给空串。
static func greeting(world: WorldState, comer_id: String) -> String:
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	if cfg.is_empty():
		return ""
	var g: Dictionary = cfg.get("greetings", {})
	var cur: String = band(world, comer_id)
	return str(g.get(cur, g.get(BAND_NEUTRAL, "")))


## 招募判定接口：好感是否已到该乱入者的招募阈值。只作判定，不入队/不战斗。
## 好感表里没有该乱入者（回 0）时基本到不了阈值，正常返回 false。
static func recruit_ready(world: WorldState, comer_id: String) -> bool:
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	if cfg.is_empty():
		return false
	return affinity(world, comer_id) >= int(cfg.get("recruitThreshold", 0))


## 该乱入者是否可招（布尔展示用，与 recruit_ready 同判）。
static func is_recruitable(world: WorldState, comer_id: String) -> bool:
	return recruit_ready(world, comer_id)


## 这一档需要多少好感才够（无该乱入者回 0）。
static func recruit_threshold(comer_id: String) -> int:
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	if cfg.is_empty():
		return 0
	return int(cfg.get("recruitThreshold", 0))


## 参与一桩好感事件：判定前置、按 delta 落账、给回应。是规则层的单一入口。
##
## avatar 用于读前置属性；world 用于读/写好感。event 可以是 comers.json 里的对象，
## 也可用 event_id 代（从表里取出）。返回：
##   { ok, eventId, label, reply, delta, applied, affinity, before, after, band, ready }
## 前置不满足时 ok=false、applied=false，仍带原文 reply 供界面展示"他没接这个话"。
static func apply_event(
	world: WorldState, avatar: PlayerAvatar, comer_id: String, event: Variant
) -> Dictionary:
	if world == null or comer_id.is_empty():
		return {"ok": false, "eventId": "", "applied": false}
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	var ev: Dictionary = event if event is Dictionary else {}
	if ev.is_empty():
		for e in cfg.get("events", []):
			if str(e.get("eventId", "")) == str(event):
				ev = e
				break
	if ev.is_empty():
		return {"ok": false, "eventId": str(event), "applied": false}
	var event_id: String = str(ev.get("eventId", ""))
	var delta: int = int(ev.get("delta", 0))
	var before: int = affinity(world, comer_id)
	if not _prereq_ok(avatar, ev):
		return {
			"ok": false, "eventId": event_id, "label": str(ev.get("label", "")),
			"reply": str(ev.get("reply", "")), "delta": delta, "applied": false,
			"affinity": before, "before": before, "after": before,
			"band": NpcInteractionSystem.band(before), "ready": false,
		}
	set_affinity(world, comer_id, before + delta)
	var after: int = affinity(world, comer_id)
	return {
		"ok": true, "eventId": event_id, "label": str(ev.get("label", "")),
		"reply": str(ev.get("reply", "")), "delta": delta, "applied": true,
		"affinity": after, "before": before, "after": after,
		"band": NpcInteractionSystem.band(after), "ready": recruit_ready(world, comer_id),
	}


# --- 前置属性判定 ---

## 一桩事件的可选前置字段：满足才给好感。约定：
##   needCha            魅力属性 ≥ 值
##   needStrOrCha       力量或魅力（取大者）≥ 值
##   needSoulOrAlchemy  灵魂属性或炼金技能（取大者）≥ 值
##   needFireOrForge    火系技能（取火树最高熟练）或锻造技能（取大者）≥ 值
##   needKarma          善恶 karma ≥ 值
## 没有前置字段的事件恒满足；遇不认识的字段按不满足（保守，宁可不给不硬塞）。
static func _prereq_ok(avatar: PlayerAvatar, ev: Dictionary) -> bool:
	if avatar == null:
		return false
	if not (ev is Dictionary) or (ev as Dictionary).is_empty():
		return true
	var m: int = -1
	if ev.has("needCha"):
		m = maxi(m, int(ev["needCha"]))
		if avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA) < m:
			return false
		m = -1
	if ev.has("needStrOrCha"):
		m = maxi(int(ev["needStrOrCha"]), 0)
		var strongest: int = maxi(
			avatar.get_attribute(PlayerAvatar.ATTR_STRENGTH),
			avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA))
		if strongest < m:
			return false
	if ev.has("needSoulOrAlchemy"):
		m = maxi(int(ev["needSoulOrAlchemy"]), 0)
		var soul: int = avatar.get_attribute(PlayerAvatar.ATTR_SOUL)
		var alchemy: int = int(avatar.skills.get("alchemy", 0))
		if maxi(soul, alchemy) < m:
			return false
	if ev.has("needFireOrForge"):
		m = maxi(int(ev["needFireOrForge"]), 0)
		var fire: int = _best_tree_skill(avatar, "fire")
		var forge: int = int(avatar.skills.get("forge", 0))
		if maxi(fire, forge) < m:
			return false
	if ev.has("needKarma"):
		m = maxi(int(ev["needKarma"]), 0)
		if avatar.karma < m:
			return false
	return true


## 技能树里最高的一项熟练度。avatar.skills 是 skillId → 熟练度；skillId 形如 fire_fireball，
## 树名在首段（skills.json 的 tree 字段，和 id 前缀一致）。无该树技能给 0。
static func _best_tree_skill(avatar: PlayerAvatar, tree: String) -> int:
	var best: int = 0
	for sid in avatar.skills:
		if str(sid).begins_with(tree + "_"):
			best = maxi(best, int(avatar.skills[sid]))
	return best