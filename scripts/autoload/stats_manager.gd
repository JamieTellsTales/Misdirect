extends Node
## StatsManager — tracks and persists all player statistics across sessions.
## Registered as an autoload. Saves to user://stats.cfg.
## Call record_game_end() at the end of each round.

func _stats_path() -> String:
	## Returns the save path for the active profile's stats file.
	return ProfileManager.profile_dir(ProfileManager.active_id) + "stats.cfg"

# ── Tracked stats ─────────────────────────────────────────────────────────────

var high_score:              int   = 0     # Highest score across all modes
var high_score_normal:       int   = 0
var high_score_endless:      int   = 0
var high_score_elimination:  int   = 0
var total_score:             int   = 0
var tokens:                  int   = 0     # Persistent currency for buying upgrades
var total_tokens_earned:     int   = 0     # Lifetime tokens earned (never decremented)
var xp:                      int   = 0     # Total XP earned (100 XP = 1 level)
var map_wins:                Dictionary = {} # Wins per map key e.g. {"triangle": 3}
var games_played:            int   = 0     # Total across all modes
var games_played_normal:     int   = 0
var games_played_endless:    int   = 0
var games_played_elimination: int  = 0
var total_time_played:       float = 0.0   # Seconds (across all sessions)
var wins:                    int   = 0
var losses:                  int   = 0
var draws:                   int   = 0
var achievements_unlocked:   int   = 0
var powerups_unlocked:       int   = 0
var modifiers_unlocked:      int   = 0
var longest_endless_seconds: float = 0.0
var longest_elimination_seconds: float = 0.0
var unlocked_powerups:       Array = []    # IDs of purchased power-ups
var unlocked_slots:          Array = []    # Slot indices (0-2) whose unlock fee has been paid
var last_power_up:           String = ""   # Legacy single-slot; kept for compatibility
var last_power_up_slots:     Array  = ["", "", ""]  # Last slot assignments, restored on pre-game screen
var last_modifiers:          Array  = []   # Last selected modifiers, restored on next pre-game screen


func _ready() -> void:
	load_stats()


# ── Persistence ───────────────────────────────────────────────────────────────

func load_stats() -> void:
	# Reset to defaults first so switching to a profile with no save file
	# doesn't leave the previous profile's data in memory.
	high_score                   = 0
	high_score_normal            = 0
	high_score_endless           = 0
	high_score_elimination       = 0
	total_score                  = 0
	tokens                       = 0
	total_tokens_earned          = 0
	xp                           = 0
	map_wins                     = {}
	games_played                 = 0
	games_played_normal          = 0
	games_played_endless         = 0
	games_played_elimination     = 0
	total_time_played            = 0.0
	wins                         = 0
	losses                       = 0
	draws                        = 0
	achievements_unlocked        = 0
	powerups_unlocked            = 0
	modifiers_unlocked           = 0
	longest_endless_seconds      = 0.0
	longest_elimination_seconds  = 0.0
	unlocked_powerups            = []
	unlocked_slots               = []
	last_power_up                = ""
	last_power_up_slots          = ["", "", ""]
	last_modifiers               = []

	var config := ConfigFile.new()
	if config.load(_stats_path()) != OK:
		return  # No save file yet — defaults are already applied above

	high_score                   = config.get_value("stats", "high_score",                   0)
	high_score_normal            = config.get_value("stats", "high_score_normal",            0)
	high_score_endless           = config.get_value("stats", "high_score_endless",           0)
	high_score_elimination       = config.get_value("stats", "high_score_elimination",       0)
	total_score                  = config.get_value("stats", "total_score",                  0)
	tokens                       = config.get_value("stats", "tokens",                       0)
	total_tokens_earned          = config.get_value("stats", "total_tokens_earned",          0)
	xp                           = config.get_value("stats", "xp",                           0)
	map_wins                     = config.get_value("stats", "map_wins",                     {})
	games_played                 = config.get_value("stats", "games_played",                 0)
	games_played_normal          = config.get_value("stats", "games_played_normal",          0)
	games_played_endless         = config.get_value("stats", "games_played_endless",         0)
	games_played_elimination     = config.get_value("stats", "games_played_elimination",     0)
	total_time_played            = config.get_value("stats", "total_time_played",            0.0)
	wins                         = config.get_value("stats", "wins",                         0)
	losses                       = config.get_value("stats", "losses",                       0)
	draws                        = config.get_value("stats", "draws",                        0)
	achievements_unlocked        = config.get_value("stats", "achievements_unlocked",        0)
	powerups_unlocked            = config.get_value("stats", "powerups_unlocked",            0)
	modifiers_unlocked           = config.get_value("stats", "modifiers_unlocked",           0)
	longest_endless_seconds      = config.get_value("stats", "longest_endless_seconds",      0.0)
	longest_elimination_seconds  = config.get_value("stats", "longest_elimination_seconds",  0.0)
	unlocked_powerups            = config.get_value("stats", "unlocked_powerups",            [])
	unlocked_slots               = config.get_value("stats", "unlocked_slots",               [])
	last_power_up                = config.get_value("stats", "last_power_up",                "")
	last_power_up_slots          = config.get_value("stats", "last_power_up_slots",          ["", "", ""])
	last_modifiers               = config.get_value("stats", "last_modifiers",               [])


