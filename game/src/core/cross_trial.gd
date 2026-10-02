class_name CrossTrial
extends RefCounted

## 交叉任务战斗·迷你游戏（第三阶段 B4，D-189~D-190）。
##
## 承接 B2/B3 的"叙事纵深"落点，这一件把手感从对白挪到**一小段可交互的判定**：
## 乱入者与主线交汇时，往往不是"打一场"而是"合一段奏 / 踢一场球"（见《乱入者
## 交叉任务剧本》CX-01 诗剑镇龙、CX-03 原力问道、CX-06 足球精神）。本模块抽出
## 两类迷你判定的纯规则，供主场景在对应交会点调用：
##
##   1. **合奏/共鸣（ensemble）**：两人（或一队）共同完成一件"声气相通"的事，按
##      契合度（同源技能树 / 属性差距 / 是否各有所长）判定共鸣档，并给出该档
##      对应的效果倍率与台词倾向。
##   2. **球赛（match）**：一方挑战一方的露地球赛，按双方"踢球关键属性"算攻防，
##      产出比分、胜方与一段赛况流水（谁先进球、谁被扳平、加时是否有）。
##
## 纯规则层：不碰世界状态、不碰面板，只把"判定 + 该档效果倍率"算出来，落账与
## UI 都是调用方的事。数值全走 balance.crossTrial，可无头钉测；不引入随机依赖，
## 同一输入永远得出同一结果（契合度与攻防都由输入属性/技能派生）。

## 共鸣档位：低到高。
const BAND_MOUTH: String = "m_out_of_tune"      ## 各弹各的，没对上
const BAND_QUAVER: String = "quaver"            ## 勉强和上，时稳时飘
const BAND_RESONANCE: String = "resonance"      ## 对上了，声气互通
const BAND_RESONANCE_CRIT: String = "resonance_crit"  ## 心有灵犀，超出预期

const BAND_ORDER: Array = [
	BAND_MOUTH, BAND_QUAVER, BAND_RESONANCE, BAND_RESONANCE_CRIT,
]

## 球赛判别的结果键（写回 match 结果的 key）。
const MATCH_HOME: String = "home"
const MATCH_AWAY: String = "away"
const MATCH_DRAW: String = "draw"
const MATCH_RESULT_KEY: String = "outcome"


# --- 合奏 / 共鸣 ---

## 合奏判定。传入参与者的规格数组与平衡配置段。
##   participants: [ { name, attributes: {attrKey: value, ...},
##                     skills: {skillId: level}, leader: bool(可选) }, ... ]
##   cfg: balance.crossTrial.ensemble
## 返回 { ok, band, score, effectMilli, detail, lines }。
##   - score 是 0..100 的共鸣分（可被枚举断言，越界会钳制）。
##   - effectMilli 是该档对"结果影响力"的倍率（毫，1000 = 无加成）。
##   - detail / lines 是给面板画的一行说明与一段台词倾向。
func ensemble(participants: Array, cfg: Dictionary) -> Dictionary:
	if participants.is_empty():
		return {"ok": false, "band": BAND_MOUTH, "score": 0, "effectMilli": 0,
			"detail": "无人应和。", "lines": []}
	var score: int = _ensemble_score(participants, cfg)
	var band: String = _band_for_score(score, cfg.get("bands", []))
	var ok: bool = band != BAND_MOUTH
	var milli: int = int(cfg.get("bandEffectMilli", {}).get(band, 1000))
	return {
		"ok": ok,
		"band": band,
		"score": score,
		"effectMilli": milli,
		"detail": _ensemble_detail(band, score, cfg),
		"lines": _ensemble_lines(band, participants),
	}


## 共鸣分：三人以内都取"每人该声部的熟练度得分"之和；超过三人按 leader 权重折。
## 每人的得分 = 该人本职技能树最高熟练 / 20（0..~5 格），再来一段"同源加成"。
func _ensemble_score(participants: Array, cfg: Dictionary) -> int:
	var tree: String = str(cfg.get("tree", "soul"))
	var bodyWeight: int = int(cfg.get("bodyWeight", 0))
	var leaderWeight: int = maxi(1, int(cfg.get("leaderWeight", 1)))
	var total: int = 0
	for p in participants:
		var attrs: Dictionary = p.get("attributes", {})
		var voice: int = _voice(p, tree, cfg)
		total += voice * (leaderWeight if bool(p.get("leader", false)) else 1)
		if bodyWeight > 0:
			var body: int = int(attrs.get("constitution", 0))
			total += body * bodyWeight / 100
	var synergy: int = _synergy_bonus(participants, tree, cfg)
	return clampi(total + synergy, 0, 100)


