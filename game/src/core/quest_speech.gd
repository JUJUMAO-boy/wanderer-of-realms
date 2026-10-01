class_name QuestSpeech
extends RefCounted

## 委托对话模板（第三阶段 B1 / D-162）。
##
## 把 M4 委托从"接了就 status 一句、办完只念参数"补成**会说话**：按委托类型 +
## 交付分支给接 / 交付 / 放弃三段台词，并接 A1 的 `MenuStyle` 文风筛验收。
##
## 台词写进 quests.json 每型委托的 speech 段（纯数据、能改就改数据不改代码）：
##   speech.accept                     接单（缺省回退到既有 dialogue，老单不至于哑）
##   speech.deliver.<branchId>         交付：分支是按"怎么做法"给话的（交付模板）
##   speech.deliver.<combat:结局>      带战斗的委托用 combat: 前缀那几段
##   speech.abandon                    放弃 / 把名额腾给别人
##
## 台词里可写占位符 {giver}/{title}/{tier}/{branch}，由调用方按当前委托填掉——
## 于是同一型委托在八座城、不同做法上说的是各自动态的话，而不是一句死样板。
##
## 纯规则：不给字体、不碰面板、不落盘，只产 Array[String]，可无头钉测。

const STAGE_ACCEPT: String = "accept"
const STAGE_DELIVER: String = "deliver"
const STAGE_ABANDON: String = "abandon"

## 行文语境占位符。配置里写了 {title} 之类的，最终由 ctx 填掉。
const PLACEHOLDERS: Array = ["giver", "title", "tier", "branch"]


## 接单台词。本型 speech.accept 缺失或有空缺 → 回退到既有的 dialogue，
## 保证每个类型至少有一段能接上的话。
static func accept_lines(quest_type: String, ctx: Dictionary = {}) -> Array:
	var speech: Dictionary = _speech(quest_type)
	var lines: Array = _array(speech.get(STAGE_ACCEPT, []))
	if lines.is_empty():
		lines = _array(ContentLoader.get_quest_type(quest_type).get("dialogue", []))
	return _render(lines, ctx)


## 交付台词。branch_id 与 QuestSystem.complete 收的是同一种字面：普通做法就是
## branchId，带战斗的是 "combat:" + 战场结局（finish/release/capture/search/defeat）。
## 找不到对应分支就回退到交付段的任意一句，保证办完了一定说得出话。
static func deliver_lines(quest_type: String, branch_id: String, ctx: Dictionary = {}) -> Array:
	var deliver: Dictionary = _deliver(quest_type)
	var lines: Array = _array(deliver.get(branch_id, []))
	if lines.is_empty() and not deliver.is_empty():
		lines = _array(deliver[deliver.keys()[0]])
	return _render(lines, ctx)


## 放弃台词。
static func abandon_lines(quest_type: String, ctx: Dictionary = {}) -> Array:
	return _render(_array(_speech(quest_type).get(STAGE_ABANDON, [])), ctx)


## 一段台词的文风验收：拼起来过 A1 的 MenuStyle 筛。
## 作者写台词时拿它当 gates，让"这段话有没有味道"有一个自动化兜底。
static func audit(lines: Array, every_n: int = 80) -> Dictionary:
	var copy: String = "\n".join(PackedStringArray(lines))
	return MenuStyle.audit(copy, every_n)


static func _speech(quest_type: String) -> Dictionary:
	var speech: Variant = ContentLoader.get_quest_type(quest_type).get("speech", {})
	return speech if speech is Dictionary else {}


static func _deliver(quest_type: String) -> Dictionary:
	var deliver: Variant = _speech(quest_type).get(STAGE_DELIVER, {})
	return deliver if deliver is Dictionary else {}


## 只收数组字面：一段话写成单条字符串（交付大多是一句）或数组都算数，
## 配置里手滑写成其它类型则兜回空，不至炸。
static func _array(variant: Variant) -> Array:
	if variant is Array:
		return variant
	if variant is String and not (variant as String).is_empty():
		return [variant]
	return []


## 占位符填字。某键没给值就填空串（宁可空着也不留 {title} 这种技术字面漏给玩家看）。
static func _render(src: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	for raw in src:
		var line: String = str(raw)
		for key in PLACEHOLDERS:
			line = line.replace("{%s}" % key, str(ctx.get(key, "")))
		out.append(line)
	return out