func save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "high_score",                   high_score)
	config.set_value("stats", "high_score_normal",            high_score_normal)
	config.set_value("stats", "high_score_endless",           high_score_endless)
	config.set_value("stats", "high_score_elimination",       high_score_elimination)
	config.set_value("stats", "total_score",                  total_score)
	config.set_value("stats", "tokens",                       tokens)
	config.set_value("stats", "total_tokens_earned",          total_tokens_earned)
	config.set_value("stats", "xp",                           xp)
	config.set_value("stats", "map_wins",                     map_wins)
	config.set_value("stats", "games_played",                 games_played)
	config.set_value("stats", "games_played_normal",          games_played_normal)
	config.set_value("stats", "games_played_endless",         games_played_endless)
	config.set_value("stats", "games_played_elimination",     games_played_elimination)
	config.set_value("stats", "total_time_played",            total_time_played)
	config.set_value("stats", "wins",                         wins)
	config.set_value("stats", "losses",                       losses)
	config.set_value("stats", "draws",                        draws)
	config.set_value("stats", "achievements_unlocked",        achievements_unlocked)
	config.set_value("stats", "powerups_unlocked",            powerups_unlocked)
	config.set_value("stats", "modifiers_unlocked",           modifiers_unlocked)
	config.set_value("stats", "longest_endless_seconds",      longest_endless_seconds)
	config.set_value("stats", "longest_elimination_seconds",  longest_elimination_seconds)
	config.set_value("stats", "unlocked_powerups",            unlocked_powerups)
	config.set_value("stats", "unlocked_slots",               unlocked_slots)
	config.set_value("stats", "last_power_up",                last_power_up)
	config.set_value("stats", "last_power_up_slots",          last_power_up_slots)
	config.set_value("stats", "last_modifiers",               last_modifiers)
	config.save(_stats_path())


# ── Recording ─────────────────────────────────────────────────────────────────

func record_game_end(player_score: int, time_seconds: float, player_won: bool, player_drew: bool = false) -> Dictionary:
	## Call once at the end of each round.
	## Returns { "tokens_earned": int, "is_new_high_score": bool,
	##           "xp_earned": int, "level_before": int, "level_after": int }
	var mode: String = GameConfig.game_mode

	games_played      += 1
	total_score       += player_score
	total_time_played += time_seconds

	match mode:
		"normal":
			games_played_normal += 1
		"endless":
			games_played_endless += 1
			if time_seconds > longest_endless_seconds:
				longest_endless_seconds = time_seconds
		"elimination":
			games_played_elimination += 1
			if time_seconds > longest_elimination_seconds:
				longest_elimination_seconds = time_seconds

	# Capture level before XP is applied so the game over screen can show progression
	var level_before: int = get_level()

	# XP: 1 XP per score point earned (capped at level 999)
	var xp_earned: int = player_score
	xp = mini(xp + xp_earned, 999 * 100)

	# Endless is a survival mode — the run always ends in death, so it does not
	# count toward wins/draws/losses (longest run + high score are its metrics).
	if mode != "endless":
		if player_won:
			wins += 1
			# Track wins per map for unlock progression
			var map_key: String = GameConfig.selected_map
			map_wins[map_key] = map_wins.get(map_key, 0) + 1
		elif player_drew:
			draws += 1
		else:
			losses += 1

	var is_new_high_score: bool = player_score > high_score
	if is_new_high_score:
		high_score = player_score
	match mode:
		"normal":
			if player_score > high_score_normal:
				high_score_normal = player_score
		"endless":
			if player_score > high_score_endless:
				high_score_endless = player_score
		"elimination":
			if player_score > high_score_elimination:
				high_score_elimination = player_score

	# Tokens: 1 per 100 score; halved (integer division) on loss.
	# Endless always pays full rate — dying is the only way a run ends.
	var tokens_earned: int = player_score / 100
	if not player_won and mode != "endless":
		tokens_earned = tokens_earned / 2
	tokens             += tokens_earned
	total_tokens_earned += tokens_earned

	save_stats()
	return {
		"tokens_earned":     tokens_earned,
		"is_new_high_score": is_new_high_score,
		"xp_earned":         xp_earned,
		"level_before":      level_before,
		"level_after":       get_level(),
	}


