class_name CreationSession
extends RefCounted

## 开局创建的状态机（M3.1 自由生成 / M3.2 随机转生）。
##
## 管的是：现在在哪一段、光标停在哪一行、按一下或点一下之后规格怎么变。界面怎么
## 画不归它管——那是 CreationViewModel 与 CreationPanel 的事，这里只把结果放进 view。
##
## 为什么从 main.gd 抽出来：这套规则原先只写在主场景的事件处理里，而主场景在无头
## 测试中不存在。于是"点第二行天赋却把第一行取消了"这种错误测试完全抓不到，只能靠
## 人点一遍。规则收到这里之后，一次点击从屏幕坐标到状态变更整条链子都在可测范围内：
## 面板的 hit_test 认出是哪一行 → click() 按行号改状态。
##
## 这个类不碰世界状态。抽宿主躯壳需要 WorldState 与 SoulRecord，那是主场景的东西，
## 从 _rebirth_source 注入进来；测试里换成一个返回固定结果的 Callable 即可。

var spec: Dictionary = {}
var section: int = CreationViewModel.SECTION_RACE
var cursor: int = 0
var mode: int = CreationViewModel.MODE_FREE
var rebirth: Dictionary = {}
## 最近一次操作的反馈文案，调用方拿它更新状态行。为空表示"没什么可说的"，
## 此时状态行保持原样，而不是被清空。
var message: String = ""
## 供绘制与命中测试使用的界面结构，与 spec / section / cursor 始终一致。
var view: Dictionary = {}

var _creator: CharacterCreation = null
var _name_rng: DeterministicRNG = null
var _city_names: Dictionary = {}
## 抽宿主的来源：(seq: int) -> Dictionary。seq 每次递增——固定种子连按 R 只会抽到
## 同一具躯壳，而"同一世界的第 n 次抽取"仍然可复现。
var _rebirth_source: Callable = Callable()
var _rebirth_seq: int = 0


func _init(
	creator: CharacterCreation,
	name_rng: DeterministicRNG,
	rebirth_source: Callable,
	city_names: Dictionary = {}
) -> void:
	_creator = creator
	_name_rng = name_rng
	_rebirth_source = rebirth_source
	_city_names = city_names


# --- 生命周期 ---

## 进入自由生成：预选第一个种族与第一个出身，抽一个名字。
func enter() -> void:
	mode = CreationViewModel.MODE_FREE
	section = CreationViewModel.SECTION_RACE
	cursor = 0
	rebirth = {}
	_rebirth_seq = 0
	spec = _creator.new_spec()
	var races: Array = _creator.race_options()
	if not races.is_empty():
		spec["race"] = str(races[0].get("raceId", ""))
	var backgrounds: Array = _creator.background_options()
	if not backgrounds.is_empty():
		spec["backgroundId"] = str(backgrounds[0].get("backgroundId", ""))
	spec["startCityId"] = str(_current_background().get("startCityId", ""))
	spec["displayName"] = roll_name()
	sync()


## 重建界面结构。每次状态变更之后都要调，于是 view 永远等于"当前状态的渲染依据"。
##
## 视图是照着 spec / section / cursor 算出来的，所以它只能是**结果**，不能当输入。
## 回头从 view 里读 cursor 正是"点第二行却改了第一行"的成因：那一份 cursor 是上一次
## 刷新时留下的。类里所有动作都只认传入的行号与自己的字段。
func sync() -> void:
	view = CreationViewModel.build(
		_creator, spec, section, cursor, mode, rebirth, _city_names
	)


# --- 段与光标 ---

## 跳到某一段。转生模式没有种族/出身/属性可填，跳过去只会让人以为填的东西丢了。
func go_to_section(index: int) -> void:
	if mode != CreationViewModel.MODE_FREE and index != CreationViewModel.SECTION_CONFIRM:
		message = "随机转生只有确认段可看。"
		return
	section = clampi(index, 0, CreationViewModel.SECTION_COUNT - 1)
	cursor = 0
	sync()


## TAB：下一段，到末段绕回第一段。转生模式下段是锁死的。
func next_section() -> void:
	if mode != CreationViewModel.MODE_FREE:
		message = "随机转生只有确认段。"
		return
	section = (section + 1) % CreationViewModel.SECTION_COUNT
	cursor = 0
	sync()


## ↑↓：在段内移光标。
func move_cursor(delta: int) -> void:
	cursor = posmod(cursor + delta, maxi(1, int(view.get("rowCount", 0))))
	sync()


## 把光标挪到某一行（点击用）。行号会被钳进当前段的条目范围。
func set_cursor(row_index: int) -> void:
	cursor = clampi(row_index, 0, maxi(0, int(view.get("rowCount", 1)) - 1))
	sync()


