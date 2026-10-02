class_name ShardLine
extends RefCounted

## 永恒者灵魂碎片主线（第四阶段 D1 / D-194~D-196）。
##
## 这条暗线横贯多世、可被选择是否深挖（剧本 1 节：**不锁进程**）——它不阻塞任何玩法，
## 玩家可以完全无视它。本类只做三件事：
##
##   1. **碎片收集**：七片碎片各有一个去处（锚点 NPC / 事件 / 副本），由外部判定"够不够
##      拿"后调用 `collect_shard` 落账。碎片与灵魂绑定、跨世不丢（剧本 13 节）。
##   2. **四幕双条件推进**（D-195）：幕次按「**已集碎片数 + 关键揭示动作**」一起判——集齐
##      碎片还不够，得听锚点 NPC 把真相说透（reveal_clue）才进下一幕。幕次**只进不退**
##      （真相学会了不会再忘；线索即便跨世残了，幕次也不会倒回去）。
##   3. **跨世继承**（剧本 13 节）：碎片跨世恒不丢；线索需 SOU ≥ 门槛才完整保留，否则
##      按比例丢掉最近学到的一部分。
##
## 落点：进度写 `SoulRecord.main_quest_progress`（随灵魂存档）。会话不落盘，本类不碰 UI、
## 不改世界，可无头钉测。数据全走 mainline.json（经 ContentLoader）。
##
## 进度结构：
##   { "shards": [shardId...], "clues": [clueId...], "act": "echo", "endings": [endingId...] }

const ACT_ECHO: String = "echo"
const ACT_SHARDS: String = "shards"
const ACT_CYCLE: String = "cycle"
const ACT_CHOICE: String = "choice"

const KEY_SHARDS: String = "shards"
const KEY_CLUES: String = "clues"
const KEY_ACT: String = "act"
const KEY_ENDINGS: String = "endings"

## 主线纪年条目的权重（> Chronicle 默认门槛 250，保证进史书）。
const WEIGHT: int = 290


## 一份空进度。SoulRecord.main_quest_progress 默认是 {}，各入口先经 _ensure 补齐。
static func progress_template() -> Dictionary:
	return {KEY_SHARDS: [], KEY_CLUES: [], KEY_ACT: ACT_ECHO, KEY_ENDINGS: []}


## 把进度补成完整形状（就地改，容忍来自存档的空字典 / 缺键）。
static func _ensure(progress: Dictionary) -> void:
	if not (progress.get(KEY_SHARDS, null) is Array):
		progress[KEY_SHARDS] = []
	if not (progress.get(KEY_CLUES, null) is Array):
		progress[KEY_CLUES] = []
	if not (progress.get(KEY_ENDINGS, null) is Array):
		progress[KEY_ENDINGS] = []
	if str(progress.get(KEY_ACT, "")).is_empty():
		progress[KEY_ACT] = ACT_ECHO


static func shard_pool(cfg: Dictionary) -> Array:
	return cfg.get("shards", [])


static func clue_pool(cfg: Dictionary) -> Array:
	return cfg.get("clues", [])


static func act_order(cfg: Dictionary) -> Array:
	var out: Array = []
	for act in cfg.get("acts", []):
		out.append(str(act.get("actId", "")))
	return out


static func has_shard(progress: Dictionary, shard_id: String) -> bool:
	return (progress.get(KEY_SHARDS, []) as Array).has(shard_id)


static func has_clue(progress: Dictionary, clue_id: String) -> bool:
	return (progress.get(KEY_CLUES, []) as Array).has(clue_id)


static func collected_count(progress: Dictionary) -> int:
	return (progress.get(KEY_SHARDS, []) as Array).size()


static func current_act(progress: Dictionary) -> String:
	var act: String = str(progress.get(KEY_ACT, ""))
	return ACT_ECHO if act.is_empty() else act


