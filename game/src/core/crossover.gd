class_name Crossover
extends RefCounted

## 乱入者×城市事件的交叉任务（第四阶段 D3 / D-197~D-199）。
##
## 承接 B4 的 `CrossTrial`（合奏/共鸣 + 球赛），把两类迷你判定接到六条城市事件交会上
## （《乱入者交叉任务剧本》CX-01~CX-06）。本类只做四件事，全是纯规则、可无头钉测：
##
##   1. **入场门槛** `gate`：交会发生时，绑定的乱入者得跟玩家够熟（好感 ≥ minAffinity）。
##      本轮乱入者尚无"入队随行"，出场即"在相遇城且好感达标"——相遇城由内容校验兜底
##      （交叉任务的 cityId 必须等于该乱入者的 meetCity）。
##   2. **判定** `judge`：把玩家（化身属性/技能）与乱入者（内容里的 comerProfile）凑成
##      CrossTrial 的参与者，跑一句奏 / 一场球，得出档位（共鸣档或球赛胜负）与该档的
##      `effectMilli`。判定全由输入派生、不掷骰——同一化身同一乱入者恒得同一档。
##   3. **折算** `effective_spec`：按 `effectMilli` 把交会分支的后果（changes）折一折
##      （共鸣越高，城受益越大）；命中 `failKeys` 的档改用分支的 `fail` 套后果（如龙被激怒），
##      且不再折——失败就是失败。
##   4. **结算** `resolve`：判定 + 折算，交出一份与事件分支同形状的 spec，供 EventSystem
##      复用既有的 `_apply` 落账通路。
##
## 数值：判定系数走 `balance.crossTrial`（B4 同一份），交会自身的门槛/档位/后果全在
## crossovers.json。本类不写死任何系数、不碰世界、不碰面板。

const TRIAL_ENSEMBLE: String = "ensemble"
const TRIAL_MATCH: String = "match"

## 球赛档位换算：净胜每多一球，效力多这一点（毫），封顶 matchMillisMax。
const MATCH_MILLI_PER_GOAL: int = 150
const MATCH_MILLI_MAX: int = 500

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"


# --- 入场门槛 ---

## 交会能不能发生：绑定的乱入者好感是否已到 minAffinity。
## 返回 {ok, reason, affinity, need}。查不到该交叉任务 → ok=false。
static func gate(world: WorldState, template_id: String) -> Dictionary:
	var cfg: Dictionary = ContentLoader.get_crossover(template_id)
	if cfg.is_empty():
		return {"ok": false, "reason": "没有这条交会", "affinity": 0, "need": 0}
	return gate_for(world, cfg)


static func gate_for(world: WorldState, cfg: Dictionary) -> Dictionary:
	var comer_id: String = str(cfg.get("comerId", ""))
	var need: int = int(cfg.get("minAffinity", 0))
	var affinity: int = ComerFavor.affinity(world, comer_id)
	if affinity < need:
		return {
			"ok": false,
			"reason": "%s还没把你当能并肩的人。" % _comer_name(comer_id),
			"affinity": affinity,
			"need": need,
		}
	return {"ok": true, "reason": "", "affinity": affinity, "need": need}


# --- 判定 ---

## 跑一次交会判定。返回：
##   {ok, kind, key, label, detail, scoreText, effectMilli, lines, failed}
##   - kind ∈ {ensemble, match}；key 是共鸣档名或球赛胜负（home/away/draw）。
##   - label/detail 取自该分支的档位表（写给人看的一句）。
##   - scoreText 是判定的原始说明（"共鸣 62" / "比分 3 : 1"）。
##   - failed：这一档是否落在分支的 failKeys 里。
static func judge(
	world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, branch: Dictionary
) -> Dictionary:
	var trial: Dictionary = branch.get("trial", {})
	if not (trial is Dictionary):
		trial = {}
	var kind: String = str((trial as Dictionary).get("kind", TRIAL_ENSEMBLE))
	var balance: Dictionary = ContentLoader.get_balance_section("crossTrial")
	var raw: Dictionary = (
		_judge_match(avatar, cfg, balance) if kind == TRIAL_MATCH
		else _judge_ensemble(avatar, cfg, trial, balance)
	)
	var key: String = str(raw.get("key", ""))
	var tier: Dictionary = tier_of(branch, key)
	var fail_keys: Array = branch.get("failKeys", [])
	return {
		"ok": bool(raw.get("ok", false)),
		"kind": kind,
		"key": key,
		"label": str(tier.get("label", key)),
		"detail": str(tier.get("detail", "")),
		"scoreText": str(raw.get("scoreText", "")),
		"effectMilli": int(raw.get("effectMilli", 1000)),
		"lines": raw.get("lines", []),
		"failed": fail_keys.has(key),
	}


