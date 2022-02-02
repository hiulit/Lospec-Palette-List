tool
extends HBoxContainer

var images_base_url = "https://lospec.com/palette-list"
var palette_image_sizes = [1, 8, 32]

var current_download_path
var download_popup
var file_name
var palette_colors
var slug

onready var colors_grid := $PaletteItemInner/PaletteItem/ColorsGrid
onready var copy_button := $PaletteItemInner/PaletteItem/PaletteItemHeader/CopyButton
onready var created_by := $PaletteItemInner/PaletteItem/PaletteItemHeader/TitleContainer/CreatedBy
onready var download_menu_button := $PaletteItemInner/PaletteItem/PaletteItemHeader/DownloadMenuButton
onready var http_request := $PaletteItemInner/PaletteItem/PaletteItemHeader/DownloadMenuButton/HTTPRequest
onready var tags_label := $PaletteItemInner/PaletteItem/TagsContainer/TagsLabel
onready var tags_list := $PaletteItemInner/PaletteItem/TagsContainer/TagsList
onready var title := $PaletteItemInner/PaletteItem/PaletteItemHeader/TitleContainer/Title


func _ready():
	add_to_group("palette_item_container")

	# Connect signals
	http_request.connect("request_completed", self, "_on_http_request_request_completed")
	copy_button.connect("pressed", self, "_on_copy_button_pressed")

	# Create download popup.
	download_popup = download_menu_button.get_popup()
	download_popup.clear()
	for size in palette_image_sizes:
		download_popup.add_item("PNG Image (%sx)" % str(size))
	download_popup.connect("id_pressed", self, "_on_download_popup_item_pressed")


func _on_copy_button_pressed():
	OS.set_clipboard(str(palette_colors))

	copy_button.disabled = true
	copy_button.text = "Copied!"
	yield(get_tree().create_timer(0.5), "timeout")
	copy_button.disabled = false
	copy_button.text = "Copy"


func _on_download_popup_item_pressed(id):
	var item_name = download_popup.get_item_text(id)
	var size = item_name.split("(")[1].replace(")", "")

	file_name = slug + "-" + size + ".png"

	var url = images_base_url + "/" + file_name

	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return

	download_menu_button.disabled = true
	download_menu_button.text = "Downloading..."


func _on_http_request_request_completed(_result, _response_code, _headers, body):
	var image = Image.new()

	var error = image.load_png_from_buffer(body)
	if error != OK:
		print("Couldn't load the image.")
		download_menu_button.disabled = false
		download_menu_button.text = "Download"
		return

	image.save_png(current_download_path.plus_file(file_name))

	download_menu_button.text = "Downloaded!"
	yield(get_tree().create_timer(0.75), "timeout")
	download_menu_button.disabled = false
	download_menu_button.text = "Download"
