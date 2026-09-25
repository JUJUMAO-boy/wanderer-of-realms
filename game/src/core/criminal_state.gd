class_name CriminalState
extends RefCounted

## 罪犯态规则层（M-B 剩余，9.31 节 D-134）。
##
## 善恶（karma）低到一定程度，玩家在外界的口碑就从"声名好坏"跌成"业力已恶"——
## 这不是没收单城门的那一笔账（那由 Economy 按每城声望算），而是这个灵魂本身的
## 底色：正常巷子里的店主看都不愿看你。与 M26 世界记忆同轴：代价落 karma，不落盘
## 新字段（karma 本就是 PlayerAvatar 上跨世保留的隐藏属性）。
##
## 边界：这里只做"判定 + 阈值取数"，它不碰交易本身。交易怎么拒绝走到哪一条，
## 是 Economy.get_price 的职责（黑市恒不问名声，是罪犯唯一的操作通道）。变装绕过
## 是 M-B 的后手、本轮不做，留给后续通道。

## 阈值数值全走 balance.json（criminal.karmaThreshold），这里的常量只是写死一个
## 兜底默认，确保 balance 缺段时语义不退化成"没有人是罪犯"。
const CRIMINAL_KARMA: int = -30
const _SECTION: String = "criminal"


## 罪犯态门槛：善恶 ≤ 此值即罪犯。读 balance.json，缺段时退到 CRIMINAL_KARMA。
static func karma_threshold() -> int:
	var section: Dictionary = ContentLoader.get_balance_section(_SECTION)
	var raw: Variant = section.get("karmaThreshold", CRIMINAL_KARMA)
	return int(raw) if raw is int or raw is float else CRIMINAL_KARMA


## 当前玩家是不是罪犯态（善恶 ≤ 门槛）。世界/化身还没挂上时恒否。
static func is_criminal(world: WorldState) -> bool:
	if world == null or world.avatar == null:
		return false
	return world.avatar.karma <= karma_threshold()