## 一人对某个声部（技能树）的独奏得分：该树最高熟练度乘以 skillToScore，
## 顶到 voiceCap（独奏分封顶，多人合奏的厚度由人数与默契撑起来）。
func _voice(p: Dictionary, tree: String, cfg: Dictionary) -> int:
	var skills: Dictionary = p.get("skills", {})
	var best: int = 0
	for key in skills.keys():
		if not str(key).begins_with(tree + "_") and str(key) != tree:
			continue
		best = maxi(best, int(skills[key]))
	var perPoint: int = int(cfg.get("skillToScore", 1))
	var cap: int = int(cfg.get("voiceCap", 40))
	return clampi((best * perPoint), 0, cap)


## 同源加成：两人都点同一技能树时，声气不易断——给一个固定的默契分。
func _synergy_bonus(participants: Array, tree: String, cfg: Dictionary) -> int:
	if participants.size() < 2:
		return 0
	var same_tree: bool = true
	var first: int = -1
	for p in participants:
		var marker: int = _tree_marker(p, tree)
		if first < 0:
			first = marker
		elif marker <= 0 or marker != first:
			same_tree = false
			break
	if not same_tree:
		return int(cfg.get("synergyForeign", 0))
	return int(cfg.get("synergySame", 0))


## 参与者在该声部是否有"拿得出手"的标记（≥1 分返回 1，否则 0）。
func _tree_marker(p: Dictionary, tree: String) -> int:
	var skills: Dictionary = p.get("skills", {})
	for key in skills.keys():
		if str(key).begins_with(tree + "_") and int(skills[key]) > 0:
			return 1
	return 0


func _band_for_score(score: int, bands: Array) -> String:
	# bands 从高档到低档排；第一个 score>=min 的就是它应落的档（命中即返回，不要再覆盖）。
	for entry in bands:
		if score >= int(entry.get("min", 0)):
			return str(entry.get("band", BAND_MOUTH))
	return BAND_MOUTH


func _ensemble_detail(band: String, score: int, _cfg: Dictionary) -> String:
	if band == BAND_RESONANCE_CRIT:
		return "心有灵犀，声气浑然一体（共鸣 %d）" % score
	if band == BAND_RESONANCE:
		return "你们找到了同一个调子，声气互通（共鸣 %d）" % score
	if band == BAND_QUAVER:
		return "勉强和上，时有走音（共鸣 %d）" % score
	return "各弹各的，始终没对上（共鸣 %d）" % score


func _ensemble_lines(band: String, participants: Array) -> Array:
	var names: Array = []
	for p in participants:
		names.append(str(p.get("name", "")))
	var joined: String = "、".join(names)
	if band == BAND_RESONANCE_CRIT:
		return ["%s的气息落成一个音，连旁人都屏住呼吸。" % joined]
	if band == BAND_RESONANCE:
		return ["%s的应和渐渐合拍，像一场真正的共鸣。" % joined]
	if band == BAND_QUAVER:
		return ["%s勉强和上了，节拍却总有一步错。" % joined]
	return ["%s各奏各的，声气始终没碰到一块。" % joined]


# --- 球赛 ---

