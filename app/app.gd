extends Control

var window := {
	"width": ProjectSettings.get_setting("display/window/size/width"),
	"height": ProjectSettings.get_setting("display/window/size/height"),
}

var app := {
	"name": ProjectSettings.get_setting("application/config/name"),
	"description": ProjectSettings.get_setting("application/config/description"),
	"version": ProjectSettings.get_setting("application/config/version"),
	"author": ProjectSettings.get_setting("application/config/author"),
	"license": ProjectSettings.get_setting("application/config/license"),
	"repository": ProjectSettings.get_setting("application/config/repository"),
}

var main_window_instance: Node

onready var main_window := preload("res://addons/lospec_palette_list/main_window.tscn")

onready var about_dialog := $AboutDialog
onready var about_dialog_label := $AboutDialog/VBoxContainer/Label


func _ready():
	OS.set_window_title(app.name)

	if OS.get_name() == "OSX" or OS.get_name() == "Windows":
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_DISABLED,
			SceneTree.STRETCH_ASPECT_IGNORE,
			Vector2(window.width * 2, window.height * 2),
			2
		)

		OS.set_window_size(Vector2(window.width * 2, window.height * 2))

		OS.center_window()

	about_dialog.window_title = "About"
	about_dialog_label.text = "%s v%s" % [app.name, app.version]
	about_dialog_label.text += "\n© 2022 %s" % app.author
	about_dialog_label.text += "\n"
	about_dialog_label.text += "\nSource code:\n%s License\n%s" % [app.license, app.repository]

	main_window_instance = main_window.instance()

	main_window_instance.config_file = "user://app_settings.cfg"

	main_window_instance.default_download_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

	main_window_instance.base_color_rect_size /= 2

	add_child(main_window_instance)

	main_window_instance.download_path_file_dialog.access = 2


func _notification(what):
	if what == NOTIFICATION_WM_ABOUT:
		about_dialog.call_deferred("popup")
