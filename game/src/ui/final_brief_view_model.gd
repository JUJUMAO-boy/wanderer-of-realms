class_name FinalBriefViewModel
extends RefCounted

## 总攻简报页的视图模型（第四阶段界面精修 · 下，里程碑 55）。
##
## 总攻的内容（阶段链、灰袍者两阶段、动摇、助阵、共鸣）此前挤在主线面板底部，与幕次/碎片/
## 线索争一屏。这里把它整理成**一份可整屏读的简报**：把 `FinalBattle` 的阶段链与
## `final_battle.json` 的波次/BOSS 摊成人能读的条目（谁、几只、二阶段怎么变）。
## 纯函数：只整理，不判定、不加工数值（成败仍由 FinalBattle 说了算）、不碰渲染。
##
## 输入取自 `FinalBattle.briefing`（门槛/动摇/助阵）+ final_battle.json（阶段细节）。

const KIND_LABELS: Dictionary = {"wave": "波次", "boss": "BOSS"}


static func kind_label(kind: String) -> String:
	return str(KIND_LABELS.get(kind, ""))


## 组装简报。返回：
##   { available, reason, won, actId, needAct, needActLabel, gates,
##     wavering, allies, resonance, stages:[...], boss:{...} }
static func build(soul: SoulRecord, world: WorldState, avatar: PlayerAvatar, cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {}
	var brief: Dictionary = FinalBattle.briefing(soul, world, avatar, cfg)
	var need_act: String = str(brief.get("needAct", ""))
	var stages: Array = []
	for stage in FinalBattle.stages(cfg):
		stages.append(_stage_row(cfg, stage))
	return {
		"available": bool(brief.get("available", false)),
		"reason": str(brief.get("reason", "")),
		"won": bool(brief.get("won", false)),
		"actId": str(brief.get("actId", "")),
		"needAct": need_act,
		"needActLabel": ShardLine.act_label(need_act, ContentLoader.get_mainline_config()),
		"wavering": _wavering_view(cfg, brief.get("wavering", {})),
		"allies": brief.get("allies", []),
		"resonance": _resonance_view(cfg),
		"stages": stages,
		"boss": _boss_view(cfg),
	}


## 一条阶段：波次取该波的敌人组成，BOSS 阶段取该阶段的召唤组成。
static func _stage_row(cfg: Dictionary, stage: Dictionary) -> Dictionary:
	var kind: String = str(stage.get("kind", ""))
	var row: Dictionary = {
		"index": int(stage.get("index", 0)),
		"stageId": str(stage.get("stageId", "")),
		"label": str(stage.get("label", "")),
		"kind": kind,
		"kindLabel": kind_label(kind),
		"summary": str(stage.get("summary", "")),
		"detail": "",
	}
	if kind == FinalBattle.KIND_WAVE:
		var waves: Array = cfg.get("waves", [])
		var wi: int = int(stage.get("waveIndex", -1))
		if wi >= 0 and wi < waves.size():
			row["detail"] = _composition((waves[wi] as Dictionary).get("enemies", []))
	else:
		var boss: Dictionary = cfg.get("boss", {}) if cfg.get("boss", null) is Dictionary else {}
		var phases: Array = boss.get("phases", [])
		var pi: int = int(stage.get("bossPhaseIndex", -1))
		if pi >= 0 and pi < phases.size():
			row["detail"] = _composition((phases[pi] as Dictionary).get("summons", []))
	return row


## 灰袍者：本相 + 两阶段（HP/攻/防倍率、自损、召唤）。
static func _boss_view(cfg: Dictionary) -> Dictionary:
	var boss: Variant = cfg.get("boss", null)
	if not (boss is Dictionary) or (boss as Dictionary).is_empty():
		return {}
	var b: Dictionary = boss
	var profile: Dictionary = b.get("profile", {}) if b.get("profile", null) is Dictionary else {}
	var phases: Array = []
	for raw in b.get("phases", []):
		if not (raw is Dictionary):
			continue
		var p: Dictionary = raw
		phases.append({
			"stageId": str(p.get("stageId", "")),
			"label": str(p.get("label", "")),
			"summary": str(p.get("summary", "")),
			"hpMult": float(p.get("hpMult", 1.0)),
			"attackMult": float(p.get("attackMult", 1.0)),
			"armorMult": float(p.get("armorMult", 1.0)),
			"selfDrainBp": int(p.get("selfDrainBp", 0)),
			"summons": _composition(p.get("summons", [])),
		})
	return {
		"label": str(b.get("label", "灰袍者")),
		"summary": str(b.get("summary", "")),
		"hp": int(profile.get("hp", 0)),
		"attack": int(profile.get("attack", 0)),
		"armor": int(profile.get("armor", 0)),
		"threatLevel": int(profile.get("threatLevel", 0)),
		"phases": phases,
	}


## 动摇：判定结果（FinalBattle）+ 数据里的标签/结语。
static func _wavering_view(cfg: Dictionary, judged: Variant) -> Dictionary:
	var out: Dictionary = (judged as Dictionary).duplicate() if judged is Dictionary else {}
	var boss: Dictionary = cfg.get("boss", {}) if cfg.get("boss", null) is Dictionary else {}
	var w: Dictionary = boss.get("wavering", {}) if boss.get("wavering", null) is Dictionary else {}
	out["label"] = str(w.get("label", "动摇"))
	out["summary"] = str(w.get("summary", ""))
	return out


## 碎片共鸣：周期与两侧增益的说明。
static func _resonance_view(cfg: Dictionary) -> Dictionary:
	var r: Variant = cfg.get("resonance", null)
	if not (r is Dictionary) or (r as Dictionary).is_empty():
		return {}
	var res: Dictionary = r
	var player: Dictionary = res.get("playerBuff", {}) if res.get("playerBuff", null) is Dictionary else {}
	var boss: Dictionary = res.get("bossBuff", {}) if res.get("bossBuff", null) is Dictionary else {}
	return {
		"everyRounds": maxi(1, int(res.get("everyRounds", 3))),
		"playerLabel": str(player.get("label", "")),
		"bossLabel": str(boss.get("label", "")),
	}


## 敌人条目列表 → "骷髅 ×5、堕落者 ×3"。单只不带 ×n。
static func _composition(entries: Variant) -> String:
	if not (entries is Array):
		return ""
	var parts: Array = []
	for raw in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var count: int = maxi(1, int(entry.get("count", 1)))
		var name: String = _enemy_name(entry)
		parts.append(name if count <= 1 else "%s ×%d" % [name, count])
	return "、".join(PackedStringArray(parts))


## 敌人条目的显示名：先查生物表，再用内联 profile。
static func _enemy_name(entry: Dictionary) -> String:
	var mid: String = str(entry.get("monsterId", ""))
	var monster: Dictionary = ContentLoader.get_monster(mid)
	if not monster.is_empty():
		return str(monster.get("displayName", mid))
	var profile: Variant = entry.get("profile", null)
	if profile is Dictionary:
		return str((profile as Dictionary).get("displayName", mid))
	return mid