## 一场迷你球赛。输入双方与平衡配置段。命中判定全部由输入属性/技能派生，
## 不掷骰——同一输入恒得同一比分，便于无头钉测复现。
##   home / away: { name, attributes: {dexterity/constitution/intelligence/...},
##                  skills: {skillId: level}, morale(可选 0..100) }
##   cfg: balance.crossTrial.match
## 返回 { outcome, home, away, score: [h, a], page: String, log: Array }。
##   - outcome ∈ {home, away, draw}。
##   - score 是最终比分，page 是把比分画成一行字的串。
##   - log 是赛况流水（每段一行），面板可逐行画。
func match(home: Dictionary, away: Dictionary, cfg: Dictionary) -> Dictionary:
	var base: Dictionary = cfg.get("base", {})
	var home_strength: int = _team_strength(home, base)
	var away_strength: int = _team_strength(away, base)
	var home_goals: int = _goals(home_strength, int(base.get("homeGoals", 0)), base)
	var away_goals: int = _goals(away_strength, int(base.get("awayGoals", 0)), base)
	# 气势优势在净胜上再咬一口（非对称，强队更会读秒）——只在有人领先后追加。
	var home_morale: int = int(home.get("morale", base.get("moraleDefault", 50)))
	var away_morale: int = int(away.get("morale", base.get("moraleDefault", 50)))
	var outcome: String = MATCH_DRAW
	if home_goals != away_goals:
		var lead: int = absi(home_goals - away_goals)
		var margin_target: int = int(base.get("marginGoal", 2))
		if lead > margin_target:
			outcome = MATCH_HOME if home_goals > away_goals else MATCH_AWAY
		else:
			outcome = MATCH_HOME if (home_strength + home_morale) \
				> (away_strength + away_morale) else MATCH_AWAY
	var log: Array = _match_log(home, away, home_goals, away_goals, outcome, cfg)
	return {
		"outcome": outcome,
		"home": str(home.get("name", "")),
		"away": str(away.get("name", "")),
		"score": [home_goals, away_goals],
		"page": "%s %d : %d %s" % [str(home.get("name", "")), home_goals,
			away_goals, str(away.get("name", ""))],
		"log": log,
	}


## 一队的整体强度：敏捷主导（跑得动），成员技能树里带"球/竞技"前缀或有任意技能
## 加点再多算一格。乘一个自平衡系数后折算成"大约能进几球的量级"。
func _team_strength(side: Dictionary, base: Dictionary) -> int:
	var attrs: Dictionary = side.get("attributes", {})
	var dex: int = int(attrs.get("dexterity", 0))
	var con: int = int(attrs.get("constitution", 0))
	var intel: int = int(attrs.get("intelligence", 0))
	var skills: Dictionary = side.get("skills", {})
	var skill_bonus: int = 0
	for key in skills.keys():
		if str(key).begins_with("ball_") or str(key) == "athletics":
			skill_bonus += int(skills[key])
	return dex * int(base.get("dexWeight", 3)) + con * int(base.get("conWeight", 2)) \
		+ intel * int(base.get("intWeight", 1)) + skill_bonus


## 由强度折算进球数：把强度按「每多少点进一球」的除数压成一个小数字（差强人意时
## 仍保留 baseline 的基础进球），比分保持在卡通感量级，强度差距由 net / marginGoal
## 决定 outcome，而不是把比分打到两位数。
func _goals(strength: int, baseline: int, base: Dictionary) -> int:
	var divisor: int = maxi(1, int(base.get("strengthDiv", 150)))
	return baseline + int(floor(float(strength) / float(divisor)))


## 赛况流水：造几行能画的对白式线条（赢 / 平 / 加时）。
func _match_log(
	home: Dictionary, away: Dictionary, hg: int, ag: int, outcome: String, cfg: Dictionary
) -> Array:
	var out: Array = []
	out.append("%s 把球挑起来，难民围出一块空地。" % str(home.get("name", "")))
	out.append("哨响，球在尘土与草屑间滚了起来。")
	if int(cfg.get("extraTime", {}).get("enabled", true)) and outcome != MATCH_DRAW:
		var lead: int = absi(hg - ag)
		if lead <= int(cfg.get("extraTime", {}).get("withinGoals", 1)):
			out.append("常规时间打平，加时里 %s 连进两球锁定胜局。" % _winner_name(
				home, away, hg, ag))
	if outcome == MATCH_DRAW:
		out.append("终场哨响，双方握手，比分定格在 %d : %d。" % [hg, ag])
	else:
		out.append("终场哨响，%s 人人高喊，比分定格在 %d : %d。" % [
			_winner_name(home, away, hg, ag), hg, ag
		])
	return out


## 取比分领先方的名字（用于台词。平局不调用）。
func _winner_name(home: Dictionary, away: Dictionary, hg: int, ag: int) -> String:
	if hg > ag:
		return str(home.get("name", ""))
	return str(away.get("name", ""))