## 一句奏：玩家 + 乱入者凑成 CrossTrial 的参与者，跑共鸣判定。
static func _judge_ensemble(
	avatar: PlayerAvatar, cfg: Dictionary, trial: Dictionary, balance: Dictionary
) -> Dictionary:
	var participants: Array = _participants(avatar, cfg, trial)
	var result: Dictionary = CrossTrial.new().ensemble(participants, balance.get("ensemble", {}))
	return {
		"ok": bool(result.get("ok", false)),
		"key": str(result.get("band", "")),
		"scoreText": str(result.get("detail", "")),
		"effectMilli": int(result.get("effectMilli", 1000)),
		"lines": result.get("lines", []),
	}


## 一场球：乱入者队为 home、玩家队为 away，跑球赛判定。效力倍率按净胜球换算。
static func _judge_match(
	avatar: PlayerAvatar, cfg: Dictionary, balance: Dictionary
) -> Dictionary:
	var home: Dictionary = _match_side(avatar, cfg.get("comerProfile", {}),
		_comer_name(str(cfg.get("comerId", ""))) + "队")
	var away: Dictionary = _match_side(avatar, {}, "你的队")
	var result: Dictionary = CrossTrial.new().match(home, away, balance.get("match", {}))
	var key: String = str(result.get("outcome", CrossTrial.MATCH_DRAW))
	var score: Array = result.get("score", [0, 0])
	var margin: int = absi(int(score[0]) - int(score[1])) if score.size() >= 2 else 0
	var milli: int = 1000 + mini(MATCH_MILLI_MAX, margin * MATCH_MILLI_PER_GOAL)
	return {
		"ok": true,
		"key": key,
		"scoreText": str(result.get("page", "")),
		"effectMilli": milli,
		"lines": result.get("log", []),
	}


## 参与者数组。[玩家, 乱入者]；领奏按分支的 trial.leader 定（缺省乱入者领）。
static func _participants(avatar: PlayerAvatar, cfg: Dictionary, trial: Dictionary) -> Array:
	var leader: String = str(trial.get("leader", "comer"))
	var comer_id: String = str(cfg.get("comerId", ""))
	var out: Array = [_player_side(avatar, leader == "player")]
	out.append(_comer_side(cfg, leader != "player"))
	return out


static func _player_side(avatar: PlayerAvatar, is_leader: bool) -> Dictionary:
	var attrs: Dictionary = {} if avatar == null else avatar.attributes.duplicate()
	var skills: Dictionary = {} if avatar == null else avatar.skills.duplicate()
	return {"name": "你", "attributes": attrs, "skills": skills, "leader": is_leader}


static func _comer_side(cfg: Dictionary, is_leader: bool) -> Dictionary:
	var profile: Variant = cfg.get("comerProfile", {})
	var p: Dictionary = profile if profile is Dictionary else {}
	return {
		"name": _comer_name(str(cfg.get("comerId", ""))),
		"attributes": _dict_copy(p.get("attributes", {})),
		"skills": _dict_copy(p.get("skills", {})),
		"morale": int(p.get("morale", 50)),
		"leader": is_leader,
	}


## 球赛一侧：用 Given 的 profile 属性/技能；玩家侧给空 profile（用化身）。
static func _match_side(avatar: PlayerAvatar, profile: Variant, name: String) -> Dictionary:
	var p: Dictionary = profile if profile is Dictionary else {}
	var attrs: Dictionary = _dict_copy(p.get("attributes", {}))
	var skills: Dictionary = _dict_copy(p.get("skills", {}))
	if attrs.is_empty() and avatar != null:
		attrs = avatar.attributes.duplicate()
	if skills.is_empty() and avatar != null:
		skills = avatar.skills.duplicate()
	return {
		"name": name,
		"attributes": attrs,
		"skills": skills,
		"morale": int(p.get("morale", 50)),
	}


