extends Node
## StatsManager — tracks and persists all player statistics across sessions.
## Registered as an autoload. Saves to user://stats.cfg.
## Call record_game_end() at the end of each round.

func _stats_path() -> String:
	## Returns the save path for the active profile's stats file.
	return ProfileManager.profile_dir(ProfileManager.active_id) + "stats.cfg"

# ── Tracked stats ─────────────────────────────────────────────────────────────

var high_score:              int   = 0
var total_score:             int   = 0
var points:                  int   = 0     # Persistent currency for buying upgrades
var games_played:            int   = 0
var total_time_played:       float = 0.0   # Seconds (across all sessions)
var wins:                    int   = 0
var losses:                  int   = 0
var achievements_unlocked:   int   = 0
var powerups_unlocked:       int   = 0
var modifiers_unlocked:      int   = 0
var longest_endless_seconds: float = 0.0   # Populated when endless mode ships
var unlocked_powerups:       Array = []    # IDs of purchased power-ups


func _ready() -> void:
	load_stats()


# ── Persistence ───────────────────────────────────────────────────────────────

func load_stats() -> void:
	var config := ConfigFile.new()
	if config.load(_stats_path()) != OK:
		return  # No save file yet — start from defaults

	high_score              = config.get_value("stats", "high_score",              0)
	total_score             = config.get_value("stats", "total_score",             0)
	points                  = config.get_value("stats", "points",                  0)
	games_played            = config.get_value("stats", "games_played",            0)
	total_time_played       = config.get_value("stats", "total_time_played",       0.0)
	wins                    = config.get_value("stats", "wins",                    0)
	losses                  = config.get_value("stats", "losses",                  0)
	achievements_unlocked   = config.get_value("stats", "achievements_unlocked",   0)
	powerups_unlocked       = config.get_value("stats", "powerups_unlocked",       0)
	modifiers_unlocked      = config.get_value("stats", "modifiers_unlocked",      0)
	longest_endless_seconds = config.get_value("stats", "longest_endless_seconds", 0.0)
	unlocked_powerups       = config.get_value("stats", "unlocked_powerups",       [])


func save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "high_score",              high_score)
	config.set_value("stats", "total_score",             total_score)
	config.set_value("stats", "points",                  points)
	config.set_value("stats", "games_played",            games_played)
	config.set_value("stats", "total_time_played",       total_time_played)
	config.set_value("stats", "wins",                    wins)
	config.set_value("stats", "losses",                  losses)
	config.set_value("stats", "achievements_unlocked",   achievements_unlocked)
	config.set_value("stats", "powerups_unlocked",       powerups_unlocked)
	config.set_value("stats", "modifiers_unlocked",      modifiers_unlocked)
	config.set_value("stats", "longest_endless_seconds", longest_endless_seconds)
	config.set_value("stats", "unlocked_powerups",       unlocked_powerups)
	config.save(_stats_path())


# ── Recording ─────────────────────────────────────────────────────────────────

func record_game_end(player_score: int, time_seconds: float, player_won: bool) -> Dictionary:
	## Call once at the end of each round.
	## Returns { "points_earned": int, "is_new_high_score": bool }
	games_played      += 1
	total_score       += player_score
	total_time_played += time_seconds

	if player_won:
		wins += 1
	else:
		losses += 1

	var is_new_high_score: bool = player_score > high_score
	if is_new_high_score:
		high_score = player_score

	# Points: 1 per 100 score; halved (integer division) on loss
	var points_earned: int = player_score / 100
	if not player_won:
		points_earned = points_earned / 2
	points += points_earned

	save_stats()
	return { "points_earned": points_earned, "is_new_high_score": is_new_high_score }


func win_loss_ratio() -> String:
	## Returns win/loss ratio as a string: "1.50", "∞" (no losses), or "—" (no games).
	if wins == 0 and losses == 0:
		return "—"
	if losses == 0:
		return "∞"
	return "%.2f" % (float(wins) / float(losses))


# ── Helpers ───────────────────────────────────────────────────────────────────

func is_powerup_unlocked(id: String) -> bool:
	## "None" (id == "") is always available; others require purchase.
	if id == "":
		return true
	return id in unlocked_powerups


func unlock_powerup(id: String, price: int) -> bool:
	## Purchase a power-up. Returns true on success, false if already owned or insufficient points.
	if id == "" or id in unlocked_powerups:
		return false
	if points < price:
		return false
	points -= price
	unlocked_powerups.append(id)
	powerups_unlocked = unlocked_powerups.size()
	save_stats()
	return true


func format_time(seconds: float) -> String:
	## Format a duration in seconds as "Xh Ym" or "Xm Ys".
	var total_mins: int = int(seconds) / 60
	var secs: int       = int(seconds) % 60
	var hours: int      = total_mins / 60
	var mins: int       = total_mins % 60
	if hours > 0:
		return "%dh %dm" % [hours, mins]
	return "%dm %ds" % [mins, secs]
