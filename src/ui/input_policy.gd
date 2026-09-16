class_name GameInputPolicy
extends RefCounted

static func blocked(viewport: Viewport, dialogs: Array) -> bool:
	for dialog: Window in dialogs:
		if dialog != null and dialog.visible: return true
	var focus: Control = viewport.gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
