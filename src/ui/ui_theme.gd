class_name ModernUITheme
extends RefCounted

const BACKGROUND := Color("111a21")
const SURFACE := Color("18252e")
const SURFACE_RAISED := Color("21313c")
const SURFACE_HIGH := Color("293b47")
const BORDER := Color("354955")
const TEXT := Color("e6edf1")
const TEXT_SECONDARY := Color("aab8c1")
const TEXT_MUTED := Color("788a95")
const ACCENT := Color("42c6b4")
const HIGHLIGHT := Color("d8b968")
const POSITIVE := Color("6fcf97")
const WARNING := Color("e0ad62")
const NEGATIVE := Color("e47777")

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24

static func build(high_contrast: bool = false) -> Theme:
	var theme := Theme.new()
	_theme_typography(theme)
	_theme_spacing(theme)
	_theme_surfaces(theme)
	_theme_buttons(theme)
	_theme_inputs(theme)
	_theme_tabs(theme)
	_theme_scrollbars(theme)
	if high_contrast:
		for type_name: String in theme.get_type_list():
			for color_name: String in theme.get_color_list(type_name):
				if "font" in color_name or color_name == "default_color":
					theme.set_color(color_name, type_name, Color.WHITE)
			for style_name: String in theme.get_stylebox_list(type_name):
				var style: StyleBoxFlat = theme.get_stylebox(style_name, type_name) as StyleBoxFlat
				if style != null:
					style.bg_color = style.bg_color.darkened(0.5)
					style.border_color = Color.WHITE if style_name in ["focus", "pressed", "tab_selected"] else Color("8299aa")
		for variation: String in ["NegativeLabel", "WarningLabel", "PositiveLabel"]:
			theme.set_font_size("font_size", variation, 16)
	return theme

static func _theme_typography(theme: Theme) -> void:
	for type_name: String in ["Label", "Button", "LineEdit", "OptionButton", "SpinBox", "CheckBox", "Tree", "TabBar", "RichTextLabel", "PopupMenu"]:
		theme.set_font_size("font_size", type_name, 14)
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, TEXT_MUTED)
		theme.set_color("font_hover_color", type_name, TEXT)
		theme.set_color("font_focus_color", type_name, TEXT)
		theme.set_color("font_pressed_color", type_name, TEXT)
		theme.set_color("font_outline_color", type_name, Color.TRANSPARENT)
		theme.set_constant("outline_size", type_name, 0)
	theme.set_font_size("normal_font_size", "RichTextLabel", 14)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("selection_color", "RichTextLabel", ACCENT.darkened(0.45))

	_set_variation(theme, "TitleLabel", "Label", 19, TEXT)
	_set_variation(theme, "SectionLabel", "Label", 16, TEXT_SECONDARY)
	_set_variation(theme, "MetaLabel", "Label", 13, TEXT_MUTED)
	_set_variation(theme, "ValueLabel", "Label", 16, TEXT)
	_set_variation(theme, "PositiveLabel", "Label", 14, POSITIVE)
	_set_variation(theme, "WarningLabel", "Label", 14, WARNING)
	_set_variation(theme, "NegativeLabel", "Label", 14, NEGATIVE)
	_set_variation(theme, "MetricLabel", "Label", 11, TEXT_MUTED)
	_set_variation(theme, "MetricValue", "Label", 19, TEXT)
	_set_variation(theme, "StatusLabel", "Label", 12, TEXT_MUTED)

static func _set_variation(theme: Theme, variation: String, base: String, size: int, color: Color) -> void:
	theme.set_type_variation(variation, base)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)

static func _theme_spacing(theme: Theme) -> void:
	theme.set_constant("separation", "HBoxContainer", SPACE_2)
	theme.set_constant("separation", "VBoxContainer", SPACE_2)
	theme.set_constant("h_separation", "GridContainer", SPACE_3)
	theme.set_constant("v_separation", "GridContainer", SPACE_2)
	theme.set_constant("item_margin", "Tree", SPACE_1)
	theme.set_constant("button_margin", "TabBar", SPACE_2)

