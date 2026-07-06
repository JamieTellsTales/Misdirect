extends Node2D
class_name PauseMenu
## In-game pause overlay — toggled by ESC during play.
## Drawn via _draw() consistent with the rest of the UI codebase.
## process_mode = ALWAYS so navigation still works while the tree is paused.

const ITEMS: Array = ["CONTINUE", "SETTINGS", "ACHIEVEMENTS", "EXIT"]
const ITEM_COLORS: Array = [
	Color.FOREST_GREEN,
	Color.DODGER_BLUE,
	Color.GOLD,
	Color.CRIMSON,
]

signal settings_requested
signal exit_requested

var is_open: bool = false
var selected_index: int = 0
var item_rects: Array = []   # Rect2 per item for mouse hit-testing
var show_achievements_soon: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Public API ────────────────────────────────────────────────────────────────

func open() -> void:
	is_open = true
	visible = true
	selected_index = 0
	show_achievements_soon = false
	get_tree().paused = true
	queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	queue_redraw()


func hide_for_settings() -> void:
	## Visually hide the panel without unpausing — settings overlay takes over.
	## Call close() or show_after_settings() when the overlay finishes.
	visible = false
	queue_redraw()


func show_after_settings() -> void:
	## Re-show the panel after the settings overlay is dismissed.
	visible = true
	queue_redraw()


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_inside_tree():
		return

	# Use canvas-space mouse position so hit-testing works at any viewport scale
	# and regardless of whether the panel is centred on the design area or the
	# full expanded canvas.
	var mouse_pos := get_global_mouse_position()

	if event is InputEventMouseMotion:
		_update_hover(mouse_pos)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(mouse_pos)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		selected_index = (selected_index - 1 + ITEMS.size()) % ITEMS.size()
		show_achievements_soon = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		selected_index = (selected_index + 1) % ITEMS.size()
		show_achievements_soon = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		_activate(selected_index)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return


func _update_hover(pos: Vector2) -> void:
	for i in range(item_rects.size()):
		if item_rects[i].has_point(pos):
			if selected_index != i:
				selected_index = i
				show_achievements_soon = false
				queue_redraw()
				AudioManager.play_button_hover()
			return


func _handle_click(pos: Vector2) -> void:
	for i in range(item_rects.size()):
		if item_rects[i].has_point(pos):
			_activate(i)
			return


func _activate(index: int) -> void:
	AudioManager.play_button_click()
	match index:
		0:  # Continue
			close()
		1:  # Settings
			hide_for_settings()
			settings_requested.emit()
		2:  # Achievements — coming soon
			show_achievements_soon = true
			queue_redraw()
		3:  # Exit to main menu
			close()
			exit_requested.emit()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _get_panel_centre() -> Vector2:
	## Returns the canvas-space centre that the panel should be drawn around.
	## In portrait mode the arena is pinned to the top, so we ask the arena for
	## its design centre rather than using the full viewport centre.
	var parent = get_parent()
	if parent and parent.has_method("get_design_centre"):
		return parent.get_design_centre()
	return get_viewport_rect().size / 2.0


func _draw() -> void:
	if not is_open:
		return

	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var panel_centre: Vector2 = _get_panel_centre()
	var cx: float = panel_centre.x
	var cy: float = panel_centre.y

	# Full-screen dim (covers entire expanded viewport)
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0, 0, 0, 0.65))

	# Panel
	var box_w: float = 380.0
	var box_h: float = 340.0
	var bx: float = cx - box_w / 2.0
	var by: float = cy - box_h / 2.0
	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.07, 0.07, 0.12, 0.97))
	draw_rect(Rect2(bx, by, box_w, box_h), Color(0.55, 0.55, 0.65, 1.0), false, 2.0)

	var font := FontManager.get_font()

	# Title
	var title      := "PAUSED"
	var title_size := 32
	var title_w    := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0 + 2, by + 50.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.45))
	draw_string(font, Vector2(cx - title_w / 2.0, by + 48.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	draw_line(
		Vector2(bx + 24, by + 60),
		Vector2(bx + box_w - 24, by + 60),
		Color(0.4, 0.4, 0.5, 0.7), 1.0
	)

	# Menu items
	item_rects.clear()
	var item_size: int  = 28
	var spacing: float  = 56.0
	var start_y: float  = by + 104.0

	for i in range(ITEMS.size()):
		var label: String = ITEMS[i]
		var iy: float     = start_y + i * spacing
		var is_sel: bool  = (i == selected_index)

		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, item_size).x
		var lx: float = cx - lw / 2.0

		item_rects.append(Rect2(lx - 30, iy - item_size, lw + 60, item_size + 10))

		var col: Color = ITEM_COLORS[i] if is_sel else Color(0.45, 0.45, 0.52, 1.0)

		if is_sel:
			draw_string(font, Vector2(lx - 30, iy), "›",
				HORIZONTAL_ALIGNMENT_LEFT, -1, item_size, col)

		draw_string(font, Vector2(lx + 2, iy + 2), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, item_size, Color(0, 0, 0, 0.4))
		draw_string(font, Vector2(lx, iy), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, item_size, col)

		# Inline "coming soon" note under Achievements when activated
		if i == 2 and show_achievements_soon:
			var sub      := "Coming soon"
			var sub_size := 14
			var sub_w    := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
			draw_string(font, Vector2(cx - sub_w / 2.0, iy + 20.0),
				sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.5, 0.5, 0.6, 0.85))

	# Hint
	var hint      := "ESC — resume"
	var hint_size := 13
	var hw        := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hw / 2.0, by + box_h - 16.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.35, 0.35, 0.45, 1.0))
