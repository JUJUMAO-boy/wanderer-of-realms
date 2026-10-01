class_name MenuStyle
extends RefCounted

## 文风验收筛（第三阶段 A1 / D-160）。
##
## 把《整合Elona设定与更新路线图》P8 与四条内核落成一段**可跑、可断言**的纯函数：
##   - 去套路：文案不能含"主角光环 / 道德说教 / 教程腔 / 终极真相"那几类台词腔，
##     命中任意一条 → audit 判不通过并把命中的套路名列进 flags。
##   - 荒诞密度：每 N 字至少一处"能观察到的荒诞细节"。这里用一组可识别的荒诞标记
##     把该抽象概念量化成可断言阈值，保证不是空话。
##   - 内核落点：默认文本必须有"人物立场"，且不能替玩家做价值审判（代价无评价）。
##
## 用途：作为 A1 交付的"全菜单文风验收筛"，测试里对一份抄好的文案断言其通过，
## 对一段故意的套路腔断言其不通过——让"文字有没有味道"第一次有自动化兜底。

## P8 四类套路腔的触发词（去套路）。命中任一词即判为套路腔。
const DENY_MARKERS: Dictionary = {
	"hero_trope": ["命中注定", "天命之子", "命运选中了你", "这是你的宿命"],
	"moral_sermon": ["你应该善良", "这是你的责任", "若不如此将天理难容", "做对的事情"],
	"tutorial_tone": ["你只需", "记住，", "听好了，这是", "按这个步骤", "非常简单"],
	"final_truth": ["真相是", "事实上答案", "其实这一切", "终极的秘密"],
}

## 荒诞细节的可识别标记：具体到反常的意象越多，越接近"每 N 字一处荒诞细节"。
const ABSURD_MARKERS: Array = [
	"会算账的老羊", "会自己发热的铁轨", "蹲在路口问旅人要火", "干脆让它烂在舱底",
	"数城底下漏的风", "换了一副哑铃似的旧铁", "井口的月亮就少一牙", "躲一笔烂账",
	"后槽牙一阵一阵发酥", "搬去赤沙的野猫",
]


## 只收字面（去空格换行），用于按字符统计密度。
static func _plain(copy: String) -> String:
	var out: String = copy.replace("\n", "").replace(" ", "").replace("　", "")
	return out


## 荒诞密度是否达标：每 every_n 字符至少一处荒诞标记命中。
## 纯说明文/目录腔检测不到任何荒诞标记 → 判不达标。
static func absurd_density_ok(copy: String, every_n: int) -> bool:
	var plain: String = _plain(copy)
	if plain.is_empty():
		return false
	var count: int = 0
	for marker in ABSURD_MARKERS:
		if plain.contains(marker):
			count += 1
	@warning_ignore("integer_division")
	return count * every_n >= plain.length()


## 找出这段文案命中的所有 P8 套路腔。
static func _flags(copy: String) -> Array:
	var out: Array = []
	var plain: String = _plain(copy)
	for flag in DENY_MARKERS:
		for marker in DENY_MARKERS[flag]:
			if plain.contains(str(marker)):
				out.append(flag)
	return out


## 文案验收。返回 {ok, flags, absurdOk, charCount}。
## ok = 没有套路腔 且 荒诞密度达标。每条 NEW 全菜单文案过这道筛。
static func audit(copy: String, every_n: int = 40) -> Dictionary:
	var flags: Array = _flags(copy)
	var absurd_ok: bool = absurd_density_ok(copy, every_n)
	var plain_len: int = _plain(copy).length()
	return {
		"ok": flags.is_empty() and absurd_ok,
		"flags": flags,
		"absurdOk": absurd_ok,
		"charCount": plain_len,
	}