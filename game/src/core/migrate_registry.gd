class_name MigrateRegistry
extends RefCounted

## 存档版本迁移链（技术设计文档 4.3）。
##
## 三条规则：
## 1. 每个版本提供一个纯函数：输入旧结构、输出新结构，不做任何 IO。
## 2. 逐级推进，禁止跨版本跳跃。跨版本迁移的组合数量随版本数平方增长，
##    既无法维护也无法测试。
## 3. 迁移前由 SaveIO 备份原文件，迁移失败时保留原文件并向上报错。
##
## 当前只有 v1，链上还没有步骤。框架与测试先就位——等第一次改 schema 时
## 只需 register_step(1, ...)，不必回头补机制。

const CURRENT_VERSION: int = 1

## from_version -> Callable(payload: Dictionary) -> Dictionary
static var _steps: Dictionary = {}


static func register_step(from_version: int, step: Callable) -> void:
	_steps[from_version] = step


static func unregister_step(from_version: int) -> void:
	_steps.erase(from_version)


static func has_step(from_version: int) -> bool:
	return _steps.has(from_version)


static func clear_steps() -> void:
	_steps.clear()


## 把 payload 从 from_version 升到 CURRENT_VERSION。
## 返回 {ok: bool, payload: Dictionary, steps: int, error: String}。
static func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	if from_version > CURRENT_VERSION:
		return {
			"ok": false,
			"payload": payload,
			"steps": 0,
			"error": "存档版本 %d 高于当前程序支持的 %d" % [from_version, CURRENT_VERSION],
		}
	if from_version == CURRENT_VERSION:
		return {"ok": true, "payload": payload, "steps": 0, "error": ""}

	var current: Dictionary = payload
	var steps: int = 0
	var version: int = from_version
	while version < CURRENT_VERSION:
		if not _steps.has(version):
			return {
				"ok": false,
				"payload": payload,
				"steps": steps,
				"error": "缺少 v%d -> v%d 的迁移步骤" % [version, version + 1],
			}
		var step: Callable = _steps[version]
		current = step.call(current)
		steps += 1
		version += 1
	return {"ok": true, "payload": current, "steps": steps, "error": ""}
