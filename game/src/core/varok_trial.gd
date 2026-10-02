class_name VarokTrial
extends RefCounted

## 古龙瓦洛克的三幕试炼（第三阶段 B2，D-185~D-186）。
##
## 这是"单局目标的支点"：外面的主循环让玩家在城里讨生活，冰川深处这位不教人、
## 只考验的古龙，给这场讨一个**配不配得上龙语**的总问。它不放常驻面板——复用
## `VIEW_EVENT` 的抉择形态（同 D-90 那条惯例），会话不落盘，每次进冰川现算。
##
## 本文件只做三件事：**前置判定**（gate，够不够格叩门）、**对话树推进**
## （choose：在你当前这一叩的台词下选一个应答，结转下一步/终局）、**落账**
## （把诱惑的代价真正结到化身身上）。台词是瓦洛克的锚点对白（他是"单局提问的
## 人"不是"接活的板"），所以写死在这、过 A1 文风闸；数值全部走 balance.varok，
## 详情见脚本《轮回之书-古龙瓦洛克试炼脚本.md》。
##
## 纯规则：不改世界、不碰面板、不落盘（只动传入的 avatar），可无头钉测。
## 两个口子都对"你是谁"负责：gate 问门槛，choose 问诚实——撒谎会被识破。

const STAGE_ENTRY: String = "entry"
const STAGE_ACT1: String = "act1"
const STAGE_ACT1_FORCE: String = "act1_force"
const STAGE_ACT2: String = "act2"
const STAGE_ACT3: String = "act3"
const STAGE_ACT3_LIE: String = "act3_lie"

const OUTCOME_LEAVE: String = "leave"   ## 呼救/宣告离开，不算失败（脚本 4.1/5.2）
const OUTCOME_FAIL: String = "fail"     ## 嘴硬到底的终局
const OUTCOME_ALLIANCE: String = "alliance"  ## 结盟成功（脚本 5.1）

const FLAG_GREEDY: String = "greedy"    ## 第二幕吞了龙魂
const FLAG_EVIL: String = "evil"        ## 第二幕触了永恒者（进恶面分支）
const FLAG_RESPECTED: String = "respected"  ## 第二幕拒绝了两重诱惑

const KEY_ACT1_EVAL: String = "act1Eval"  ## 第一幕力竭点的评价档位（倔/稳）
const KEY_TEMP: String = "temp"           ## 第一幕体温计数（限时参数，脚本 4.1）


## 台词段（瓦洛克视角）。行文过 MenuStyle.audit（A1 文风闸）。
const _INTRO_LINES: Array = [
	"冰川最深处没有风雪，只有死一般的寂静。青铜色的古龙盘踞在冰壁之间，一只眼半阖。",
	"瓦洛克：又一个来求龙语的凡人。",
	"瓦洛克：龙语不是被授予的，是被证明的。你以凡人之躯走到这里，只证明了你还能走。",
]
const _ACT1_INTRO: Array = [
	"瓦洛克吹出一口寒气，风雪将你封进一片幻境。体温顺着骨头往下掉，前方有三条隐约的路。",
]
const _ACT1_PATH: Array = [
	"风雪里三条路，你选。限时——体温正一寸寸抽走。",
]
const _ACT1_FORCE: Array = [
	"风雪最深处，你的腿像灌了铅，眼前只剩最后一段路。这是力竭点。",
]
const _ACT1_LEAVE_LINES: Array = [
	"瓦洛克：回去吧，你不属于这里。下回雪再大些，我会认得你这张脸。",
]
const _ACT2_INTRO: Array = [
	"风雪散去，龙魂的残影在虚空中浮动——你看见了前世的一角，以及被封印的『永恒者』的虚影。",
	"瓦洛克：在这里，选。别急着答，我听着。",
]
const _ACT2_EVAL_WILLFUL: Array = [
	"瓦洛克：第一幕，你的血还没冷透。不错。",
]
const _ACT2_EVAL_STEADY: Array = [
	"瓦洛克：第一幕，你懂得在风雪里停下歇脚。稳当。",
]
const _ACT2_ABSORB_LINES: Array = [
	"你把那枚完整的龙魂吞了下去。热流顺着脊柱涨满四肢，你又变得更强了——只是那股灼烫，也不像白来的。",
]
const _ACT2_ETERNAL_LINES: Array = [
	"你伸出手，指尖触到那位『永恒者』的碎片。无数个世纪的无声低语涌进来，像一只冰凉的手，在你灵魂上掐了一把。",
]
const _ACT2_REFUSE_LINES: Array = [
	"龙魂在眼前浮动，永恒者在耳畔低语。你转过身，把它们都留在身后。",
	"瓦洛克：你没有被力量吞掉。难得。",
]
const _ACT3_QUESTION: Array = [
	"幻境消散，古龙起身，龙翼遮天。他俯视着你。",
	"瓦洛克：你说，龙语。用你的话回答我——你为何要学它？",
]
const _ACT3_POWER: Array = [
	"瓦洛克：诚实。力量值得被追求——只要你看得清它的价签。",
]
const _ACT3_GUARD: Array = [
	"瓦洛克：守护会让你软弱，也会让你坚硬。看来你已经尝过其中一样了。",
]
const _ACT3_CYCLE: Array = [
	"瓦洛克：那么，你与那位永恒者，有何区别？",
]
const _ACT3_UNKNOWING: Array = [
	"瓦洛克：不知道，却来了。这最接近龙语的回答。",
]
const _LIE_EXPOSED: Array = [
	"瓦洛克：你撒谎。你的灵魂带着贪婪的锈味。",
]
const _ALLIANCE_LINES: Array = [
	"瓦洛克：我以古龙之名，与你结为盟友。龙不记短，记长——这份盟约会陪你走过三世。",
]


