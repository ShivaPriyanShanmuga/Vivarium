@tool
class_name VivTheme
extends RefCounted
## A polished dark editor Theme (Godot-editor / Unity flavour): consistent StyleBoxFlat for
## every control, hover/pressed states, styled sliders + lists + inputs, subtle 1px borders,
## real padding. Applied to the workspace root so all descendants inherit it. Built in code
## so it works both inside the Godot editor and in the standalone render harnesses.

# --- palette --------------------------------------------------------------------
const BG        := Color("1b1d23")  # window
const PANEL     := Color("24272f")  # panel body
const PANEL_HDR := Color("2c303a")  # section header bar
const CONTROL   := Color("333843")  # button / input
const CONTROL_HOVER := Color("3f4452")
const CONTROL_PRESS := Color("2a2e37")
const INPUT     := Color("1d1f26")  # list / text field background
const BORDER    := Color("12131a")
const BORDER_LT := Color("3a3f4b")
const TEXT      := Color("d6d9e0")
const TEXT_DIM  := Color("868c99")
const ACCENT    := Color("4b8bd0")  # selection / active (blue)
const ACCENT_BG := Color("2b3d54")  # selection fill
const GRABBER   := Color("c3c8d2")
const OK        := Color("6fbf73")
const WARN      := Color("e0674f")

static func _sb(bg: Color, border: Color, bw: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = maxi(2, margin - 2)
	s.content_margin_bottom = maxi(2, margin - 2)
	return s

static func _circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := size * 0.5
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r)) <= r - 0.5:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13

	# Panels
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, BORDER, 1, 4, 0))
	t.set_stylebox("panel", "Panel", _sb(BG, BORDER, 0, 0, 0))

	# Buttons (+ OptionButton, CheckButton fall back to Button styles)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _sb(CONTROL, BORDER_LT, 1, 3, 9))
		t.set_stylebox("hover", cls, _sb(CONTROL_HOVER, BORDER_LT, 1, 3, 9))
		t.set_stylebox("pressed", cls, _sb(CONTROL_PRESS, ACCENT, 1, 3, 9))
		t.set_stylebox("hover_pressed", cls, _sb(CONTROL_PRESS, ACCENT, 1, 3, 9))
		t.set_stylebox("focus", cls, _sb(Color(0, 0, 0, 0), ACCENT, 1, 3, 9))
		t.set_stylebox("disabled", cls, _sb(CONTROL.darkened(0.2), BORDER, 1, 3, 9))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, ACCENT.lightened(0.3))
		t.set_color("font_focus_color", cls, TEXT)

	# CheckButton — readable text, transparent frame (uses its own on/off icons)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_stylebox("normal", "CheckButton", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	t.set_stylebox("hover", "CheckButton", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	t.set_stylebox("pressed", "CheckButton", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))

	# Line/Text edit
	t.set_stylebox("normal", "LineEdit", _sb(INPUT, BORDER_LT, 1, 3, 7))
	t.set_stylebox("focus", "LineEdit", _sb(INPUT, ACCENT, 1, 3, 7))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_stylebox("normal", "TextEdit", _sb(Color("15161c"), BORDER_LT, 1, 3, 8))
	t.set_stylebox("focus", "TextEdit", _sb(Color("15161c"), ACCENT, 1, 3, 8))
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("caret_color", "TextEdit", ACCENT)

	# ItemList
	t.set_stylebox("panel", "ItemList", _sb(INPUT, BORDER, 1, 3, 4))
	t.set_stylebox("focus", "ItemList", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0))
	var sel := _sb(ACCENT_BG, ACCENT, 1, 3, 2)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	t.set_stylebox("hovered", "ItemList", _sb(CONTROL_HOVER, Color(0, 0, 0, 0), 0, 3, 2))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 3)

	# Sliders
	t.set_stylebox("slider", "HSlider", _sb(Color("14151a"), BORDER, 1, 3, 0))
	t.set_stylebox("grabber_area", "HSlider", _sb(ACCENT.darkened(0.15), Color(0, 0, 0, 0), 0, 3, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb(ACCENT, Color(0, 0, 0, 0), 0, 3, 0))
	t.set_icon("grabber", "HSlider", _circle(15, GRABBER))
	t.set_icon("grabber_highlight", "HSlider", _circle(15, Color.WHITE))

	# Labels / rich text
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Container spacing
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 5)

	return t