## 收集一片碎片。已收集 → ok=false, already=true（幂等，不重复落账）。
## 落账后按双条件尝试推进幕次，返回 {ok, already, advanced, act, shardId}。
static func collect_shard(progress: Dictionary, shard_id: String, cfg: Dictionary) -> Dictionary:
	_ensure(progress)
	if shard_id.is_empty() or not _shard_known(cfg, shard_id):
		return {"ok": false, "already": false, "advanced": false,
			"act": current_act(progress), "shardId": shard_id}
	if has_shard(progress, shard_id):
		return {"ok": false, "already": true, "advanced": false,
			"act": current_act(progress), "shardId": shard_id}
	(progress[KEY_SHARDS] as Array).append(shard_id)
	var advanced: bool = advance(progress, cfg)
	return {"ok": true, "already": false, "advanced": advanced,
		"act": current_act(progress), "shardId": shard_id}


## 揭示一条线索（关键揭示动作）。已揭示 → already=true。
## 落账后按双条件尝试推进幕次，返回 {ok, already, advanced, act, clueId}。
static func reveal_clue(progress: Dictionary, clue_id: String, cfg: Dictionary) -> Dictionary:
	_ensure(progress)
	if clue_id.is_empty() or not _clue_known(cfg, clue_id):
		return {"ok": false, "already": false, "advanced": false,
			"act": current_act(progress), "clueId": clue_id}
	if has_clue(progress, clue_id):
		return {"ok": false, "already": true, "advanced": false,
			"act": current_act(progress), "clueId": clue_id}
	(progress[KEY_CLUES] as Array).append(clue_id)
	var advanced: bool = advance(progress, cfg)
	return {"ok": true, "already": false, "advanced": advanced,
		"act": current_act(progress), "clueId": clue_id}


## 双条件判定：当前"够得着的最高一幕"（门槛都满足的最后一幕）。
static func derived_act(progress: Dictionary, cfg: Dictionary) -> String:
	var result: String = ACT_ECHO
	var shards: int = collected_count(progress)
	for act in cfg.get("acts", []):
		if not (act is Dictionary):
			continue
		if requirement_met(progress, act, shards):
			result = str(act.get("actId", result))
	return result


## 单幕门槛是否满足：碎片数够 + 关键线索齐。
static func requirement_met(progress: Dictionary, act: Dictionary, shard_count: int = -1) -> bool:
	var need_shards: int = int(act.get("requiresShards", 0))
	var have_shards: int = collected_count(progress) if shard_count < 0 else shard_count
	if have_shards < need_shards:
		return false
	for clue_id in act.get("requiresClues", []):
		if not has_clue(progress, str(clue_id)):
			return false
	return true


## 按双条件推进幕次（只进不退）。返回是否真的进了一幕。
static func advance(progress: Dictionary, cfg: Dictionary) -> bool:
	_ensure(progress)
	var order: Array = act_order(cfg)
	var cur_idx: int = order.find(current_act(progress))
	var target_idx: int = order.find(derived_act(progress, cfg))
	if target_idx > cur_idx:
		progress[KEY_ACT] = str(order[target_idx])
		return true
	return false


## 主线是否走完：幕次到顶且碎片集齐。
static func is_complete(progress: Dictionary, cfg: Dictionary) -> bool:
	var order: Array = act_order(cfg)
	var top: String = str(order[order.size() - 1]) if not order.is_empty() else ACT_ECHO
	return current_act(progress) == top and collected_count(progress) >= shard_pool(cfg).size()


## 下一道门槛的可读描述（供面板）。返回 {done, actId, actLabel, needShards, haveShards,
## needClues:[{clueId,label,have}], missingShards}。
static func next_requirement(progress: Dictionary, cfg: Dictionary) -> Dictionary:
	_ensure(progress)
	var shards: int = collected_count(progress)
	for act in cfg.get("acts", []):
		if not (act is Dictionary):
			continue
		if requirement_met(progress, act, shards):
			continue
		var need_clues: Array = []
		for clue_id in act.get("requiresClues", []):
			need_clues.append({
				"clueId": str(clue_id),
				"label": clue_label(cfg, str(clue_id)),
				"have": has_clue(progress, str(clue_id)),
			})
		return {
			"done": false,
			"actId": str(act.get("actId", "")),
			"actLabel": act_label(str(act.get("actId", "")), cfg),
			"needShards": int(act.get("requiresShards", 0)),
			"haveShards": shards,
			"needClues": need_clues,
			"missingShards": maxi(0, int(act.get("requiresShards", 0)) - shards),
		}
	return {"done": true, "actId": "", "actLabel": "", "needShards": 0,
		"haveShards": shards, "needClues": [], "missingShards": 0}


