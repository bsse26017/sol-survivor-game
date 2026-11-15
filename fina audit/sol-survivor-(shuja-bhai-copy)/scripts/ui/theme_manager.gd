class_name UITheme
extends RefCounted

# Exact Render Palette
const BASALT_DARK := Color("#16141A")
const SLATE_PANEL := Color("#1B2030")
const SLATE_TRACK := Color("#2D3548")
const SLATE_HUD := Color(0.106, 0.125, 0.188, 0.84)
const CREAM_SHEET := Color("#F5EFE6")
const CREAM_NOTE := Color("#E7DEC8")
const CREAM_HOVER := Color("#EBE2D3")
const TERRACOTTA := Color("#D95D39")
const TERRACOTTA_HOVER := Color("#E56B47")
const TEAL_CHIP := Color("#5EA394")
const SAGE_POSITIVE := Color("#69A478")
const SAGE_CHECK := Color("#7DA87B")
const SAND_GOLD := Color("#DFC896")
const SAND_NEUTRAL := Color("#D6C69C")
const TEXT_MUTED_LIGHT := Color("#C4CCD8")
const TEXT_MUTED_DARK := Color("#3E3A36")

# Legacy Compatibility Aliases
const COL_TEAL := TEAL_CHIP
const COL_CREAM := CREAM_SHEET
const COL_SLATE := SLATE_PANEL
const COL_RUST := TERRACOTTA

static var _body_font: Font = null
static var _display_font: Font = null
static var _fonts_scanned: bool = false

static var FONT_NUNITO: Font:
	get:
		return get_font()

static func _scan_fonts() -> void:
	if _fonts_scanned:
		return
	_fonts_scanned = true

	var found_fonts: Array[String] = []
	var dir := DirAccess.open("res://assets/fonts")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and (fname.ends_with(".ttf") or fname.ends_with(".otf")):
				found_fonts.append("res://assets/fonts/" + fname)
			fname = dir.get_next()

	for path in found_fonts:
		var lower := path.to_lower()
		if "oswald" in lower or "bebas" in lower or "condensed" in lower or "display" in lower:
			_display_font = load(path)
		elif "jetbrains" in lower or "mono" in lower or "nunito" in lower or "inter" in lower:
			_body_font = load(path)

	if _display_font == null and not found_fonts.is_empty():
		_display_font = load(found_fonts[0])
	if _body_font == null and not found_fonts.is_empty():
		_body_font = load(found_fonts[-1])

	if _display_font == null:
		_display_font = ThemeDB.fallback_font
	if _body_font == null:
		_body_font = ThemeDB.fallback_font

static func get_font() -> Font:
	_scan_fonts()
	return _body_font

static func get_heavy_font() -> Font:
	_scan_fonts()
	return _display_font

static func create_panel_style(
	bg: Color = SLATE_PANEL,
	border: Color = CREAM_SHEET,
	border_w: int = 2,
	radius: int = 2
) -> StyleBoxFlat:
	return make_flat_box(bg, border, border_w, radius, 24, 20)

static func make_flat_box(
	bg: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = 2,
	pad_h: int = 16,
	pad_v: int = 12,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner_radius)
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	box.anti_aliasing = true
	if shadow_size > 0:
		box.shadow_color = Color(0.05, 0.04, 0.07, 0.42)
		box.shadow_size = shadow_size
		box.shadow_offset = Vector2(0, 6)
	return box

## Round gold coin used by the HUD counter, night summary and debrief.
static func make_coin_icon(diameter: float = 16.0) -> Control:
	var coin := PanelContainer.new()
	coin.custom_minimum_size = Vector2(diameter, diameter)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_theme_stylebox_override("panel",
			make_flat_box(SAND_GOLD, Color("#B8892B"), 2, int(diameter / 2.0), 0, 0))
	return coin


static func style_label(
	label: Label,
	size: int,
	color: Color,
	uppercase: bool = false,
	shadow: bool = false
) -> Label:
	label.add_theme_font_override("font", get_heavy_font() if size >= 20 else get_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.uppercase = uppercase
	if shadow:
		label.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.04, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 3)
	return label