## 前置判定。够格返回 {ok:true}；不够格给一句不了题的口吻。
## 门槛见脚本 2 节：未半龙（龙化 < dragonizationMax）+ 灵魂系或任一元素技能 ≥ skillMin。
static func gate(avatar: PlayerAvatar) -> Dictionary:
	if avatar == null:
		return {"ok": false, "reason": "你还没站到冰川最深处。"}
	var cfg: Dictionary = ContentLoader.get_balance_section("varok")
	if avatar.dragonization >= int(cfg.get("dragonizationMax", 1)):
		return {"ok": false, "reason": "你已经是半个龙种了。瓦洛克不考验已沾龙血的人。"}
	if not _has_language_mastery(avatar, cfg):
		return {"ok": false, "reason": "瓦洛克只唤来懂『语言的重量』的人——让灵魂，或任一元素之境，先长出些功力。"}
	return {"ok": true}


## 判断"灵魂系或任一元素技能 ≥ 门槛"（脚本 2 节）。元素树取 balance.combat.
## elementCycle 四系，与战斗模块同源；灵魂树取 PlayerAvatar.ATTR_SOUL。
static func _has_language_mastery(avatar: PlayerAvatar, cfg: Dictionary) -> bool:
	var min_skill: int = int(cfg.get("skillMin", 0))
	var element_trees: Array = ContentLoader.get_balance_section("combat").get("elementCycle", [])
	var soul_tree: String = PlayerAvatar.ATTR_SOUL
	for skill_id in avatar.skills:
		if int(avatar.skills[skill_id]) < min_skill:
			continue
		var tree: String = _tree_of(str(skill_id))
		if tree == soul_tree or element_trees.has(tree):
			return true
	return false


## skillId → 技能树（skills.json 的 tree 字段；找不到当树作者自己叫 skillId）。
static func _tree_of(skill_id: String) -> String:
	var skill: Dictionary = ContentLoader.get_skill(skill_id)
	if not skill.is_empty():
		return str(skill.get("tree", ""))
	return ""


## 新建一场会话。会话本身不落盘——只由 main 持有推进，读完即弃。
## 体温从 tempMax 起算（第一幕的限时计数），每选一条路径按 tempDrop 往下掉。
static func new_session() -> Dictionary:
	var act1: Dictionary = ContentLoader.get_balance_section("varok").get("act1", {})
	return {
		"stage": STAGE_ENTRY,
		"flags": {},
		KEY_TEMP: int(act1.get("tempMax", 100)),
		KEY_ACT1_EVAL: "",
	}


## 当前这一叩的台词与可选的应答。返回对话面板（VarokPanel）消费的那副样子：
## title（幕名）、lines（逐行台词）、branches（可选应答，label 是玩家能说的话、
## effect 是选了之后会发生什么的预览）、tempLabel（第一幕的体温状态）。
static func node_view(session: Dictionary) -> Dictionary:
	var stage: String = str(session.get("stage", ""))
	return {
		"title": _title_for(stage),
		"lines": _lines_for(stage, session),
		"branches": _branches_for(stage, session),
		"stage": stage,
		"temp": int(session.get(KEY_TEMP, 0)),
		"tempLabel": _temp_label(stage, session),
		"act1Eval": str(session.get(KEY_ACT1_EVAL, "")),
	}


