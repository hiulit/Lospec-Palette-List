tool
extends Control

var config := ConfigFile.new()
var config_file := "user://plugin_settings.cfg"

var base_url := "https://lospec-api.vercel.app/api"

var query_params := {
	"filter_type": "any", "number": 8, "page": 0, "tag": "", "sorting_type": "default"
}

var url: String
var query_string: String

var current_pressed_filter_type_button: Button
var current_pressed_sort_button: Button

var default_download_path := "res://"
var current_download_path: String setget _set_current_download_path

var slider_min_value := 2
var slider_timer_on := false
var slider_editing_value: int

var total_count
var max_pages
var items_per_page

var base_color_rect_size = 8

var debug_mode := false

onready var button_group_filter_type := preload(
	"res://addons/lospec_palette_list/resources/button_group_filter_type.tres"
)
onready var button_group_sort := preload(
	"res://addons/lospec_palette_list/resources/button_group_sort.tres"
)
onready var palette_item_container := preload(
	"res://addons/lospec_palette_list/components/palette_item_container/palette_item_container.tscn"
)

onready var download_path_button := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/DownloadPathContainer/DownloadPathButton
onready var download_path_file_dialog := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/DownloadPathContainer/DownloadPathFileDialog
onready var download_path_line_edit := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/DownloadPathContainer/DownloadPathLineEdit
onready var filter_type_buttons_container := $MainContainer/ColorSelectorContainer/HBoxContainer/FilterTypeButtonsContainer
onready var grid_container := $MainContainer/PalettesContainer/ScrollContainer/GridContainer
onready var http_request := $HTTPRequest
onready var next_button := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/ResultsWrapper/PaginationContainer/NextButton
onready var overlay_container := $MainContainer/PalettesContainer/OverlayContainer
onready var overlay_container_label := $MainContainer/PalettesContainer/OverlayContainer/OverlayLabel
onready var previous_button := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/ResultsWrapper/PaginationContainer/PreviousButton
onready var results_label := $MainContainer/ResultsAndDowloadPathContainer/ResultsAndDownloadPathWrapper/ResultsWrapper/ResultsContainer/ResultsLabel
onready var search_by_tag_line_edit := $MainContainer/SearchAndSortContainer/SearchByTagContainer/SearchByTagLineEdit
onready var slider := $MainContainer/ColorSelectorContainer/HBoxContainer/SliderContainer/Slider
onready var slider_line_edit := $MainContainer/ColorSelectorContainer/HBoxContainer/SliderContainer/SliderLineEdit
onready var sorting_buttons_container := $MainContainer/SearchAndSortContainer/SortingContainer/SortingButtonsContainer


func _ready():
	# Connect signals.
	connect("resized", self, "_on_main_window_resized")

	http_request.connect("request_completed", self, "_on_http_request_completed")

	for button in filter_type_buttons_container.get_children():
		button.connect("pressed", self, "_on_button_group_filter_type_pressed")
		button.toggle_mode = true
		button.group = button_group_filter_type

	for button in sorting_buttons_container.get_children():
		button.connect("pressed", self, "_on_button_group_sort_pressed")
		button.toggle_mode = true
		button.group = button_group_sort

	slider.connect("value_changed", self, "_on_slider_value_changed")
	slider_line_edit.connect("text_entered", self, "_on_slider_line_edit_text_entered")

	search_by_tag_line_edit.connect(
		"text_entered", self, "_on_search_by_tag_line_edit_text_entered"
	)
	search_by_tag_line_edit.connect(
		"text_changed", self, "_on_search_by_tag_line_edit_text_changed"
	)

	previous_button.connect("pressed", self, "_on_previous_button_pressed")
	next_button.connect("pressed", self, "_on_next_button_pressed")

	download_path_button.connect("pressed", self, "_on_download_path_button_pressed")
	download_path_file_dialog.connect(
		"dir_selected", self, "on_download_path_file_dialog_dir_selected"
	)

	# Create config file.
	config_create()

	# Set initial values.
	self.current_download_path = config_get("settings", "download_path")

	filter_type_buttons_container.get_child(0).pressed = true
	sorting_buttons_container.get_child(0).pressed = true

	slider_line_edit.text = str(query_params.number)
	slider.value = query_params.number

	results_label.text = "0 results"

	overlay_container.visible = false

	# Make the HTTP call.
	make_http_call()


