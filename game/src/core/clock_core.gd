class_name ClockCore
extends RefCounted

## 时间推进的纯逻辑。
##
## 不继承 Node，也不引用引擎的渲染、场景或配置设施——时间刻度由调用方
## 从配置读出后传进来。这样它能脱离引擎运行，快进性能测试（设计文档
## 5.2 节的百万次结算）可以在无渲染环境下直接跑。
##
## 周期事件只负责"宣告边界到达"，不做任何结算。结算由各系统订阅后自行
## 处理：世界模拟响应 month、NPC 生命周期响应 year。时间推进与状态结算
## 解耦，是快进能批量处理的前提。

const PERIOD_DAY: String = "day"
const PERIOD_MONTH: String = "month"
const PERIOD_YEAR: String = "year"

var time: WorldTime

var _ticks_per_day: int = 24
var _days_per_month: int = 30
var _months_per_year: int = 12
var _ticks_per_month: int = 720
var _total_ticks: int = 0


func _init(ticks_per_day: int = 24, days_per_month: int = 30, months_per_year: int = 12) -> void:
	_ticks_per_day = maxi(1, ticks_per_day)
	_days_per_month = maxi(1, days_per_month)
	_months_per_year = maxi(1, months_per_year)
	_ticks_per_month = _ticks_per_day * _days_per_month
	time = WorldTime.new()
	_sync()


## 推进 ticks 个游戏小时，返回途中跨越的周期边界。
##
## 同一次推进中若同时跨过日界与月界（每个月的最后一小时），两个事件都会
## 返回，顺序为 day 在前、month 在后。这个顺序不能反：当日的收尾结算要
## 先于月度结算完成。
func advance(ticks: int) -> Array[Dictionary]:
	var fired: Array[Dictionary] = []
	if ticks <= 0:
		return fired
	for _i in range(ticks):
		_total_ticks += 1
		var in_month: int = _total_ticks % _ticks_per_month
		if in_month % _ticks_per_day == 0:
			fired.append(_event(ClockCore.PERIOD_DAY))
		if in_month == 0:
			fired.append(_event(ClockCore.PERIOD_MONTH))
			if total_months() % _months_per_year == 0:
				fired.append(_event(ClockCore.PERIOD_YEAR))
	_sync()
	return fired


## 推进整月。转生沉眠的快进会用到。
func advance_months(months: int) -> Array[Dictionary]:
	if months <= 0:
		return [] as Array[Dictionary]
	return advance(months * _ticks_per_month)


func total_months() -> int:
	@warning_ignore("integer_division")
	var m: int = _total_ticks / _ticks_per_month
	return m


func total_ticks() -> int:
	return _total_ticks


## 读档后恢复时间。只接受两个权威值，其余全部重算。
func restore(elapsed_months: int, tick_in_month: int) -> void:
	var em: int = maxi(0, elapsed_months)
	var tim: int = clampi(tick_in_month, 0, _ticks_per_month - 1)
	_total_ticks = em * _ticks_per_month + tim
	_sync()


func ticks_per_month() -> int:
	return _ticks_per_month


func ticks_per_day() -> int:
	return _ticks_per_day


func to_dict() -> Dictionary:
	return time.to_dict()


func _sync() -> void:
	@warning_ignore("integer_division")
	var em: int = _total_ticks / _ticks_per_month
	time.elapsed_months = em
	time.tick_in_month = _total_ticks % _ticks_per_month
	time.refresh(_ticks_per_day, _days_per_month, _months_per_year)


func _event(period: String) -> Dictionary:
	return {
		"period": period,
		"elapsedMonths": time.elapsed_months,
		"tickInMonth": time.tick_in_month,
	}
