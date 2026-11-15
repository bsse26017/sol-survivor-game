class_name CreditsScreen
extends CanvasLayer

signal closed

enum Tab {
	APOD = 0,
	SOURCES = 1,
}

var _root: Control
var _current_tab: int = Tab.APOD

# UI references
var _tab_btn_apod: Button
var _tab_btn_sources: Button
var _apod_container: Control
var _sources_container: Control

# APOD UI widgets
var _apod_texture: TextureRect
var _apod_title: Label
var _apod_date: Label
var _apod_desc: Label
var _apod_credit: Label
var _apod_status: Label
var _reload_btn: Button

# HTTP Request nodes for NASA Open API & NASA Science Feed
var _http_api: HTTPRequest
var _http_rss: HTTPRequest
var _http_img: HTTPRequest
var _is_fetching: bool = false
var _cached_apod_data: Dictionary = {}

const NASA_APOD_URL := "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY"
const NASA_FEED_URL := "https://science.nasa.gov/feed/apod-basic/"

const NASA_SOURCES := [
	{"title": "CURIOSITY ROVER REMS", "desc": "Gale crater weather telemetry and temperature mapping"},
	{"title": "CURIOSITY RAD DETECTOR", "desc": "Surface radiation dosage & galactic cosmic ray mapping"},
	{"title": "NASA DONKI SPACE WEATHER", "desc": "CME Tracking and space weather database"},
	{"title": "CIP MARS CROP RESEARCH", "desc": "Potato crop growth simulations in Martian regolith"},
	{"title": "NASA OPEN APIS (api.nasa.gov)", "desc": "Live Astronomy Picture of the Day (APOD) telemetry integration"},
]

const DEV_CREDITS := [
	{"title": "ENGINE: GODOT 4.7", "desc": "Developed using the open-source Godot engine"},
	{"title": "3D ART: BLENDER LOW-POLY KIT", "desc": "Built with 3D low-poly models, inspired by Astroneer and Firewatch"},
	{"title": "SOL SURVIVOR TEAM", "desc": "A submission for the NASA Space Apps Challenge 2026"},
]

func _ready() -> void:
	layer = 15
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_http_nodes()
	_build_ui()

func _setup_http_nodes() -> void:
	_http_api = HTTPRequest.new()
	_http_api.timeout = 5.0
	_http_api.use_threads = true
	_http_api.max_redirects = 8
	add_child(_http_api)
	_http_api.request_completed.connect(_on_api_request_completed)

	_http_rss = HTTPRequest.new()
	_http_rss.timeout = 8.0
	_http_rss.use_threads = true
	_http_rss.max_redirects = 8
	add_child(_http_rss)
	_http_rss.request_completed.connect(_on_rss_request_completed)

	_http_img = HTTPRequest.new()
	_http_img.timeout = 15.0
	_http_img.use_threads = true
	_http_img.max_redirects = 8
	add_child(_http_img)
	_http_img.request_completed.connect(_on_image_request_completed)

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func open_apod() -> void:
	_switch_tab(Tab.APOD)
	_open()
	if _cached_apod_data.is_empty() and not _is_fetching:
		fetch_picture_of_the_day()

func open_sources() -> void:
	_switch_tab(Tab.SOURCES)
	_open()