## 选一个应答。把这一选的代价/收获落账到 avatar，返回新的会话（沿用同一份
## session，免得 main 手忙脚乱），外加一句要不要收场的提示。
## 返回 {ok, session, outcome(可空), notice, finish(bool)}。
static func choose(avatar: PlayerAvatar, session: Dictionary, choice_id: String) -> Dictionary:
	if avatar == null or session.is_empty():
		return {"ok": false, "notice": "还没站到瓦洛克面前。"}
	var old_stage: String = str(session.get("stage", ""))
	var next: Dictionary = _transition(old_stage, choice_id, session)
	var new_session: Dictionary = session.duplicate(true)
	new_session["flags"] = (session.get("flags", {}) as Dictionary).duplicate(true)
	# 先按"玩家在哪个幕做出的选择"落账，再结转下一幕——效果永远按旧幕判。
	_apply_effects(avatar, new_session, old_stage, choice_id)
	new_session["stage"] = str(next.get("stage", old_stage))
	var finished: bool = bool(next.get("finish", false))
	# 结盟成功：把三幕熬出来的龙语之约落账到化身（脚本 5.1）。习符文与跨世
	# 盟友都是幂等的——重复结盟不会重复习，回响龙魂可以再攒。
	if finished and str(next.get("outcome", "")) == OUTCOME_ALLIANCE:
		_apply_alliance_reward(avatar)
	return {
		"ok": true,
		"session": new_session,
		"outcome": next.get("outcome", ""),
		"notice": str(next.get("notice", "")),
		"finish": finished,
	}


## stage → 台词。力竭点/回响等的后续评价台词按会话里的标志拼。
static func _lines_for(stage: String, session: Dictionary) -> Array:
	var flags: Dictionary = session.get("flags", {})
	match stage:
		STAGE_ENTRY:
			return _INTRO_LINES
		STAGE_ACT1:
			return _ACT1_INTRO + _ACT1_PATH
		STAGE_ACT1_FORCE:
			return _ACT1_FORCE
		STAGE_ACT2:
			var eval_lines: Array = []
			match str(session.get(KEY_ACT1_EVAL, "")):
				"倔":
					eval_lines = _ACT2_EVAL_WILLFUL
				"稳":
					eval_lines = _ACT2_EVAL_STEADY
			return eval_lines + _ACT2_INTRO
		STAGE_ACT3:
			if bool(flags.get(FLAG_EVIL, false)):
				return ["幻境惊醒。古龙睁开另一只眼，里面有与方才不同的冷意。"] + _ACT3_QUESTION
			return _ACT3_QUESTION
		STAGE_ACT3_LIE:
			return _LIE_EXPOSED
	return []


## stage → 标题（对话面板的幕名）。
static func _title_for(stage: String) -> String:
	match stage:
		STAGE_ENTRY:
			return "龙骸冰川最深处"
		STAGE_ACT1:
			return "第一幕 · 寒霜"
		STAGE_ACT1_FORCE:
			return "第一幕 · 力竭点"
		STAGE_ACT2:
			return "第二幕 · 回响"
		STAGE_ACT3:
			return "第三幕 · 直面我"
		STAGE_ACT3_LIE:
			return "第三幕 · 恶面"
	return "瓦洛克试炼"


