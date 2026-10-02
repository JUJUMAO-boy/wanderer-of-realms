class_name AnchorLine
extends RefCounted

## 锚点 NPC 规则层（第四阶段 D2 / D-200~D-202）。
##
## 锚点是转生世界里不随世代消亡的固定坐标（《游戏设计文档》4.3）。本类只做四件事，
## 全是纯规则、可无头钉测：
##
##   1. **跨世好感**：锚点好感落 `SoulRecord.anchor_relations`（随灵魂存档，跨世保留），
##      键是 anchorId，另带一串记忆标记（memoryFlags）——锚点记得玩家的**灵魂**，
##      而不是这一世。这与 B3 乱入者好感（落 world.player_relations，随世界）不同。
##   2. **招呼**：按好感档取一句开场白（档位沿用 M18 的 band 分界）。
##   3. **好感事件**：像 B3 那样做件事涨/跌锚点好感（可带前置属性）。
##   4. **揭示**：把主线真相说给玩家——条件（幕次 / 碎片数 / 已揭线索 / 锚点好感 /
##      前置属性）够了才解锁；落账直接调 D1 的 `ShardLine.reveal_clue`，幕次推进、
##      跨世继承全由 ShardLine 单一来源负责，本类不重复实现。
##
## 进度结构（SoulRecord.anchor_relations 的一项）：
##   { "anchorId": "crow", "affinity": 30, "memoryFlags": ["crow_hint_echo"] }

const KEY_ID: String = "anchorId"
const KEY_AFFINITY: String = "affinity"
const KEY_FLAGS: String = "memoryFlags"

## 锚点好感的钳制区间（与 M18 同一口径的保守上下界）。
const AFFINITY_MIN: int = -100
const AFFINITY_MAX: int = 100

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"


# --- 跨世好感与记忆 ---

## 取（或就地建）某位锚点在灵魂上的一条关系记录。
static func record_of(soul: SoulRecord, anchor_id: String) -> Dictionary:
	if soul == null or anchor_id.is_empty():
		return {}
	if not (soul.anchor_relations is Array):
		soul.anchor_relations = []
	for item in soul.anchor_relations:
		if item is Dictionary and str((item as Dictionary).get(KEY_ID, "")) == anchor_id:
			var rec: Dictionary = item
			if not (rec.get(KEY_FLAGS, null) is Array):
				rec[KEY_FLAGS] = []
			return rec
	var created: Dictionary = {KEY_ID: anchor_id, KEY_AFFINITY: 0, KEY_FLAGS: []}
	soul.anchor_relations.append(created)
	return created


static func affinity(soul: SoulRecord, anchor_id: String) -> int:
	if soul == null or anchor_id.is_empty():
		return 0
	for item in soul.anchor_relations:
		if item is Dictionary and str((item as Dictionary).get(KEY_ID, "")) == anchor_id:
			return int((item as Dictionary).get(KEY_AFFINITY, 0))
	return 0


static func set_affinity(soul: SoulRecord, anchor_id: String, value: int) -> void:
	var rec: Dictionary = record_of(soul, anchor_id)
	if rec.is_empty():
		return
	rec[KEY_AFFINITY] = clampi(value, AFFINITY_MIN, AFFINITY_MAX)


static func band(soul: SoulRecord, anchor_id: String) -> String:
	return NpcInteractionSystem.band(affinity(soul, anchor_id))


static func band_label(band_value: String) -> String:
	return NpcInteractionSystem.band_label(band_value)


static func has_memory(soul: SoulRecord, anchor_id: String, flag: String) -> bool:
	if soul == null or anchor_id.is_empty() or flag.is_empty():
		return false
	for item in soul.anchor_relations:
		if item is Dictionary and str((item as Dictionary).get(KEY_ID, "")) == anchor_id:
			return ((item as Dictionary).get(KEY_FLAGS, []) as Array).has(flag)
	return false


static func add_memory(soul: SoulRecord, anchor_id: String, flag: String) -> void:
	if flag.is_empty():
		return
	var rec: Dictionary = record_of(soul, anchor_id)
	if rec.is_empty():
		return
	var flags: Array = rec.get(KEY_FLAGS, [])
	if not flags.has(flag):
		flags.append(flag)
	rec[KEY_FLAGS] = flags


## 按当前锚点好感档取一句开场招呼。查不到该档台词时回退 neutral；没有 neutral 给空串。
static func greeting(soul: SoulRecord, cfg: Dictionary) -> String:
	if cfg.is_empty():
		return ""
	var g: Dictionary = cfg.get("greetings", {})
	var cur: String = band(soul, str(cfg.get("anchorId", "")))
	return str(g.get(cur, g.get("neutral", "")))