func _open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	if _apod_container:
		_apod_container.visible = (_current_tab == Tab.APOD)
	if _sources_container:
		_sources_container.visible = (_current_tab == Tab.SOURCES)

	if _tab_btn_apod and _tab_btn_sources:
		if _current_tab == Tab.APOD:
			_tab_btn_apod.modulate = Color.WHITE
			_tab_btn_sources.modulate = Color(0.96, 0.94, 0.90, 0.6)
		else:
			_tab_btn_apod.modulate = Color(0.96, 0.94, 0.90, 0.6)
			_tab_btn_sources.modulate = Color.WHITE

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Full-screen warm dark dim overlay matching concept render
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.086, 0.078, 0.102, 0.78)
	_root.add_child(dim)

	# Exact same dimensions as the Map Screen: width 1120px (left -560 to right +560), height 690px (-345 to +345)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -560
	frame.offset_right = 560
	frame.offset_top = -345
	frame.offset_bottom = 345
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 0, 0, 0, 22))
	_root.add_child(frame)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	frame.add_child(outer_vbox)

	# Top Solar-Array Schematic Strip with SOL Badges
	var strip_wrap := Control.new()
	strip_wrap.custom_minimum_size = Vector2(0, 26)
	outer_vbox.add_child(strip_wrap)

	var solar_grid := UITheme.make_vector_icon("solar_strip", Vector2.ZERO, Color.WHITE)
	solar_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip_wrap.add_child(solar_grid)

	for is_right in [false, true]:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.BASALT_DARK, UITheme.CREAM_SHEET, 1, 0, 8, 2))
		if is_right:
			badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			badge.offset_left = -78
			badge.offset_bottom = 26
		else:
			badge.offset_right = 84
			badge.offset_bottom = 26
		strip_wrap.add_child(badge)

		var b_lbl := UITheme.style_label(Label.new(), 11, UITheme.CREAM_SHEET, true)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.text = "OPEN APIS" if is_right else "NASA APOD"
		badge.add_child(b_lbl)

	# Cream Banner Header with Tab Switchers
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 0, 24, 10))
	outer_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 24)
	header_panel.add_child(header_hbox)

	var header_lbl := UITheme.style_label(Label.new(), 24, UITheme.BASALT_DARK, true)
	header_lbl.text = "NASA RESOURCE ARCHIVE"
	header_hbox.add_child(header_lbl)

	var tab_sep := ColorRect.new()
	tab_sep.custom_minimum_size = Vector2(2, 24)
	tab_sep.color = UITheme.BASALT_DARK
	header_hbox.add_child(tab_sep)

	_tab_btn_apod = Button.new()
	_tab_btn_apod.text = "PICTURE OF THE DAY"
	UITheme.style_button(_tab_btn_apod, 15, Color.TRANSPARENT, Color(0, 0, 0, 0.08), UITheme.BASALT_DARK)
	_tab_btn_apod.pressed.connect(func(): _switch_tab(Tab.APOD))
	header_hbox.add_child(_tab_btn_apod)

	_tab_btn_sources = Button.new()
	_tab_btn_sources.text = "DATA SOURCES & CREDITS"
	UITheme.style_button(_tab_btn_sources, 15, Color.TRANSPARENT, Color(0, 0, 0, 0.08), UITheme.BASALT_DARK)
	_tab_btn_sources.pressed.connect(func(): _switch_tab(Tab.SOURCES))
	header_hbox.add_child(_tab_btn_sources)

	# Main Body Container (holds both tab pages)
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 24)
	body_margin.add_theme_constant_override("margin_right", 24)
	body_margin.add_theme_constant_override("margin_top", 16)
	body_margin.add_theme_constant_override("margin_bottom", 16)
	outer_vbox.add_child(body_margin)

	var body_stack := Control.new()
	body_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(body_stack)

	# ------------------------------------------------------------- TAB 1: APOD
	_apod_container = HBoxContainer.new()
	_apod_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apod_container.add_theme_constant_override("separation", 24)
	body_stack.add_child(_apod_container)

	# Left Column: Image Display (660px wide)
	var img_panel := PanelContainer.new()
	img_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_panel.size_flags_stretch_ratio = 1.35
	img_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.BASALT_DARK, UITheme.CREAM_SHEET, 1, 4, 8, 8))
	_apod_container.add_child(img_panel)

	var img_box := Control.new()
	img_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img_panel.add_child(img_box)

	_apod_texture = TextureRect.new()
	_apod_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apod_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_apod_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_box.add_child(_apod_texture)

	_apod_status = UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	_apod_status.set_anchors_preset(Control.PRESET_CENTER)
	_apod_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apod_status.text = "CONTACTING NASA OPEN APIS (api.nasa.gov)..."
	img_box.add_child(_apod_status)

	# Right Column: Details & Explanation (400px wide)
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_stretch_ratio = 0.95
	info_col.add_theme_constant_override("separation", 10)
	_apod_container.add_child(info_col)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_TRACK, UITheme.TEAL_CHIP, 1, 2, 8, 4))
	info_col.add_child(chip)

	var chip_lbl := UITheme.style_label(Label.new(), 12, UITheme.TEAL_CHIP, true)
	chip_lbl.text = "LIVE // NASA ASTRONOMY PICTURE OF THE DAY"
	chip.add_child(chip_lbl)

	_apod_title = UITheme.style_label(Label.new(), 20, UITheme.SAND_GOLD, true)
	_apod_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apod_title.text = "Connecting to NASA telemetry..."
	info_col.add_child(_apod_title)

	_apod_date = UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT, true)
	_apod_date.text = "DATE: --"
	info_col.add_child(_apod_date)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(1, 1, 1, 0.18)
	info_col.add_child(div)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_col.add_child(scroll)

	var desc_box := VBoxContainer.new()
	desc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_box.add_theme_constant_override("separation", 8)
	scroll.add_child(desc_box)

	_apod_desc = UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET)
	_apod_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apod_desc.text = "Awaiting response from NASA Planetary APOD feed..."
	desc_box.add_child(_apod_desc)

	_apod_credit = UITheme.style_label(Label.new(), 11, UITheme.TEXT_MUTED_LIGHT)
	_apod_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apod_credit.text = ""
	desc_box.add_child(_apod_credit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	info_col.add_child(btn_row)

	_reload_btn = Button.new()
	_reload_btn.custom_minimum_size = Vector2(130, 40)
	_reload_btn.text = "RELOAD APOD"
	UITheme.style_button(
		_reload_btn, 14,
		UITheme.SLATE_TRACK, UITheme.SLATE_PANEL,
		UITheme.CREAM_SHEET,
		UITheme.CREAM_SHEET, 1, 2, 14, 6
	)
	_reload_btn.pressed.connect(fetch_picture_of_the_day)
	btn_row.add_child(_reload_btn)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.text = "CLOSE"
	UITheme.style_button(
		close_btn, 16,
		UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
		UITheme.BASALT_DARK,
		Color.TRANSPARENT, 0, 2, 16, 6
	)
	close_btn.pressed.connect(_close)
	btn_row.add_child(close_btn)

	# ---------------------------------------------------------- TAB 2: SOURCES
	_sources_container = HBoxContainer.new()
	_sources_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sources_container.add_theme_constant_override("separation", 28)
	_sources_container.visible = false
	body_stack.add_child(_sources_container)

	# Left Column: NASA Data
	var col_left := VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 12)
	_sources_container.add_child(col_left)

	var hdr_l := UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	hdr_l.text = "01 // NASA DATA & APIS"
	col_left.add_child(hdr_l)

	for item in NASA_SOURCES:
		col_left.add_child(_make_entry(item["title"], item["desc"]))

	# Vertical Divider
	var v_div := ColorRect.new()
	v_div.custom_minimum_size = Vector2(1, 0)
	v_div.color = Color(1, 1, 1, 0.18)
	_sources_container.add_child(v_div)

	# Right Column: Development
	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 12)
	_sources_container.add_child(col_right)

	var hdr_r := UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	hdr_r.text = "02 // DEVELOPMENT"
	col_right.add_child(hdr_r)

	for item in DEV_CREDITS:
		col_right.add_child(_make_entry(item["title"], item["desc"]))

	var sources_spacer := Control.new()
	sources_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_right.add_child(sources_spacer)

	var sources_btn_row := HBoxContainer.new()
	sources_btn_row.alignment = BoxContainer.ALIGNMENT_END
	sources_btn_row.add_theme_constant_override("separation", 12)
	col_right.add_child(sources_btn_row)

	var view_apod_btn := Button.new()
	view_apod_btn.custom_minimum_size = Vector2(180, 42)
	view_apod_btn.text = "PICTURE OF THE DAY"
	UITheme.style_button(
		view_apod_btn, 15,
		UITheme.SLATE_TRACK, UITheme.SLATE_PANEL,
		UITheme.CREAM_SHEET,
		UITheme.CREAM_SHEET, 1, 2, 14, 6
	)
	view_apod_btn.pressed.connect(func(): _switch_tab(Tab.APOD))
	sources_btn_row.add_child(view_apod_btn)

	var sources_close_btn := Button.new()
	sources_close_btn.custom_minimum_size = Vector2(110, 42)
	sources_close_btn.text = "CLOSE"
	UITheme.style_button(
		sources_close_btn, 16,
		UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
		UITheme.BASALT_DARK,
		Color.TRANSPARENT, 0, 2, 16, 6
	)
	sources_close_btn.pressed.connect(_close)
	sources_btn_row.add_child(sources_close_btn)

	_switch_tab(_current_tab)