## 跨世继承（剧本 13 节）。碎片恒不丢；线索在 SOU < 门槛时按比例丢掉最近的一部分。
## 返回 {cluesLost:[...], clueCount, kept}。**幕次不回退**（真相学会了不会忘）。
static func inheritance_on_death(progress: Dictionary, sou_value: int, cfg: Dictionary) -> Dictionary:
	_ensure(progress)
	var inh: Dictionary = cfg.get("inheritance", {})
	var threshold: int = int(inh.get("clueSoulThreshold", 50))
	var clues: Array = progress[KEY_CLUES]
	if sou_value >= threshold or clues.is_empty():
		return {"cluesLost": [], "clueCount": clues.size(), "kept": clues.duplicate()}
	var ratio: float = clampf(float(inh.get("clueLossRatio", 0.5)), 0.0, 1.0)
	var drop_count: int = int(ceil(float(clues.size()) * ratio))
	drop_count = clampi(drop_count, 0, clues.size())
	var lost: Array = []
	for i in range(drop_count):
		lost.append(clues[clues.size() - 1 - i])  # 从最近学到的开始丢
	progress[KEY_CLUES] = clues.slice(0, clues.size() - drop_count)
	# 反过来按时间顺序给出（先去后留），便于文案
	lost.reverse()
	return {"cluesLost": lost, "clueCount": progress[KEY_CLUES].size(),
		"kept": (progress[KEY_CLUES] as Array).duplicate()}


static func act_label(act_id: String, cfg: Dictionary) -> String:
	for act in cfg.get("acts", []):
		if str(act.get("actId", "")) == act_id:
			return str(act.get("label", act_id))
	return act_id


static func clue_label(cfg: Dictionary, clue_id: String) -> String:
	for clue in clue_pool(cfg):
		if str(clue.get("clueId", "")) == clue_id:
			return str(clue.get("label", clue_id))
	return clue_id


static func shard_name(cfg: Dictionary, shard_id: String) -> String:
	for shard in shard_pool(cfg):
		if str(shard.get("shardId", "")) == shard_id:
			return str(shard.get("name", shard_id))
	return shard_id


# --- 纪年 ---

## 拾得一片碎片的史书条目。接 M16 Chronicle。
static func shard_entry(world: WorldState, shard_id: String, month: int, year: String) -> Dictionary:
	var shard: Dictionary = ContentLoader.get_shard(shard_id)
	var name: String = str(shard.get("name", shard_id))
	var place: String = str(shard.get("place", ""))
	return {
		"kind": Chronicle.KIND_MAINLINE,
		"title": "拾得%s" % name,
		"cityId": str(shard.get("cityId", "")),
		"cityLabel": "",
		"detail": "%s被从%s里带了出来，落在你的掌心——凉得不像死物。" % [name, place],
		"attribution": "主线",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}


## 主线推进一步（幕次前进）的史书条目。
static func act_entry(world: WorldState, act_id: String, month: int, year: String) -> Dictionary:
	var cfg: Dictionary = ContentLoader.get_mainline_config()
	var label: String = act_label(act_id, cfg)
	return {
		"kind": Chronicle.KIND_MAINLINE,
		"title": "主线进至%s" % label,
		"cityId": "",
		"cityLabel": "",
		"detail": "拼图又合上一块。你还没看清全貌，但已经回不去那个什么都不知道的自己了。",
		"attribution": "主线",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}


# --- 内部 ---

static func _shard_known(cfg: Dictionary, shard_id: String) -> bool:
	for shard in shard_pool(cfg):
		if str(shard.get("shardId", "")) == shard_id:
			return true
	return false


static func _clue_known(cfg: Dictionary, clue_id: String) -> bool:
	for clue in clue_pool(cfg):
		if str(clue.get("clueId", "")) == clue_id:
			return true
	return false