## 显式判型地复制一份字典（配置里该字段缺席/写错类型时给空字典，不炸）。
static func _dict_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate() if value is Dictionary else {}


# --- 折算 ---

## 把判定结果折成交会分支的后果 spec。返回 {} 表示这条分支没有 trial。
##   {branchId, label, detail, changes, reputation, karma, flags, resolved, comerAffinity,
##    trialKey, trialLabel, trialDetail, trialScore, trialFailed, effectMilli}
static func effective_spec(cfg: Dictionary, branch: Dictionary, judged: Dictionary) -> Dictionary:
	if not branch.has("trial"):
		return {}
	var failed: bool = bool(judged.get("failed", false))
	# 命中失败档且分支写了 fail 套 → 用 fail 套（不再折）；否则用分支本身并按其档位倍率折。
	var base: Dictionary = branch
	var fold_milli: int = 1000
	if failed and branch.get("fail", null) is Dictionary:
		base = branch.get("fail", {})
	else:
		fold_milli = int(judged.get("effectMilli", 1000))
	var changes: Dictionary = _fold_changes(base.get("changes", {}), fold_milli)
	return {
		"branchId": str(branch.get("branchId", "")),
		"label": str(branch.get("label", "")),
		"detail": str(judged.get("detail", "")),
		"changes": changes,
		"reputation": int(base.get("reputation", 0)),
		"karma": int(base.get("karma", 0)),
		"flags": base.get("flags", []),
		"resolved": bool(base.get("resolved", true)),
		"comerAffinity": int(branch.get("comerAffinity", 0)),
		"trialKey": str(judged.get("key", "")),
		"trialLabel": str(judged.get("label", "")),
		"trialDetail": str(judged.get("detail", "")),
		"trialScore": str(judged.get("scoreText", "")),
		"trialFailed": failed,
		"effectMilli": int(judged.get("effectMilli", 1000)),
	}


## 按千分位倍率折一组维度增量。折到 0 但有原值时保留一个最小刻度（±1）——
## "有点用"和"毫无变化"不该在界面上混为一谈。
static func _fold_changes(changes: Variant, milli: int) -> Dictionary:
	var out: Dictionary = {}
	if not (changes is Dictionary):
		return out
	for dimension in (changes as Dictionary):
		var value: int = int((changes as Dictionary)[dimension])
		if value == 0:
			continue
		var folded: int = int(round(float(value) * float(milli) / 1000.0))
		if folded == 0:
			folded = 1 if value > 0 else -1
		out[str(dimension)] = folded
	return out


# --- 结算 ---

## 判定 + 折算。返回 {ok, judgement, spec, errorCode, error}。
## 交会能否发生（gate）由调用方先判——此处只负责"给定交会分支，算出它的后果"。
static func resolve(
	world: WorldState, avatar: PlayerAvatar, cfg: Dictionary, branch: Dictionary
) -> Dictionary:
	if cfg.is_empty():
		return {"ok": false, "judgement": {}, "spec": {},
			"errorCode": ERROR_NOT_FOUND, "error": "没有这条交会"}
	if not branch.has("trial"):
		return {"ok": false, "judgement": {}, "spec": {},
			"errorCode": ERROR_NOT_FOUND, "error": "这条分支不是交会分支"}
	var judged: Dictionary = judge(world, avatar, cfg, branch)
	var spec: Dictionary = effective_spec(cfg, branch, judged)
	return {"ok": true, "judgement": judged, "spec": spec,
		"errorCode": ERROR_NONE, "error": ""}


# --- 内容查表 ---

static func tier_of(branch: Dictionary, key: String) -> Dictionary:
	for tier in branch.get("tiers", []):
		if str(tier.get("key", "")) == key:
			return tier
	return {}


static func _comer_name(comer_id: String) -> String:
	var cfg: Dictionary = ContentLoader.get_comer(comer_id)
	return str(cfg.get("displayName", "那位乱入者"))