func config_create() -> void:
	var f = File.new()

	if not f.file_exists(config_file):
		config.set_value("settings", "download_path", default_download_path)
		config.save(config_file)


func config_get(section: String, key: String) -> String:
	var error = config.load(config_file)
	if error != OK:
		push_error("ERROR: Couldn't load the config file!")

	return config.get_value("settings", "download_path")


func config_set(section: String, key: String, value: String) -> void:
	var error = config.load(config_file)
	if error != OK:
		push_error("ERROR: Couldn't load the config file!")

	config.set_value(section, key, value)
	config.save(config_file)


func set_query_string():
	query_string = (
		"?"
		+ "colorNumberFilterType="
		+ query_params.filter_type
		+ "&colorNumber="
		+ str(query_params.number)
		+ "&page="
		+ str(query_params.page)
		+ "&tag="
		+ query_params.tag
		+ "&sortingType="
		+ query_params.sorting_type
	)


func set_url():
	url = base_url + query_string


func make_http_call():
	if http_request.get_http_client_status() != 0:
		http_request.cancel_request()

	for child in grid_container.get_children():
		child.queue_free()

	overlay_container.visible = true
	overlay_container_label.text = "Loading..."
	results_label.text = "Loading..."

	set_query_string()
	set_url()

	if debug_mode:
		print(url)

	var error = http_request.request(url)
	if error != OK:
		overlay_container_label.text = "An error occurred in the HTTP request."
		overlay_container.visible = true
		results_label.text = "No results!"
		return


# https://stackoverflow.com/a/50848344 (CC BY-SA 4.0)
func editing_slider(new_value):
	if not slider_timer_on:
		slider_timer_on = true
		yield(get_tree().create_timer(0.2), "timeout")
		slider_timer_on = false

		if slider_editing_value != new_value:
			if debug_mode:
				print("continue editing")

			editing_slider(new_value)
		else:
			if debug_mode:
				print("slider set to " + str(slider.value))

			query_params.number = slider.value
			query_params.page = 0

			make_http_call()

	slider_editing_value = new_value


func _on_main_window_resized():
	var window_size = rect_size

	if OS.get_name() == "OSX" or OS.get_name() == "Windows":
		window_size /= 2

	if window_size.x < 768:
		grid_container.columns = 1
	elif window_size.x < 1280:
		grid_container.columns = 2
	elif window_size.x < 1440:
		grid_container.columns = 3
	else:
		grid_container.columns = 4


