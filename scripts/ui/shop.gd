extends Node2D
class_name ShopScreen
## Shop — purchase power-ups with earned tokens.
## Card grid layout: add entries to GameConfig.POWER_UPS to extend the shop automatically.

const CornerHUD = preload("res://scripts/ui/corner_hud.gd")

const CARD_W:   float = 260.0
const CARD_H:   float = 150.0
const CARD_GAP: float = 24.0
const COLS:     int   = 2
const PAGE_ROWS: int  = 3
const CARDS_PER_PAGE: int = COLS * PAGE_ROWS   # 6 cards per page

var _buy_rects: Array = []  # Array of {rect: Rect2, id: String, price: int}
var _back_rect: Rect2 = Rect2()
var _prev_rect: Rect2 = Rect2()
var _next_rect: Rect2 = Rect2()
var _hover_rect_id: String = ""   # tracks which rect is hovered for sound
var _page: int = 0
var _total_pages: int = 1


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_change_page(1)
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_change_page(-1)

	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())


func _change_page(delta: int) -> void:
	var new_page: int = clampi(_page + delta, 0, _total_pages - 1)
	if new_page != _page:
		_page = new_page
		AudioManager.play_button_click()


func _update_hover(pos: Vector2) -> void:
	var new_id: String = ""
	if _back_rect.has_point(pos):
		new_id = "__back"
	elif _total_pages > 1 and _page > 0 and _prev_rect.has_point(pos):
		new_id = "__prev"
	elif _total_pages > 1 and _page < _total_pages - 1 and _next_rect.has_point(pos):
		new_id = "__next"
	else:
		for entry in _buy_rects:
			if entry.rect.has_point(pos):
				new_id = entry.id
				break
	if new_id != _hover_rect_id and new_id != "":
		AudioManager.play_button_hover()
	_hover_rect_id = new_id