# --- 好感事件 ---

## 做一桩事，按 delta 落锚点好感（前置不满足就不给，但把原文 reply 带来展示）。
## 返回 {ok, eventId, label, reply, delta, applied, before, after, affinity, band}。
static func apply_event(
	soul: SoulRecord, avatar: PlayerAvatar, cfg: Dictionary, event: Variant
) -> Dictionary:
	if soul == null or cfg.is_empty():
		return {"ok": false, "eventId": "", "applied": false}
	var ev: Dictionary = event if event is Dictionary else {}
	if ev.is_empty():
		for e in cfg.get("events", []):
			if str(e.get("eventId", "")) == str(event):
				ev = e
				break
	if ev.is_empty():
		return {"ok": false, "eventId": str(event), "applied": false}
	var anchor_id: String = str(cfg.get("anchorId", ""))
	var before: int = affinity(soul, anchor_id)
	if not _prereq_ok(avatar, ev):
		return {
			"ok": false, "eventId": str(ev.get("eventId", "")), "label": str(ev.get("label", "")),
			"reply": str(ev.get("reply", "")), "delta": int(ev.get("delta", 0)), "applied": false,
			"before": before, "after": before, "affinity": before,
			"band": NpcInteractionSystem.band(before),
		}
	set_affinity(soul, anchor_id, before + int(ev.get("delta", 0)))
	var after: int = affinity(soul, anchor_id)
	return {
		"ok": true, "eventId": str(ev.get("eventId", "")), "label": str(ev.get("label", "")),
		"reply": str(ev.get("reply", "")), "delta": int(ev.get("delta", 0)), "applied": true,
		"before": before, "after": after, "affinity": after,
		"band": NpcInteractionSystem.band(after),
	}


# --- 揭示 ---

## 一条揭示分支此刻能不能解锁。返回 {ok, reason}。
static func revelation_ready(
	soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, revelation: Dictionary
) -> Dictionary:
	if revelation.is_empty():
		return {"ok": false, "reason": "没有这条揭示"}
	var anchor_id: String = str(cfg.get("anchorId", ""))
	if affinity(soul, anchor_id) < int(revelation.get("minAffinity", 0)):
		return {"ok": false, "reason": "你和%s还没熟到这个份上。" % str(cfg.get("displayName", ""))}
	if bool(_memory_known(soul, cfg, revelation)):
		return {"ok": false, "reason": "这段他已经对你说过了。"}
	var main_cfg: Dictionary = ContentLoader.get_mainline_config()
	var need_shards: int = int(revelation.get("requiresShards", 0))
	if ShardLine.collected_count(_progress(soul)) < need_shards:
		return {"ok": false, "reason": "你手里的碎片还不够。"}
	var need_act: String = str(revelation.get("requiresAct", ""))
	if not need_act.is_empty():
		var order: Array = ShardLine.act_order(main_cfg)
		var need_idx: int = order.find(need_act)
		var cur_idx: int = order.find(ShardLine.current_act(_progress(soul)))
		if need_idx >= 0 and cur_idx < need_idx:
			return {"ok": false, "reason": "还不到说这话的时候。"}
	for clue_id in revelation.get("requiresClues", []):
		if not ShardLine.has_clue(_progress(soul), str(clue_id)):
			return {"ok": false, "reason": "他还等你先弄清另一件事。"}
	if not _prereq_ok(avatar, revelation):
		return {"ok": false, "reason": "你还没拿出让他信服的东西。"}
	return {"ok": true, "reason": ""}


## 一位锚点此刻的全部揭示分支，各带 unlocked 与未解锁的原因。供面板列。
static func available_revelations(
	soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary
) -> Array:
	var out: Array = []
	for rev in cfg.get("revelations", []):
		if not (rev is Dictionary):
			continue
		var checked: Dictionary = revelation_ready(soul, world, avatar, cfg, rev)
		out.append({
			"revelationId": str((rev as Dictionary).get("revelationId", "")),
			"label": str((rev as Dictionary).get("label", "")),
			"detail": str((rev as Dictionary).get("detail", "")),
			"unlocked": bool(checked.get("ok", false)),
			"reason": str(checked.get("reason", "")),
			"known": bool(_memory_known(soul, cfg, rev)),
		})
	return out


