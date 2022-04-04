extends Control

var window := {
	"width": ProjectSettings.get_setting("display/window/size/width"),
	"height": ProjectSettings.get_setting("display/window/size/height"),
}

var main_window_instance: Node

onready var main_window := preload("res://addons/lospec_palette_list/main_window.tscn")


func _ready():
	var scale_factor := 1.0

	if OS.get_name() == "OSX":
		scale_factor = OS.get_screen_max_scale()
	elif OS.get_name() == "Windows":
		scale_factor = OS.get_screen_dpi() / 96.0

		if scale_factor < 1.0:
			scale_factor = 1.0

	get_tree().set_screen_stretch(
		SceneTree.STRETCH_MODE_DISABLED,
		SceneTree.STRETCH_ASPECT_IGNORE,
		Vector2(window.width * scale_factor, window.height * scale_factor),
		scale_factor
	)
	OS.set_window_size(Vector2(window.width * scale_factor, window.height * scale_factor))
	OS.center_window()

	main_window_instance = main_window.instance()

	OS.set_window_title(main_window_instance.project_settings.name)

	main_window_instance.config_file = "user://app_settings.cfg"
	main_window_instance.default_download_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	main_window_instance.base_color_rect_size /= scale_factor

	add_child(main_window_instance)

	main_window_instance.about_dialog_texture.rect_min_size /= scale_factor
	main_window_instance.about_dialog_text.rect_min_size.y /= scale_factor
	main_window_instance.about_dialog.rect_size = Vector2(window.width / scale_factor, window.height / scale_factor)
	main_window_instance.download_path_file_dialog.access = scale_factor


func _notification(what):
	if what == NOTIFICATION_WM_ABOUT:
		main_window_instance.about_dialog.call_deferred("popup_centered")
