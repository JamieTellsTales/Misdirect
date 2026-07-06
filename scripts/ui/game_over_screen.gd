extends Control
class_name GameOverScreen
## Game over overlay showing results

const ColourData = preload("res://scripts/resources/department_data.gd")
const CornerHUD  = preload("res://scripts/ui/corner_hud.gd")

signal restart_requested
signal quit_requested

var final_scores: Dictionary = {}
var winner_colour: int = -1
var player_colour: int = -1
var player_collapsed: bool = false
var player_eliminated: bool = false  # True when player lost all lives (endless/elimination)
var is_draw: bool = false
var top_score: int = -1
var tokens_earned: int = 0
var is_new_high_score: bool = false
var xp_earned: int = 0
var level_before: int = 0
var level_after: int = 0

# XP bar animation
var _xp_anim_from:  float = 0.0   # total XP at start of game
var _xp_anim_to:    float = 0.0   # total XP at end of game
var _xp_anim_cur:   float = 0.0   # current animated position
var _xp_anim_rate:  float = 0.0   # XP per second
var _xp_anim_done:  bool  = true
var _xp_last_level: int   = 0     # last level crossed, for triggering sounds
var _level_flash:   float = 0.0   # countdown for the level-up text flash (seconds)


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not visible or _xp_anim_done:
		return

	_xp_anim_cur = minf(_xp_anim_cur + _xp_anim_rate * delta, _xp_anim_to)

	# Check for level boundary crossings
	var cur_level: int = int(_xp_anim_cur) / 100
	if cur_level > _xp_last_level:
		_xp_last_level = cur_level
		_level_flash = 0.6
		AudioManager.play_level_up()

	if _level_flash > 0.0:
		_level_flash -= delta

	if _xp_anim_cur >= _xp_anim_to:
		_xp_anim_done = true

	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept"):
		AudioManager.play_button_click()
		get_tree().paused = false
		restart_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		AudioManager.play_button_click()
		get_tree().paused = false
		quit_requested.emit()


func show_results(
		scores: Dictionary,
		player_ct: int,
		collapsed_colours: Array,
		earned: int = 0,
		new_high: bool = false,
		xp_gained: int = 0,
		lv_before: int = 0,
		lv_after: int = 0,
		eliminated: bool = false,
) -> void:
	final_scores      = scores
	player_colour     = player_ct
	player_collapsed  = player_ct in collapsed_colours
	player_eliminated = eliminated
	tokens_earned     = earned
	is_new_high_score = new_high
	xp_earned         = xp_gained
	level_before      = lv_before
	level_after       = lv_after

	var best_score: int = -1
	winner_colour = -1
	for ct in scores.keys():
		if ct not in collapsed_colours:
			if scores[ct] > best_score:
				best_score = scores[ct]
				winner_colour = ct

	# Count how many non-collapsed players share the top score.
	top_score = best_score
	var top_scorers: int = 0
	for ct in scores.keys():
		if ct not in collapsed_colours and scores[ct] == best_score:
			top_scorers += 1
	is_draw = top_scorers > 1
	if is_draw:
		winner_colour = -1  # No single winner in a draw

	visible = true
	queue_redraw()
	var player_in_top: bool = (not player_collapsed) and (scores.get(player_ct, -1) == best_score)
	if player_eliminated or player_collapsed:
		AudioManager.play_defeat()
	elif not is_draw and winner_colour == player_colour:
		AudioManager.play_victory()
	elif player_in_top and is_draw:
		AudioManager.play_victory()
	else:
		AudioManager.play_defeat()
	get_tree().paused = true

	# Initialise XP bar animation
	if xp_gained > 0:
		_xp_anim_to   = float(StatsManager.xp)
		_xp_anim_from = _xp_anim_to - float(xp_gained)
		_xp_anim_cur  = _xp_anim_from
		# Target ~3 s total regardless of XP gained; at least 20 XP/s for tiny amounts
		_xp_anim_rate = maxf(float(xp_gained) / 3.0, 20.0)
		_xp_anim_done = false
		_xp_last_level = lv_before
	else:
		_xp_anim_cur  = float(StatsManager.xp)
		_xp_anim_done = true


