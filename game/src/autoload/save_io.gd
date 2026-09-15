extends Node

## 存档读写（接口 I-29 / I-30）。
##
## 目录结构（技术设计文档 4.1）：
##   user://saves/<slot>/world.json              世界快照，跨转生保留
##   user://saves/<slot>/soul.json               灵魂记录，跨转生携带
##   user://saves/<slot>/archive/life-NNN.json   历史化身，每世追加一份
##   user://saves/<slot>/backup/                 覆盖前的上一份，读档失败时回退
##
## 用未压缩 JSON：本作存档约 1.5 MB，体积不构成压力，而可读性对调试、手改
## 存档、版本迁移的价值很高。等存档明显变大再启用 FileAccess 的压缩模式，
## 返回值里的 compressed 字段就是为那天预留的。
##
## 完整性判断靠"能解析 + 必填字段齐全"，不额外加校验和。原因是校验和要么
## 在序列化后重算（浮点格式差异会导致误报），要么引入自引用结构，两者都比
## 它挡住的静默损坏（现代文件系统上极少）代价更大。

const SAVE_ROOT: String = "user://saves/"
const WORLD_FILE: String = "world.json"
const SOUL_FILE: String = "soul.json"
const ARCHIVE_DIR: String = "archive"
const BACKUP_DIR: String = "backup"

# 错误码，与接口契约中的约定一致
const ERR_NOT_FOUND: String = "NOT_FOUND"
const ERR_SAVE_CORRUPT: String = "SAVE_CORRUPT"
const ERR_MIGRATION_FAILED: String = "MIGRATION_FAILED"
const ERR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"


func slot_dir(slot_id: String) -> String:
	return SAVE_ROOT + slot_id + "/"


func slot_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(slot_dir(slot_id) + WORLD_FILE)


func list_slots() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(SAVE_ROOT)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return out


## 写入一个存档槽。world.json 覆盖前会先备份到 backup/。
## 返回 {ok, bytes, compressed, error, errorCode}。
func save_slot(slot_id: String, world: WorldState, soul: SoulRecord, time_data: Dictionary) -> Dictionary:
	if slot_id.is_empty():
		return _fail(ERR_INVALID_ARGUMENT, "槽位名为空")
	if world == null:
		return _fail(ERR_INVALID_ARGUMENT, "缺少世界状态")

	var dir_path: String = slot_dir(slot_id)
	var mk: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if mk != OK:
		return _fail(ERR_INVALID_ARGUMENT, "无法创建存档目录 %s（错误码 %d）" % [dir_path, mk])

	# 覆盖前备份。读档遇到损坏时，这是唯一的退路。
	if FileAccess.file_exists(dir_path + WORLD_FILE):
		DirAccess.make_dir_recursive_absolute(dir_path + BACKUP_DIR)
		DirAccess.copy_absolute(dir_path + WORLD_FILE, dir_path + BACKUP_DIR + "/" + WORLD_FILE)
		DirAccess.copy_absolute(dir_path + SOUL_FILE, dir_path + BACKUP_DIR + "/" + SOUL_FILE)

	var world_payload: Dictionary = {
		"time": time_data.duplicate(),
		"world": world.to_dict(),
	}
	var world_result: Dictionary = _write_file(
		dir_path + WORLD_FILE, MigrateRegistry.CURRENT_VERSION, world_payload
	)
	if not world_result.get("ok", false):
		return world_result

	var soul_payload: Dictionary = {"soul": soul.to_dict() if soul != null else {}}
	var soul_result: Dictionary = _write_file(
		dir_path + SOUL_FILE, MigrateRegistry.CURRENT_VERSION, soul_payload
	)
	if not soul_result.get("ok", false):
		return soul_result

	return {
		"ok": true,
		"bytes": int(world_result.get("bytes", 0)) + int(soul_result.get("bytes", 0)),
		"compressed": false,
		"error": "",
		"errorCode": "",
	}


