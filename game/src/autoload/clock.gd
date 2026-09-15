extends Node

## 时间服务（接口 I-01 / I-02）。
##
## 只负责推进时间与派发周期边界事件，不做任何结算：世界模拟订阅 month、
## NPC 生命周期订阅 year、战斗与探索订阅 tick。时间推进与状态结算解耦，
## 是快进能批量处理的前提。
##
## 依赖 autoload 顺序：本节点排在 ContentLoader 之后（见 project.godot），
## 因为 _ready 里要读 time 段的时间刻度。

signal period_reached(period: String, elapsed_months: int, tick_in_month: int)

var _core: ClockCore = null


func _ready() -> void:
	var t: Dictionary = ContentLoader.get_balance_section("time")
	_core = ClockCore.new(
		int(t.get("ticksPerDay", 24)),
		int(t.get("daysPerMonth", 30)),
		int(t.get("monthsPerYear", 12))
	)


## 纯逻辑核心。测试与快进性能测量可以直接拿它，绕过信号派发。
func core() -> ClockCore:
	return _core


func now() -> WorldTime:
	return _core.time


## 推进 ticks 个游戏小时，并把途中跨越的周期边界逐个发出去。
func advance(ticks: int) -> Array[Dictionary]:
	var fired: Array[Dictionary] = _core.advance(ticks)
	_emit_all(fired)
	return fired


func advance_months(months: int) -> Array[Dictionary]:
	var fired: Array[Dictionary] = _core.advance_months(months)
	_emit_all(fired)
	return fired


func to_dict() -> Dictionary:
	return _core.to_dict()


func restore(data: Dictionary) -> void:
	_core.restore(int(data.get("elapsedMonths", 0)), int(data.get("tickInMonth", 0)))


func total_months() -> int:
	return _core.total_months()


func _emit_all(fired: Array[Dictionary]) -> void:
	for ev in fired:
		period_reached.emit(str(ev["period"]), int(ev["elapsedMonths"]), int(ev["tickInMonth"]))