## ←→：段内改值。逐段含义不同。
func step(delta: int) -> void:
	match section:
		CreationViewModel.SECTION_RACE:
			_cycle_option(_creator.race_options(), "race", "raceId", "种族", delta)
			# 换了种族就重掷姓名：人类叫「月影」这种组合看着就不对
			spec["displayName"] = roll_name()
		CreationViewModel.SECTION_BACKGROUND:
			_cycle_option(
				_creator.background_options(), "backgroundId", "backgroundId", "出身", delta
			)
			spec["startCityId"] = str(_current_background().get("startCityId", ""))
		CreationViewModel.SECTION_ATTRIBUTES:
			_allocate(cursor, delta)
		CreationViewModel.SECTION_TRAITS:
			_toggle(cursor)
		CreationViewModel.SECTION_CONFIRM:
			if mode == CreationViewModel.MODE_REBIRTH:
				roll_rebirth()
	sync()


## 回上一步。ESC 与「← 上一步」按钮都走这里——两套输入必须落在同一个状态变更上，
## 否则"按键回退"和"按钮回退"迟早会变成两种行为。
##
## 之前的问题是界面上一个字都没提 ESC，而 TAB 只会一路往前：玩家撞到确认页才发现
## 没有回头路。所以除了补按钮，段标签也做成了直接跳段的入口。
func back() -> void:
	if mode != CreationViewModel.MODE_FREE:
		# 转生模式没有种族/出身/属性可改，退回那些段只会让人以为填的东西丢了
		message = "随机转生没有上一步；要自己选就按「切换开局方式」。"
		return
	if section <= CreationViewModel.SECTION_RACE:
		message = "已经在第一段了。"
		return
	section -= 1
	cursor = 0
	message = "回到第 %d 段：%s" % [
		section + 1, str(CreationViewModel.SECTION_LABELS[section])
	]
	sync()


# --- 规格变更 ---

## 加减一点。加点受"剩余点数"与"单项上限"两条约束，减点不受——减总是合法，
## 所以减到最后一位时不该被任何规则挡住。
func allocate(row_index: int, delta: int) -> void:
	_allocate(row_index, delta)
	sync()


func _allocate(row_index: int, delta: int) -> void:
	var rows: Array = view.get("rows", [])
	if row_index < 0 or row_index >= rows.size():
		return
	var attr: String = str(rows[row_index].get("key", ""))
	if attr.is_empty():
		return
	var allocations: Dictionary = spec[CharacterCreation.ATTR_POINTS_KEY]
	var next: int = int(allocations.get(attr, 0)) + (1 if delta > 0 else -1)
	if next < 0:
		return
	if next > _creator.per_attribute_cap():
		message = "创建期单项最多分配 %d 点。" % _creator.per_attribute_cap()
		return
	if delta > 0 and _creator.remaining_points(spec) <= 0:
		message = "可分配点数已用完，先减掉别的属性。"
		return
	allocations[attr] = next


## 勾选 / 取消勾选一行天赋或缺陷。
func toggle_row(row_index: int) -> void:
	_toggle(row_index)
	sync()


func _toggle(row_index: int) -> void:
	var rows: Array = view.get("rows", [])
	if row_index < 0 or row_index >= rows.size():
		return
	var row: Dictionary = rows[row_index]
	var entry_id: String = str(row.get("key", ""))
	if entry_id.is_empty():
		return
	var field: String = "talents" if str(row.get("categoryLabel", "")) == "天赋" else "flaws"
	var chosen: Array = spec.get(field, [])
	var verb: String = "取消"
	if chosen.has(entry_id):
		chosen.erase(entry_id)
	else:
		chosen.append(entry_id)
		verb = "已选"
	spec[field] = chosen
	message = "%s：%s（天赋 %d / 缺陷 %d）" % [
		verb, str(row.get("label", "")), _count("talents"), _count("flaws")
	]


## 点某一行 = 直接选中它，只用于种族与出身。属性行与天赋行点一下只移动光标：
## 它们各自有加减方块与勾选框，点整行就改值的话误触代价太大。
func pick_row(row_index: int) -> void:
	var rows: Array = view.get("rows", [])
	if row_index < 0 or row_index >= rows.size():
		return
	var key: String = str(rows[row_index].get("key", ""))
	var label: String = str(rows[row_index].get("label", key))
	match section:
		CreationViewModel.SECTION_RACE:
			spec["race"] = key
			# 换了种族就重掷姓名：人类叫「月影」这种组合看着就不对
			spec["displayName"] = roll_name()
			message = "种族：%s" % label
		CreationViewModel.SECTION_BACKGROUND:
			spec["backgroundId"] = key
			spec["startCityId"] = str(_current_background().get("startCityId", ""))
			message = "出身：%s" % label
		_:
			return
	sync()


## 重掷姓名。姓名不参与任何数值，抽坏了再抽一次即可。
func reroll_name() -> void:
	spec["displayName"] = roll_name()
	message = "姓名：%s" % str(spec["displayName"])
	sync()