func win_loss_ratio() -> String:
	## Returns (wins + draws) / losses as a string. Draws count as wins.
	var positive: int = wins + draws
	if positive == 0 and losses == 0:
		return "—"
	if losses == 0:
		return "∞"
	return "%.2f" % (float(positive) / float(losses))


# ── XP & Levels ───────────────────────────────────────────────────────────────

func get_level() -> int:
	## Returns the current level (0–999). Each 100 XP = 1 level.
	return mini(xp / 100, 999)


func get_xp_in_level() -> int:
	## Returns XP progress within the current level (0–99).
	## At max level 999 returns 99 (bar stays full).
	if get_level() >= 999:
		return 99
	return xp % 100


# ── Map Unlocks ───────────────────────────────────────────────────────────────

func is_map_unlocked(map_key: String) -> bool:
	## Returns true if the player has unlocked the given map.
	var req: Dictionary = GameConfig.MAP_UNLOCK_REQUIREMENTS.get(map_key, {})
	if req.is_empty():
		return false
	var required_wins: int = req.get("wins", 0)
	if required_wins == 0:
		return true  # Triangle — always unlocked
	var prev_map: String = req.get("prev", "")
	if prev_map == "":
		return true
	return map_wins.get(prev_map, 0) >= required_wins


# ── Helpers ───────────────────────────────────────────────────────────────────

func is_powerup_unlocked(id: String) -> bool:
	## "None" (id == "") is always available; others require purchase.
	if id == "":
		return true
	return id in unlocked_powerups


func unlock_powerup(id: String, price: int) -> bool:
	## Purchase a power-up. Returns true on success, false if already owned or insufficient tokens.
	if id == "" or id in unlocked_powerups:
		return false
	if tokens < price:
		return false
	tokens -= price
	unlocked_powerups.append(id)
	powerups_unlocked = unlocked_powerups.size()
	save_stats()
	return true


func is_slot_unlocked(slot_idx: int) -> bool:
	## Returns true if this slot is available. Free slots (unlock_price 0, e.g. the
	## always-available active slot) count as unlocked without purchase.
	if slot_idx >= 0 and slot_idx < GameConfig.POWER_UP_SLOT_DEFS.size():
		if GameConfig.POWER_UP_SLOT_DEFS[slot_idx].get("unlock_price", 0) <= 0:
			return true
	return slot_idx in unlocked_slots


func unlock_slot(slot_idx: int, price: int) -> bool:
	## Pay the token fee to unlock a slot. Returns true on success.
	if slot_idx in unlocked_slots:
		return false
	if tokens < price:
		return false
	tokens -= price
	unlocked_slots.append(slot_idx)
	save_stats()
	return true


func save_last_slot_selections(slots: Array, modifiers: Array) -> void:
	## Persist the player's last slot assignments and modifier choices for this profile.
	last_power_up_slots = slots.duplicate()
	last_modifiers      = modifiers.duplicate()
	save_stats()


func save_last_selections(power_up: String, modifiers: Array) -> void:
	## Legacy: persist single power-up selection. Kept for compatibility.
	last_power_up  = power_up
	last_modifiers = modifiers.duplicate()
	save_stats()


func format_time(seconds: float) -> String:
	## Format a duration in seconds as "Xh Ym" or "Xm Ys".
	var total_mins: int = int(seconds) / 60
	var secs: int       = int(seconds) % 60
	var hours: int      = total_mins / 60
	var mins: int       = total_mins % 60
	if hours > 0:
		return "%dh %dm" % [hours, mins]
	return "%dm %ds" % [mins, secs]