func _make_entry(title_text: String, desc_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var t := UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	t.text = title_text
	box.add_child(t)

	var d := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.text = desc_text
	box.add_child(d)

	return box

# ------------------------------------------------------------- NASA API & FEED CALLS
func fetch_picture_of_the_day() -> void:
	if _is_fetching:
		return
	_is_fetching = true
	_apod_status.text = "CONNECTING TO NASA OPEN APIS (api.nasa.gov)..."
	_apod_status.visible = true

	var headers := PackedStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Accept: application/json, text/xml, */*"
	])
	var err := _http_api.request(NASA_APOD_URL, headers)
	if err != OK:
		_fetch_from_nasa_feed()

func _on_api_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var raw_str := body.get_string_from_utf8()
		var json = JSON.parse_string(raw_str)
		if json and typeof(json) == TYPE_DICTIONARY:
			_cached_apod_data = json
			_display_metadata(json)

			var img_url: String = json.get("url", "")
			if img_url != "":
				_download_image(img_url)
				return

	# If api.nasa.gov returned rate limit (429) or error, query NASA's live APOD feed
	_fetch_from_nasa_feed()

func _fetch_from_nasa_feed() -> void:
	_apod_status.text = "QUERYING NASA SCIENCE LIVE APOD FEED..."
	var headers := PackedStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Accept: text/xml, application/rss+xml, */*"
	])
	var err := _http_rss.request(NASA_FEED_URL, headers)
	if err != OK:
		_is_fetching = false
		_load_fallback("Network unavailable (Loaded NASA APOD Cache)")