func _on_http_request_completed(result, response_code, headers, body):
	if result != 0 and response_code != 200:
		overlay_container_label.text = "ERROR: " + str(result) + "-" + str(response_code)
		overlay_container.visible = true
		results_label.text = "No results!"
		return

	var response = parse_json(body.get_string_from_utf8())

	if "error" in response and response.error:
		overlay_container_label.text = "ERROR: " + str(response.error)
		overlay_container.visible = true
		results_label.text = "No results!"
		return

	if not response.palettes:
		results_label.text = "No results!"

		overlay_container_label.text = "No results!"
		overlay_container.visible = true

		previous_button.disabled = true
		next_button.disabled = true

		return

	total_count = response.totalCount
	items_per_page = response.palettes.size()
	max_pages = ceil(total_count / items_per_page) - 1

	if total_count <= items_per_page:
		previous_button.disabled = true
		next_button.disabled = true
	else:
		previous_button.disabled = false
		next_button.disabled = false

	for i in response.palettes.size():
		var palette_item_instance = palette_item_container.instance()

		grid_container.add_child(palette_item_instance)

		palette_item_instance.title.text = response.palettes[i].title

		if "user" in response.palettes[i]:
			palette_item_instance.created_by.text = "Created by: " + response.palettes[i].user.name
		else:
			palette_item_instance.created_by.text = ""

		if "tags" in response.palettes[i] and response.palettes[i].tags:
			for tag in response.palettes[i].tags:
				var tag_button = Button.new()

				tag_button.flat = true
				tag_button.text = tag
				tag_button.connect("pressed", self, "_on_tag_button_pressed", [tag_button.text])

				palette_item_instance.tags_list.add_child(tag_button)
		else:
			palette_item_instance.tags_label.text = ""

		var palette_colors = []

		for color in response.palettes[i].colors:
			palette_colors.append('"#' + color + '"')

			var color_rect = ColorRect.new()

			color_rect.color = color

			var ratio = 8

			if response.palettes[i].colors.size() >= 4:
				ratio = 7.5
			if response.palettes[i].colors.size() >= 8:
				ratio = 7
			if response.palettes[i].colors.size() >= 12:
				ratio = 6.5
			if response.palettes[i].colors.size() >= 16:
				ratio = 6
			if response.palettes[i].colors.size() >= 24:
				ratio = 5.5
			if response.palettes[i].colors.size() >= 32:
				ratio = 5
			if response.palettes[i].colors.size() >= 48:
				ratio = 4.5
			if response.palettes[i].colors.size() >= 64:
				ratio = 4
			if response.palettes[i].colors.size() >= 96:
				ratio = 3.5
			if response.palettes[i].colors.size() >= 128:
				ratio = 3
			if response.palettes[i].colors.size() >= 192:
				ratio = 2.5
			if response.palettes[i].colors.size() >= 256:
				ratio = 2

			color_rect.rect_min_size = Vector2.ONE * (base_color_rect_size * ratio)
			color_rect.rect_size = color_rect.rect_min_size

			palette_item_instance.colors_grid.add_child(color_rect)

		palette_item_instance.palette_colors = palette_colors
		palette_item_instance.slug = response.palettes[i].slug
		palette_item_instance.current_download_path = current_download_path

	results_label.text = str(total_count) + " results"

	if query_params.page == 0:
		previous_button.disabled = true

	overlay_container.visible = false


func _on_button_group_filter_type_pressed():
	var pressed_button = button_group_filter_type.get_pressed_button()

	if pressed_button == current_pressed_filter_type_button:
		return

	current_pressed_filter_type_button = pressed_button

	query_params.filter_type = current_pressed_filter_type_button.name.to_lower()
	slider_line_edit.emit_signal("text_entered", slider_line_edit.text)

	make_http_call()


func _on_button_group_sort_pressed():
	var pressed_button = button_group_sort.get_pressed_button()

	if pressed_button == current_pressed_sort_button:
		return

	current_pressed_sort_button = pressed_button

	query_params.sorting_type = current_pressed_sort_button.name.to_lower()

	make_http_call()


func _on_slider_value_changed(value):
	editing_slider(value)

	slider_line_edit.text = str(value)


func _on_slider_line_edit_text_entered(new_text):
	slider.value = int(new_text)


func _on_search_by_tag_line_edit_text_entered(new_text):
	var tags = new_text.split(",")
	var tags_query = ""

	for tag in tags:
		tags_query += tag.strip_edges().replace(" ", "%20") + ","

	tags_query.erase(tags_query.length() - 1, 1)

	query_params.tag = tags_query

	make_http_call()


func _on_search_by_tag_line_edit_text_changed(new_text):
	if not new_text:
		query_params.tag = new_text

		make_http_call()


func _on_previous_button_pressed():
	query_params.page -= 1

	if query_params.page == 0:
		previous_button.disabled = true

	if query_params.page < max_pages:
		next_button.disabled = false

	make_http_call()


func _on_next_button_pressed():
	query_params.page += 1

	if query_params.page >= 1:
		previous_button.disabled = false

	if query_params.page == max_pages:
		next_button.disabled = true

	make_http_call()


func _on_download_path_button_pressed() -> void:
	download_path_file_dialog.current_dir = current_download_path
	download_path_file_dialog.popup_centered_ratio(0.5)


func on_download_path_file_dialog_dir_selected(dir: String) -> void:
	config_set("settings", "download_path", dir)

	self.current_download_path = config_get("settings", "download_path")


func _on_tag_button_pressed(text) -> void:
	search_by_tag_line_edit.text = text
	search_by_tag_line_edit.emit_signal("text_entered", text)


func _set_current_download_path(new_value) -> void:
	if new_value != current_download_path:
		current_download_path = new_value

		download_path_line_edit.text = current_download_path

		for item in get_tree().get_nodes_in_group("palette_item_container"):
			item.current_download_path = current_download_path
