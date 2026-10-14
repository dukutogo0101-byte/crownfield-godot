@tool
extends SceneTree

func _initialize() -> void:
	_configure.call_deferred()

func _configure() -> void:
	for i in range(12):
		await process_frame
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("export/android/android_sdk_path", OS.get_environment("ANDROID_SDK_ROOT"))
	settings.set_setting("export/android/java_sdk_path", OS.get_environment("JAVA_HOME"))
	settings.set_setting("export/android/debug_keystore", OS.get_environment("CROWNFIELD_DEBUG_KEYSTORE"))
	settings.set_setting("export/android/debug_keystore_user", "androiddebugkey")
	settings.set_setting("export/android/debug_keystore_pass", "android")
	quit()
