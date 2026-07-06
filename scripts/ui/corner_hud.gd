extends Object
## CornerHUD — draws a small player-info overlay in the top-left of any scene.
## Usage: preload this script and call .draw_on(self) at the end of any _draw().

const PAD_X:    float = 10.0
const PAD_Y:    float = 8.0
const BOX_PAD:  float = 10.0
const BAR_H:    float = 5.0    # XP bar height in pixels
const BAR_GAP:  float = 4.0    # gap between stats text and bar


static func draw_on(ci: CanvasItem) -> void:
	var font := FontManager.get_font()

	var profile_name: String = ProfileManager.active_name()
	var level: int           = StatsManager.get_level()
	var tokens: int          = StatsManager.tokens
	var xp_in: int           = StatsManager.get_xp_in_level()

	var sz_name:  int = 13
	var sz_stats: int = 12

	var line1: String = profile_name
	var line2: String = "Lv %d   %d tokens" % [level, tokens]

	var w1: float = font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, sz_name).x
	var w2: float = font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz_stats).x
	var bar_w: float = maxf(w1, w2)
	var box_w: float = bar_w + BOX_PAD * 2.0
	var box_h: float = BOX_PAD + sz_name + 4.0 + sz_stats + BAR_GAP + BAR_H + BOX_PAD

	# Semi-transparent backing box
	ci.draw_rect(Rect2(PAD_X, PAD_Y, box_w, box_h), Color(0.0, 0.0, 0.0, 0.55))
	ci.draw_rect(Rect2(PAD_X, PAD_Y, box_w, box_h), Color(0.35, 0.35, 0.5, 0.7), false, 1.0)

	var inner_x: float = PAD_X + BOX_PAD
	var text_y1: float = PAD_Y + BOX_PAD + sz_name
	var text_y2: float = text_y1 + 4.0 + sz_stats
	var bar_y:   float = text_y2 + BAR_GAP

	# Profile name
	ci.draw_string(font, Vector2(inner_x, text_y1),
		line1, HORIZONTAL_ALIGNMENT_LEFT, -1, sz_name, Color(0.75, 0.85, 0.75, 1.0))

	# Stats line
	ci.draw_string(font, Vector2(inner_x, text_y2),
		line2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz_stats, Color(0.55, 0.65, 0.75, 1.0))

	# XP bar
	var fill: float = float(xp_in) / 100.0 if level < 999 else 1.0
	ci.draw_rect(Rect2(inner_x, bar_y, bar_w, BAR_H), Color(0.12, 0.12, 0.22, 1.0))
	ci.draw_rect(Rect2(inner_x, bar_y, bar_w, BAR_H), Color(0.3, 0.3, 0.5, 0.6), false, 1.0)
	if fill > 0.0:
		ci.draw_rect(Rect2(inner_x, bar_y, bar_w * fill, BAR_H), Color(0.3, 0.75, 0.9, 1.0))
