class_name MainlineCross
extends RefCounted

## 乱入者×主线的交叉任务（第四阶段 D4 / D-203~D-205）。
##
## 承接 D3 的 `Crossover`（判定与折档复用同一套），把六条**主线交叉**
## （《乱入者交叉任务剧本》CX-07~CX-12）接到 D1 的主线节点上。与 D3 的城市事件交叉
## 相反——它们**不碰城市**，而是：
##
##   1. **入场门槛** `gate`：以**主线幕次**为前置（`requiresAct`，可选 `requiresShards`），
##      叠加乱入者好感（`minAffinity`）。三条都满足，这条主线交叉才在乱入者对话里登场。
##      这是"乱入者在主线节点上登场"的落点。幕次读 `SoulRecord.main_quest_progress`，
##      与 D1/D2 同一份进度、单一来源。
##   2. **判定** `judge`：直接复用 `Crossover.judge`——把玩家与乱入者凑成 CrossTrial，
##      跑一句奏 / 一场球，同一化身恒得同一档，不掷骰。
##   3. **反哺主线** `resolve`：判定过关才揭示该分支的主线线索（`revealClues`，落账调
##      D1 的 `ShardLine.reveal_clue`）——线索可能正好补上某幕的关键凭据，从而把幕次
##      往前推（双条件由 ShardLine 判）。失败档（`failKeys`）改用 `fail` 套、不揭示。
##      另加乱入者好感、可选世界标记（如"结局预告"）。
##   4. **幂等**：以 `crossId:branchId` 记在 `SoulRecord.main_quest_progress["crossovers"]`，
##      跨世保留——同一条分支只结算一次好感（线索本就由 ShardLine 幂等兜底）；
##      失败不记，可再来。这样也避免了"只此一条路"把真相锁死。
##
## 数值：判定系数走 `balance.crossTrial`（B4/D3 同一份），门槛/档位/线索全在
## mainline_crossovers.json。本类不写死系数、不碰世界几何与面板。

const KEY_CROSSOVERS: String = "crossovers"

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"


# --- 入场门槛 ---