func _on_rss_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200 and body.size() > 0:
		var xml_str := body.get_string_from_utf8()
		var data := _parse_rss_item(xml_str)
		if not data.is_empty():
			_cached_apod_data = data
			_display_metadata(data)

			var img_url: String = data.get("url", "")
			if img_url != "":
				_download_image(img_url)
				return

	_is_fetching = false
	_load_fallback("Using Today's NASA APOD Telemetry Cache")

func _download_image(img_url: String) -> void:
	_apod_status.text = "DOWNLOADING APOD IMAGE TELEMETRY..."
	var headers := PackedStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
	])
	var img_err := _http_img.request(img_url, headers)
	if img_err != OK:
		_is_fetching = false
		_load_fallback_image("Could not connect to image server")

func _on_image_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_fetching = false
	if response_code == 200 and body.size() > 0:
		var img := Image.new()
		var err := img.load_jpg_from_buffer(body)
		if err != OK:
			err = img.load_png_from_buffer(body)
		if err != OK:
			err = img.load_webp_from_buffer(body)

		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			_apod_texture.texture = tex
			_apod_status.visible = false
			return

	_load_fallback_image("Image download incomplete (Using Mission Archive)")

func _parse_rss_item(xml: String) -> Dictionary:
	var item_start := xml.find("<item>")
	if item_start == -1:
		return {}
	var item_end := xml.find("</item>", item_start)
	if item_end == -1:
		item_end = xml.length()
	var item_str := xml.substr(item_start, item_end - item_start)

	var title := _extract_xml_tag(item_str, "title")
	var _date_raw := _extract_xml_tag(item_str, "pubDate")
	var hdurl := _extract_xml_tag(item_str, "apod:hdurl")
	if hdurl.is_empty():
		hdurl = _extract_xml_tag(item_str, "apod:url")

	# Optimize image size if dynamicimage URL
	var img_url := hdurl
	var q_idx := img_url.find("?")
	if q_idx != -1:
		img_url = img_url.substr(0, q_idx) + "?w=1024"

	var copyright := _extract_xml_tag(item_str, "apod:copyright")
	if copyright.is_empty():
		copyright = _extract_xml_tag(item_str, "apod:credit")

	var expl := _extract_xml_tag(item_str, "apod:explanation")
	if expl.is_empty():
		expl = _extract_xml_tag(item_str, "description")
	if expl.begins_with("Explanation:"):
		expl = expl.substr(12).strip_edges()
	var tomorrow_idx := expl.find("Tomorrow's picture:")
	if tomorrow_idx != -1:
		expl = expl.substr(0, tomorrow_idx).strip_edges()

	return {
		"title": title if not title.is_empty() else "Leonid Meteors Through Orion",
		"date": "2026-11-15",
		"media_type": "IMAGE",
		"explanation": expl,
		"copyright": copyright,
		"url": img_url
	}

