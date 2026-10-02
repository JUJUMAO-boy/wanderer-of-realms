class_name EndingLine
extends RefCounted

## 四种结局与后日谈规则层（第四阶段 D6 / D-213~D-215）。
##
## 剧本 12 节：站到轮回之轮核心前的玩家，按沿途的抉择分出四种去向——
##   return 归还·秩序 / inherit 继承·轮回 / break 打破·自由 / turn 转身·自由。
## 本类只做四件事，全是纯规则、可无头钉测：
##
##   1. **资格** `gate`：三步——终结性结局要已打赢总攻（`requiresVictory`，读
##      FinalBattle.has_won）；`requiresAct` 要主线幕次到档；已做过终结性抉择后
##      其余终结性结局一律关闭。**转身不锁**（`terminal=false`）——它记一笔
##      `worldFlag`，但主线仍可继续（剧本 12.4：主线不封闭）。
##   2. **建议** `suggested`：按玩家沿途的形迹（吞过龙魂 → 打破；结盟瓦洛克得龙魂 →
##      继承；干干净净 → 归还）挑一个"推荐"，纯提示，不做限制。同一存档恒得同一结果。
##   3. **后日谈关系分支** `relation_lines`：剧本 12.5——后日谈不是死的，前世积累的
##      关系（鸦 / 伊莉丝高好感、瓦洛克结盟、李白入队）会追加专属文字。关系不达即不显，
##      绝不硬凑。
##   4. **落账** `resolve`：把选中的结局记进 `SoulRecord.main_quest_progress["endings"]`
##      （与 ShardLine 同键、同列表），落世界标记，交回 epilogue + 关系分支正文。
##      终结性结局跨世保留；转身不锁。
##
## 数值与正文全走 mainline.json 的 `endings`（经 ContentLoader）。本类不写死系数、
## 不碰世界几何与面板、不改城市。

## 结局类型（仅用于界面分组与史书标注）。
const KIND_ORDER: String = "order"
const KIND_CYCLE: String = "cycle"
const KIND_FREE: String = "free"

## 已选结局的落点键（与 ShardLine.KEY_ENDINGS 同键：同一份 main_quest_progress）。
const KEY_ENDINGS: String = "endings"

## 主线终局史书条目的权重（> FinalBattle 的 320，保证压轴进史书）。
const WEIGHT: int = 340

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"


# --- 查表 ---

static func endings(cfg: Dictionary) -> Array:
	return cfg.get("endings", [])


static func find(cfg: Dictionary, ending_id: String) -> Dictionary:
	for entry in endings(cfg):
		if entry is Dictionary and str((entry as Dictionary).get("endingId", "")) == ending_id:
			return entry
	return {}


## 已选过的结局 id 列表（顺序即选择顺序）。
static func chosen(soul: SoulRecord) -> Array:
	if soul == null or not (soul.main_quest_progress is Dictionary):
		return []
	var list: Variant = soul.main_quest_progress.get(KEY_ENDINGS, null)
	return list if list is Array else []


static func has_chosen(soul: SoulRecord, ending_id: String) -> bool:
	return chosen(soul).has(ending_id)


## 是否已做过"终结性"抉择（return/inherit/break）。转身（terminal=false）不算。
static func has_ended(soul: SoulRecord, cfg: Dictionary) -> bool:
	for ending_id in chosen(soul):
		if bool(find(cfg, str(ending_id)).get("terminal", true)):
			return true
	return false


# --- 资格 ---

## 这个结局此刻能不能选。返回 {ok, reason, endingId, needVictory}。
static func gate(soul: SoulRecord, world: WorldState, cfg: Dictionary, ending: Dictionary) -> Dictionary:
	if ending.is_empty():
		return {"ok": false, "reason": "没有这个结局。", "endingId": "", "needVictory": false}
	var ending_id: String = str(ending.get("endingId", ""))
	var need_victory: bool = bool(ending.get("requiresVictory", false))
	var base: Dictionary = {
		"ok": false, "reason": "", "endingId": ending_id, "needVictory": need_victory,
	}
	if has_ended(soul, cfg):
		base["reason"] = "你的抉择已经做过了——轮子只会为你转这一次。"
		return base
	if need_victory and bool(ending.get("terminal", true)) and has_chosen(soul, ending_id):
		base["reason"] = "这条路你已经选过了。"
		return base
	if need_victory and not FinalBattle.has_won(soul):
		base["reason"] = "你还没站到轮核之前——灰袍者仍挡在路上。"
		return base
	var need_act: String = str(ending.get("requiresAct", ""))
	if not need_act.is_empty() and not _act_reached(soul, need_act):
		base["reason"] = "时候还没到——你还没看清这一切。"
		return base
	base["ok"] = true
	return base