## stage → 可选应答（label 是玩家能说的话，effect 是选了之后会发生什么的预览）。
static func _branches_for(stage: String, session: Dictionary) -> Array:
	match stage:
		STAGE_ENTRY:
			return [
				{"choiceId": "ask", "label": "我是来学龙语的。", "effect": "他注视你片刻，呼出一口寒气。"},
				{"choiceId": "leave", "label": "我不配，我走。", "effect": "他合上眼，风雪送你出去。"},
			]
		STAGE_ACT1:
			return [
				{"choiceId": "shortcut", "label": "抄近路——从冰缝穿过去。", "effect": "最快，但体温掉得最狠。"},
				{"choiceId": "ridge", "label": "沿山脊走。", "effect": "折中，暴露在风暴里。"},
				{"choiceId": "valley", "label": "绕行避风谷。", "effect": "最稳，却磨得最久。"},
			]
		STAGE_ACT1_FORCE:
			return [
				{"choiceId": "bite", "label": "咬牙坚持，硬走过去。", "effect": "以命相搏，最不取巧。"},
				{"choiceId": "fire", "label": "停下，生火歇口气。", "effect": "稳当，他却会记下你回过一次头。"},
				{"choiceId": "help", "label": "放弃，呼救。", "effect": "他解除幻境，送你这句：回去吧。"},
			]
		STAGE_ACT2:
			return [
				{"choiceId": "absorb", "label": "把龙魂吞下去。", "effect": "全属性 +%d，习得一个符文；龙化 +%d。" % [
					_int(_act2(), "soulAttrBonus"), _int(_act2(), "soulDragonizationGain")]},
				{"choiceId": "eternal", "label": "触碰『永恒者』的碎片。", "effect": "善恶 -%d，这条路通向他最冷的目光。" % [
					_int(_act2(), "eternalKarmaLoss")]},
				{"choiceId": "refuse", "label": "拒绝两者，转身离开幻境。", "effect": "什么也不拿，他罕见的微微颔首。"},
			]
		STAGE_ACT3:
			return [
				{"choiceId": "power", "label": "为了力量。", "effect": "若你在第二幕承认过贪婪，他点头：诚实。"},
				{"choiceId": "guard", "label": "为了守护一个人、一座城。", "effect": "他沉默片刻，似有所感。"},
				{"choiceId": "cycle", "label": "为了不被轮回摆布。", "effect": "他眼神一紧：那你与永恒者，有何区别？"},
				{"choiceId": "unknowing", "label": "我不知道，只是觉得必须来。", "effect": "他最满意的回答。"},
			]
		STAGE_ACT3_LIE:
			return [
				{"choiceId": "admit", "label": "承认：我说了谎。", "effect": "他给你第二次机会——重走一遍试炼。"},
				{"choiceId": "stubborn", "label": "嘴硬：我没骗你。", "effect": "他发怒，将你击退；试炼失败。"},
			]
	return []


## stage + choiceId → 下一步。finish=true 表示这是本次会话的最后一叩。
## 撒谎判定放在这里：第二幕吞过龙魂却答非「为了力量」，就是骗——进识破分支，
## 不直接结盟（脚本 4.3）。
static func _transition(stage: String, choice_id: String, session: Dictionary) -> Dictionary:
	var flags: Dictionary = session.get("flags", {})
	match stage:
		STAGE_ENTRY:
			if choice_id == "leave":
				return {"stage": STAGE_ENTRY, "finish": true, "outcome": OUTCOME_LEAVE,
					"notice": "瓦洛克合上眼，风雪送你离开冰川。"}
			return {"stage": STAGE_ACT1, "notice": "他呼出一口寒气，第一幕开始。"}
		STAGE_ACT1:
			return {"stage": STAGE_ACT1_FORCE, "notice": "你往前走，体温一路抽走，终于歇了脚。"}
		STAGE_ACT1_FORCE:
			if choice_id == "help":
				return {"stage": STAGE_ACT1_FORCE, "finish": true, "outcome": OUTCOME_LEAVE,
					"notice": "".join(PackedStringArray(_ACT1_LEAVE_LINES))}
			return {"stage": STAGE_ACT2, "notice": "第一幕过去，血还没冷透。"}
		STAGE_ACT2:
			return {"stage": STAGE_ACT3, "notice": "第二幕过去，他望着你走回他面前。"}
		STAGE_ACT3:
			if bool(flags.get(FLAG_GREEDY, false)) and choice_id != "power":
				return {"stage": STAGE_ACT3_LIE,
					"notice": "他察觉到你灵魂里的贪婪锈味——你撒谎了。"}
			return {"stage": STAGE_ACT3, "finish": true, "outcome": OUTCOME_ALLIANCE,
				"notice": _alliance_notice(choice_id)}
		STAGE_ACT3_LIE:
			if choice_id == "admit":
				return {"stage": STAGE_ACT1_FORCE, "notice": "他收回怒意：退回去，重走一遍。"}
			return {"stage": STAGE_ACT3_LIE, "finish": true, "outcome": OUTCOME_FAIL,
				"notice": "他发怒，将你击退出冰川——你眼前一花，人已到了冰崖外。"}
	return {"stage": stage}