## 从所选种族的姓名池里抽一个名字。这里不追求"生成得像名字"，只保证种族对得上。
func roll_name() -> String:
	var race_id: String = str(spec.get("race", ""))
	for race in _creator.race_options():
		if str(race.get("raceId", "")) != race_id:
			continue
		var given: Array = race.get("givenNames", [])
		var family: Array = race.get("familyNames", [])
		if given.is_empty() or family.is_empty():
			break
		var rng: DeterministicRNG = _name_rng if _name_rng != null else DeterministicRNG.new(1)
		return "%s%s" % [
			str(given[rng.next_int(given.size())]), str(family[rng.next_int(family.size())])
		]
	return "无名者"


## 自由生成 ↔ 随机转生。转生模式没有种族/出身/属性段，直接落到确认段。
func toggle_mode() -> void:
	if mode == CreationViewModel.MODE_FREE:
		mode = CreationViewModel.MODE_REBIRTH
		roll_rebirth()
	else:
		mode = CreationViewModel.MODE_FREE
		rebirth = {}
		message = "改回自由生成。"
	section = CreationViewModel.SECTION_CONFIRM
	cursor = 0
	sync()


## 抽一具宿主躯壳。真正的抽取由外部完成（要世界状态与灵魂记录），这里只管递增序号。
func roll_rebirth() -> void:
	_rebirth_seq += 1
	if not _rebirth_source.is_valid():
		return
	rebirth = _rebirth_source.call(_rebirth_seq)
	if not bool(rebirth.get("ok", false)):
		message = "抽不到宿主：%s" % str(rebirth.get("reason", ""))


# --- 输入 ---

## 处理一次点击。面板只说"点到了什么"，怎么改状态是这里的事——这样"点第二行勾第
## 二项"整条链子都能被测试钉住，而不是只测到面板认出了行号。
##
## 返回与 confirm() 同形的请求：点「开始这一生」和按回车走的是同一条判定。
func click(hit: Dictionary) -> Dictionary:
	var kind: String = str(hit.get("kind", ""))
	var index: int = int(hit.get("index", -1))
	match kind:
		"button":
			return _press(str(hit.get("id", "")))
		"tab":
			go_to_section(index)
		"option":
			cursor = index
			pick_row(index)
		"toggle":
			cursor = index
			toggle_row(index)
		"attribute_plus":
			cursor = index
			allocate(index, 1)
		"attribute_minus":
			cursor = index
			allocate(index, -1)
		"row":
			set_cursor(index)
	return {"ok": false}


## 底部动作条。四个按钮的语义都在别处已实现，这里只做转发——鼠标与键盘必须落在
## 同一处状态变更上，否则两条路的回退深度会慢慢不一致。
##
## 置灰的按钮也照样响应，由处理器说明为什么不能用："点不动且毫无反应"比
## "点不动但告诉你原因"难懂得多。
func _press(button_id: String) -> Dictionary:
	match button_id:
		"back":
			back()
		"reroll":
			reroll_name()
		"mode":
			toggle_mode()
		"start":
			return confirm()
	return {"ok": false}


## 回车 / 「开始这一生」。
##
## 返回 {ok, mode, rebirth} 或 {ok: false}：ok 为真时调用方按 mode 去装配化身。
## 装配要动世界与时钟（转生还要先让人沉眠若干月），所以那一步留在主场景，
## 这里只回答"现在能不能开始"。
func confirm() -> Dictionary:
	if section < CreationViewModel.SECTION_CONFIRM:
		section += 1
		cursor = 0
		sync()
		return {"ok": false}
	if mode == CreationViewModel.MODE_REBIRTH:
		if not bool(rebirth.get("ok", false)):
			roll_rebirth()
			sync()
		if not bool(rebirth.get("ok", false)):
			message = "抽不到宿主，暂时无法转生。"
			return {"ok": false}
		return {
			"ok": true,
			"mode": CreationViewModel.MODE_REBIRTH,
			"rebirth": rebirth,
		}
	var validation: Dictionary = _creator.validate(spec)
	if not bool(validation["ok"]):
		message = "还不能开始：%s" % str(validation["errors"][0])
		sync()
		return {"ok": false}
	return {"ok": true, "mode": CreationViewModel.MODE_FREE}


# --- 内部 ---

## 在某一类选项里前后移动，并把选中的值写回规格的 field。
func _cycle_option(
	options: Array, field: String, id_key: String, label: String, delta: int
) -> void:
	if options.is_empty():
		return
	var ids: Array = []
	for option in options:
		ids.append(str(option.get(id_key, "")))
	var index: int = ids.find(str(spec.get(field, "")))
	index = posmod((index if index >= 0 else 0) + delta, ids.size())
	spec[field] = str(ids[index])
	message = "%s：%s" % [label, str(options[index].get("displayName", ""))]


func _current_background() -> Dictionary:
	var background_id: String = str(spec.get("backgroundId", ""))
	for background in _creator.background_options():
		if str(background.get("backgroundId", "")) == background_id:
			return background
	return {}


func _count(field: String) -> int:
	return spec.get(field, []).size()
