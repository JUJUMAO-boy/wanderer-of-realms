class_name DeterministicRNG
extends RefCounted

## 确定性随机数发生器。
##
## 不使用 Godot 内置的 RandomNumberGenerator：本作要求"同一世界种子在不同
## 机器、不同运行次数下产生相同的演化结果"，随机算法必须完全固定且可复现，
## 状态还要能写进存档。
##
## 算法用 xorshift32（Marsaglia）。选 32 位而非 64 位的原因：GDScript 的整数
## 是 64 位有符号，右移是算术右移（负数补 1），而 xorshift 需要逻辑右移。
## 把内部值保持在 [0, 2^32) 之后，右移天然等价于逻辑右移，省掉一层掩码，
## 也少一个出错的地方。
##
## 附带一条约束：世界种子与随机状态都限制在 32 位内。存档是 JSON，数字会
## 经过双精度浮点，2^53 以内才精确；32 位远在安全范围内。

const MASK32: int = 0xFFFFFFFF
const UINT32_RANGE: int = 0x100000000  # 2^32
const FALLBACK_SEED: int = 0x9E3779B9  # 状态为 0 时 xorshift 会退化成恒 0，用它兜底

var _state: int = 0

func _init(seed_value: int = 0) -> void:
	seed_from(seed_value)


func seed_from(seed_value: int) -> void:
	var s: int = seed_value & MASK32
	if s == 0:
		s = FALLBACK_SEED
	_state = s


func get_state() -> int:
	return _state


func set_state(value: int) -> void:
	var s: int = value & MASK32
	if s == 0:
		s = FALLBACK_SEED
	_state = s


## 推进一步，返回 [0, 2^32) 的整数。
func next_u32() -> int:
	var x: int = _state
	x = (x ^ (x << 13)) & MASK32
	x = (x ^ (x >> 17)) & MASK32
	x = (x ^ (x << 5)) & MASK32
	_state = x
	return x


## 返回 [0, max_exclusive) 的整数。
## 用拒绝采样而非直接取模：取模会让偏小的结果概率偏高，抽职业、抽姓名这类
## 高频小范围随机上会累积出可测量的偏差。
func next_int(max_exclusive: int) -> int:
	if max_exclusive <= 1:
		return 0
	var span: int = mini(max_exclusive, UINT32_RANGE)
	var limit: int = UINT32_RANGE - (UINT32_RANGE % span)
	var v: int = next_u32()
	while v >= limit:
		v = next_u32()
	return v % span


## 返回 [0.0, 1.0) 的浮点数。
func next_float() -> float:
	return float(next_u32()) / float(UINT32_RANGE)


## 以概率 p 返回 true。
func chance(p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	return next_float() < p


## 返回 [min_value, max_value] 闭区间内的整数。
func range_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + next_int(max_value - min_value + 1)