## 这条主线交叉此刻能不能登场。返回 {ok, reason, actId, needAct, affinity, needAffinity,
##                                 shards, needShards, crossId}。
static func gate(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {"ok": false, "reason": "没有这条主线交叉", "crossId": ""}
	var cross_id: String = str(cfg.get("crossId", ""))
	var comer_id: String = str(cfg.get("comerId", ""))
	var need_aff: int = int(cfg.get("minAffinity", 0))
	var affinity: int = ComerFavor.affinity(world, comer_id)
	var prog: Dictionary = _progress(soul)
	var main_cfg: Dictionary = ContentLoader.get_mainline_config()
	var cur_act: String = ShardLine.current_act(prog)
	var need_act: String = str(cfg.get("requiresAct", ""))
	var shards: int = ShardLine.collected_count(prog)
	var need_shards: int = int(cfg.get("requiresShards", 0))
	var base: Dictionary = {
		"actId": cur_act, "needAct": need_act,
		"affinity": affinity, "needAffinity": need_aff,
		"shards": shards, "needShards": need_shards,
		"crossId": cross_id,
	}

	if affinity < need_aff:
		base["ok"] = false
		base["reason"] = "%s还没把你当能说这件事的人。" % _comer_name(comer_id)
		return base
	if not _act_reached(cur_act, need_act, main_cfg):
		base["ok"] = false
		base["reason"] = "时候还没到——你还走不到他说的那一步。"
		return base
	if shards < need_shards:
		base["ok"] = false
		base["reason"] = "你手里的碎片还不够。"
		return base
	base["ok"] = true
	base["reason"] = ""
	return base


## 当前幕次是否已到（或已过）所需幕次。need_act 为空 → 恒满足。
static func _act_reached(cur_act: String, need_act: String, main_cfg: Dictionary) -> bool:
	if need_act.is_empty():
		return true
	var order: Array = ShardLine.act_order(main_cfg)
	var need_idx: int = order.find(need_act)
	var cur_idx: int = order.find(cur_act)
	if need_idx < 0:
		return true
	return cur_idx >= need_idx


# --- 面板列（当前这位乱入者的主线交叉与逐分支可否选）---

## 某位乱入者在主线节点上的交叉分支。返回
##   {ok, reason, crossId, displayName, summary, dialogue,
##    branches: [{branchId, label, detail, enabled, done, reason}]}
## ok=false（门槛没过）时 branches 仍给出，但全不可选——调用方可据此决定是否展示。
static func available(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {"ok": false, "reason": "没有这条主线交叉", "crossId": "", "branches": []}
	var checked: Dictionary = gate(soul, world, cfg)
	var rows: Array = []
	for branch in cfg.get("branches", []):
		if not (branch is Dictionary):
			continue
		var b: Dictionary = branch
		var branch_id: String = str(b.get("branchId", ""))
		var done: bool = branch_done(soul, str(cfg.get("crossId", "")), branch_id)
		var enabled: bool = bool(checked.get("ok", false)) and not done
		var reason: String = ""
		if done:
			reason = "这条路你已经走过了。"
		elif not bool(checked.get("ok", false)):
			reason = str(checked.get("reason", ""))
		rows.append({
			"branchId": branch_id,
			"label": str(b.get("label", "")),
			"detail": str(b.get("detail", "")),
			"enabled": enabled,
			"done": done,
			"reason": reason,
		})
	return {
		"ok": bool(checked.get("ok", false)),
		"reason": str(checked.get("reason", "")),
		"crossId": str(cfg.get("crossId", "")),
		"displayName": str(cfg.get("displayName", "")),
		"summary": str(cfg.get("summary", "")),
		"dialogue": cfg.get("dialogue", []),
		"branches": rows,
	}


# --- 判定 ---

## 跑一次判定（复用 Crossover）。返回与 D3 同形状的判定结构。
static func judge(world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, branch: Dictionary) -> Dictionary:
	return Crossover.judge(world, avatar, cfg, branch)


# --- 反哺主线 ---

## 执行一条主线交叉分支：判 → 揭示主线线索（成功套）/记乱入者好感/落世界标记，
## 返回 {ok, crossId, branchId, label, detail, lines, revealedClues, advanced, act,
##        actLabel, comerAffinity, worldFlag, judged, failed, errorCode, error}。
static func resolve(
	soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, branch_id: String
) -> Dictionary:
	if cfg.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这条主线交叉")
	var branch: Dictionary = _find_branch(cfg, branch_id)
	if branch.is_empty():
		return _fail(ERROR_NOT_FOUND, "这条主线交叉没有这个做法：" + branch_id)
	var checked: Dictionary = gate(soul, world, cfg)
	if not bool(checked.get("ok", false)):
		return _fail(ERROR_PRECONDITION_FAILED, str(checked.get("reason", "现在还轮不到这件事。")))
	var cross_id: String = str(cfg.get("crossId", ""))
	if branch_done(soul, cross_id, branch_id):
		return _fail(ERROR_PRECONDITION_FAILED, "这条路你已经走过了。")

	# 判（有 trial 才判；无 trial 的分支恒"成功"，如 CX-11 拼记忆 / CX-12 一场球）。
	var judged: Dictionary = {}
	var failed: bool = false
	if branch.has("trial"):
		judged = judge(world, avatar, cfg, branch)
		failed = bool(judged.get("failed", false))
	# 结果套：失败且写了 fail 套 → 用 fail；否则用分支本身。失败绝不揭示线索。
	var outcome: Dictionary = branch
	if failed:
		outcome = branch.get("fail", {}) if branch.get("fail", null) is Dictionary else {}

	var main_cfg: Dictionary = ContentLoader.get_mainline_config()
	var before_act: String = ShardLine.current_act(_progress(soul))
	var revealed: Array = []
	for clue_id in outcome.get("revealClues", []):
		var res: Dictionary = ShardLine.reveal_clue(_progress(soul), str(clue_id), main_cfg)
		if bool(res.get("ok", false)):
			revealed.append(str(clue_id))
	var after_act: String = ShardLine.current_act(_progress(soul))

	# 乱入者好感 / 世界标记：都取自结果套（失败时就是 fail 套的那份）。
	var aff_gain: int = int(outcome.get("comerAffinity", 0))
	var comer_id: String = str(cfg.get("comerId", ""))
	if aff_gain != 0 and not comer_id.is_empty():
		ComerFavor.set_affinity(
			world, comer_id, ComerFavor.affinity(world, comer_id) + aff_gain)
	var world_flag: String = str(outcome.get("worldFlag", ""))
	if not world_flag.is_empty() and world != null:
		world.world_flags[world_flag] = true

	# 成功的分支记下"已走"，跨世保留（失败不记，可再来）。
	if not failed:
		mark_branch_done(soul, cross_id, branch_id)

	return {
		"ok": true,
		"crossId": cross_id,
		"branchId": branch_id,
		"label": str(branch.get("label", "")),
		"detail": str(judged.get("detail", "") if not judged.is_empty() else branch.get("detail", "")),
		"lines": outcome.get("lines", []),
		"revealedClues": revealed,
		"advanced": after_act != before_act,
		"act": after_act,
		"actLabel": ShardLine.act_label(after_act, main_cfg),
		"comerAffinity": aff_gain,
		"worldFlag": world_flag,
		"judged": judged,
		"failed": failed,
		"errorCode": ERROR_NONE,
		"error": "",
	}


# --- 幂等记账（crossId:branchId 落 SoulRecord.main_quest_progress["crossovers"]）---

static func branch_done(soul: SoulRecord, cross_id: String, branch_id: String) -> bool:
	if soul == null or cross_id.is_empty() or branch_id.is_empty():
		return false
	return _done_list(soul).has(_done_key(cross_id, branch_id))


static func mark_branch_done(soul: SoulRecord, cross_id: String, branch_id: String) -> void:
	if soul == null or cross_id.is_empty() or branch_id.is_empty():
		return
	var key: String = _done_key(cross_id, branch_id)
	var list: Array = _done_list(soul)
	if not list.has(key):
		list.append(key)


## 已完成的主线交叉键列表（就地在 main_quest_progress 上建/补形状，容忍空进度）。
static func _done_list(soul: SoulRecord) -> Array:
	if soul == null:
		return []
	if not (soul.main_quest_progress is Dictionary):
		soul.main_quest_progress = {}
	if not (soul.main_quest_progress.get(KEY_CROSSOVERS, null) is Array):
		soul.main_quest_progress[KEY_CROSSOVERS] = []
	return soul.main_quest_progress[KEY_CROSSOVERS]


static func _done_key(cross_id: String, branch_id: String) -> String:
	return "%s:%s" % [cross_id, branch_id]


# --- 查表 / 内部 ---

static func _find_branch(cfg: Dictionary, branch_id: String) -> Dictionary:
	for branch in cfg.get("branches", []):
		if branch is Dictionary and str((branch as Dictionary).get("branchId", "")) == branch_id:
			return branch
	return {}


static func _progress(soul: SoulRecord) -> Dictionary:
	return {} if soul == null else soul.main_quest_progress


static func _comer_name(comer_id: String) -> String:
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	return str(cfg.get("displayName", "那位乱入者"))


static func _fail(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "error": message, "revealedClues": [], "lines": []}