## 结盟时按第三幕的回答给一句收尾台词（脚本 4.3 表格里的反应）。
static func _alliance_notice(choice_id: String) -> String:
	match choice_id:
		"power":
			return str(_ACT3_POWER[0])
		"guard":
			return str(_ACT3_GUARD[0])
		"cycle":
			return str(_ACT3_CYCLE[0])
	return str(_ACT3_UNKNOWING[0])


## 把选择落账到化身。只改传入的 avatar（跨世与否由字段本身上），不写世界。
## old_stage 是玩家做出这一选时所在的幕——效果永远按旧幕判，避免结转后误判。
static func _apply_effects(
	avatar: PlayerAvatar, session: Dictionary, old_stage: String, choice_id: String
) -> void:
	var flags: Dictionary = session.get("flags", {})
	match old_stage:
		STAGE_ACT1:
			# 第一幕的限时参数：体温按所选路径的 tempDrop 往下掉（balance.act1.tempDrop）
			var drop: int = int(_act1().get("tempDrop", {}).get(choice_id, 0))
			session[KEY_TEMP] = maxi(0, int(session.get(KEY_TEMP, 0)) - drop)
		STAGE_ACT1_FORCE:
			# 力竭点的评价档位（脚本 4.1）：咬牙=倔、生火=稳，第三幕/评价用它
			if choice_id == "bite":
				session[KEY_ACT1_EVAL] = str(_act1().get("evalWillful", "倔"))
			elif choice_id == "fire":
				session[KEY_ACT1_EVAL] = str(_act1().get("evalSteady", "稳"))
		STAGE_ACT2:
			if choice_id == "absorb":
				var act2: Dictionary = _act2()
				var bonus: int = int(act2.get("soulAttrBonus", 0))
				for attr in PlayerAvatar.ALL_ATTRIBUTES:
					avatar.set_attribute(attr, avatar.get_attribute(attr) + bonus)
				avatar.dragonization = clampi(
					avatar.dragonization + int(act2.get("soulDragonizationGain", 0)), 0, 100)
				var rune: String = str(act2.get("soulRune", ""))
				if not rune.is_empty() and not avatar.known_runes.has(rune):
					avatar.known_runes.append(rune)
				flags[FLAG_GREEDY] = true
			elif choice_id == "eternal":
				avatar.set_karma(avatar.karma - int(_act2().get("eternalKarmaLoss", 0)))
				flags[FLAG_EVIL] = true
			else:
				flags[FLAG_RESPECTED] = true
		STAGE_ACT3_LIE:
			# 承认过：重走一趟不带旧账（脚本 5.2），体温也重新起算
			if choice_id == "admit":
				flags[FLAG_GREEDY] = false
				session[KEY_TEMP] = int(_act1().get("tempMax", 100))
	session["flags"] = flags


## 结盟奖励落账（脚本 5.1）：习得龙语符文（幂等）、回响龙魂 +dragonSoulGain、
## 追加『三世盟约』跨世盟友符文（幂等，会随灵魂记忆转生携带）。
static func _apply_alliance_reward(avatar: PlayerAvatar) -> void:
	var reward: Dictionary = ContentLoader.get_balance_section("varok").get("reward", {})
	for rune in reward.get("runeGranted", []):
		var rune_id: String = str(rune)
		if not rune_id.is_empty() and not avatar.known_runes.has(rune_id):
			avatar.known_runes.append(rune_id)
	avatar.dragon_soul += int(reward.get("dragonSoulGain", 0))
	var alliance_rune: String = str(reward.get("allianceRune", ""))
	if not alliance_rune.is_empty() and not avatar.known_runes.has(alliance_rune):
		avatar.known_runes.append(alliance_rune)


## 第一幕体温状态的一行字。第一幕两幕给体温计数（限时参数的可见面），
## 力竭点之后的幕让位给剧情。
static func _temp_label(stage: String, session: Dictionary) -> String:
	var temp: int = int(session.get(KEY_TEMP, 0))
	if stage == STAGE_ACT1 or stage == STAGE_ACT1_FORCE:
		return "体温 %d" % temp
	return ""


static func _act1() -> Dictionary:
	return ContentLoader.get_balance_section("varok").get("act1", {})


static func _act2() -> Dictionary:
	return ContentLoader.get_balance_section("varok").get("act2", {})


static func _int(d: Dictionary, key: String) -> int:
	return int(d.get(key, 0))
