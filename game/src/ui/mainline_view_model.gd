class_name MainlineViewModel
extends RefCounted

## 主线面板的视图模型（第四阶段 D1 / D-194~D-196）。纯函数：把灵魂上的主线进度
## （`SoulRecord.main_quest_progress`）与 mainline.json 组装成界面能直接画的结构——
## 幕次进度、七片碎片格、线索揭示、下一道门槛。不加工数值、不碰渲染。

## 七片碎片的槽位列（界面按元素排，与剧本 3 节表的顺序一致）。
## battle —— 终局战役简报（FinalBattle.briefing 的产出，第四阶段 D5）。缺省不摆总攻段。
static func build(progress: Dictionary, cfg: Dictionary, battle: Dictionary = {}) -> Dictionary:
	var order: Array = ShardLine.act_order(cfg)
	var cur: String = ShardLine.current_act(progress)
	var cur_idx: int = order.find(cur)

	var acts: Array = []
	for i in range(order.size()):
		var act_id: String = str(order[i])
		acts.append({
			"actId": act_id,
			"label": ShardLine.act_label(act_id, cfg),
			"reached": i <= cur_idx,
			"current": act_id == cur,
		})

	var shards: Array = []
	for shard in ShardLine.shard_pool(cfg):
		if not (shard is Dictionary):
			continue
		var sid: String = str((shard as Dictionary).get("shardId", ""))
		shards.append({
			"shardId": sid,
			"name": str((shard as Dictionary).get("name", sid)),
			"element": str((shard as Dictionary).get("element", "")),
			"aspect": str((shard as Dictionary).get("aspect", "")),
			"place": str((shard as Dictionary).get("place", "")),
			"collected": ShardLine.has_shard(progress, sid),
		})

	var clues: Array = []
	var revealed: int = 0
	for clue in ShardLine.clue_pool(cfg):
		if not (clue is Dictionary):
			continue
		var cid: String = str((clue as Dictionary).get("clueId", ""))
		var have: bool = ShardLine.has_clue(progress, cid)
		if have:
			revealed += 1
		clues.append({
			"clueId": cid,
			"label": str((clue as Dictionary).get("label", cid)),
			"source": str((clue as Dictionary).get("source", "")),
			"text": str((clue as Dictionary).get("text", "")),
			"revealed": have,
		})

	return {
		"actId": cur,
		"actLabel": ShardLine.act_label(cur, cfg),
		"acts": acts,
		"shards": shards,
		"clues": clues,
		"collected": ShardLine.collected_count(progress),
		"shardTotal": ShardLine.shard_pool(cfg).size(),
		"clueRevealed": revealed,
		"clueTotal": ShardLine.clue_pool(cfg).size(),
		"next": ShardLine.next_requirement(progress, cfg),
		"complete": ShardLine.is_complete(progress, cfg),
		"endings": cfg.get("endings", []),
		"battle": battle,
	}