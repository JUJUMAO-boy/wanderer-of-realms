class_name FinalBattle
extends RefCounted

## 第三幕总攻战役规则层（第四阶段 D5 / D-206~D-209）。
##
## 剧本 11 节：第三幕『轮回』揭开魂之碎片与玩家身份后，深渊教团倾巢而出，玩家向
## 『轮回之轮核心』发起总攻。这是一场**多阶段遭遇**——三波敌人 + 灰袍者两阶段 BOSS。
## 本类只做四件事，全是纯规则、可无头钉测：
##
##   1. **阶段链** `stages`：把 final_battle.json 的波次与 BOSS 阶段摊成一条**有序阶段链**
##      （wave1 → wave2 → boss1 → boss2），每阶段是一场独立战斗（沿用 M29 副本/BOSS
##      那套『多阶段遭遇 = 一场接一场』的承载方式）。阶段推进与阶段切换判定是本类的核心。
##   2. **入场门槛** `gate`：主线幕次到了（`requiresAct`，缺省 cycle）且没打通过，总攻才可发起。
##   3. **阶段对手** `enemy_spec`：按阶段拼出与 EncounterSystem 对齐的对手规格。灰袍者两阶段
##      按其 `hpMult/attackMult/armorMult/selfDrainBp` 与召唤落成对手；**动摇**（`wavering`）
##      命中时，攻击 -30%、防御 -20%、二阶段不再狂暴。
##   4. **特殊机制** `resonance`（碎片共鸣，每 N 回合确定性给一方增益）、`ally_supports`
##      （已结盟的锚点 NPC 助阵）、`wavering`（揭示真相后灰袍者动摇）。
##
## 数值全走 final_battle.json（经 ContentLoader）。本类不写死系数、不碰世界几何与面板。
##
## 达成标记写 `SoulRecord.main_quest_progress["finalWon"]`（随灵魂存档、跨世保留），
## 供 D6 据以分结局。

const KIND_WAVE: String = "wave"
const KIND_BOSS: String = "boss"

## 结算后的"是否已打赢总攻"标记键（落 main_quest_progress）。
const KEY_WON: String = "finalWon"

## 总攻史书条目的权重（> Chronicle 默认门槛，保证进史书）。
const WEIGHT: int = 320


# --- 阶段链 ---

## 有序阶段链。波次按声明次序，BOSS 各阶段接在其后。返回 [stage, ...]，每项：
##   { stageId, label, kind, index, total, summary, phaseLabel, selfDrainBp }
static func stages(cfg: Dictionary) -> Array:
	var out: Array = []
	for wave in cfg.get("waves", []):
		if not (wave is Dictionary):
			continue
		out.append({
			"stageId": str((wave as Dictionary).get("stageId", "wave")),
			"label": str((wave as Dictionary).get("label", "波次")),
			"kind": KIND_WAVE,
			"summary": str((wave as Dictionary).get("summary", "")),
			"phaseLabel": "",
			"selfDrainBp": 0,
			"waveIndex": out.size(),
			"bossPhaseIndex": -1,
		})
	var boss: Dictionary = cfg.get("boss", {}) if cfg.get("boss", null) is Dictionary else {}
	var phases: Array = boss.get("phases", [])
	for i in range(phases.size()):
		var phase: Dictionary = phases[i] if phases[i] is Dictionary else {}
		out.append({
			"stageId": str(phase.get("stageId", "boss%d" % (i + 1))),
			"label": str(phase.get("label", str(boss.get("label", "灰袍者")))),
			"kind": KIND_BOSS,
			"summary": str(phase.get("summary", "")),
			"phaseLabel": str(phase.get("label", "")),
			"selfDrainBp": int(phase.get("selfDrainBp", 0)),
			"waveIndex": -1,
			"bossPhaseIndex": i,
		})
	var total: int = out.size()
	for i in range(total):
		out[i]["index"] = i
		out[i]["total"] = total
	return out


static func stage_count(cfg: Dictionary) -> int:
	return stages(cfg).size()


static func stage_at(cfg: Dictionary, index: int) -> Dictionary:
	var list: Array = stages(cfg)
	if index < 0 or index >= list.size():
		return {}
	return list[index]


## 阶段推进：给定当前状态（{"index": 已完成到第几阶段}），交回下一阶段。
## 返回 {done, index, stage, text}。done=true 表示已走完全部阶段。
static func advance(state: Dictionary, cfg: Dictionary) -> Dictionary:
	var list: Array = stages(cfg)
	var next_index: int = int(state.get("index", 0)) + 1
	if next_index >= list.size():
		return {"done": true, "index": next_index, "stage": {}, "text": "轮核之前，再没有人挡路了。"}
	var stage: Dictionary = list[next_index]
	return {
		"done": false, "index": next_index, "stage": stage,
		"text": "下一场：%s。" % str(stage.get("label", "")),
	}