static func _theme_surfaces(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _box(SURFACE, BORDER, 1, 4, SPACE_3))
	theme.set_stylebox("panel", "PanelContainer", _box(SURFACE, BORDER, 1, 4, SPACE_3))
	theme.set_type_variation("AppBarPanel", "PanelContainer")
	theme.set_stylebox("panel", "AppBarPanel", _box(SURFACE_RAISED, BORDER, 1, 4, SPACE_3))
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", _box(SURFACE_RAISED, BORDER, 1, 4, SPACE_3))
	theme.set_type_variation("ManagementSection", "PanelContainer")
	theme.set_stylebox("panel", "ManagementSection", _box(SURFACE, BORDER.darkened(0.08), 1, 3, SPACE_3))
	theme.set_stylebox("panel", "PopupPanel", _box(SURFACE_RAISED, BORDER, 1, 4, SPACE_3))
	theme.set_stylebox("panel", "Tree", _box(SURFACE, BORDER, 1, 3, SPACE_2))
	theme.set_stylebox("focus", "Tree", _box(Color.TRANSPARENT, ACCENT, 1, 3, 0))
	theme.set_color("font_color", "Tree", TEXT_SECONDARY)
	theme.set_color("font_selected_color", "Tree", TEXT)
	theme.set_color("relationship_line_color", "Tree", BORDER)
	theme.set_color("drop_position_color", "Tree", ACCENT)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_font_size("title_font_size", "Window", 18)

static func _theme_buttons(theme: Theme) -> void:
	_set_button_set(theme, "Button", SURFACE_RAISED, SURFACE_HIGH, ACCENT.darkened(0.28), BORDER, TEXT)
	theme.set_type_variation("PrimaryButton", "Button")
	_set_button_set(theme, "PrimaryButton", ACCENT.darkened(0.22), ACCENT.darkened(0.08), ACCENT.darkened(0.35), ACCENT, TEXT)
	theme.set_type_variation("DestructiveButton", "Button")
	_set_button_set(theme, "DestructiveButton", NEGATIVE.darkened(0.52), NEGATIVE.darkened(0.38), NEGATIVE.darkened(0.60), NEGATIVE.darkened(0.18), TEXT)
	theme.set_type_variation("NavigationButton", "Button")
	_set_button_set(theme, "NavigationButton", SURFACE_RAISED, SURFACE_HIGH, ACCENT.darkened(0.35), BORDER, TEXT)

static func _set_button_set(theme: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, border: Color, text_color: Color) -> void:
	theme.set_stylebox("normal", type_name, _box(normal, border, 1, 3, SPACE_2))
	theme.set_stylebox("hover", type_name, _box(hover, border.lightened(0.15), 1, 3, SPACE_2))
	theme.set_stylebox("pressed", type_name, _box(pressed, ACCENT, 1, 3, SPACE_2))
	theme.set_stylebox("disabled", type_name, _box(SURFACE, BORDER.darkened(0.2), 1, 3, SPACE_2))
	theme.set_stylebox("focus", type_name, _box(Color.TRANSPARENT, ACCENT, 1, 3, 1))
	theme.set_color("font_color", type_name, text_color)
	theme.set_color("font_hover_color", type_name, TEXT)
	theme.set_color("font_pressed_color", type_name, TEXT)
	theme.set_color("font_disabled_color", type_name, TEXT_MUTED.darkened(0.15))
	theme.set_constant("h_separation", type_name, SPACE_2)