static func style_button(
	btn: Button,
	size: int = 16,
	bg_normal: Color = TERRACOTTA,
	bg_hover: Color = TERRACOTTA_HOVER,
	text_color: Color = BASALT_DARK,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = 3,
	pad_h: int = 18,
	pad_v: int = 10
) -> Button:
	btn.add_theme_font_override("font", get_heavy_font() if size >= 18 else get_font())
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_focus_color", text_color)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn.add_theme_stylebox_override("normal", make_flat_box(bg_normal, border_color, border_width, corner_radius, pad_h, pad_v))
	btn.add_theme_stylebox_override("hover", make_flat_box(bg_hover, border_color, border_width, corner_radius, pad_h, pad_v))
	btn.add_theme_stylebox_override("pressed", make_flat_box(bg_hover.darkened(0.1), border_color, border_width, corner_radius, pad_h, pad_v))
	return btn

static func make_vector_icon(icon_type: String, icon_size: Vector2, tint: Color, shrink_center: bool = true) -> Control:
	var glyph := UIVectorGlyph.new()
	glyph.glyph_type = icon_type
	glyph.tint = tint
	if icon_size != Vector2.ZERO:
		glyph.custom_minimum_size = icon_size
	if shrink_center:
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


class UIVectorGlyph extends Control:
	var glyph_type: String = ""
	var tint: Color = Color.WHITE

	func _draw() -> void:
		var s := size
		var cx := s.x * 0.5
		var cy := s.y * 0.5
		# Uniform square dimension prevents any icon distortion regardless of container height
		var d := minf(s.x, s.y)
		var ox := cx - d * 0.5
		var oy := cy - d * 0.5

		match glyph_type:
			"lungs":
				draw_line(Vector2(cx, oy + d * 0.12), Vector2(cx, oy + d * 0.44), tint, maxf(2.0, d * 0.08), true)
				draw_line(Vector2(cx, oy + d * 0.40), Vector2(cx - d * 0.16, oy + d * 0.50), tint, maxf(1.8, d * 0.07), true)
				draw_line(Vector2(cx, oy + d * 0.40), Vector2(cx + d * 0.16, oy + d * 0.50), tint, maxf(1.8, d * 0.07), true)
				var left_lobe := PackedVector2Array([
					Vector2(cx - d * 0.08, oy + d * 0.28),
					Vector2(cx - d * 0.34, oy + d * 0.40),
					Vector2(cx - d * 0.38, oy + d * 0.84),
					Vector2(cx - d * 0.08, oy + d * 0.84),
				])
				var right_lobe := PackedVector2Array([
					Vector2(cx + d * 0.08, oy + d * 0.28),
					Vector2(cx + d * 0.34, oy + d * 0.40),
					Vector2(cx + d * 0.38, oy + d * 0.84),
					Vector2(cx + d * 0.08, oy + d * 0.84),
				])
				draw_colored_polygon(left_lobe, tint)
				draw_colored_polygon(right_lobe, tint)

			"lightning":
				var bolt := PackedVector2Array([
					Vector2(cx + d * 0.08, oy + d * 0.08),
					Vector2(cx - d * 0.26, oy + d * 0.54),
					Vector2(cx - d * 0.02, oy + d * 0.54),
					Vector2(cx - d * 0.10, oy + d * 0.92),
					Vector2(cx + d * 0.28, oy + d * 0.44),
					Vector2(cx + d * 0.04, oy + d * 0.44),
				])
				draw_colored_polygon(bolt, tint)

			"apple":
				# Clean overlapping twin circles for plump apple body + stem & leaf
				draw_circle(Vector2(cx - d * 0.13, cy + d * 0.10), d * 0.26, tint)
				draw_circle(Vector2(cx + d * 0.13, cy + d * 0.10), d * 0.26, tint)
				draw_line(Vector2(cx, cy - d * 0.10), Vector2(cx + d * 0.05, oy + d * 0.14), tint, maxf(2.0, d * 0.07), true)
				var leaf := PackedVector2Array([
					Vector2(cx + d * 0.04, oy + d * 0.22),
					Vector2(cx + d * 0.28, oy + d * 0.14),
					Vector2(cx + d * 0.20, oy + d * 0.30),
				])
				draw_colored_polygon(leaf, tint)

			"utensils":
				var fx := cx - d * 0.18
				draw_line(Vector2(fx, oy + d * 0.42), Vector2(fx, oy + d * 0.88), tint, 2.4)
				draw_line(Vector2(fx - d * 0.10, oy + d * 0.14), Vector2(fx - d * 0.10, oy + d * 0.42), tint, 2.0)
				draw_line(Vector2(fx, oy + d * 0.14), Vector2(fx, oy + d * 0.42), tint, 2.0)
				draw_line(Vector2(fx + d * 0.10, oy + d * 0.14), Vector2(fx + d * 0.10, oy + d * 0.42), tint, 2.0)
				draw_line(Vector2(fx - d * 0.10, oy + d * 0.42), Vector2(fx + d * 0.10, oy + d * 0.42), tint, 2.2)

				var kx := cx + d * 0.18
				draw_line(Vector2(kx, oy + d * 0.14), Vector2(kx, oy + d * 0.88), tint, 2.6)
				var blade := PackedVector2Array([
					Vector2(kx, oy + d * 0.14),
					Vector2(kx + d * 0.12, oy + d * 0.26),
					Vector2(kx + d * 0.12, oy + d * 0.52),
					Vector2(kx, oy + d * 0.52),
				])
				draw_colored_polygon(blade, tint)

			"shield":
				var outer := PackedVector2Array([
					Vector2(cx, oy + d * 0.10),
					Vector2(ox + d * 0.84, oy + d * 0.24),
					Vector2(ox + d * 0.78, oy + d * 0.62),
					Vector2(cx, oy + d * 0.90),
					Vector2(ox + d * 0.22, oy + d * 0.62),
					Vector2(ox + d * 0.16, oy + d * 0.24),
				])
				draw_colored_polygon(outer, tint)

			"house":
				var roof := PackedVector2Array([
					Vector2(cx, oy + d * 0.16),
					Vector2(ox + d * 0.86, oy + d * 0.50),
					Vector2(ox + d * 0.14, oy + d * 0.50),
				])
				draw_colored_polygon(roof, tint)
				draw_rect(Rect2(ox + d * 0.24, oy + d * 0.48, d * 0.52, d * 0.36), tint)

			"plus":
				draw_line(Vector2(cx, oy + d * 0.20), Vector2(cx, oy + d * 0.80), tint, 2.4)
				draw_line(Vector2(ox + d * 0.20, cy), Vector2(ox + d * 0.80, cy), tint, 2.4)

			"arrow_right":
				draw_line(Vector2(s.x * 0.10, cy), Vector2(s.x * 0.86, cy), tint, 2.4, true)
				draw_line(Vector2(s.x * 0.60, cy - s.y * 0.26), Vector2(s.x * 0.88, cy), tint, 2.4, true)
				draw_line(Vector2(s.x * 0.60, cy + s.y * 0.26), Vector2(s.x * 0.88, cy), tint, 2.4, true)

			"bracket_bl":
				draw_line(Vector2(2, 0), Vector2(2, s.y - 2), tint, 2.4)
				draw_line(Vector2(2, s.y - 2), Vector2(s.x, s.y - 2), tint, 2.4)

			"bracket_br":
				draw_line(Vector2(s.x - 2, 0), Vector2(s.x - 2, s.y - 2), tint, 2.4)
				draw_line(Vector2(0, s.y - 2), Vector2(s.x - 2, s.y - 2), tint, 2.4)

			"bracket_tl":
				draw_line(Vector2(2, s.y), Vector2(2, 2), tint, 2.4)
				draw_line(Vector2(2, 2), Vector2(s.x, 2), tint, 2.4)

			"bracket_tr":
				draw_line(Vector2(s.x - 2, s.y), Vector2(s.x - 2, 2), tint, 2.4)
				draw_line(Vector2(0, 2), Vector2(s.x - 2, 2), tint, 2.4)

			"chamfer_note":
				var cut := 18.0
				var poly := PackedVector2Array([
					Vector2(0, 0),
					Vector2(s.x, 0),
					Vector2(s.x, s.y - cut),
					Vector2(s.x - cut, s.y),
					Vector2(0, s.y),
				])
				draw_colored_polygon(poly, tint)
				draw_polyline(PackedVector2Array([
					Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
					Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, 0)
				]), Color(0.086, 0.078, 0.102, 0.30), 1.5, true)

			"solar_strip":
				draw_rect(Rect2(Vector2.ZERO, s), UITheme.BASALT_DARK)
				var cols := 36
				var rows := 3
				var cell_w := s.x / float(cols)
				var cell_h := s.y / float(rows)
				var line_col := Color(0.96, 0.94, 0.90, 0.55)
				for c in range(cols + 1):
					draw_line(Vector2(c * cell_w, 0), Vector2(c * cell_w, s.y), line_col, 1.0)
				for r in range(rows + 1):
					draw_line(Vector2(0, r * cell_h), Vector2(s.x, r * cell_h), line_col, 1.0)