## 读取一个存档槽。解析失败时自动回退到 backup/，全部失败才报 SAVE_CORRUPT。
## 返回 {ok, worldData, soulData, timeData, migratedFrom, usedBackup, error, errorCode}。
func load_slot(slot_id: String) -> Dictionary:
	var dir_path: String = slot_dir(slot_id)
	if not FileAccess.file_exists(dir_path + WORLD_FILE):
		return _fail(ERR_NOT_FOUND, "槽位 %s 没有存档" % slot_id)

	var world_read: Dictionary = _read_and_migrate(dir_path + WORLD_FILE)
	if not world_read.get("ok", false) and world_read.get("errorCode", "") == ERR_SAVE_CORRUPT:
		# 主文件坏了，试备份
		var backup_path: String = dir_path + BACKUP_DIR + "/" + WORLD_FILE
		if FileAccess.file_exists(backup_path):
			var backup_read: Dictionary = _read_and_migrate(backup_path)
			if backup_read.get("ok", false):
				backup_read["usedBackup"] = true
				world_read = backup_read
	if not world_read.get("ok", false):
		return world_read

	var soul_read: Dictionary = _read_and_migrate(dir_path + SOUL_FILE)
	if not soul_read.get("ok", false):
		# 灵魂记录缺失不该让整个存档作废，但必须让调用方知道
		push_warning("[SaveIO] %s 读取失败：%s" % [SOUL_FILE, soul_read.get("error", "")])

	var payload: Dictionary = world_read["payload"]
	return {
		"ok": true,
		"worldData": payload.get("world", {}),
		"timeData": payload.get("time", {}),
		"soulData": soul_read.get("payload", {}).get("soul", {}) if soul_read.get("ok", false) else {},
		"migratedFrom": int(world_read.get("migratedFrom", MigrateRegistry.CURRENT_VERSION)),
		"usedBackup": bool(world_read.get("usedBackup", false)),
		"error": "",
		"errorCode": "",
	}


## 追加一份历史化身（转生时调用）。只增不改。
func write_archive(slot_id: String, index: int, archive: Dictionary) -> Dictionary:
	var dir_path: String = slot_dir(slot_id) + ARCHIVE_DIR + "/"
	var mk: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if mk != OK:
		return _fail(ERR_INVALID_ARGUMENT, "无法创建归档目录（错误码 %d）" % mk)
	var file_name: String = "life-%03d.json" % index
	return _write_file(dir_path + file_name, MigrateRegistry.CURRENT_VERSION, {"archive": archive})


# --- 内部实现 ---

func _write_file(path: String, schema_version: int, payload: Dictionary) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail(ERR_INVALID_ARGUMENT, "无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
	var text: String = JSON.stringify(
		{"schemaVersion": schema_version, "payload": payload}, "\t"
	)
	file.store_string(text)
	file.close()
	return {
		"ok": true,
		"bytes": text.length(),
		"compressed": false,
		"error": "",
		"errorCode": "",
	}


func _read_and_migrate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(ERR_NOT_FOUND, "文件不存在：%s" % path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail(ERR_SAVE_CORRUPT, "无法打开 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
	var text: String = file.get_as_text()
	file.close()

	var parser := JSON.new()
	var err: int = parser.parse(text)
	if err != OK:
		return _fail(ERR_SAVE_CORRUPT, "%s 解析失败（第 %d 行）：%s" % [
			path, parser.get_error_line(), parser.get_error_message()
		])
	if not (parser.data is Dictionary):
		return _fail(ERR_SAVE_CORRUPT, "%s 根节点不是对象" % path)

	var root: Dictionary = parser.data
	if not root.has("schemaVersion"):
		return _fail(ERR_SAVE_CORRUPT, "%s 缺少 schemaVersion" % path)
	if not root.has("payload") or not (root["payload"] is Dictionary):
		return _fail(ERR_SAVE_CORRUPT, "%s 缺少 payload 对象" % path)

	var from_version: int = int(root["schemaVersion"])
	var result: Dictionary = MigrateRegistry.migrate(root["payload"], from_version)
	if not result.get("ok", false):
		return _fail(ERR_MIGRATION_FAILED, str(result.get("error", "")))

	return {
		"ok": true,
		"payload": result["payload"],
		"migratedFrom": from_version,
		"steps": int(result.get("steps", 0)),
		"usedBackup": false,
		"error": "",
		"errorCode": "",
	}


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"errorCode": code,
		"bytes": 0,
		"compressed": false,
	}