static func _theme_inputs(theme: Theme) -> void:
	for type_name: String in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type_name, _box(BACKGROUND.lightened(0.025), BORDER, 1, 3, SPACE_2))
		theme.set_stylebox("focus", type_name, _box(BACKGROUND.lightened(0.04), ACCENT, 1, 3, SPACE_2))
		theme.set_stylebox("read_only", type_name, _box(SURFACE, BORDER.darkened(0.15), 1, 3, SPACE_2))
		theme.set_color("caret_color", type_name, ACCENT)
		theme.set_color("selection_color", type_name, ACCENT.darkened(0.5))
	_set_button_set(theme, "OptionButton", BACKGROUND.lightened(0.025), SURFACE_HIGH, ACCENT.darkened(0.35), BORDER, TEXT)
	theme.set_stylebox("panel", "PopupMenu", _box(SURFACE_RAISED, BORDER, 1, 3, SPACE_2))
	theme.set_stylebox("hover", "PopupMenu", _box(SURFACE_HIGH, Color.TRANSPARENT, 0, 2, SPACE_1))
	theme.set_color("font_separator_color", "PopupMenu", TEXT_MUTED)
	theme.set_color("font_accelerator_color", "PopupMenu", TEXT_MUTED)
	theme.set_color("font_separator_color", "PopupMenu", TEXT_MUTED)
	theme.set_constant("v_separation", "PopupMenu", SPACE_1)
	theme.set_color("font_color", "CheckBox", TEXT_SECONDARY)
	theme.set_color("font_hover_color", "CheckBox", TEXT)

static func _theme_tabs(theme: Theme) -> void:
	theme.set_stylebox("panel", "TabContainer", _box(SURFACE_RAISED, BORDER, 1, 4, SPACE_3))
	theme.set_stylebox("tab_unselected", "TabContainer", _tab_box(SURFACE, BORDER, TEXT_MUTED))
	theme.set_stylebox("tab_hovered", "TabContainer", _tab_box(SURFACE_HIGH, BORDER, TEXT))
	theme.set_stylebox("tab_selected", "TabContainer", _tab_box(SURFACE_RAISED, ACCENT, TEXT))
	theme.set_stylebox("tab_disabled", "TabContainer", _tab_box(SURFACE, BORDER.darkened(0.2), TEXT_MUTED))
	theme.set_stylebox("tab_unselected", "TabBar", _tab_box(SURFACE, BORDER, TEXT_MUTED))
	theme.set_stylebox("tab_hovered", "TabBar", _tab_box(SURFACE_HIGH, BORDER, TEXT))
	theme.set_stylebox("tab_selected", "TabBar", _tab_box(SURFACE_RAISED, ACCENT, TEXT))
	theme.set_stylebox("tab_disabled", "TabBar", _tab_box(SURFACE, BORDER.darkened(0.2), TEXT_MUTED))
	theme.set_color("font_unselected_color", "TabBar", TEXT_MUTED)
	theme.set_color("font_hovered_color", "TabBar", TEXT)
	theme.set_color("font_selected_color", "TabBar", TEXT)

static func _theme_scrollbars(theme: Theme) -> void:
	for type_name: String in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type_name, _box(BACKGROUND.lightened(0.035), Color.TRANSPARENT, 0, 3, 0))
		theme.set_stylebox("scroll_focus", type_name, _box(BACKGROUND.lightened(0.035), Color.TRANSPARENT, 0, 3, 0))
		theme.set_stylebox("grabber", type_name, _box(BORDER, Color.TRANSPARENT, 0, 3, 0))
		theme.set_stylebox("grabber_highlight", type_name, _box(TEXT_MUTED, Color.TRANSPARENT, 0, 3, 0))
		theme.set_stylebox("grabber_pressed", type_name, _box(ACCENT.darkened(0.2), Color.TRANSPARENT, 0, 3, 0))
		theme.set_constant("scroll_size", type_name, 8)

static func _tab_box(fill: Color, border: Color, _font: Color) -> StyleBoxFlat:
	var style := _box(fill, border, 0, 3, SPACE_2)
	style.border_width_bottom = 2
	style.border_color = border
	return style

static func _box(fill: Color, border: Color, width: int, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
