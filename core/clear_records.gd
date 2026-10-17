extends RefCounted
## Device-local achievements, deliberately outside deterministic game state.
const WEB_KEY := "crownfield.clear_records.v1"
var path: String = "user://crownfield_clears.json"
var use_web_storage: bool = OS.has_feature("web")
var clears: Array = []
var last_error: String = ""

func new_run_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func load_records() -> bool:
	last_error = ""
	var raw: String = ""
	var exists: bool = false
	if use_web_storage:
		var reply = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('" + WEB_KEY + "')||'';}catch(e){return null;}})()")
		if reply == null:
			last_error = "ブラウザの記録保存領域を利用できません。"
			return false
		raw = str(reply)
		exists = not raw.is_empty()
	else:
		if FileAccess.file_exists(path):
			exists = true
			raw = FileAccess.get_file_as_string(path)
		elif FileAccess.file_exists(path + ".bak"):
			exists = true
			raw = FileAccess.get_file_as_string(path + ".bak")
	if not exists:
		clears = []
		return true
	var loaded = _decode(raw)
	if loaded == null and not use_web_storage and FileAccess.file_exists(path + ".bak"):
		loaded = _decode(FileAccess.get_file_as_string(path + ".bak"))
	if loaded == null:
		last_error = "クリア記録を読み込めません。既存の記録は上書きしません。"
		return false
	clears = loaded
	return true

func _decode(raw: String):
	var parser: JSON = JSON.new()
	if parser.parse(raw) != OK: return null
	var data = parser.data
	if not data is Dictionary or data.get("format") != 1 or not data.get("clears") is Array: return null
	var seen: Dictionary = {}
	for entry in data.clears:
		if not entry is Dictionary: return null
		for key in ["run_id", "map_id", "map_name", "completed_at"]:
			if not entry.get(key) is String or entry[key].is_empty(): return null
		for key in ["ticks", "day_ticks", "completed_unix"]:
			var value = entry.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or float(value) != floor(float(value)): return null
			entry[key] = int(value)
		if entry.day_ticks < 1 or seen.has(entry.run_id): return null
		seen[entry.run_id] = true
	return data.clears

func record_victory(run_id: String, state: Dictionary, rules: Dictionary, map_name: String, playback: bool = false) -> String:
	if playback or state.get("result") != "victory" or state.get("winner") != 0: return "ignored"
	if run_id.is_empty() or str(state.get("id", "")).is_empty(): return "ignored"
	# Reload before adding, so records made by another window are retained.
	if not load_records(): return "error"
	for entry in clears:
		if entry.run_id == run_id: return "duplicate"
	var next: Array = clears.duplicate(true)
	next.append({"run_id": run_id, "map_id": str(state.id), "map_name": map_name,
		"ticks": int(state.tick), "day_ticks": int(rules.day_ticks),
		"completed_unix": int(Time.get_unix_time_from_system()),
		"completed_at": Time.get_datetime_string_from_system(false, true)})
	if not _save(next): return "error"
	clears = next
	return "added"

func _save(next: Array) -> bool:
	var raw: String = JSON.stringify({"format": 1, "clears": next})
	if use_web_storage:
		var script: String = "(function(){try{const s=" + JSON.stringify(raw) + ";localStorage.setItem('" + WEB_KEY + "',s);return localStorage.getItem('" + WEB_KEY + "')===s;}catch(e){return false;}})()"
		if JavaScriptBridge.eval(script) == true: return true
	else:
		var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file != null:
			file.store_string(raw)
			file.flush()
			var error: Error = file.get_error()
			file.close()
			if error == OK:
				var destination: String = ProjectSettings.globalize_path(path)
				if FileAccess.file_exists(path):
					# Retain only a validated backup, including after recovery from corruption.
					if _decode(FileAccess.get_file_as_string(path)) != null:
						DirAccess.copy_absolute(destination, destination + ".bak")
				if DirAccess.rename_absolute(destination + ".tmp", destination) == OK: return true
	last_error = "クリア記録を保存できませんでした。空き容量と保存設定を確認してください。"
	return false

func summary(map_id: String) -> Dictionary:
	var result: Dictionary = {"count": 0}
	for entry in clears:
		if entry.map_id != map_id: continue
		result.count += 1
		if not result.has("best") or float(entry.ticks) / entry.day_ticks < float(result.best.ticks) / result.best.day_ticks:
			result["best"] = entry
		if not result.has("latest") or entry.completed_unix >= result.latest.completed_unix:
			result["latest"] = entry
	return result

func describe(map_id: String) -> String:
	var record: Dictionary = summary(map_id)
	if record.count == 0: return "未クリア"
	return "クリア %d回 · 最短 %.1f日\n直近 %s" % [record.count, float(record.best.ticks) / record.best.day_ticks, record.latest.completed_at]