static func _act_reached(soul: SoulRecord, need_act: String) -> bool:
	var order: Array = ShardLine.act_order(ContentLoader.get_mainline_config())
	var need_idx: int = order.find(need_act)
	if need_idx < 0:
		return true
	var prog: Dictionary = {} if soul == null else soul.main_quest_progress
	return order.find(ShardLine.current_act(prog)) >= need_idx


# --- 面板列（四个去向与逐条可否选）---

## 四个结局的当前状态。返回 [{endingId,label,note,kind,terminal,requiresVictory,
##                                available,reason,suggested,chosen}]。
static func available(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> Array:
	var pick: String = suggested(soul, world, cfg)
	var out: Array = []
	for entry in endings(cfg):
		if not (entry is Dictionary):
			continue
		var ending: Dictionary = entry
		var ending_id: String = str(ending.get("endingId", ""))
		var checked: Dictionary = gate(soul, world, cfg, ending)
		out.append({
			"endingId": ending_id,
			"label": str(ending.get("label", ending_id)),
			"note": str(ending.get("note", "")),
			"kind": str(ending.get("kind", "")),
			"terminal": bool(ending.get("terminal", true)),
			"requiresVictory": bool(ending.get("requiresVictory", false)),
			"available": bool(checked.get("ok", false)),
			"reason": str(checked.get("reason", "")),
			"suggested": ending_id == pick,
			"chosen": has_chosen(soul, ending_id),
		})
	return out


# --- 建议（纯提示）---

## 推荐哪一个去向：按 config 次序，第一个"形迹对得上"且可选的结局；都不对就取
## 标了 defaultSuggested 的（转身）。同存档恒得同一结果。
static func suggested(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> String:
	var avatar: PlayerAvatar = world.avatar if world != null else null
	var first_available: String = ""
	var fallback: String = ""
	for entry in endings(cfg):
		if not (entry is Dictionary):
			continue
		var ending: Dictionary = entry
		var ending_id: String = str(ending.get("endingId", ""))
		if bool(ending.get("defaultSuggested", false)):
			fallback = ending_id
		if not bool(gate(soul, world, cfg, ending).get("ok", false)):
			continue
		if first_available.is_empty():
			first_available = ending_id
		var spec: Variant = ending.get("suggest", null)
		if spec is Dictionary and _matches(spec, soul, avatar):
			return ending_id
	if not first_available.is_empty():
		return first_available
	return fallback


## 形迹是否对得上（全部条件都满足才为真）。
static func _matches(spec: Dictionary, soul: SoulRecord, avatar: PlayerAvatar) -> bool:
	var dragonization: int = _dragonization(soul, avatar)
	var dragon_soul: int = _dragon_soul(soul, avatar)
	if spec.has("dragonizationAtLeast") and dragonization < int(spec["dragonizationAtLeast"]):
		return false
	if spec.has("dragonizationAtMost") and dragonization > int(spec["dragonizationAtMost"]):
		return false
	if spec.has("dragonSoulAtLeast") and dragon_soul < int(spec["dragonSoulAtLeast"]):
		return false
	if spec.has("dragonSoulAtMost") and dragon_soul > int(spec["dragonSoulAtMost"]):
		return false
	return true


## 化身当前的龙化度（吞龙魂留下的痕迹）；化身不在时退到灵魂上的跨世印记。
static func _dragonization(soul: SoulRecord, avatar: PlayerAvatar) -> int:
	var carried: int = 0 if soul == null else int(soul.dragonization_carry)
	return maxi(carried, 0 if avatar == null else avatar.dragonization)


static func _dragon_soul(soul: SoulRecord, avatar: PlayerAvatar) -> int:
	return 0 if avatar == null else avatar.dragon_soul


# --- 后日谈关系分支（剧本 12.5）---

## 该结局下、玩家确实持有的关系所追加的专属文字。
## 返回 [{relId, label, lines:[...]}]。关系不达标就不显——绝不硬凑。
static func relation_lines(soul: SoulRecord, world: WorldState, cfg: Dictionary, ending_id: String) -> Array:
	var ending: Dictionary = find(cfg, ending_id)
	var out: Array = []
	for entry in ending.get("relations", []):
		if not (entry is Dictionary):
			continue
		var rel: Dictionary = entry
		if not _relation_held(soul, world, rel):
			continue
		out.append({
			"relId": str(rel.get("relId", "")),
			"label": str(rel.get("label", "")),
			"lines": rel.get("lines", []),
		})
	return out


static func _relation_held(soul: SoulRecord, world: WorldState, rel: Dictionary) -> bool:
	var need: int = int(rel.get("minAffinity", 0))
	match str(rel.get("kind", "")):
		"anchor":
			return AnchorLine.affinity(soul, str(rel.get("targetId", ""))) >= need
		"comer":
			return ComerFavor.affinity(world, str(rel.get("targetId", ""))) >= need
		"rune":
			return soul != null and soul.known_runes.has(str(rel.get("requiresRune", "")))
		"flag":
			return world != null and bool(world.world_flags.get(str(rel.get("requiresFlag", "")), false))
	return false


# --- 落账 ---

## 选中一个结局：资格过则记进 progress["endings"]、落世界标记，交回后日谈正文与关系分支。
## 返回 {ok, endingId, label, note, kind, terminal, epilogue, worldAfter, relationLines,
##        worldFlag, errorCode, error}。
static func resolve(
	soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, ending_id: String
) -> Dictionary:
	var ending: Dictionary = find(cfg, ending_id)
	if ending.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这个结局：" + ending_id)
	var checked: Dictionary = gate(soul, world, cfg, ending)
	if not bool(checked.get("ok", false)):
		return _fail(ERROR_PRECONDITION_FAILED, str(checked.get("reason", "现在还轮不到这个抉择。")))
	if soul == null:
		return _fail(ERROR_PRECONDITION_FAILED, "没有可落账的灵魂。")
	if not (soul.main_quest_progress is Dictionary):
		soul.main_quest_progress = {}
	if not (soul.main_quest_progress.get(KEY_ENDINGS, null) is Array):
		soul.main_quest_progress[KEY_ENDINGS] = []
	if not has_chosen(soul, ending_id):
		(soul.main_quest_progress[KEY_ENDINGS] as Array).append(ending_id)
	var world_flag: String = str(ending.get("worldFlag", ""))
	if not world_flag.is_empty() and world != null:
		world.world_flags[world_flag] = true
	return {
		"ok": true,
		"endingId": ending_id,
		"label": str(ending.get("label", ending_id)),
		"note": str(ending.get("note", "")),
		"kind": str(ending.get("kind", "")),
		"terminal": bool(ending.get("terminal", true)),
		"epilogue": ending.get("epilogue", []),
		"worldAfter": str(ending.get("worldAfter", "")),
		"relationLines": relation_lines(soul, world, cfg, ending_id),
		"worldFlag": world_flag,
		"errorCode": ERROR_NONE,
		"error": "",
	}


# --- 简报（接线/界面共用）---

## 把资格、去向列表、已选结局的正文组装成接线与界面能直接用的结构。返回：
##   { ready, ended, options:[...], chosen:{endingId,label,note,kind,epilogue,worldAfter,relationLines} }
static func briefing(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> Dictionary:
	var options: Array = available(soul, world, cfg)
	var any_available: bool = false
	for option in options:
		if bool((option as Dictionary).get("available", false)):
			any_available = true
			break
	var ids: Array = chosen(soul)
	var chosen_view: Dictionary = {}
	if not ids.is_empty():
		var last_id: String = str(ids[ids.size() - 1])
		var ending: Dictionary = find(cfg, last_id)
		chosen_view = {
			"endingId": last_id,
			"label": str(ending.get("label", last_id)),
			"note": str(ending.get("note", "")),
			"kind": str(ending.get("kind", "")),
			"epilogue": ending.get("epilogue", []),
			"worldAfter": str(ending.get("worldAfter", "")),
			"relationLines": relation_lines(soul, world, cfg, last_id),
		}
	return {
		"ready": any_available or not chosen_view.is_empty(),
		"ended": has_ended(soul, cfg),
		"options": options,
		"chosen": chosen_view,
	}


# --- 纪年 ---

## 结局的史书条目。接 M16 Chronicle。
static func chronicle_entry(world: WorldState, ending: Dictionary, month: int, year: String) -> Dictionary:
	var label: String = str(ending.get("label", ""))
	return {
		"kind": Chronicle.KIND_MAINLINE,
		"title": "主线终局·%s" % label,
		"cityId": "",
		"cityLabel": "",
		"detail": str(ending.get("note", "")),
		"attribution": "主线",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}


static func _fail(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "error": message}