## 执行一条揭示：把该说的话说了、把主线线索揭示掉、记下记忆、加锚点好感。
## 返回 {ok, revelationId, label, detail, lines, revealedClues, advanced, act,
##        affinity, memoryFlags, errorCode, error}。
static func reveal(
	soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, revelation_id: String
) -> Dictionary:
	var rev: Dictionary = _find_revelation(cfg, revelation_id)
	if rev.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这条揭示：" + revelation_id)
	var checked: Dictionary = revelation_ready(soul, world, avatar, cfg, rev)
	if not bool(checked.get("ok", false)):
		return _fail(ERROR_PRECONDITION_FAILED, str(checked.get("reason", "现在还说不出口。")))
	var anchor_id: String = str(cfg.get("anchorId", ""))
	var main_cfg: Dictionary = ContentLoader.get_mainline_config()
	var before_act: String = ShardLine.current_act(_progress(soul))
	var revealed: Array = []
	for clue_id in rev.get("revealClues", []):
		var res: Dictionary = ShardLine.reveal_clue(_progress(soul), str(clue_id), main_cfg)
		if bool(res.get("ok", false)):
			revealed.append(str(clue_id))
	for shard_id in rev.get("collectShards", []):
		var res: Dictionary = ShardLine.collect_shard(_progress(soul), str(shard_id), main_cfg)
		if bool(res.get("ok", false)):
			revealed.append(str(shard_id))
	var flags: Array = rev.get("memoryFlags", [])
	for flag in flags:
		add_memory(soul, anchor_id, str(flag))
	var gained: int = int(rev.get("affinity", 0))
	if gained != 0:
		set_affinity(soul, anchor_id, affinity(soul, anchor_id) + gained)
	# 幕次可能因这次揭示而推进（碎片数 + 关键线索双条件，见 D-195）。
	var after_act: String = ShardLine.current_act(_progress(soul))
	return {
		"ok": true,
		"revelationId": revelation_id,
		"label": str(rev.get("label", "")),
		"detail": str(rev.get("detail", "")),
		"lines": rev.get("lines", []),
		"revealedClues": revealed,
		"advanced": after_act != before_act,
		"act": after_act,
		"actLabel": ShardLine.act_label(after_act, main_cfg),
		"affinity": affinity(soul, anchor_id),
		"affinityGain": gained,
		"memoryFlags": flags,
		"errorCode": ERROR_NONE,
		"error": "",
	}


# --- 内部 ---

## 灵魂上的主线进度（SoulRecord.main_quest_progress，缺失时给空字典由 ShardLine 兜）。
static func _progress(soul: SoulRecord) -> Dictionary:
	return {} if soul == null else soul.main_quest_progress


## 这条揭示是否"已经说过"（记忆标记齐了就当作说过）。
static func _memory_known(soul: SoulRecord, cfg: Dictionary, revelation: Dictionary) -> bool:
	var flags: Array = revelation.get("memoryFlags", [])
	if flags.is_empty():
		return false
	var anchor_id: String = str(cfg.get("anchorId", ""))
	for flag in flags:
		if not has_memory(soul, anchor_id, str(flag)):
			return false
	return true


static func _find_revelation(cfg: Dictionary, revelation_id: String) -> Dictionary:
	for rev in cfg.get("revelations", []):
		if rev is Dictionary and str((rev as Dictionary).get("revelationId", "")) == revelation_id:
			return rev
	return {}


## 前置属性判定（好感事件沿用 B3 的 `need*` 键，揭示分支用更贴条件的 `requires*` 键；
## 两套前缀都认，值取较大者）：
##   needCha / requiresCha                       魅力 ≥ 值
##   needStrOrCha / requiresStrOrCha             力量或魅力（取大者）≥ 值
##   needSoulOrAlchemy / requiresSoulOrAlchemy   灵魂属性或炼金技能（取大者）≥ 值
## 没有前置字段恒满足；不认识的字段按满足（保守地不拦）。
static func _prereq_ok(avatar: PlayerAvatar, spec: Dictionary) -> bool:
	if avatar == null:
		return false
	var need_cha: int = maxi(int(spec.get("needCha", 0)), int(spec.get("requiresCha", 0)))
	if need_cha > 0 and avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA) < need_cha:
		return false
	var need_str_cha: int = maxi(int(spec.get("needStrOrCha", 0)), int(spec.get("requiresStrOrCha", 0)))
	if need_str_cha > 0:
		var strongest: int = maxi(
			avatar.get_attribute(PlayerAvatar.ATTR_STRENGTH),
			avatar.get_attribute(PlayerAvatar.ATTR_CHARISMA))
		if strongest < need_str_cha:
			return false
	var need_soul: int = maxi(int(spec.get("needSoulOrAlchemy", 0)), int(spec.get("requiresSoulOrAlchemy", 0)))
	if need_soul > 0:
		var soul_attr: int = avatar.get_attribute(PlayerAvatar.ATTR_SOUL)
		var alchemy: int = int(avatar.skills.get("alchemy", 0))
		if maxi(soul_attr, alchemy) < need_soul:
			return false
	return true


static func _fail(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "error": message}