## 这一阶段是不是最后一阶段。
static func is_final_stage(cfg: Dictionary, index: int) -> bool:
	var n: int = stage_count(cfg)
	return n > 0 and index == n - 1


# --- 入场门槛 ---

## 总攻能不能发起。返回 {ok, reason, actId, needAct, won}。
static func gate(soul: SoulRecord, cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {"ok": false, "reason": "没有总攻战役配置", "actId": "", "needAct": "", "won": false}
	var prog: Dictionary = {} if soul == null else soul.main_quest_progress
	var cur_act: String = ShardLine.current_act(prog)
	var need_act: String = str(cfg.get("requiresAct", ShardLine.ACT_CYCLE))
	var base: Dictionary = {
		"actId": cur_act, "needAct": need_act, "won": has_won(soul),
	}
	if has_won(soul):
		base["ok"] = false
		base["reason"] = "这场总攻你已经打过了。"
		return base
	if not _act_reached(cur_act, need_act):
		base["ok"] = false
		base["reason"] = "还不到向轮核发起总攻的时候。"
		return base
	base["ok"] = true
	base["reason"] = ""
	return base


static func _act_reached(cur_act: String, need_act: String) -> bool:
	if need_act.is_empty():
		return true
	var order: Array = ShardLine.act_order(ContentLoader.get_mainline_config())
	var need_idx: int = order.find(need_act)
	var cur_idx: int = order.find(cur_act)
	if need_idx < 0:
		return true
	return cur_idx >= need_idx


# --- 动摇（揭示真相后灰袍者动摇）---

## 灵魂之力：灵魂属性与任一魂系技能的较大者（剧本 11.3 的"灵魂系 ≥ 60"）。
static func soul_power(avatar: PlayerAvatar) -> int:
	if avatar == null:
		return 0
	var best_skill: int = 0
	for key in avatar.skills.keys():
		if str(key).begins_with("soul_") or str(key) == "soul":
			best_skill = maxi(best_skill, int(avatar.skills[key]))
	return maxi(avatar.get_attribute(PlayerAvatar.ATTR_SOUL), best_skill)


## 灰袍者会不会动摇：已揭示"灰袍者是被残魂操纵"的真相（requiresClue）且灵魂之力 ≥ requiresSoul。
## 返回 {ok, reason, soul, need, hasClue}。
static func wavering(soul: SoulRecord, avatar: PlayerAvatar, cfg: Dictionary) -> Dictionary:
	var boss: Dictionary = cfg.get("boss", {}) if cfg.get("boss", null) is Dictionary else {}
	var w: Dictionary = boss.get("wavering", {}) if boss.get("wavering", null) is Dictionary else {}
	var need: int = int(w.get("requiresSoul", 60))
	var soul_pow: int = soul_power(avatar)
	var need_clue: String = str(w.get("requiresClue", ""))
	var has_clue: bool = true
	if not need_clue.is_empty():
		var prog: Dictionary = {} if soul == null else soul.main_quest_progress
		has_clue = ShardLine.has_clue(prog, need_clue)
	var base: Dictionary = {"soul": soul_pow, "need": need, "hasClue": has_clue}
	if not has_clue:
		base["ok"] = false
		base["reason"] = "你还没弄清他到底是谁。"
		return base
	if soul_pow < need:
		base["ok"] = false
		base["reason"] = "你的灵魂之力还压不住他。"
		return base
	base["ok"] = true
	base["reason"] = ""
	return base


# --- 阶段对手规格 ---

## 拼出某阶段与会话战斗对齐的对手规格 {title, opponents:[...]}。
##   wavering_ok —— 动摇是否命中（只对 BOSS 阶段起作用）
## 波次阶段：逐条敌人乘 count；BOSS 阶段：灰袍者本体（按阶段倍率/动摇改数值）+ 本阶段召唤。
static func enemy_spec(
	cfg: Dictionary, stage: Dictionary, wavering_ok: bool = false
) -> Dictionary:
	if stage.is_empty():
		return {}
	if str(stage.get("kind", "")) == KIND_BOSS:
		return _boss_spec(cfg, stage, wavering_ok)
	return _wave_spec(cfg, stage)


static func _wave_spec(cfg: Dictionary, stage: Dictionary) -> Dictionary:
	var wave: Dictionary = {}
	if int(stage.get("waveIndex", -1)) >= 0 and int(stage["waveIndex"]) < (cfg.get("waves", []) as Array).size():
		wave = (cfg.get("waves", []) as Array)[int(stage["waveIndex"])]
	var opponents: Array = []
	for entry in wave.get("enemies", []):
		if not (entry is Dictionary):
			continue
		var resolved: Dictionary = _resolve_enemy(entry)
		var monster: Dictionary = resolved.get("monster", {})
		if monster.is_empty():
			continue
		for i in range(int(resolved.get("count", 1))):
			var suffix: String = "" if int(resolved.get("count", 1)) <= 1 else " %d" % (i + 1)
			opponents.append(_opponent_of(monster, "%s-%s-%d" % [
				str(stage.get("stageId", "wave")), str(monster.get("monsterId", "m")), i + 1
			], suffix))
	return {"title": str(stage.get("label", "")), "opponents": opponents}


static func _boss_spec(cfg: Dictionary, stage: Dictionary, wavering_ok: bool) -> Dictionary:
	var boss: Dictionary = cfg.get("boss", {}) if cfg.get("boss", null) is Dictionary else {}
	var profile: Dictionary = boss.get("profile", {}) if boss.get("profile", null) is Dictionary else {}
	if profile.is_empty():
		return {}
	var phases: Array = boss.get("phases", [])
	var pi: int = int(stage.get("bossPhaseIndex", 0))
	if pi < 0 or pi >= phases.size():
		return {}
	var phase: Dictionary = phases[pi] if phases[pi] is Dictionary else {}
	var w: Dictionary = boss.get("wavering", {}) if boss.get("wavering", null) is Dictionary else {}

	var hp: int = maxi(1, roundi(float(int(profile.get("hp", 1))) * float(phase.get("hpMult", 1.0))))
	var atk_mult: float = float(phase.get("attackMult", 1.0))
	var arm_mult: float = float(phase.get("armorMult", 1.0))
	var self_drain: int = int(phase.get("selfDrainBp", 0))
	# 动摇：攻击 -30%、防御 -20%；breakEnrage 时连二阶段的狂暴倍率与自损一并卸掉。
	if wavering_ok:
		atk_mult = float(w.get("attackMult", 0.7))
		arm_mult = float(w.get("armorMult", 0.8))
		if bool(w.get("breakEnrage", true)):
			self_drain = 0

	var boss_name: String = str(profile.get("displayName", str(boss.get("label", "灰袍者"))))
	var named: Dictionary = profile.duplicate()
	named["hp"] = hp
	named["attack"] = maxi(1, roundi(float(int(profile.get("attack", 1))) * atk_mult))
	named["armor"] = maxi(0, roundi(float(int(profile.get("armor", 0))) * arm_mult))
	var opponents: Array = [_opponent_of(named, "final-%s" % str(stage.get("stageId", "boss")), "")]
	opponents[0]["selfDrainBp"] = self_drain
	opponents[0]["isBoss"] = true
	opponents[0]["wavering"] = wavering_ok

	for entry in phase.get("summons", []):
		if not (entry is Dictionary):
			continue
		var resolved: Dictionary = _resolve_enemy(entry)
		var monster: Dictionary = resolved.get("monster", {})
		if monster.is_empty():
			continue
		for i in range(int(resolved.get("count", 1))):
			var suffix: String = "" if int(resolved.get("count", 1)) <= 1 else " %d" % (i + 1)
			opponents.append(_opponent_of(monster, "final-%s-sum-%d-%d" % [
				str(stage.get("stageId", "boss")), i + 1, opponents.size()
			], suffix))
	return {
		"title": str(stage.get("label", boss_name)),
		"opponents": opponents,
	}


## 敌人条目 → {monster, count}。先查 monsters.json，查不到再用条目内联的 profile。
static func _resolve_enemy(entry: Dictionary) -> Dictionary:
	var mid: String = str(entry.get("monsterId", ""))
	var monster: Dictionary = ContentLoader.get_monster(mid)
	if monster.is_empty():
		var inline: Variant = entry.get("profile", null)
		monster = inline if inline is Dictionary else {}
	return {"monster": monster, "count": maxi(1, int(entry.get("count", 1)))}


## 一条生物 → 对手规格（与 EncounterSystem.units_of 消费的形状对齐）。
static func _opponent_of(monster: Dictionary, unit_id: String, name_suffix: String) -> Dictionary:
	var dname: String = str(monster.get("displayName", ""))
	return {
		"unitId": unit_id,
		"name": dname + name_suffix,
		"displayName": dname,
		"category": str(monster.get("category", "")),
		"monsterId": str(monster.get("monsterId", "")),
		"threatLevel": int(monster.get("threatLevel", 1)),
		"attributes": (monster.get("attributes", {}) as Dictionary).duplicate(),
		"hp": maxi(1, int(monster.get("hp", 1))),
		"armor": maxi(0, int(monster.get("armor", 0))),
		"magicResist": maxi(0, int(monster.get("magicResist", 0))),
		"attack": maxi(1, int(monster.get("attack", 1))),
		"attackRange": int(monster.get("attackRange", 1)),
		"parleyable": false,
		"isNpc": false,
		"npcId": "",
		"isVariant": false,
	}


# --- 特殊机制 ---

## 碎片共鸣：每 everyRounds 回合为玩家或灰袍者之一提供一次增益。确定性——
## 同一回合数恒得同一结果（玩家与灰袍者按 step 奇偶交替），不掷骰，可钉测。
## 返回 {fires, side, label, hitBonus, attackBonusBp}。
static func resonance(round_number: int, cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("resonance", {}) if cfg.get("resonance", null) is Dictionary else {}
	var every: int = maxi(1, int(r.get("everyRounds", 3)))
	var flat: Dictionary = {"fires": false, "side": "", "label": "", "hitBonus": 0, "attackBonusBp": 0}
	if round_number <= 0 or round_number % every != 0:
		return flat
	var step: int = round_number / every
	var side: String = "player" if step % 2 == 1 else "boss"
	if side == "player":
		var buff: Dictionary = r.get("playerBuff", {}) if r.get("playerBuff", null) is Dictionary else {}
		return {
			"fires": true, "side": "player", "label": str(buff.get("label", "碎片提点你")),
			"hitBonus": int(buff.get("hitBonus", 0)), "attackBonusBp": 0,
		}
	var boss_buff: Dictionary = r.get("bossBuff", {}) if r.get("bossBuff", null) is Dictionary else {}
	return {
		"fires": true, "side": "boss", "label": str(boss_buff.get("label", "碎片助长灰袍者")),
		"hitBonus": 0, "attackBonusBp": int(boss_buff.get("attackBonusBp", 0)),
	}


## 可参战的锚点助阵（11.5）。瓦洛克要"三世盟约"符文（B2 结盟），
## 伊莉丝要锚点好感达档（D2）。返回 [{anchorId, label, support}]。
static func ally_supports(soul: SoulRecord, world: WorldState, cfg: Dictionary) -> Array:
	var out: Array = []
	var allies: Dictionary = cfg.get("allies", {}) if cfg.get("allies", null) is Dictionary else {}
	var varok: Dictionary = allies.get("varok", {}) if allies.get("varok", null) is Dictionary else {}
	if not varok.is_empty():
		var rune: String = str(varok.get("requiresRune", ""))
		var has_rune: bool = soul != null and soul.known_runes.has(rune)
		if not rune.is_empty() and has_rune:
			out.append({
				"anchorId": "varok", "label": str(varok.get("label", "古龙瓦洛克")),
				"support": str(varok.get("support", "")),
			})
	var elise: Dictionary = allies.get("elise", {}) if allies.get("elise", null) is Dictionary else {}
	if not elise.is_empty():
		var aid: String = str(elise.get("requiresAnchor", "elise"))
		var need: int = int(elise.get("requiresAnchorAffinity", 0))
		if soul != null and AnchorLine.affinity(soul, aid) >= need:
			out.append({
				"anchorId": aid, "label": str(elise.get("label", "返魂者伊莉丝")),
				"support": str(elise.get("support", "")),
			})
	return out


# --- 达成标记 ---

static func has_won(soul: SoulRecord) -> bool:
	if soul == null or not (soul.main_quest_progress is Dictionary):
		return false
	return bool(soul.main_quest_progress.get(KEY_WON, false))


static func mark_won(soul: SoulRecord) -> void:
	if soul == null:
		return
	if not (soul.main_quest_progress is Dictionary):
		soul.main_quest_progress = {}
	soul.main_quest_progress[KEY_WON] = true


# --- 纪年 ---

## 一场阶段战斗的史书条目。接 M16 Chronicle。
static func stage_entry(world: WorldState, stage: Dictionary, month: int, year: String) -> Dictionary:
	return {
		"kind": Chronicle.KIND_MAINLINE,
		"title": "总攻轮核·%s" % str(stage.get("label", "")),
		"cityId": "",
		"cityLabel": "",
		"detail": str(stage.get("summary", "")),
		"attribution": "主线",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}


## 总攻功成的史书条目。
static func victory_entry(world: WorldState, month: int, year: String) -> Dictionary:
	return {
		"kind": Chronicle.KIND_MAINLINE,
		"title": "总攻功成·灰袍者伏诛",
		"cityId": "",
		"cityLabel": "",
		"detail": "轮核之前再没有人挡路了。灰袍者倒下时，那道折磨了他一生的执念，终于安静了。",
		"attribution": "主线",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}