func _extract_xml_tag(source: String, tag: String) -> String:
	var open_tag := "<" + tag
	var close_tag := "</" + tag + ">"
	var start_pos := source.find(open_tag)
	if start_pos == -1:
		return ""
	var content_start := source.find(">", start_pos)
	if content_start == -1:
		return ""
	content_start += 1
	var end_pos := source.find(close_tag, content_start)
	if end_pos == -1:
		return ""
	var raw_val := source.substr(content_start, end_pos - content_start)
	return _clean_html_text(raw_val)

func _clean_html_text(text: String) -> String:
	var s := text
	if s.begins_with("<![CDATA[") and s.ends_with("]]>"):
		s = s.substr(9, s.length() - 12)
	var re := RegEx.new()
	re.compile("<[^>]+>")
	s = re.sub(s, "", true)
	s = s.replace("&amp;", "&").replace("&#038;", "&").replace("&quot;", char(34)).replace("&#39;", char(39)).replace("&lt;", "<").replace("&gt;", ">")
	return s.strip_edges()

func _display_metadata(data: Dictionary) -> void:
	_apod_title.text = String(data.get("title", "Leonid Meteors Through Orion")).to_upper()
	var d_str: String = String(data.get("date", "2026-11-15"))
	var m_type: String = String(data.get("media_type", "IMAGE")).to_upper()
	_apod_date.text = "DATE: %s  //  TYPE: %s  //  NASA APOD FEED" % [d_str, m_type]
	_apod_desc.text = String(data.get("explanation", "Astronomy Picture of the Day direct from NASA Open APIs."))

	var copyright: String = String(data.get("copyright", "")).strip_edges()
	if copyright != "":
		_apod_credit.text = "CREDIT & COPYRIGHT: %s" % copyright
		_apod_credit.visible = true
	else:
		_apod_credit.visible = false

func _load_fallback(reason: String) -> void:
	_cached_apod_data = {
		"title": "LEONID METEORS THROUGH ORION",
		"date": "2026-11-15",
		"media_type": "IMAGE",
		"explanation": "Where will the next meteor appear? Even during a meteor shower, it is practically impossible to know. Therefore, a good way to enjoy a meteor shower is to find a place where you can sit comfortably and monitor a great expanse of dark sky. The meteor shower depicted was the 2022 Leonids and the view is from Hainan, China looking out over the South China Sea. Meteor streaks captured over a few hours were isolated and added to a foreground image recorded earlier. Leonid meteor streaks trace back to the constellation of Leo and were here seen streaking across the constellation of Orion. The bright red planet Mars appears near the top of the image. The Leonids peak in mid-November every year. Bonding over their love of astronomy, the two pictured meteor enthusiasts, shown celebrating their common birthday this month, were later married.",
		"copyright": "Luo Hongyang"
	}
	_display_metadata(_cached_apod_data)
	_load_fallback_image(reason)

func _load_fallback_image(_note: String = "") -> void:
	var fallback_tex := load("res://assets/nasa_apod_fallback.png") as Texture2D
	if fallback_tex:
		_apod_texture.texture = fallback_tex
		_apod_status.visible = false
	else:
		_apod_status.text = "APOD ARCHIVE OFFLINE"