func _draw() -> void:
	if not visible:
		return

	var screen_size := get_viewport_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0

	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.5))

	var font := FontManager.get_font()

	# Box width: just wide enough for the instructions line + 24 px padding each side.
	var inst_size: int = 15
	var inst_text: String = "ENTER — play again     ESC — main menu"
	var inst_text_w := font.get_string_size(inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, inst_size).x
	var box_w: float = inst_text_w + 48.0

	# Height grows with the number of score rows so all colours always fit.
	var n: int = final_scores.size()
	var box_h: float = 90.0              # header (title + divider + padding to first row)
	box_h += float(n) * 38.0            # score rows
	box_h += 8.0                        # gap between scores and extras
	if is_new_high_score:
		box_h += 26.0
	if tokens_earned > 0:
		box_h += 22.0
	if xp_earned > 0:
		box_h += 8.0 + 16.0 + 18.0 + 19.0  # gap + labels + bar + xp text
		if level_after > level_before:
			box_h += 22.0  # level-up announcement line
	# Newly unlocked modifiers
	var newly_unlocked: Array = _get_newly_unlocked_modifiers()
	if newly_unlocked.size() > 0:
		box_h += 8.0                          # gap before section
		box_h += float(newly_unlocked.size()) * 22.0
	box_h += 50.0                       # gap before instructions + instructions area
	var box_x: float = center_x - box_w / 2.0
	var box_y: float = center_y - box_h / 2.0
	var box_rect := Rect2(box_x, box_y, box_w, box_h)

	draw_rect(box_rect, Color(0.07, 0.07, 0.12, 0.97))
	draw_rect(box_rect, Color(0.55, 0.55, 0.65, 1.0), false, 2.0)

	var title: String
	var title_color: Color
	if player_eliminated or player_collapsed:
		title = "GAME OVER"
		title_color = Color.TOMATO
	elif is_draw:
		title = "IT'S A DRAW!"
		title_color = Color(0.5, 0.85, 1.0, 1.0)
	elif winner_colour == player_colour:
		title = "YOU WIN!"
		title_color = Color.GOLD
	else:
		title = "YOU LOSE"
		title_color = Color.WHITE

	var title_size: int = 36
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(center_x - title_w / 2.0, box_y + 50.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	draw_line(Vector2(box_x + 24, box_y + 62), Vector2(box_x + box_w - 24, box_y + 62),
		Color(0.4, 0.4, 0.5, 0.7), 1.0)

	var sorted_colours: Array = final_scores.keys()
	sorted_colours.sort_custom(func(a, b): return final_scores[a] > final_scores[b])

	var score_size: int = 22
	var label_x: float = box_x + 24.0
	var value_x: float = box_x + box_w - 24.0
	var y_pos: float = box_y + 90.0
	for ct in sorted_colours:
		var ct_color: Color = ColourData.get_color(ct)
		var score_val: int = final_scores[ct]

		# Left: colour name (player shows their profile name) with markers
		var label: String = ProfileManager.active_name() if ct == player_colour else ColourData.get_colour_name(ct)
		if (not is_draw and ct == winner_colour) or (is_draw and final_scores[ct] == top_score):
			label += "  ★"
		draw_string(font, Vector2(label_x, y_pos),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, ct_color)

		# Right: score, right-aligned
		var val_str: String = "%d" % score_val
		var val_w := font.get_string_size(val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size).x
		draw_string(font, Vector2(value_x - val_w, y_pos),
			val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, ct_color)

		y_pos += 38.0

	# ── Extras: high score, tokens, XP ───────────────────────────────────────
	var extra_y: float = y_pos + 8.0

	if is_new_high_score:
		var hs_text: String = "★  NEW HIGH SCORE!"
		var hs_size: int    = 18
		var hs_w := font.get_string_size(hs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs_size).x
		draw_string(font, Vector2(center_x - hs_w / 2.0, extra_y),
			hs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs_size, Color.GOLD)
		extra_y += 26.0

	if tokens_earned > 0:
		var sb_active: bool = GameConfig.has_modifier("speed_ball")
		var pts_text: String = "+ %d tokens earned" % tokens_earned
		if sb_active:
			pts_text += "  (Speed Ball ×2)"
		var pts_size: int = 15
		var pts_w := font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_size).x
		draw_string(font, Vector2(center_x - pts_w / 2.0, extra_y),
			pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_size, Color(0.55, 0.85, 0.55, 1.0))
		extra_y += 22.0

	# ── XP / Level bar ───────────────────────────────────────────────────────
	if xp_earned > 0:
		extra_y += 8.0  # breathing gap before XP section

		# Animated position — which level and XP-in-level are we currently showing?
		var anim_level:        int   = int(_xp_anim_cur) / 100
		var anim_xp_in_level:  int   = int(_xp_anim_cur) % 100

		# Level-up announcement — appears as soon as the animation crosses a boundary
		if anim_level > level_before:
			var up_text: String
			if anim_level >= 999:
				up_text = "★  MAX LEVEL REACHED!"
			else:
				up_text = "★  LEVEL UP!  %d → %d" % [level_before, anim_level]
			var up_sz: int = 16
			var up_w := font.get_string_size(up_text, HORIZONTAL_ALIGNMENT_LEFT, -1, up_sz).x
			# Flash white on level-up, settle to gold
			var flash_t: float = clampf(_level_flash / 0.6, 0.0, 1.0)
			var up_col: Color = Color.WHITE.lerp(Color.GOLD, 1.0 - flash_t)
			draw_string(font, Vector2(center_x - up_w / 2.0, extra_y + up_sz),
				up_text, HORIZONTAL_ALIGNMENT_LEFT, -1, up_sz, up_col)
			extra_y += 22.0

		# Level label row: "Level N" left, "Level N+1" right — tracks anim position
		var lv_now: int     = anim_level
		var lbl_sz: int     = 12
		var bar_margin: float = 24.0
		var bar_bx: float   = box_x + bar_margin
		var bar_bw: float   = box_w - bar_margin * 2.0
		var bar_bh: float   = 12.0

		var lv_lft_str: String = "Level %d" % lv_now
		var lv_rgt_str: String = "Level %d" % (lv_now + 1) if lv_now < 999 else "MAX"
		draw_string(font, Vector2(bar_bx, extra_y + lbl_sz),
			lv_lft_str, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz, Color(0.55, 0.85, 1.0, 1.0))
		var rgt_lbl_w := font.get_string_size(lv_rgt_str, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz).x
		draw_string(font, Vector2(bar_bx + bar_bw - rgt_lbl_w, extra_y + lbl_sz),
			lv_rgt_str, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_sz, Color(0.45, 0.65, 0.85, 1.0))
		extra_y += lbl_sz + 4.0

		# Bar background + animated fill
		draw_rect(Rect2(bar_bx, extra_y, bar_bw, bar_bh), Color(0.12, 0.12, 0.2, 1.0))
		draw_rect(Rect2(bar_bx, extra_y, bar_bw, bar_bh), Color(0.3, 0.3, 0.5, 0.6), false, 1.0)
		var xp_fill: float = float(anim_xp_in_level) / 100.0 if lv_now < 999 else 1.0
		if xp_fill > 0.0:
			# Bar pulses brighter during the level-up flash
			var flash_t: float = clampf(_level_flash / 0.6, 0.0, 1.0)
			var bar_col: Color = Color(0.3, 0.75, 0.9, 1.0).lerp(Color(0.65, 0.95, 1.0, 1.0), flash_t)
			draw_rect(Rect2(bar_bx, extra_y, bar_bw * xp_fill, bar_bh), bar_col)
		extra_y += bar_bh + 6.0

		# XP counter below bar: shows running total XP in level during animation
		var xp_str: String
		if lv_now >= 999:
			xp_str = "+ %d XP  (MAX LEVEL)" % xp_earned
		else:
			xp_str = "+ %d XP  (%d / 100)" % [xp_earned, anim_xp_in_level]
		var xp_str_sz: int = 13
		var xp_str_w := font.get_string_size(xp_str, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_str_sz).x
		draw_string(font, Vector2(center_x - xp_str_w / 2.0, extra_y + xp_str_sz),
			xp_str, HORIZONTAL_ALIGNMENT_LEFT, -1, xp_str_sz, Color(0.45, 0.78, 0.95, 1.0))

	# ── Newly unlocked modifiers ──────────────────────────────────────────────
	if newly_unlocked.size() > 0:
		extra_y += 8.0
		var unlock_sz: int = 14
		for mod in newly_unlocked:
			var ul_text: String = "🔓  UNLOCKED: %s" % mod["label"]
			var ul_w := font.get_string_size(ul_text, HORIZONTAL_ALIGNMENT_LEFT, -1, unlock_sz).x
			draw_string(font, Vector2(center_x - ul_w / 2.0, extra_y),
				ul_text, HORIZONTAL_ALIGNMENT_LEFT, -1, unlock_sz, Color(0.85, 0.55, 1.0, 1.0))
			extra_y += 22.0

	# ── Instructions ─────────────────────────────────────────────────────────
	var inst_w: float = inst_text_w  # already measured above for box_w
	draw_string(font, Vector2(center_x - inst_w / 2.0, box_y + box_h - 20.0),
		inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, inst_size, Color(0.45, 0.45, 0.55, 1.0))

	CornerHUD.draw_on(self)


func hide_screen() -> void:
	visible = false


func _get_newly_unlocked_modifiers() -> Array:
	## Returns modifiers whose unlock_level falls in (level_before, level_after].
	var result: Array = []
	for mod in GameConfig.MODIFIERS:
		var ul: int = mod.get("unlock_level", 0)
		if ul > 0 and level_before < ul and ul <= level_after:
			result.append(mod)
	return result
