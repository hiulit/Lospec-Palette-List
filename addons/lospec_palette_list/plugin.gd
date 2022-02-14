tool
extends EditorPlugin

const main_panel = preload("res://addons/lospec_palette_list/main_window.tscn")

var main_panel_instance


func _enter_tree():
	main_panel_instance = main_panel.instance()

	get_editor_interface().get_editor_viewport().add_child(main_panel_instance)

	make_visible(false)


func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()


func has_main_screen():
	return true


func make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible


func get_plugin_name():
	return "Lospec Palette List"


func get_plugin_icon():
	return preload("res://addons/lospec_palette_list/icon.svg")