func _handle_click(pos: Vector2) -> void:
	if _back_rect.has_point(pos):
		AudioManager.play_button_click()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if _total_pages > 1 and _page > 0 and _prev_rect.has_point(pos):
		_change_page(-1)
		return
	if _total_pages > 1 and _page < _total_pages - 1 and _next_rect.has_point(pos):
		_change_page(1)
		return

	for entry in _buy_rects:
		if entry.rect.has_point(pos):
			AudioManager.play_button_click()
			StatsManager.unlock_powerup(entry.id, entry.price)
			return


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var font := FontManager.get_font()
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(sw, sh)), Color(0.07, 0.07, 0.12, 1.0))
	_draw_background_deco()

	# Purchasable power-ups only (skip "None" which is always free)
	var paid_pus: Array = []
	for pu in GameConfig.POWER_UPS:
		if pu["id"] != "":
			paid_pus.append(pu)

	_total_pages = maxi(1, ceili(float(paid_pus.size()) / float(CARDS_PER_PAGE)))
	_page = clampi(_page, 0, _total_pages - 1)

	# Panel is a fixed size (one full page) so it doesn't resize between pages.
	var grid_w: float = COLS * CARD_W + (COLS - 1) * CARD_GAP
	var grid_h: float = PAGE_ROWS * CARD_H + (PAGE_ROWS - 1) * CARD_GAP

	var panel_w: float = grid_w + 64.0
	var panel_h: float = 88.0 + grid_h + 76.0   # header + grid + page controls/footer
	var px: float = cx - panel_w / 2.0
	var py: float = cy - panel_h / 2.0

	# Panel
	draw_rect(Rect2(px, py, panel_w, panel_h), Color(0.09, 0.09, 0.15, 1.0))
	draw_rect(Rect2(px, py, panel_w, panel_h), Color(0.55, 0.55, 0.65, 1.0), false, 2.0)

	# Title
	var title      := "UNLOCKS"
	var title_size := 36
	var title_w    := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0 + 2, py + 52.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.4))
	draw_string(font, Vector2(cx - title_w / 2.0, py + 50.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	# Tokens balance (top-right of panel)
	var pts_text := "%d tokens available" % StatsManager.tokens
	var pts_size := 17
	var pts_w    := font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_size).x
	draw_string(font, Vector2(px + panel_w - pts_w - 20.0, py + 50.0),
		pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_size, Color(0.4, 0.9, 0.4, 1.0))

	draw_line(
		Vector2(px + 24, py + 62),
		Vector2(px + panel_w - 24, py + 62),
		Color(0.4, 0.4, 0.5, 0.7), 1.0
	)

	# Card grid — current page only
	_buy_rects.clear()
	var grid_start_x: float = cx - grid_w / 2.0
	var grid_start_y: float = py + 78.0

	var start: int = _page * CARDS_PER_PAGE
	var end_i: int = mini(start + CARDS_PER_PAGE, paid_pus.size())
	for i in range(start, end_i):
		var slot: int = i - start
		var col_idx: int = slot % COLS
		var row_idx: int = slot / COLS
		var card_x: float = grid_start_x + col_idx * (CARD_W + CARD_GAP)
		var card_y: float = grid_start_y + row_idx * (CARD_H + CARD_GAP)
		_draw_card(font, paid_pus[i], card_x, card_y)

	# Page controls (only when there's more than one page)
	if _total_pages > 1:
		var pc_y: float = grid_start_y + grid_h + 26.0
		var page_lbl := "Page %d / %d" % [_page + 1, _total_pages]
		var pl_sz := 16
		var pl_w := font.get_string_size(page_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, pl_sz).x
		draw_string(font, Vector2(cx - pl_w / 2.0, pc_y), page_lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pl_sz, Color(0.7, 0.72, 0.82, 1.0))

		var nav_sz := 16
		var prev_lbl := "‹ PREV"
		var prev_w := font.get_string_size(prev_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nav_sz).x
		var prev_x := cx - pl_w / 2.0 - 28.0 - prev_w
		_prev_rect = Rect2(prev_x - 10.0, pc_y - nav_sz, prev_w + 20.0, nav_sz + 10.0)
		var prev_on := _page > 0
		draw_string(font, Vector2(prev_x, pc_y), prev_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nav_sz,
			(Color(0.6, 0.75, 0.95, 1.0) if _hover_rect_id == "__prev" else Color(0.5, 0.6, 0.8, 1.0)) if prev_on else Color(0.3, 0.3, 0.38, 1.0))

		var next_lbl := "NEXT ›"
		var next_x := cx + pl_w / 2.0 + 28.0
		var next_w := font.get_string_size(next_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nav_sz).x
		_next_rect = Rect2(next_x - 10.0, pc_y - nav_sz, next_w + 20.0, nav_sz + 10.0)
		var next_on := _page < _total_pages - 1
		draw_string(font, Vector2(next_x, pc_y), next_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, nav_sz,
			(Color(0.6, 0.75, 0.95, 1.0) if _hover_rect_id == "__next" else Color(0.5, 0.6, 0.8, 1.0)) if next_on else Color(0.3, 0.3, 0.38, 1.0))

	# Back button
	var back_lbl  := "← BACK"
	var back_size := 18
	var back_w    := font.get_string_size(back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size).x
	var back_x    := cx - back_w / 2.0
	var back_y    := py + panel_h - 26.0
	_back_rect = Rect2(back_x - 16, back_y - back_size, back_w + 32, back_size + 10)
	draw_string(font, Vector2(back_x, back_y),
		back_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, back_size, Color(0.45, 0.55, 0.75, 1.0))

	# ESC hint
	var hint      := "← →  change page     ESC — back" if _total_pages > 1 else "ESC — back"
	var hint_size := 13
	var hint_w    := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, sh - 24.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.3, 0.3, 0.38, 1.0))

	CornerHUD.draw_on(self)


