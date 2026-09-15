class_name WorldTime
extends RefCounted

## 游戏时间。
##
## 权威字段只有两个：elapsed_months（自开局起的总月数）与 tick_in_month
## （当月第几个小时）。年、月、日、时都由这两个推出来，不单独持久化——
## 否则会出现"总月数与年份对不上"这类只在读档时才暴露的错误。
##
## 时间的推进与归一化由 ClockCore 负责，本类只保存值并刷新显示字段。

var elapsed_months: int = 0  ## 自开局起的总月数
var tick_in_month: int = 0   ## 当月第几小时，0 .. ticks_per_month-1

var year: int = 1   ## 城邦历，从 1 起算
var month: int = 1  ## 1-12
var day: int = 1    ## 1-30
var hour: int = 0   ## 0-23


func refresh(ticks_per_day: int, days_per_month: int, months_per_year: int) -> void:
	var tpd: int = maxi(1, ticks_per_day)
	var dpm: int = maxi(1, days_per_month)
	var mpy: int = maxi(1, months_per_year)
	@warning_ignore("integer_division")
	var d: int = tick_in_month / tpd
	day = d + 1
	hour = tick_in_month % tpd
	@warning_ignore("integer_division")
	var y: int = elapsed_months / mpy
	year = y + 1
	month = elapsed_months % mpy + 1


func to_dict() -> Dictionary:
	return {
		"elapsedMonths": elapsed_months,
		"tickInMonth": tick_in_month,
	}


static func from_dict(data: Dictionary, ticks_per_day: int, days_per_month: int, months_per_year: int) -> WorldTime:
	var t := WorldTime.new()
	t.elapsed_months = int(data.get("elapsedMonths", 0))
	t.tick_in_month = int(data.get("tickInMonth", 0))
	t.refresh(ticks_per_day, days_per_month, months_per_year)
	return t


## 显示用的一行文本，如 "城邦历 1 年 3 月 12 日 07:00"。
func format() -> String:
	return "城邦历 %d 年 %d 月 %d 日 %02d:00" % [year, month, day, hour]