func _draw_card(font: Font, pu: Dictionary, x: float, y: float) -> void:
	var owned:      bool = StatsManager.is_powerup_unlocked(pu["id"])
	var can_afford: bool = StatsManager.tokens >= pu["price"]

	# Card background + border
	var card_bg    := Color(0.13, 0.14, 0.22, 1.0) if owned else Color(0.1, 0.1, 0.16, 1.0)
	var border_col: Color
	if owned:
		border_col = Color(0.3, 0.75, 0.4, 0.85)
	elif can_afford:
		border_col = Color(0.5, 0.5, 0.65, 0.75)
	else:
		border_col = Color(0.3, 0.3, 0.4, 0.5)

	draw_rect(Rect2(x, y, CARD_W, CARD_H), card_bg)
	draw_rect(Rect2(x, y, CARD_W, CARD_H), border_col, false, 1.5)

	# Power-up name
	var name_size := 21
	var name_col  := Color(0.75, 0.95, 0.78, 1.0) if owned else Color(0.88, 0.88, 0.96, 1.0)
	draw_string(font, Vector2(x + 14, y + 28),
		pu["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, name_col)

	# ACTIVE / PASSIVE tag (top-right)
	var kind: String = pu.get("kind", "")
	if kind != "":
		var tag: String = "ACTIVE" if kind == "active" else "PASSIVE"
		var tag_col: Color = Color(0.5, 0.75, 1.0, 1.0) if kind == "active" else Color(0.75, 0.6, 0.95, 1.0)
		var tag_sz: int = 11
		var tag_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz).x
		var tag_x := x + CARD_W - tag_w - 12.0
		draw_rect(Rect2(tag_x - 5.0, y + 10.0, tag_w + 10.0, 16.0), Color(tag_col.r, tag_col.g, tag_col.b, 0.14))
		draw_string(font, Vector2(tag_x, y + 22.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz, tag_col)

	# Description (word-wrapped)
	var desc_col := Color(0.5, 0.65, 0.52, 1.0) if owned else Color(0.45, 0.45, 0.58, 1.0)
	_draw_wrapped_text(font, pu["desc"], x + 14, y + 52, CARD_W - 28.0, 13, desc_col)

	if owned:
		# OWNED badge
		var badge      := "OWNED"
		var badge_size := 15
		var badge_w    := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size).x
		draw_string(font, Vector2(x + CARD_W - badge_w - 12, y + CARD_H - 16),
			badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size, Color(0.35, 0.9, 0.45, 1.0))
	else:
		# Price
		var price_text := "%d tokens" % pu["price"]
		var price_size := 16
		var price_col  := Color(0.95, 0.82, 0.3, 1.0) if can_afford else Color(0.5, 0.5, 0.52, 1.0)
		draw_string(font, Vector2(x + 14, y + CARD_H - 16),
			price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_size, price_col)

		# BUY button
		var btn_w    := 72.0
		var btn_h    := 30.0
		var btn_x    := x + CARD_W - btn_w - 12
		var btn_y    := y + CARD_H - btn_h - 10
		var btn_rect := Rect2(btn_x, btn_y, btn_w, btn_h)

		var btn_bg  := Color(0.15, 0.5, 0.2, 1.0) if can_afford else Color(0.14, 0.14, 0.2, 1.0)
		var btn_brd := Color(0.3, 0.82, 0.42, 0.85) if can_afford else Color(0.28, 0.28, 0.38, 0.5)
		var btn_col := Color.WHITE if can_afford else Color(0.38, 0.38, 0.44, 1.0)

		draw_rect(btn_rect, btn_bg)
		draw_rect(btn_rect, btn_brd, false, 1.5)

		var buy_lbl  := "BUY"
		var buy_size := 15
		var buy_w    := font.get_string_size(buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_size).x
		draw_string(font, Vector2(btn_x + (btn_w - buy_w) / 2.0, btn_y + 20),
			buy_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, buy_size, btn_col)

		if can_afford:
			_buy_rects.append({"rect": btn_rect, "id": pu["id"], "price": pu["price"]})


func _draw_wrapped_text(font: Font, text: String, x: float, y: float,
		max_w: float, font_size: int, color: Color) -> void:
	var words    := text.split(" ")
	var line     := ""
	var line_y   := y
	var line_h   := float(font_size) + 4.0

	for word in words:
		var test   := (line + " " + word).strip_edges()
		var test_w := font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if test_w > max_w and line != "":
			draw_string(font, Vector2(x, line_y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			line_y += line_h
			line = word
		else:
			line = test

	if line != "":
		draw_string(font, Vector2(x, line_y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_background_deco() -> void:
	var sw: float = get_viewport_rect().size.x
	var sh: float = get_viewport_rect().size.y
	var cx: float = sw / 2.0
	var cy: float = sh / 2.0
	var half: float  = 380.0
	var inset: float = 130.0
	var pts: PackedVector2Array = [
		Vector2(cx - half, cy - inset), Vector2(cx - inset, cy - half),
		Vector2(cx + inset, cy - half), Vector2(cx + half, cy - inset),
		Vector2(cx + half, cy + inset), Vector2(cx + inset, cy + half),
		Vector2(cx - inset, cy + half), Vector2(cx - half, cy + inset),
	]
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.18, 0.18, 0.28, 1.0), 1.5)

	var ca: float = 0.08
	draw_circle(Vector2(0, 0), 200, Color(Color.DODGER_BLUE, ca))
	draw_circle(Vector2(sw, 0), 200, Color(Color.CRIMSON, ca))
	draw_circle(Vector2(0, sh), 200, Color(Color.FOREST_GREEN, ca))
	draw_circle(Vector2(sw, sh), 200, Color(Color.GOLD, ca))
