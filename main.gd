extends Node2D

# BORROWED TIME
# Freeze time, pin glowing threads with your shots, release to SNAP them
# through everything they cross. Stitched kills explode and chain.
# All art is drawn in _draw() and all sound is synthesized in _ready().

const MINT = Color("00f0ff")
const PINK = Color("ff2a6d")
const GOLD = Color("fcee0a")
const ICE = Color("b28dff")
const RANKS = [["D", 0.0], ["C", 2.0], ["B", 4.5], ["A", 8.0], ["S", 12.0], ["SS", 17.0], ["SSS", 23.0]]
const SHADE = Color(0.02, 0.04, 0.08)
const MAX_ANCHORS = 60
const MIN_PIN_GAP = 24.0
const UPGRADES = [
	{"id": "rapid", "name": "RAPID FIRE", "short": "Rapid", "tag": "STAT", "max": 4},
	{"id": "heavy", "name": "HEAVY ROUNDS", "short": "Heavy", "tag": "STAT", "max": 4},
	{"id": "swift", "name": "FLEET FOOT", "short": "Fleet", "tag": "STAT", "max": 3},
	{"id": "mend", "name": "MEND", "short": "Mend", "tag": "STAT", "max": 3},
	{"id": "sharp", "name": "SHARP THREADS", "short": "Sharp", "tag": "STITCH", "max": 3},
	{"id": "pockets", "name": "DEEP POCKETS", "short": "Pockets", "tag": "STITCH", "max": 2},
	{"id": "volatile", "name": "VOLATILE", "short": "Volatile", "tag": "STITCH", "max": 2},
	{"id": "refund", "name": "REFUND", "short": "Refund", "tag": "STITCH", "max": 2},
	{"id": "reach", "name": "LONG NEEDLE", "short": "Needle", "tag": "STITCH", "max": 2},
	{"id": "lasso", "name": "LASSO", "short": "Lasso", "tag": "STITCH", "max": 1},
	{"id": "hijack", "name": "HIJACK+", "short": "Hijack+", "tag": "STITCH", "max": 2},
	{"id": "scars", "name": "TIME SCARS", "short": "Scars", "tag": "STITCH", "max": 2},
	{"id": "fork", "name": "FORKED FIRE", "short": "Fork", "tag": "STAT", "max": 2},
	{"id": "grace", "name": "GRACE PERIOD", "short": "Grace", "tag": "STITCH", "max": 2},
]
const BOSS_CHARGE = 0.8
const BOSS_HP = 220
const SAVE_PATH = "user://borrowed_time.cfg"
const PATTERN_NAMES = ["RING", "SPIRAL", "VOLLEY"]
const LIME = Color("7dff4a")
const ORANGE = Color("ff7a1a")
const MAX_BULLETS = 900  # simulation cap, below every bullet render pool (1000)
const MAX_SHARDS = 300
const CHARGER_WINDUP = 1.0
const XP_VALUE = [1, 2, 0, 2]  # chaser, shooter, boss, charger
const CHARACTERS = [
	{"name": "RUNNER", "weapon": "PULSE RIFLE", "color": Color("00f0ff"), "line": "Balanced and accurate. Fast single shots.",
		"hp": 5, "speed": 290.0, "rate": 0.2, "damage": 1, "dmg_step": 1, "proj_speed": 760.0, "pierce": 0, "pellets": 1, "spread": 0.0, "life": 6.0,
		"noun": "shots", "rapid": "RAPID FIRE", "heavy": "HEAVY ROUNDS", "fork": "FORKED FIRE", "unit": "Bolt"},
	{"name": "WRAITH", "weapon": "ENERGY BOW", "color": Color("b28dff"), "line": "Slow, heavy arrows pierce up to 3 enemies. Line them up.",
		"hp": 4, "speed": 305.0, "rate": 0.48, "damage": 3, "dmg_step": 2, "proj_speed": 980.0, "pierce": 2, "pellets": 1, "spread": 0.0, "life": 6.0,
		"noun": "arrows", "rapid": "QUICK DRAW", "heavy": "BARBED ARROWS", "fork": "SPLIT ARROWS", "unit": "Arrow"},
	{"name": "BREAKER", "weapon": "SCATTERGUN", "color": Color("ff9e3d"), "line": "Short-range spread. Get close and shred whole groups.",
		"hp": 6, "speed": 270.0, "rate": 0.62, "damage": 1, "dmg_step": 1, "proj_speed": 640.0, "pierce": 0, "pellets": 5, "spread": 0.42, "life": 0.5,
		"noun": "blasts", "rapid": "PUMP ACTION", "heavy": "SLUG PELLETS", "fork": "WIDE CHOKE", "unit": "Pellet"},
]
const STAGES = [
	{"name": "NEON ROOFTOPS", "tip": "Freeze, pin threads through the crowd, release to cut", "quota": 60, "cap": 22, "slow": 1.05, "fast": 0.6, "chaser": 2, "shooter": 3, "charger": 4},
	{"name": "RELAY DISTRICT", "tip": "Shooters and chargers. Dodge the red dash lines", "quota": 80, "cap": 28, "slow": 0.85, "fast": 0.5, "chaser": 3, "shooter": 3, "charger": 5},
	{"name": "COLLECTOR'S VAULT", "tip": "Elites guard the vault. The Collector waits at the end", "quota": 70, "cap": 32, "slow": 0.75, "fast": 0.45, "chaser": 3, "shooter": 4, "charger": 6},
]

var player = Vector2.ZERO
var enemies: Array = []
var bullets: Array = []
var sparks: Array = []
var portals: Array = []
var anchors: Array = []
var snap_lines: Array = []
var blasts: Array = []
var pops: Array = []  # short, sharp kill rings (visual only)
var popups: Array = []
var state = "title"
var stage = 1
var kills_stage = 0
var boss_phase = false
var transition = 0.0
var xp = 0
var level = 1
var pending_levels = 0
var shards: Array = []
var magnet = 95.0
var hijack_level = 0
var hijack_offers = 0
var scar_level = 0
var fork_level = 0
var scars: Array = []
var next_id = 0
var autofire = false
var low_fx = false
var xp_tick = 0.0
var picked_time = 0.0
var steals = 0
var stolen_hits = 0
var hint_time = 0.0
var intro_shooter = false
var bot: Dictionary = {}  # scripted input for automated pacing runs (empty = human)
var char_index = 0
var select_index = 0
var score = 0
var best = 0
var new_best = false
var health = 5
var max_health = 5
var debt = 0.0
var max_debt = 3.0
var repay_speed = 1.8
var frozen = false
var space_ready = true
var world_speed = 1.0
var fire_timer = 0.0
var fire_rate = 0.22
var damage = 1
var speed = 290.0
var thread_damage = 3
var blast_radius = 80.0
var blast_damage = 2
var reach = 160.0
var refund = 0.0
var lasso = false
var dash_reset = 1.0
var levels: Dictionary = {}
var offers: Array = []
var upgrade_delay = 0.0
var picked_text = ""
var loop_poly = PackedVector2Array()
var loop_life = 0.0
var ripples: Array = []
var trail: Array = []
var world_clock = 0.0
var hitstop = 0.0
var style = 0.0
var last_rank = 0
var peak_rank = 0
var glitch = 0.0
var immunity = 0.0
var dash_timer = 0.0
var dash_cooldown = 0.0
var dash_direction = Vector2.RIGHT
var spawn_timer = 0.0
var clock = 0.0
var run_time = 0.0
var shake = 0.0
var flash = 0.0
var flash_color = Color.WHITE
var banner = ""
var banner_sub = ""
var banner_time = 0.0
var taught = false
var best_combo = 0
var cheated = false
var muted = false
var sounds: Dictionary = {}


func _ready() -> void:
	var save = ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		best = int(save.get_value("game", "best", 0))

	_make_sound("shot", 760.0, 420.0, 0.07, 0.30, 0.05)
	_make_sound("stitch", 1300.0, 1750.0, 0.06, 0.30, 0.0)
	_make_sound("hit", 240.0, 60.0, 0.28, 0.85, 0.35)
	_make_sound("kill", 520.0, 150.0, 0.15, 0.55, 0.25)
	_make_sound("dash", 280.0, 1100.0, 0.12, 0.35, 0.35)
	_make_sound("freeze", 1000.0, 180.0, 0.38, 0.45, 0.0)
	_make_sound("snap", 180.0, 1500.0, 0.20, 0.55, 0.45)
	_make_sound("boom", 140.0, 35.0, 0.35, 0.70, 0.60)
	_make_sound("paid", 660.0, 990.0, 0.22, 0.35, 0.0)
	_make_sound("upgrade", 520.0, 1250.0, 0.35, 0.40, 0.0)
	_make_sound("warn", 440.0, 440.0, 0.16, 0.30, 0.10)

	_setup_view()
	get_viewport().focus_exited.connect(_lost_focus)


func _make_sound(id: String, f0: float, f1: float, length: float, volume: float, noise: float) -> void:
	var rate = 22050
	var count = int(rate * length)
	var data = PackedByteArray()
	data.resize(count * 2)
	var phase = 0.0

	for i in range(count):
		var k = float(i) / count
		phase += TAU * lerpf(f0, f1, k) / rate
		var sample = sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var envelope = minf(1.0, k * 30.0) * pow(1.0 - k, 2.0)
		data.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	var audio = AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = -10.0
	audio.max_polyphony = 4
	add_child(audio)
	sounds[id] = audio


func _lost_focus() -> void:
	if state == "play":
		state = "pause"


func _sound(id: String, pitch: float = 1.0) -> void:
	if not muted:
		sounds[id].pitch_scale = pitch
		sounds[id].play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and state == "select":
		_hover_select(get_global_mouse_position())  # only real mouse movement changes the hover pick
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and state == "select":
		for i in range(CHARACTERS.size()):
			if _select_card_rect(i).has_point(get_global_mouse_position()):
				select_index = i
				_choose_character()
				return
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and state == "upgrade":
		var mouse = get_global_mouse_position()
		for i in range(offers.size()):
			if _card_rect(i).has_point(mouse):
				_pick_upgrade(i)
				return
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key = event.keycode
	if key == KEY_M:
		muted = not muted
	elif state == "select":
		if key in [KEY_LEFT, KEY_A]:
			select_index = (select_index + CHARACTERS.size() - 1) % CHARACTERS.size()
		elif key in [KEY_RIGHT, KEY_D]:
			select_index = (select_index + 1) % CHARACTERS.size()
		elif key in [KEY_1, KEY_2, KEY_3]:
			select_index = key - KEY_1
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_choose_character()
		elif key == KEY_ESCAPE:
			state = "title"
	elif key in [KEY_ENTER, KEY_KP_ENTER] and state == "title":
		_open_select()
	elif key in [KEY_ENTER, KEY_KP_ENTER] and state in ["over", "win"]:
		_start()
	elif key == KEY_C and state in ["over", "win"]:
		_open_select()
	elif key == KEY_Q and state == "pause":
		_open_select()
	elif key == KEY_ESCAPE and state in ["play", "pause"]:
		state = "pause" if state == "play" else "play"
	elif state == "upgrade" and key in [KEY_1, KEY_2, KEY_3]:
		_pick_upgrade(key - KEY_1)
	elif key == KEY_F and state in ["play", "pause"]:
		autofire = not autofire
	elif key == KEY_V:
		low_fx = not low_fx
	elif OS.is_debug_build() and state == "play" and key in [KEY_F2, KEY_F3, KEY_F4]:
		# Editor-only test shortcuts. They disable best-score saving for this run.
		cheated = true
		if key == KEY_F2:
			kills_stage = STAGES[stage - 1].quota  # finish this stage
		elif key == KEY_F3:
			_begin_stage(3)
			kills_stage = STAGES[2].quota  # straight to the Collector
		else:
			_gain_xp(_xp_need(level) - xp)  # instant level-up


# --- UPGRADES ----------------------------------------------------------------

func _info(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return UPGRADES[0]


func _upgrade_name(id: String) -> String:
	# Weapon upgrades use the current character's words (an archer gets arrows).
	var info = CHARACTERS[char_index]
	match id:
		"rapid":
			return info.rapid
		"heavy":
			return info.heavy
		"fork":
			return info.fork
	return _info(id).name


func _roll_offers() -> Array:
	# Three different upgrades: at least one STITCH and one STAT when possible.
	var stat = []
	var stitch = []
	for u in UPGRADES:
		if levels.get(u.id, 0) < u.max:
			if u.tag == "STITCH":
				stitch.append(u.id)
			else:
				stat.append(u.id)
	stat.shuffle()
	stitch.shuffle()
	var picks = []
	if not stitch.is_empty():
		picks.append(stitch.pop_back())
	if not stat.is_empty():
		picks.append(stat.pop_back())
	var rest = stat + stitch
	rest.shuffle()
	while picks.size() < 3 and not rest.is_empty():
		picks.append(rest.pop_back())
	picks.shuffle()  # (basic Hijack is a starting ability now; HIJACK+ is a normal offer)
	return picks


func _upgrade_lines(id: String) -> Array:
	# Exact effect, written as current value -> value after picking.
	match id:
		"rapid":
			var w = CHARACTERS[char_index]
			return ["%s per second %.1f -> %.1f" % [w.noun.capitalize(), 1.0 / fire_rate, 1.0 / (fire_rate * 0.8)], "Also more pins per freeze"]
		"heavy":
			var w = CHARACTERS[char_index]
			return ["%s damage %d -> %d" % [w.unit, damage, damage + w.dmg_step], ["Every bolt, incl. pinned shots", "Still pierces up to 3 enemies", "Per pellet (5+ pellets per blast)"][char_index]]
		"swift":
			return ["Move speed %d -> %d" % [int(speed), int(speed) + 35], "Dash cooldown %.1fs -> %.1fs" % [dash_reset, dash_reset - 0.2]]
		"mend":
			return ["Max HP %d -> %d" % [max_health, max_health + 1], "Heal now: %d -> %d HP" % [health, mini(max_health + 1, health + 2)]]
		"sharp":
			return ["Thread damage %d -> %d" % [thread_damage, thread_damage + 2], "per crossing. Cuts tougher foes"]
		"pockets":
			return ["Freeze cap %.0fs -> %.0fs" % [max_debt, max_debt + 1.0], "More pins, but longer repayment"]
		"volatile":
			return ["Blast radius %d -> %d px" % [int(blast_radius), int(blast_radius) + 35], "Blast damage %d -> %d" % [blast_damage, blast_damage + 1]]
		"refund":
			return ["Debt repaid per stitch kill:", "%.1fs -> %.1fs. Chains end it early" % [refund, refund + 0.4]]
		"reach":
			return ["Pin reach %d -> %d px" % [int(reach), int(reach) + 60], "Stitch from a safer distance"]
		"lasso":
			return ["End your thread near the first", "pin to close a loop: everything", "inside takes 3x thread damage"]
		"grace":
			return ["Repay speed %.2fx -> %.2fx" % [repay_speed, repay_speed - 0.25], "Enemies rush less after a freeze"]
		"hijack":
			return ["Stolen bullets hit harder", "Stolen damage %d -> %d" % [1 + hijack_level, 2 + hijack_level], "Max level: they pierce 1 more enemy" if hijack_level >= 2 else "Max level adds piercing"]
		"scars":
			return ["Released threads linger on the floor", "%.1fs -> %.1fs, hitting each enemy" % [(1.25 + scar_level * 0.75) if scar_level > 0 else 0.0, 2.0 + scar_level * 0.75], "once. Damage %d -> %d. Lure them in!" % [(1 + scar_level) if scar_level > 0 else 0, 2 + scar_level]]
		"fork":
			var per = _volley(Vector2.RIGHT).size()
			return [["Bolts", "Arrows", "Pellets"][char_index] + " per trigger %d -> %d" % [per, per + 2], ["Angled side shots, full damage", "Split arrows keep their pierce", "Wider spread, same short range"][char_index], "Freeze pins stay single + precise"]
	return [""]


func _apply_upgrade(id: String) -> void:
	match id:
		"rapid":
			fire_rate *= 0.8
		"heavy":
			damage += CHARACTERS[char_index].dmg_step
		"swift":
			speed += 35.0
			dash_reset -= 0.2
		"mend":
			max_health += 1
			health = mini(max_health, health + 2)
		"sharp":
			thread_damage += 2
		"pockets":
			max_debt += 1.0
		"volatile":
			blast_radius += 35.0
			blast_damage += 1
		"refund":
			refund += 0.4
		"reach":
			reach += 60.0
		"lasso":
			lasso = true
		"grace":
			repay_speed -= 0.25
		"hijack":
			hijack_level += 1
		"scars":
			scar_level += 1
		"fork":
			fork_level += 1


func _pick_upgrade(choice: int) -> void:
	if upgrade_delay > 0.0 or choice < 0 or choice >= offers.size():
		return
	var id = offers[choice]
	var info = _info(id)
	var summary = _upgrade_lines(id)[0]
	_apply_upgrade(id)
	levels[id] = levels.get(id, 0) + 1
	picked_text = "UPGRADED: %s  Lv %d   (%s)" % [_upgrade_name(id), levels[id], summary]

	_sound("upgrade")
	picked_time = 3.0
	pending_levels = maxi(0, pending_levels - 1)
	if pending_levels > 0:
		offers = _roll_offers()  # another level was earned: next choice
		upgrade_delay = 0.35
	else:
		state = "play"
		immunity = maxf(immunity, 0.6)
	flash = 0.4
	flash_color = GOLD
	_burst(player, GOLD, 30)
	_popup(player + Vector2(0, -44), "+ " + _upgrade_name(id), GOLD, 20, 1.6)


func _card_rect(i: int) -> Rect2:
	var size = get_viewport_rect().size
	var w = minf(300.0, (size.x - 100.0) / 3.0)
	var gap = 22.0
	var x0 = (size.x - (w * 3.0 + gap * 2.0)) / 2.0
	return Rect2(x0 + i * (w + gap), size.y / 2.0 - 112.0, w, 220.0)


func _build_text() -> String:
	var parts = []
	for u in UPGRADES:
		var lv = levels.get(u.id, 0)
		if lv > 0:
			parts.append(u.short if u.max == 1 else "%s %d" % [u.short, lv])
	return "  /  ".join(parts)


func _stats_lines() -> Array:
	var w = CHARACTERS[char_index]
	return [
		"%s: %s dmg %d   %.1f %s/s   %d per trigger%s   Stolen shots %d dmg" % [w.weapon, w.unit, damage, 1.0 / fire_rate, w.noun, _volley(Vector2.RIGHT).size(), ("   hits up to %d" % (w.pierce + 1)) if w.pierce > 0 else "", 1 + hijack_level],
		"Move %d   Dash %.1fs   Max HP %d   Thread dmg %d   Pin reach %d   Freeze cap %.0fs   Repay %.2fx" % [int(speed), dash_reset, max_health, thread_damage, int(reach), max_debt, repay_speed],
		"Chain blast %d px / %d dmg    Refund %.1fs per kill    Lasso %s    Time Scars %s" % [int(blast_radius), blast_damage, refund, "ON" if lasso else "off", ("%d dmg" % (1 + scar_level)) if scar_level > 0 else "off"],
	]


func _start() -> void:
	player = get_viewport_rect().size / 2.0
	stage = 1
	xp = 0
	level = 1
	pending_levels = 0
	shards.clear()
	hijack_level = 1  # basic Bullet Hijack: every character can steal bullets
	hijack_offers = 0
	steals = 0
	stolen_hits = 0
	hint_time = 0.0
	intro_shooter = false
	scar_level = 0
	fork_level = 0
	scars.clear()
	picked_time = 0.0
	score = 0
	new_best = false
	var info = CHARACTERS[char_index]
	max_health = info.hp
	health = max_health
	last_health = health
	max_debt = 3.0
	repay_speed = 1.8
	fire_rate = info.rate
	damage = info.damage
	speed = info.speed
	thread_damage = 3
	blast_radius = 80.0
	blast_damage = 2
	reach = 160.0
	refund = 0.0
	lasso = false
	dash_reset = 1.0
	levels.clear()
	offers.clear()
	picked_text = ""
	loop_life = 0.0
	ripples.clear()
	trail.clear()
	world_clock = 0.0
	hitstop = 0.0
	style = 0.0
	last_rank = 0
	peak_rank = 0
	glitch = 0.0
	fire_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	immunity = 1.5
	shake = 0.0
	flash = 0.0
	run_time = 0.0
	best_combo = 0
	taught = false
	cheated = false
	sparks.clear()
	popups.clear()
	snap_lines.clear()
	blasts.clear()
	pops.clear()
	_begin_stage(1)


func _hover_select(pos: Vector2) -> void:
	for i in range(CHARACTERS.size()):
		if _select_card_rect(i).has_point(pos):
			select_index = i


func _open_select() -> void:
	state = "select"
	select_index = char_index
	enemies.clear()
	bullets.clear()
	portals.clear()
	shards.clear()
	anchors.clear()
	scars.clear()
	sparks.clear()  # a clean stage for the fighter previews
	popups.clear()
	frozen = false
	debt = 0.0


func _choose_character() -> void:
	char_index = select_index
	_sound("upgrade")
	_start()


func _begin_stage(n: int) -> void:
	stage = n
	kills_stage = 0
	boss_phase = false
	player = get_viewport_rect().size / 2.0 + Vector2(0, 30)
	scars.clear()
	state = "play"
	enemies.clear()
	bullets.clear()
	portals.clear()
	anchors.clear()
	debt = 0.0
	frozen = false
	space_ready = false
	world_speed = 1.0
	spawn_timer = 1.0
	immunity = maxf(immunity, 1.0)
	_banner("STAGE %d  -  %s" % [stage, STAGES[stage - 1].name], STAGES[stage - 1].tip)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	clock += delta

	if state == "play" and hitstop > 0.0:
		hitstop -= delta  # brief freeze-frame on big hits
		_update_view(delta)
		queue_redraw()
		return

	if state == "play":
		run_time += delta
		_tick(delta)
	elif state == "upgrade":
		upgrade_delay = maxf(0.0, upgrade_delay - delta)
	elif state == "stage_clear":
		_tick_transition(delta)

	if state != "pause":
		_update_effects(delta)

	_update_view(delta)
	queue_redraw()


func _update_effects(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].life -= delta
		sparks[i].pos += sparks[i].vel * delta
		if sparks[i].life <= 0:
			sparks.remove_at(i)

	for i in range(popups.size() - 1, -1, -1):
		popups[i].life -= delta
		popups[i].pos += Vector2(0, -26.0 * delta)
		if popups[i].life <= 0:
			popups.remove_at(i)

	for list in [snap_lines, blasts, pops]:
		for i in range(list.size() - 1, -1, -1):
			list[i].life -= delta
			if list[i].life <= 0:
				list.remove_at(i)

	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].t += delta
		if ripples[i].t > 0.9:
			ripples.remove_at(i)

	loop_life = maxf(0.0, loop_life - delta)
	glitch = maxf(0.0, glitch - delta * 3.0)
	picked_time = maxf(0.0, picked_time - delta)
	hint_time = maxf(0.0, hint_time - delta)
	shake = maxf(0.0, shake - delta * 2.2)
	flash = maxf(0.0, flash - delta * 2.5)
	banner_time = maxf(0.0, banner_time - delta)


# --- TIME: freeze, debt, release ------------------------------------------

func _time_step(delta: float, holding: bool) -> void:
	if not holding:
		space_ready = true

	if holding and debt < max_debt and (frozen or (debt <= 0.0 and space_ready)):
		if not frozen:
			frozen = true
			anchors.clear()
			flash = 0.3
			flash_color = ICE
			ripples.append({"pos": player, "t": 0.0, "color": ICE})
			glitch = 0.6
			_sound("freeze")
		debt = minf(max_debt, debt + delta)
		world_speed = 0.0
		return

	if frozen:
		frozen = false
		if holding:
			space_ready = false  # hit the debt cap: must re-press SPACE later
		_release_stitch()

	if debt > 0.0:
		world_speed = repay_speed
		debt = maxf(0.0, debt - delta)
		if debt <= 0.0:
			world_speed = 1.0
			_popup(player + Vector2(0, -36), "DEBT PAID", MINT, 17, 1.0)
			_sound("paid")
	else:
		world_speed = 1.0


func _pin_point() -> Vector2:
	return _pin_from(_mouse())


func _pin_from(target: Vector2) -> Vector2:
	# A pin lands on the aimed target, limited to the reach circle and the arena.
	var size = get_viewport_rect().size
	var offset = (target - player).limit_length(reach)
	return (player + offset).clamp(Vector2(22, 106), size - Vector2(22, 42))


func _fire() -> void:
	var aim = player.direction_to(_mouse())
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	fire_timer = fire_rate

	if frozen:
		var pin = _pin_point()
		# Pins need real spacing: stacking pins on one spot is not a stitch.
		if anchors.size() >= MAX_ANCHORS or (anchors.size() > 0 and anchors[anchors.size() - 1].distance_to(pin) < MIN_PIN_GAP):
			return
		var direction = player.direction_to(pin)
		if direction == Vector2.ZERO:
			direction = aim
		anchors.append(pin)
		# Every weapon pins exactly ONE projectile per click (no pellet/arrow spam).
		var w = CHARACTERS[char_index]
		_shoot(pin, direction * w.proj_speed, true, damage, w.pierce, w.life, char_index)
		snap_lines.append({"a": player + direction * 20.0, "b": pin, "life": 0.15, "max": 0.15, "color": MINT, "width": 2.0})
		_sound("stitch", 1.0 + anchors.size() * 0.02)
	else:
		var w = CHARACTERS[char_index]
		for d in _volley(aim):
			var spd = w.proj_speed * (randf_range(0.88, 1.0) if w.pellets > 1 else 1.0)
			_shoot(player + d * 24.0, d * spd, true, damage, w.pierce, w.life, char_index)
		recoil = 1.0
		_sound("shot", [1.0, 0.75, 0.55][char_index])


func _volley(aim: Vector2) -> Array:
	# Directions for one trigger pull. Caps: rifle/bow 5 per trigger, scattergun 9 pellets.
	var w = CHARACTERS[char_index]
	var dirs = []
	if w.pellets > 1:
		var count = w.pellets + fork_level * 2
		var spread = w.spread + fork_level * 0.08
		for k in range(count):
			dirs.append(aim.rotated(lerpf(-spread, spread, float(k) / (count - 1)) + randf_range(-0.03, 0.03)))
	else:
		dirs.append(aim)
		var step = 0.12 if char_index == 1 else 0.2
		for k in range(1, fork_level + 1):
			dirs.append(aim.rotated(step * k))
			dirs.append(aim.rotated(-step * k))
	return dirs


func _loop_closed() -> bool:
	return lasso and anchors.size() >= 4 and anchors[0].distance_to(anchors[anchors.size() - 1]) < 90.0


func _thread_hits(pos: Vector2, tolerance: float) -> int:
	var count = 0
	for i in range(anchors.size() - 1):
		if anchors[i].distance_to(anchors[i + 1]) < 1.0:
			continue  # degenerate segment: not a thread
		var closest = Geometry2D.get_closest_point_to_segment(pos, anchors[i], anchors[i + 1])
		if closest.distance_to(pos) < tolerance:
			count += 1
	if _loop_closed() and anchors[anchors.size() - 1].distance_to(anchors[0]) >= 1.0:
		var closing = Geometry2D.get_closest_point_to_segment(pos, anchors[anchors.size() - 1], anchors[0])
		if closing.distance_to(pos) < tolerance:
			count += 1
	return count


func _inside_loop(pos: Vector2, looped: bool) -> bool:
	return looped and Geometry2D.is_point_in_polygon(pos, PackedVector2Array(anchors))


func _stitch_damage(pos: Vector2, radius: float, looped: bool) -> int:
	# Used by BOTH the frozen preview and the release, so the preview never lies.
	var amount = _thread_hits(pos, radius + 6.0) * thread_damage
	if _inside_loop(pos, looped):
		amount += thread_damage * 3
	return amount


func _rank() -> int:
	var index = 0
	for i in range(RANKS.size()):
		if style >= RANKS[i][1]:
			index = i
	return index


func _gain_style(amount: float) -> void:
	style = minf(30.0, style + amount)
	var r = _rank()
	if r > last_rank:
		peak_rank = maxi(peak_rank, r)
		_popup(player + Vector2(0, -80), "%s RANK" % RANKS[r][0], GOLD if r >= 4 else MINT, 24 + r * 3, 1.2)
		_sound("upgrade", 1.0 + r * 0.08)
		glitch = 0.5
	last_rank = r


func _release_stitch() -> void:
	ripples.append({"pos": player, "t": 0.0, "color": MINT})
	glitch = maxf(glitch, 0.35)
	if anchors.size() < 2:
		anchors.clear()
		_sound("snap", 0.6)
		return

	_sound("snap")
	var looped = _loop_closed()
	var hit_count = 0
	var pin_center = Vector2.ZERO
	for a in anchors:
		pin_center += a
	pin_center /= anchors.size()
	for e in enemies:
		var amount = _stitch_damage(e.pos, e.radius, looped)
		if amount > 0:
			e.hp -= amount
			e.flash = 0.25
			e.pos += pin_center.direction_to(e.pos) * 16.0  # visible snap reaction
			hit_count += 1
			_popup(e.pos + Vector2(0, e.radius + 24), "-%d" % amount, Color.WHITE, 15, 0.7)

	var cut = 0
	var stolen: Array = []
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		if not b.friendly and (_thread_hits(b.pos, 10.0) > 0 or _inside_loop(b.pos, looped)):
			cut += 1
			if hijack_level > 0:
				# BULLET HIJACK: the shot becomes ours (once). It turns friendly right
				# away so chain blasts below can't delete it; it is aimed later.
				b.friendly = true
				b.hijack = true
				b.damage = 1 + hijack_level
				b.pierce = 1 if hijack_level >= 3 else 0
				b.vel = -b.vel.normalized() * 640.0  # fallback if nothing survives
				b.life = 1.4
				stolen.append(b)
				_burst(b.pos, ICE, 4)
			else:
				_burst(b.pos, GOLD, 3)
				bullets.remove_at(i)

	var center = Vector2.ZERO
	for i in range(anchors.size()):
		center += anchors[i]
		var next = i + 1
		if next >= anchors.size():
			if not looped:
				continue
			next = 0
		snap_lines.append({"a": anchors[i], "b": anchors[next], "life": 0.45, "max": 0.45, "color": GOLD if looped else Color.WHITE, "width": 5.0})
		_burst(anchors[i].lerp(anchors[next], randf()), MINT, 2)
	center /= anchors.size()
	if scar_level > 0:
		# TIME SCARS: every real segment lingers as a floor hazard for enemies.
		var life = 1.25 + scar_level * 0.75
		for i in range(anchors.size()):
			var j = i + 1
			if j >= anchors.size():
				if not looped:
					break
				j = 0
			if anchors[i].distance_to(anchors[j]) >= 1.0:
				scars.append({"a": anchors[i], "b": anchors[j], "life": life, "max": life, "hit": {}})
		while scars.size() > 80:
			scars.remove_at(0)
	if looped:
		loop_poly = PackedVector2Array(anchors)
		loop_life = 0.6
		_popup(center + Vector2(0, -36), "LASSO!", GOLD, 30, 1.1)
	anchors.clear()

	var kills = _resolve_deaths()
	if state != "play":
		return

	# Aim stolen shots only now, after deaths and chain reactions are resolved,
	# so they always target an enemy that is still alive.
	for b in stolen:
		var target = _nearest_enemy(b.pos, 560.0)
		if not target.is_empty():
			b.vel = b.pos.direction_to(target.pos) * 640.0
	if not stolen.is_empty():
		steals += stolen.size()
		_sound("upgrade", 1.6)

	if hit_count > 0:
		taught = true
	if kills > 0:
		best_combo = maxi(best_combo, kills)
		if refund > 0.0 and debt > 0.0:
			var repaid = minf(debt, refund * kills)
			debt -= repaid
			_popup(player + Vector2(0, -56), "REFUND -%.1fs DEBT" % repaid, MINT, 16, 1.2)
		_popup(center, "STITCH x%d" % kills if kills > 1 else "STITCHED", GOLD, mini(22 + kills * 4, 46), 1.3)
		shake = minf(1.0, shake + 0.2 + kills * 0.12)
		if kills >= 2:
			hitstop = minf(0.16, 0.04 + kills * 0.025)
		flash = 0.35
		flash_color = MINT
	else:
		shake = minf(1.0, shake + 0.15)
	if cut > 0:
		_popup(player + Vector2(0, -30), "%d SHOTS %s" % [cut, "HIJACKED" if hijack_level > 0 else "CUT"], ICE if hijack_level > 0 else MINT, 16, 1.0)


func _resolve_deaths() -> int:
	# Removes dead enemies. Stitched kills detonate, which can kill more (chain).
	var kills = 0
	for guard in range(40):
		var dead: Array = []
		for j in range(enemies.size() - 1, -1, -1):
			if enemies[j].hp <= 0:
				dead.append(enemies[j])
				enemies.remove_at(j)
		if dead.is_empty():
			break

		for e in dead:
			kills += 1
			_on_kill(e, kills, true)
			if state != "play":
				return kills
			blasts.append({"pos": e.pos, "life": 0.35, "max": 0.35, "radius": blast_radius})
			_sound("boom", 1.0 + 0.05 * kills)
			for o in enemies:
				if o.pos.distance_to(e.pos) < blast_radius + o.radius:
					o.hp -= blast_damage
					o.flash = 0.25
			for i in range(bullets.size() - 1, -1, -1):
				if not bullets[i].friendly and bullets[i].pos.distance_to(e.pos) < blast_radius:
					bullets.remove_at(i)
	return kills


# --- MAIN UPDATE -------------------------------------------------------------

func _tick(delta: float) -> void:
	_time_step(delta, bot.get("space", false) if not bot.is_empty() else Input.is_physical_key_pressed(KEY_SPACE))
	if state != "play":
		return

	var dt = delta * world_speed
	var size = get_viewport_rect().size
	var lo = Vector2(30, 115)
	var hi = size - Vector2(30, 55)

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	direction.y += float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	direction = direction.limit_length()
	if not bot.is_empty():
		direction = bot.get("move", Vector2.ZERO).limit_length()

	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	immunity = maxf(0.0, immunity - delta)

	if (bot.get("dash", false) if not bot.is_empty() else Input.is_physical_key_pressed(KEY_SHIFT)) and dash_cooldown <= 0:
		dash_direction = direction if direction.length() > 0 else player.direction_to(_mouse())
		dash_timer = 0.16
		dash_cooldown = dash_reset
		immunity = maxf(immunity, 0.22)
		_sound("dash")

	if dash_timer > 0:
		dash_timer -= delta
		player += dash_direction * 950.0 * delta
		_burst(player, MINT, 2)
	else:
		player += direction * speed * delta
	player = player.clamp(lo, hi)
	world_clock += dt
	style = maxf(0.0, style - dt * (0.3 + style * 0.05))  # decays only while time moves
	last_rank = mini(last_rank, _rank())
	trail.push_front(player)
	if trail.size() > 12:
		trail.pop_back()

	fire_timer -= delta
	# Auto-fire (F) never places pins: while frozen, pins need a real click.
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (autofire and not frozen) or bot.get("fire", false)) and fire_timer <= 0:
		_fire()

	_direct_spawns(dt)

	for i in range(portals.size() - 1, -1, -1):
		var p = portals[i]
		p.time -= dt
		if p.time <= 0:
			if p.pos.distance_to(player) < 90:
				p.time = 0.3  # never materialize on top of the player
			else:
				portals.remove_at(i)
				_materialize(p)

	for e in enemies:
		e.age += dt
		e.flash = maxf(0.0, e.flash - delta)
		var toward = e.pos.direction_to(player)
		var distance = e.pos.distance_to(player)

		if e.kind == 0:
			e.pos += toward * (85.0 + stage * 10.0) * (0.8 if e.elite else 1.0) * dt
		elif e.kind == 1:
			e.pos += toward * (55.0 if distance > 260 else -25.0) * dt
			# The last 0.5s is the visible warning: it runs at real-time pace even
			# during repayment, so a sped-up world never shortens a telegraph.
			e.cooldown -= dt if e.cooldown > 0.5 else dt / maxf(world_speed, 1.0)
			if e.cooldown <= 0 and dt > 0.0:
				e.cooldown = [2.2, 1.9, 1.6][stage - 1]
				_shoot(e.pos, toward * 230.0, false)
				if e.elite:
					_shoot(e.pos, toward.rotated(0.25) * 230.0, false)
					_shoot(e.pos, toward.rotated(-0.25) * 230.0, false)
		elif e.kind == 3:
			_charger_ai(e, dt, toward)
		else:
			_boss_ai(e, dt, toward, distance)

		e.pos = e.pos.clamp(lo, hi)
		if e.pos.distance_to(player) < e.radius + 13:
			_hurt()
			if state != "play":
				return

	_update_scars(dt)
	if state != "play":
		return

	var screen = get_viewport_rect().grow(60)
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		var previous = b.pos
		b.pos += b.vel * dt
		b.life -= dt
		var used = false

		if b.friendly:
			if dt > 0:  # pinned shots wait for the release
				# Hits resolve in TRAVEL ORDER along this step's path, so a fast shot
				# never skips a nearer enemy for a farther one (or an older one).
				for hit in _swept_hits(b, previous):
					var e = hit.e
					var at = previous.lerp(b.pos, hit.t)
					b.hits[e.id] = true  # a piercing shot damages each enemy only once
					e.hp -= b.damage
					e.flash = 0.08
					if b.hijack:
						_burst(at, ICE, 10)  # stolen shot landing: loud and violet
						_sound("kill", 1.7)
						stolen_hits += 1
						if stolen_hits <= 6:
							_popup(e.pos + Vector2(0, -30), "STOLEN HIT!", ICE, 16, 0.8)
					else:
						_burst(at, GOLD, 4)
					if e.hp <= 0:
						enemies.erase(e)
						_on_kill(e, 1, false, b.hijack)
						if state != "play":
							return
					if b.pierce > 0:
						b.pierce -= 1
					else:
						used = true
						break
		else:
			var closest = Geometry2D.get_closest_point_to_segment(player, previous, b.pos)
			if closest.distance_to(player) < 17:
				_hurt()
				used = true
				if state != "play":
					return

		if used or b.life <= 0 or not screen.has_point(b.pos):
			bullets.remove_at(i)

	_update_shards(dt)

	if kills_stage >= STAGES[stage - 1].quota and not boss_phase:
		if stage < STAGES.size():
			_stage_cleared()
			return
		boss_phase = true
		_boss_entrance()

	_try_level_menu()


func _try_level_menu() -> void:
	# Level-up menu waits until the freeze is over, then pauses everything.
	if pending_levels > 0 and not frozen and state == "play":
		state = "upgrade"
		offers = _roll_offers()
		upgrade_delay = 0.5
		_sound("upgrade", 1.3)


func _update_scars(dt: float) -> void:
	if scars.is_empty() or dt <= 0.0:
		return
	var hit_any = false
	for i in range(scars.size() - 1, -1, -1):
		var s = scars[i]
		s.life -= dt
		if s.life <= 0.0:
			scars.remove_at(i)
			continue
		for e in enemies:
			if s.hit.has(e.id):
				continue  # each scar hits each enemy at most once
			if Geometry2D.get_closest_point_to_segment(e.pos, s.a, s.b).distance_to(e.pos) < e.radius + 4.0:
				s.hit[e.id] = true
				e.hp -= 1 + scar_level
				e.flash = 0.15
				hit_any = true
	if hit_any:
		var kills = _resolve_deaths()
		if kills >= 2 and state == "play":
			_popup(player + Vector2(0, -50), "SCAR x%d" % kills, ICE, 20, 1.0)


func _charger_ai(e: Dictionary, dt: float, toward: Vector2) -> void:
	# Creep -> clear windup (red dash line) -> straight dash -> recover.
	if dt <= 0.0:
		return
	e.timer -= dt / maxf(world_speed, 1.0) if e.mode == "windup" else dt  # windup at real-time pace
	if e.mode == "rest":
		e.pos += toward * 55.0 * dt
		e.dir = toward
		if e.timer <= 0.0 and e.pos.distance_to(player) < 430.0:
			e.mode = "windup"
			e.timer = CHARGER_WINDUP
			e.dir = toward
			_sound("warn", 1.3)
	elif e.mode == "windup":
		if e.timer <= 0.0:
			e.mode = "dash"
			e.timer = 0.5
	else:
		e.pos += e.dir * 500.0 * dt
		if e.timer <= 0.0:
			e.mode = "rest"
			e.timer = 1.8


# --- XP ------------------------------------------------------------------------

func _xp_need(l: int) -> int:
	return 5 + (l - 1) * 5 + (l - 1) * (l - 1)


func _drop_xp(pos: Vector2, value: int) -> void:
	if value <= 0:
		return
	if shards.size() >= MAX_SHARDS:
		shards[randi() % shards.size()].value += value  # merge instead of growing
		return
	shards.append({"pos": pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), "value": value})


func _gain_xp(amount: int) -> void:
	xp += amount
	if clock - xp_tick > 0.06:
		xp_tick = clock
		_sound("stitch", 1.7 + randf() * 0.2)
	while xp >= _xp_need(level):
		xp -= _xp_need(level)  # excess XP carries over
		level += 1
		pending_levels += 1
		_popup(player + Vector2(0, -70), "LEVEL %d" % level, LIME, 24, 1.2)
		ripples.append({"pos": player, "t": 0.0, "color": LIME})


func _update_shards(dt: float) -> void:
	for s in shards:
		var d = s.pos.distance_to(player)
		if d < magnet:
			s.pos = s.pos.move_toward(player, (260.0 + (magnet - d) * 6.0) * dt)
	_collect_shards()


func _collect_shards() -> void:
	for i in range(shards.size() - 1, -1, -1):
		if shards[i].pos.distance_to(player) < 22.0:
			var value = shards[i].value
			shards.remove_at(i)
			_gain_xp(value)


func _nearest_enemy(pos: Vector2, max_range: float) -> Dictionary:
	var found = {}
	var best_d = max_range
	for e in enemies:
		var d = e.pos.distance_to(pos)
		if d < best_d:
			best_d = d
			found = e
	return found


func _entry_t(p0: Vector2, p1: Vector2, c: Vector2, r: float) -> float:
	# Earliest fraction (0..1) of the path p0 -> p1 that is inside the circle
	# (c, r); -1 if the path never enters it during this step.
	var f = p0 - c
	var cc = f.dot(f) - r * r
	if cc < 0.0:
		return 0.0  # already overlapping at the start of the step
	var d = p1 - p0
	var a = d.dot(d)
	if a < 0.000001:
		return -1.0
	var bq = 2.0 * f.dot(d)
	var disc = bq * bq - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var t = (-bq - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _swept_hits(b: Dictionary, from: Vector2) -> Array:
	# Every enemy this projectile's path enters during this step (skipping ones
	# it already hit), ordered by WHERE along the path it enters them.
	var found = []
	for e in enemies:
		if b.hits.has(e.id):
			continue
		var r = e.radius + 5.0
		if Geometry2D.get_closest_point_to_segment(e.pos, from, b.pos).distance_squared_to(e.pos) >= r * r:
			continue  # fast built-in reject: the path never comes within reach of this enemy
		var t = _entry_t(from, b.pos, e.pos, r)
		if t >= 0.0:
			found.append({"t": t, "d": from.distance_to(e.pos), "e": e})
	found.sort_custom(func(x, y): return x.t < y.t or (x.t == y.t and x.d < y.d))
	return found


func _boss_ai(e: Dictionary, dt: float, toward: Vector2, distance: float) -> void:
	if dt <= 0.0:
		return  # frozen world time: no movement, no summons, no attacks
	e.pos += toward * (40.0 if distance > 250 else -35.0) * dt  # holds mid range: every weapon can reach
	var enraged = e.hp <= e.max_hp * 0.5
	var pace = 1.25 if enraged else 1.05

	if (e.summons == 0 and e.hp <= e.max_hp * 0.66) or (e.summons == 1 and e.hp <= e.max_hp * 0.33):
		e.summons += 1
		# Summons are explicit extras, but never push the boss arena past 9 minions.
		var minions = enemies.size() - 1 + portals.size()
		for k in range(mini(3, 9 - minions)):
			portals.append(_portal(e.pos + Vector2.from_angle(TAU * k / 3.0 + randf()) * 95.0, 0))
		_popup(e.pos + Vector2(0, -70), "MINIONS INCOMING", GOLD, 16, 1.4)

	e.timer -= dt / maxf(world_speed, 1.0) if e.mode == "charge" else dt  # warnings at real-time pace
	if e.mode == "rest":
		if e.timer <= 0:
			e.mode = "charge"
			e.timer = BOSS_CHARGE
			e.pattern = (e.pattern + 1) % 3
			_sound("warn")
	elif e.mode == "charge":
		if e.timer <= 0:
			e.mode = "fire"
			e.shot_timer = 0.0
			e.shots_left = [3 if enraged else 2, 22 if enraged else 16, 4 if enraged else 3][e.pattern]
	else:
		e.shot_timer -= dt
		if e.shot_timer <= 0:
			e.shots_left -= 1
			if e.pattern == 0:
				var gap = randi() % 18
				for k in range(18):
					if (k - gap + 18) % 18 < 4:
						continue  # a 4-bullet gap you can slip through
					_shoot(e.pos, Vector2.from_angle(e.spin + TAU * k / 18.0) * 150.0 * pace, false)
				e.spin += TAU / 36.0
				e.shot_timer = 0.6
			elif e.pattern == 1:
				for k in range(3):
					_shoot(e.pos, Vector2.from_angle(e.spin + TAU * k / 3.0) * 140.0 * pace, false)
				e.spin += 0.3
				e.shot_timer = 0.14
			else:
				var base = toward.angle()
				for k in range(-2, 3):
					_shoot(e.pos, Vector2.from_angle(base + k * 0.22) * 230.0 * pace, false)
				e.shot_timer = 0.45

			if e.shots_left <= 0:
				e.mode = "rest"
				e.timer = 0.7 if enraged else 1.1


# --- SPAWNING ----------------------------------------------------------------

func _direct_spawns(dt: float) -> void:
	# Survivor-style director: groups keep arriving, faster as the stage goes on.
	var info = STAGES[stage - 1]
	spawn_timer -= dt
	# Capacity counts live enemies AND pending portals (boss phase: boss + 6).
	var room = (7 if boss_phase else info.cap) - (enemies.size() + portals.size())
	if spawn_timer > 0.0 or room <= 0:
		return
	var progress = clampf(float(kills_stage) / info.quota, 0.0, 1.0)
	spawn_timer = lerpf(info.slow, info.fast, progress) * (2.2 if boss_phase else 1.0)
	if stage == 1 and not intro_shooter and kills_stage >= 4:
		intro_shooter = true  # teach stealing: one lone, clearly telegraphed shooter
		portals.append(_portal(_safe_point(), 1))
		hint_time = 24.0
		spawn_timer = 3.0  # give the lesson some room
		return
	var pos = _safe_point()
	var roll = randf()
	if stage == 1:
		if progress > 0.4 and roll < 0.22:
			portals.append(_portal(pos, 1))
		else:
			_pack(pos, mini(2 + randi() % 3, room), false)
	elif stage == 2:
		if roll < 0.3:
			portals.append(_portal(pos, 1))
		elif roll < 0.5:
			portals.append(_portal(pos, 3))
		else:
			_pack(pos, mini(3 + randi() % 3, room), false)
	else:
		if roll < 0.25:
			portals.append(_portal(pos, 1))
			if room >= 2:
				portals.append(_portal(pos + Vector2(60, 0), 1, randf() < 0.3))
		elif roll < 0.45:
			portals.append(_portal(pos, 3, randf() < 0.3))
		else:
			_pack(pos, mini(4 + randi() % 3, room), not boss_phase)


func _pack(pos: Vector2, count: int, with_elite: bool) -> void:
	# Clustered groups are what make a good stitch possible.
	for k in range(count):
		var offset = Vector2.ZERO if k == 0 else Vector2.from_angle(TAU * k / count + randf() * 0.5) * (34.0 + 10.0 * (k % 2))
		portals.append(_portal(pos + offset, 0, with_elite and k == 0))


func _boss_entrance() -> void:
	# Clean arena for the finale: no leftover hazards, a moment to breathe.
	for i in range(bullets.size() - 1, -1, -1):
		if not bullets[i].friendly:
			_burst(bullets[i].pos, GOLD, 2)
			bullets.remove_at(i)
	for e in enemies:
		_burst(e.pos, PINK, 8)
		_drop_xp(e.pos, XP_VALUE[e.kind])
	enemies.clear()
	portals.clear()
	anchors.clear()
	immunity = maxf(immunity, 1.5)
	spawn_timer = 4.0
	shake = 0.6
	_spawn_boss()


func _spawn_boss() -> void:
	var size = get_viewport_rect().size
	var spot = Vector2(size.x / 2.0, 230)
	if spot.distance_to(player) < 280:
		spot.y = size.y - 170
	portals.append({"pos": spot, "kind": 2, "time": 2.2, "max": 2.2, "elite": false})
	_banner("THE COLLECTOR", "It collects every second you borrowed")
	_sound("warn", 0.7)


func _safe_point() -> Vector2:
	var size = get_viewport_rect().size
	var best_pos = Vector2(60, 150)
	var best_distance = -1.0
	for attempt in range(16):
		var p = Vector2(randf_range(60, size.x - 60), randf_range(150, size.y - 85))
		var d = p.distance_to(player)
		if d > 280:
			return p
		if d > best_distance:
			best_distance = d
			best_pos = p
	return best_pos


func _portal(pos: Vector2, kind: int, elite: bool = false) -> Dictionary:
	var size = get_viewport_rect().size
	return {"pos": pos.clamp(Vector2(40, 130), size - Vector2(40, 65)), "kind": kind, "time": 1.0, "max": 1.0, "elite": elite}


func _materialize(p: Dictionary) -> void:
	var kind = p.kind
	var elite = p.get("elite", false)
	var info = STAGES[stage - 1]
	var hp = BOSS_HP if kind == 2 else [info.chaser, info.shooter, 0, info.charger][kind]
	if elite:
		hp *= 3
	next_id += 1
	enemies.append({
		"id": next_id,
		"elite": elite,
		"dir": Vector2.RIGHT,
		"pos": p.pos,
		"kind": kind,
		"hp": hp,
		"max_hp": hp,
		"radius": 40.0 if kind == 2 else (26.0 if elite else (20.0 if kind == 3 else 18.0)),
		"cooldown": 1.4,
		"age": 0.0,
		"flash": 0.0,
		"mode": "rest",
		"timer": 1.5,
		"pattern": -1,
		"shots_left": 0,
		"shot_timer": 0.0,
		"spin": 0.0,
		"summons": 0,
	})
	_burst(p.pos, PINK if kind == 0 else GOLD, 30 if kind == 2 else 12)
	if kind == 2:
		shake = 0.6
		_sound("boom", 0.6)


# --- COMBAT EVENTS -----------------------------------------------------------

func _shoot(pos: Vector2, velocity: Vector2, friendly: bool, power: int = 1, pierce: int = 0, life: float = 6.0, kind: int = 0) -> void:
	# kind: 0 bolt, 1 arrow, 2 pellet. pierce = extra enemies it may pass through.
	if bullets.size() >= MAX_BULLETS:
		return  # hard cap: every simulated bullet always fits a render pool
	bullets.append({"pos": pos, "vel": velocity, "friendly": friendly, "damage": power, "life": life, "hijack": false, "pierce": pierce, "hits": {}, "kind": kind})


func _on_kill(e: Dictionary, chain: int, stitched: bool, hijacked: bool = false) -> void:
	# The ONLY place a kill is rewarded. Callers remove the enemy first, so
	# score and XP can never be awarded twice for one enemy.
	if e.kind == 2:
		score += 5000
		_burst(e.pos, GOLD, 80)
		_burst(e.pos, PINK, 60)
		for o in enemies:
			_burst(o.pos, PINK, 10)
		enemies.clear()
		portals.clear()
		bullets.clear()
		shake = 1.0
		flash = 0.8
		flash_color = GOLD
		hitstop = 0.35
		ripples.append({"pos": e.pos, "t": 0.0, "color": GOLD})
		_finish("win")
		return

	kills_stage += 1
	_drop_xp(e.pos, XP_VALUE[e.kind] + (4 if e.elite else 0))
	_gain_style(1.2 if stitched else (0.8 if hijacked else 0.35))
	if hijacked and refund > 0.0 and debt > 0.0:
		debt = maxf(0.0, debt - refund * 0.5)  # Hijack + Refund synergy
	var points = int((100 if e.kind == 0 else 150) * (3 if e.elite else 1) * chain * (1.0 + _rank() * 0.25))
	score += points
	_burst(e.pos, PINK if e.kind == 0 else GOLD, 16)
	pops.append({"pos": e.pos, "life": 0.22, "r": e.radius})
	_sound("kill", 1.0 + 0.08 * (chain - 1))
	if chain > 1:
		_popup(e.pos, "+%d" % points, GOLD, 14, 0.8)


func _hurt() -> void:
	if immunity > 0:
		return

	health -= 1
	immunity = 1.1
	shake = minf(1.0, shake + 0.5)
	flash = 0.6
	flash_color = PINK
	hitstop = 0.07
	glitch = 1.0
	if style >= 2.0:
		_popup(player + Vector2(0, -60), "RANK LOST", PINK, 18, 1.0)
	style *= 0.3
	last_rank = _rank()
	ripples.append({"pos": player, "t": 0.3, "color": PINK})
	_burst(player, PINK, 22)
	_sound("hit")

	if health <= 0:
		_finish("over")


func _stage_cleared() -> void:
	# Safe transition: clear hazards, dissolve stragglers, vacuum XP, heal a bit.
	for e in enemies:
		_burst(e.pos, PINK if e.kind == 0 else GOLD, 6)
	enemies.clear()
	portals.clear()
	bullets.clear()
	anchors.clear()
	frozen = false
	debt = 0.0
	world_speed = 1.0
	health = mini(max_health, health + 2)
	state = "stage_clear"
	transition = 3.2
	ripples.append({"pos": player, "t": 0.0, "color": GOLD})
	_sound("paid", 0.8)


func _tick_transition(delta: float) -> void:
	transition -= delta
	for s in shards:
		s.pos = s.pos.move_toward(player, 900.0 * delta)
	_collect_shards()
	if transition <= 0.0:
		_begin_stage(stage + 1)


func _finish(result: String) -> void:
	state = result
	frozen = false
	anchors.clear()
	if not cheated and score > best:
		best = score
		new_best = true
		var save = ConfigFile.new()
		save.set_value("game", "best", best)
		save.save(SAVE_PATH)
	_sound("upgrade" if result == "win" else "boom", 0.8)


func _burst(pos: Vector2, color: Color, count: int) -> void:
	if low_fx or enemies.size() > 26:
		count = int(count / 2.0)  # fewer decorative sparks when combat is busy
	for i in range(count):
		if sparks.size() < 500:
			sparks.append({
				"pos": pos,
				"vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 190),
				"life": randf_range(0.15, 0.45),
				"color": color
			})


func _popup(pos: Vector2, words: String, color: Color, size: int, life: float) -> void:
	popups.append({"pos": pos, "text": words, "color": color, "size": size, "life": life})


func _banner(title: String, sub: String) -> void:
	banner = title
	banner_sub = sub
	banner_time = 2.6


# --- 3D VIEW -----------------------------------------------------------------
# Game logic runs in 2D "pixel" coordinates. The arena is rendered in real 3D:
# 1 unit = UNIT pixels and the floor is the XZ plane. The HUD is drawn in 2D
# on top (a Node2D canvas always renders over the 3D view).

const UNIT = 40.0
const PIN_H = 0.95
const AIM_H = 0.7
const BODY_H = 0.5  # enemies and hostile bullets are drawn here; aim and threads use it too
const CITY_GAP = 1.5  # minimum clearance between skyline buildings and the arena edge
const BULLET_PICK_PX = 14.0  # screen radius for snapping a pin onto a frozen enemy bullet
const FLOOR_SHADER = """
shader_type spatial;
uniform vec4 line_color : source_color = vec4(0.07, 0.16, 0.24, 1.0);
uniform vec4 accent : source_color = vec4(0.17, 0.26, 0.33, 1.0);
uniform vec2 half_size = vec2(14.0, 6.4);
uniform float scroll = 0.0;
uniform vec2 focus = vec2(0.0, 0.0);
uniform float focus_r = 6.5;
uniform float ripple_data[16];
uniform float ripple_rgb[12];
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 f = fract(vec2(p.x, p.y + scroll) / 1.2);
	vec2 dd = min(f, 1.0 - f) * 1.2;
	float line = 1.0 - smoothstep(0.0, 0.035, min(dd.x, dd.y));
	vec2 e = half_size - abs(p);
	float edge_d = min(e.x, e.y);
	float inside = step(0.0, edge_d);
	vec3 em = line_color.rgb * line * mix(0.08, 0.75, inside);
	em += accent.rgb * exp(-abs(edge_d) * 4.0) * 0.14;  // thin boundary hint, not a neon frame
	vec2 fp = p - focus;
	em *= mix(0.22, 1.0, exp(-dot(fp, fp) / (2.0 * focus_r * focus_r)));  // light pool around the player
	for (int i = 0; i < 4; i++) {
		float s = ripple_data[i * 4 + 3];
		if (s > 0.0) {
			vec2 c = vec2(ripple_data[i * 4], ripple_data[i * 4 + 1]);
			float d = abs(length(p - c) - ripple_data[i * 4 + 2]);
			vec3 rc = vec3(ripple_rgb[i * 3], ripple_rgb[i * 3 + 1], ripple_rgb[i * 3 + 2]);
			em += rc * exp(-d * d * 5.0) * s * (0.3 + line * 1.6);
		}
	}
	ALBEDO = vec3(0.02, 0.035, 0.06);
	ROUGHNESS = 0.28;
	METALLIC = 0.55;
	EMISSION = em;
}
"""

const POST_SHADER = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float glitch = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float band = step(0.93, fract(sin(floor(uv.y * 40.0) * 12.9898 + floor(TIME * 24.0)) * 43758.5453));
	vec2 off = c * dot(c, c) * 0.004 + vec2(glitch * 0.012 * (0.4 + band), 0.0);
	vec3 col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	col *= 0.94 + 0.06 * sin(FRAGCOORD.y * 2.2);
	COLOR = vec4(col, 1.0);
}
"""

var post_mat: ShaderMaterial
var view: Node3D
var cam: Camera3D
var env: Environment
var floor_mat: ShaderMaterial
var wall_mat: StandardMaterial3D
var walls: Array = []
var pylons: Array = []
var player_light: OmniLight3D
var boss_light: OmniLight3D
var fx_mesh: ImmediateMesh
var mm_friend: MultiMesh
var mm_hijack: MultiMesh
var mm_arrow: MultiMesh
var mm_shard: MultiMesh
var aim_cam: Camera3D
var post_rect: ColorRect
var city: Node3D
var props: Array = []
var heroes: Array = []
var recoil = 0.0
var mm_foe: MultiMesh
var mm_spark: MultiMesh
var pools: Dictionary = {}
var mats: Dictionary = {}
var boxes: Dictionary = {}
var font: Font
var font_bold: Font
var origin2d = Vector2(576, 356)
var fit_size = Vector2.ZERO
var cam_target = Vector3.ZERO
var cam_pitch = deg_to_rad(54.0)
var cam_dist = 20.0
var cam_fov = 42.0
var floor_scroll = 0.0
var mouse_hidden = false
var pv: Dictionary = {"hits": 0, "kills": 0, "cut": 0, "looped": false, "marks": [], "cuts": []}


func _setup_view() -> void:
	var regular = SystemFont.new()
	regular.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	font = regular
	var bold = SystemFont.new()
	bold.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	bold.font_weight = 700
	font_bold = bold

	view = Node3D.new()
	add_child(view)

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050914")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("34456e")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color("0b1428")
	env.fog_density = 0.022
	env.adjustment_enabled = true
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 30, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("ffe1c2")  # warm key light
	sun.shadow_enabled = true
	view.add_child(sun)
	var rim = DirectionalLight3D.new()  # cool back light: every silhouette gets a readable edge
	rim.rotation_degrees = Vector3(-35, 200, 0)
	rim.light_energy = 0.45
	rim.light_color = Color("7f9cff")
	view.add_child(rim)

	cam = Camera3D.new()
	cam.fov = cam_fov
	view.add_child(cam)
	cam.make_current()

	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(90, 60)
	floor_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = FLOOR_SHADER
	floor_mat.shader = shader
	var ground = MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.material_override = floor_mat
	view.add_child(ground)

	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("0b1420")
	wall_mat.emission_enabled = true
	wall_mat.emission_energy_multiplier = 2.2
	for i in range(4):
		var wall = MeshInstance3D.new()
		wall.mesh = BoxMesh.new()
		wall.material_override = wall_mat
		view.add_child(wall)
		walls.append(wall)
		var pylon = MeshInstance3D.new()
		var tube = CylinderMesh.new()
		tube.top_radius = 0.12
		tube.bottom_radius = 0.2
		tube.height = 1.8
		pylon.mesh = tube
		pylon.material_override = wall_mat
		view.add_child(pylon)
		pylons.append(pylon)

	player_light = OmniLight3D.new()
	player_light.omni_range = 6.5
	player_light.light_energy = 1.8
	view.add_child(player_light)
	boss_light = OmniLight3D.new()
	boss_light.omni_range = 7.0
	boss_light.light_energy = 2.5
	boss_light.light_color = GOLD
	view.add_child(boss_light)

	var chaser = CylinderMesh.new()
	chaser.top_radius = 0.2
	chaser.bottom_radius = 0.48
	chaser.height = 0.7
	chaser.radial_segments = 4
	chaser.rings = 1
	_add_pool("chaser", chaser)
	var shooter = CylinderMesh.new()
	shooter.top_radius = 0.5
	shooter.bottom_radius = 0.5
	shooter.height = 0.5
	shooter.radial_segments = 3
	shooter.rings = 1
	_add_pool("shooter", shooter)
	var boss = CylinderMesh.new()
	boss.top_radius = 0.75
	boss.bottom_radius = 1.0
	boss.height = 1.0
	boss.radial_segments = 6
	boss.rings = 1
	_add_pool("boss", boss)
	var ring = TorusMesh.new()
	ring.inner_radius = 1.25
	ring.outer_radius = 1.4
	_add_pool("boss_ring", ring)
	var orb = SphereMesh.new()
	orb.radius = 0.33
	orb.height = 0.66
	_add_pool("player", orb)
	var gun = BoxMesh.new()
	gun.size = Vector3(0.12, 0.12, 0.55)
	_add_pool("gun", gun)

	var small = SphereMesh.new()
	small.radius = 0.11
	small.height = 0.22
	small.radial_segments = 8
	small.rings = 4
	mm_friend = _make_multimesh(small, _mat(MINT, 4.0), false, 1000)
	var shaft = BoxMesh.new()
	shaft.size = Vector3(0.05, 0.05, 0.62)
	mm_arrow = _make_multimesh(shaft, _mat(MINT, 4.5), false, 1000)
	mm_hijack = _make_multimesh(small, _mat(ICE, 5.0), false, 1000)
	var big = SphereMesh.new()
	big.radius = 0.16
	big.height = 0.32
	big.radial_segments = 8
	big.rings = 4
	mm_foe = _make_multimesh(big, _mat(GOLD, 3.5), false, 1000)
	var spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	var cube = BoxMesh.new()
	cube.size = Vector3(0.09, 0.09, 0.09)
	mm_spark = _make_multimesh(cube, spark_mat, true, 600)
	var gem = SphereMesh.new()
	gem.radius = 0.13
	gem.height = 0.3
	gem.radial_segments = 4
	gem.rings = 2
	mm_shard = _make_multimesh(gem, _mat(LIME, 3.0), false, MAX_SHARDS + 20)

	var wedge = PrismMesh.new()
	wedge.size = Vector3(0.7, 0.9, 0.45)
	_add_pool("charger", wedge)
	var crown = TorusMesh.new()
	crown.inner_radius = 0.55
	crown.outer_radius = 0.66
	_add_pool("elite_ring", crown)

	aim_cam = Camera3D.new()
	view.add_child(aim_cam)

	var eye = BoxMesh.new()
	eye.size = Vector3(0.22, 0.1, 0.08)
	_add_pool("eye", eye)
	var barrel = BoxMesh.new()
	barrel.size = Vector3(0.12, 0.12, 0.55)
	_add_pool("barrel", barrel)
	_setup_fx()
	for k in range(CHARACTERS.size()):
		heroes.append(_build_hero(k))


# --- PLAYER CHARACTERS: one grouped-mesh rig, three distinct builds ------------

func _limb(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = pos
	part.material_override = mat
	parent.add_child(part)
	return part


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var joint = Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	return joint


func _cloth(color: Color, metal: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.45
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _build_hero(kind: int) -> Dictionary:
	var accent = CHARACTERS[kind].color
	var suit = _cloth([Color("1b1530"), Color("141c26"), Color("221a16")][kind], 0.15)  # matte undersuit
	var coat = _cloth([Color("3a2366"), Color("1f3340"), Color("4a3424")][kind], 0.55)  # armour with sheen
	var skin = _cloth(Color("d8a888"), 0.0)
	var glow = _mat(accent, 1.8)  # restrained trims: the visor stays the brightest point
	var bulk = [1.0, 0.9, 1.3][kind]
	var root = Node3D.new()
	root.scale = Vector3.ONE * 1.4
	view.add_child(root)
	var rig = _pivot(root, Vector3.ZERO)
	var hips = _pivot(rig, Vector3(0, 0.5, 0))
	_limb(hips, Vector3(0.3 * bulk, 0.14, 0.2), Vector3.ZERO, suit)
	var chest = _pivot(hips, Vector3(0, 0.07, 0))
	_limb(chest, Vector3(0.42 * bulk, 0.36, 0.26 * bulk), Vector3(0, 0.2, 0), coat)
	_limb(chest, Vector3(0.44 * bulk, 0.05, 0.28 * bulk), Vector3(0, 0.03, 0), glow)
	_limb(chest, Vector3(0.05, 0.28, 0.02), Vector3(0.1, 0.22, -0.13 * bulk - 0.006), glow)
	var head = _pivot(chest, Vector3(0, 0.44, 0))
	var visor: MeshInstance3D
	if kind == 0:  # RUNNER: light jacket, bright hair
		_limb(chest, Vector3(0.46, 0.08, 0.3), Vector3(0, 0.36, 0), coat)
		_limb(head, Vector3(0.2, 0.22, 0.2), Vector3(0, 0.08, 0), skin)
		_limb(head, Vector3(0.23, 0.08, 0.23), Vector3(0, 0.2, 0.01), _mat(PINK, 0.8))
		visor = _limb(head, Vector3(0.24, 0.06, 0.06), Vector3(0, 0.1, -0.1), glow)
	elif kind == 1:  # WRAITH: pointed hood and a long split coat
		var hood = MeshInstance3D.new()
		var cone = PrismMesh.new()
		cone.size = Vector3(0.3, 0.38, 0.3)
		hood.mesh = cone
		hood.position = Vector3(0, 0.17, 0.02)
		hood.material_override = coat
		head.add_child(hood)
		_limb(head, Vector3(0.17, 0.17, 0.17), Vector3(0, 0.07, -0.03), skin)
		visor = _limb(head, Vector3(0.19, 0.04, 0.05), Vector3(0, 0.09, -0.12), glow)
		var tails = _pivot(hips, Vector3(0, 0.02, 0.1))
		_limb(tails, Vector3(0.36, 0.44, 0.05), Vector3(0, -0.21, 0.02), coat)
		_limb(tails, Vector3(0.38, 0.03, 0.06), Vector3(0, -0.43, 0.02), glow)
	else:  # BREAKER: heavy helmet with a T-visor and armour pads
		_limb(head, Vector3(0.27, 0.27, 0.27), Vector3(0, 0.1, 0), suit)
		visor = _limb(head, Vector3(0.28, 0.05, 0.06), Vector3(0, 0.13, -0.13), glow)
		_limb(head, Vector3(0.05, 0.14, 0.06), Vector3(0, 0.06, -0.13), glow)
		for side in [-1.0, 1.0]:
			_limb(chest, Vector3(0.2, 0.17, 0.33), Vector3(side * 0.34, 0.36, 0), coat)
	var device = MeshInstance3D.new()  # the time device: a ring on the back
	var ring = TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.19
	device.mesh = ring
	device.position = Vector3(0, 0.24, 0.15 * bulk + 0.03)
	chest.add_child(device)
	var arms = []
	for side in [-1.0, 1.0]:
		var shoulder = _pivot(chest, Vector3(side * 0.26 * bulk, 0.33, 0))
		_limb(shoulder, Vector3(0.11 * bulk, 0.26, 0.11 * bulk), Vector3(0, -0.13, 0), coat)
		_limb(shoulder, Vector3(0.09 * bulk, 0.22, 0.09 * bulk), Vector3(0, -0.36, 0), suit)
		_limb(shoulder, Vector3(0.1, 0.08, 0.1), Vector3(0, -0.5, 0), skin)
		arms.append(shoulder)
	var parts = {}
	if kind == 0:  # pulse rifle in the right hand, extending past the fist
		var g = arms[1]
		_limb(g, Vector3(0.08, 0.5, 0.12), Vector3(0, -0.68, 0), suit)
		_limb(g, Vector3(0.08, 0.16, 0.15), Vector3(0, -0.46, 0.07), suit)
		_limb(g, Vector3(0.05, 0.14, 0.05), Vector3(0, -0.64, 0.1), glow)
		parts["muzzle"] = _limb(g, Vector3(0.06, 0.06, 0.06), Vector3(0, -0.95, 0), _mat(accent, 4.0))
	elif kind == 1:  # energy bow held upright in the left hand
		var b = arms[0]
		_limb(b, Vector3(0.05, 0.09, 0.12), Vector3(0, -0.53, 0), suit)
		var upper = _limb(b, Vector3(0.04, 0.05, 0.34), Vector3(0, -0.5, -0.2), glow)
		upper.rotation.x = 0.35
		var lower = _limb(b, Vector3(0.04, 0.05, 0.34), Vector3(0, -0.5, 0.2), glow)
		lower.rotation.x = -0.35
		parts["string"] = _limb(b, Vector3(0.012, 0.012, 0.66), Vector3(0, -0.4, 0), _mat(Color.WHITE, 3.0))
		parts["muzzle"] = parts["string"]
	else:  # scattergun: thick short barrel, pump grip, held low at the hip
		var g = arms[1]
		_limb(g, Vector3(0.15, 0.42, 0.15), Vector3(0, -0.7, 0), suit)
		_limb(g, Vector3(0.1, 0.18, 0.19), Vector3(0, -0.45, 0.07), coat)
		parts["pump"] = _limb(g, Vector3(0.18, 0.12, 0.18), Vector3(0, -0.76, 0), _mat(accent, 1.5))
		parts["muzzle"] = _limb(g, Vector3(0.13, 0.04, 0.13), Vector3(0, -0.92, 0), _mat(accent, 4.0))
	var legs = []
	for side in [-1.0, 1.0]:
		var hip = _pivot(hips, Vector3(side * 0.09 * bulk, -0.04, 0))
		_limb(hip, Vector3(0.13 * bulk, 0.24, 0.14 * bulk), Vector3(0, -0.12, 0), suit)
		_limb(hip, Vector3(0.11 * bulk, 0.22, 0.12 * bulk), Vector3(0, -0.33, 0), suit)
		_limb(hip, Vector3(0.14 * bulk, 0.09, 0.22), Vector3(0, -0.44, -0.03), coat)
		_limb(hip, Vector3(0.15 * bulk, 0.02, 0.23), Vector3(0, -0.48, -0.03), glow)
		legs.append(hip)
	parts.merge({"hips": hips, "chest": chest, "head": head, "arm_l": arms[0], "arm_r": arms[1], "leg_l": legs[0], "leg_r": legs[1], "device": device, "visor": visor})
	root.visible = false
	return {"kind": kind, "root": root, "rig": rig, "parts": parts, "phase": 0.0, "last": Vector2.ZERO}


func _pose_hero(h: Dictionary, delta: float, moving: float, yaw: float, kick: float, dashing: bool, tint: Color) -> void:
	# kick: 1 right after a shot, falling to 0 (recoil / bow release / pump).
	var p = h.parts
	h.phase += delta * (4.0 + 10.0 * moving)
	h.rig.rotation = Vector3(-0.45 if dashing else 0.0, yaw, 0)
	h.rig.scale = Vector3(0.9, 1.0, 1.25) if dashing else Vector3.ONE
	var swing = sin(h.phase) * 0.75 * moving
	p.leg_l.rotation.x = swing
	p.leg_r.rotation.x = -swing
	p.hips.position.y = 0.5 + absf(sin(h.phase)) * 0.04 * moving + sin(clock * 2.0) * 0.008
	if h.kind == 0:
		p.chest.rotation.x = -0.12 * moving - kick * 0.05
		p.arm_r.rotation = Vector3(PI / 2.0 - 0.12 + kick * 0.3, 0, 0)
		p.arm_l.rotation = Vector3(PI / 2.0 - 0.5 - swing * 0.3, 0, -0.55)
	elif h.kind == 1:
		p.chest.rotation.x = -0.08 * moving
		p.arm_l.rotation = Vector3(PI / 2.0, 0, 0.22)  # bow arm straight out
		p.arm_r.rotation = Vector3(PI / 2.0 * (0.82 + 0.18 * kick), 0, lerpf(-1.0, -0.45, kick))  # draw hand
		p.string.position.y = lerpf(-0.36, -0.47, kick)  # string pulled back, snaps forward on release
	else:
		p.chest.rotation.x = -0.12 * moving - kick * 0.16
		p.arm_r.rotation = Vector3(PI / 2.0 - 0.35 + kick * 0.5, 0, 0)
		p.arm_l.rotation = Vector3(PI / 2.0 - 0.55 + kick * 0.3, 0, -0.5)
		p.pump.position.y = -0.76 + kick * 0.09
	p.device.rotation = Vector3(PI / 2.0, 0, clock * (12.0 if frozen and state == "play" else 2.0))
	p.device.material_override = _mat(tint, 5.0 if tint == ICE else 2.5)
	p.visor.material_override = _mat(tint, 4.0)
	p.muzzle.material_override = _mat(Color.WHITE if kick > 0.5 else CHARACTERS[h.kind].color, 6.0 if kick > 0.5 else 3.0)


func _animate_hero(delta: float, repaying: bool) -> void:
	for i in range(heroes.size()):
		heroes[i].root.visible = false
	var h = heroes[char_index]
	h.root.visible = not (immunity > 0.0 and dash_timer <= 0.0 and sin(clock * 35.0) > 0.0)
	h.root.position = _to3(player)
	h.root.scale = Vector3.ONE * 1.4
	var moved = (player - h.last).length() / maxf(delta, 0.001)
	h.last = player
	recoil = maxf(0.0, recoil - delta * (9.0 if char_index == 0 else 3.5))
	var aim = player.direction_to(_mouse())
	var yaw = atan2(-aim.x, -aim.y) if aim.length() > 0.01 else h.rig.rotation.y
	var tint = ICE if frozen else (PINK if repaying else CHARACTERS[char_index].color)
	_pose_hero(h, delta, clampf(moved / 250.0, 0.0, 1.0), yaw, recoil, dash_timer > 0.0, tint)


func _select_spot(i: int) -> Vector3:
	# Put each preview fighter right above its selection card.
	var size = get_viewport_rect().size
	var card = _select_card_rect(i)
	var depth = cam.position.distance_to(Vector3(0, 1.0, 0.6))
	var half_w = depth * tan(deg_to_rad(cam.fov) / 2.0) * size.x / size.y
	return Vector3((card.get_center().x - size.x / 2.0) / (size.x / 2.0) * half_w, 0, 0.6)


func _animate_select(delta: float) -> void:
	cam.fov = 42.0
	cam.position = Vector3(0, 2.7, 8.6)
	cam.look_at(Vector3(0, 1.0, 0.6), Vector3.UP)
	aim_cam.transform = cam.transform
	for i in range(heroes.size()):
		var h = heroes[i]
		var chosen = i == select_index
		h.root.visible = true
		h.root.position = _select_spot(i)
		h.root.scale = Vector3.ONE * (2.15 if chosen else 1.85) * clampf(648.0 / get_viewport_rect().size.y, 0.6, 1.0)
		var kick = maxf(0.0, sin(clock * 2.6 + i)) if chosen else 0.0
		_pose_hero(h, delta, 0.0, PI - 0.55 + sin(clock * 0.7 + i) * 0.12, kick, false, CHARACTERS[i].color)
	player_light.visible = true
	player_light.position = _select_spot(select_index) + Vector3(0, 3.2, 2.2)
	player_light.light_color = CHARACTERS[select_index].color


func _setup_fx() -> void:
	# Effects mesh, neon city and the screen filter (created once at startup).
	fx_mesh = ImmediateMesh.new()
	var fx_mat = StandardMaterial3D.new()
	fx_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx_mat.vertex_color_use_as_albedo = true
	fx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fx_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fx_mat.albedo_color = Color(1.6, 1.6, 1.6)
	var fx = MeshInstance3D.new()
	fx.mesh = fx_mesh
	fx.material_override = fx_mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(fx)


	# Screen filter: scanlines, edge colour fringing and a glitch on big moments.
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var screen = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_mat = ShaderMaterial.new()
	var post = Shader.new()
	post.code = POST_SHADER
	post_mat.shader = post
	screen.material = post_mat
	layer.add_child(screen)
	post_rect = screen

	# The whole 2D interface lives on a layer ABOVE the filter: crisp, unglitched text.
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	hud_node = Node2D.new()
	ui_layer.add_child(hud_node)
	hud_node.draw.connect(_draw_ui)


func _build_city(hx: float, hz: float) -> void:
	# Neon skyline around the arena (fixed seed so it looks the same every run).
	# Built from the CURRENT arena size and rebuilt only when that changes, so a
	# building's whole footprint always stays outside the playable area.
	if city != null:
		city.queue_free()
	city = Node3D.new()
	view.add_child(city)
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("0b1020")
	dark.roughness = 0.9
	var neon = [MINT, PINK, ICE, GOLD]
	var rng = RandomNumberGenerator.new()
	rng.seed = 2077
	var placed = 0
	var tries = 0
	while placed < 60 and tries < 3000:
		tries += 1
		var x = rng.randf_range(-(hx + 22.0), hx + 22.0)
		var z = rng.randf_range(-(hz + 20.0), 3.0)
		var h = rng.randf_range(2.5, 11.0)
		var w = rng.randf_range(1.4, 3.4)
		var d = rng.randf_range(1.4, 3.4)
		if absf(x) - w / 2.0 < hx + CITY_GAP and z + d / 2.0 > -(hz + CITY_GAP):
			continue  # footprint would touch the arena (plus a viewing margin)
		placed += 1
		var tower = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(w, h, d)
		tower.mesh = box
		tower.material_override = dark
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tower.position = Vector3(x, h / 2.0, z)
		city.add_child(tower)
		var light_strip = MeshInstance3D.new()
		var strip = BoxMesh.new()
		if rng.randf() < 0.55:
			strip.size = Vector3(w + 0.05, 0.1, d + 0.05)
			light_strip.position = Vector3(x, h * rng.randf_range(0.55, 0.97), z)
		else:
			strip.size = Vector3(0.12, h * 0.7, 0.12)
			light_strip.position = Vector3(x + w / 2.0, h * 0.5, z + d / 2.0)
		light_strip.mesh = strip
		light_strip.material_override = _mat(neon[rng.randi() % 4], 1.5)
		light_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(light_strip)


func _add_pool(id: String, mesh: Mesh) -> void:
	pools[id] = {"mesh": mesh, "nodes": [], "used": 0}


func _pool_get(id: String) -> MeshInstance3D:
	var pool = pools[id]
	if pool.used >= pool.nodes.size():
		var node = MeshInstance3D.new()
		node.mesh = pool.mesh
		view.add_child(node)
		pool.nodes.append(node)
	var item = pool.nodes[pool.used]
	pool.used += 1
	item.visible = true
	return item


func _make_multimesh(mesh: Mesh, material: Material, colors: bool, count: int) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(inst)
	return mm


func _mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key = color.to_html() + str(energy)
	if not mats.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.55)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.35
		m.metallic = 0.4
		mats[key] = m
	return mats[key]


func _to3(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3((p.x - origin2d.x) / UNIT, h, (p.y - origin2d.y) / UNIT)


func _to2(v: Vector3) -> Vector2:
	return Vector2(v.x * UNIT + origin2d.x, v.z * UNIT + origin2d.y)


func _screen(p: Vector2, h: float = 0.0) -> Vector2:
	return cam.unproject_position(_to3(p, h))


func _mouse() -> Vector2:
	if not bot.is_empty():
		return bot.get("aim", player)
	return _pick_at(get_global_mouse_position())


func _enemy_h(e: Dictionary) -> float:
	# Height an enemy's body is DRAWN at (used by rendering and by picking).
	return (0.75 if e.kind == 2 else BODY_H) + sin(e.age * 3.0 + e.pos.x) * 0.06


func _pick_at(m: Vector2) -> Vector2:
	# What the player SEES under the cursor, in game coordinates. Uses the
	# UNSHAKEN aim camera, so screen shake never moves the target.
	# 1) Cursor on a visible target -> that target's exact position: enemies at
	#    their real drawn height, and (while frozen, when they are thread
	#    targets) hostile bullets at the height they are drawn.
	# 2) Otherwise -> the plane at body height, where enemies and bullets live.
	if aim_cam == null:
		return m
	var picked = null
	var picked_d = INF
	if frozen:
		var near = (reach + 40.0) * (reach + 40.0)
		for b in bullets:
			if not b.friendly and b.pos.distance_squared_to(player) < near:  # a pin can't land beyond reach anyway
				var d = aim_cam.unproject_position(_to3(b.pos, BODY_H)).distance_to(m)
				if d < BULLET_PICK_PX and d < picked_d:
					picked_d = d
					picked = b.pos
	var right = aim_cam.global_transform.basis.x
	for e in enemies:
		var c = _to3(e.pos, _enemy_h(e))
		var s = aim_cam.unproject_position(c)
		var d = s.distance_to(m)
		if d < s.distance_to(aim_cam.unproject_position(c + right * (e.radius / UNIT))) and d < picked_d:
			picked_d = d
			picked = e.pos
	if picked != null:
		return picked
	return _plane_at(m, BODY_H)


func _plane_at(m: Vector2, h: float) -> Vector2:
	# Screen point -> game point where the view ray crosses the plane at height h.
	var from = aim_cam.project_ray_origin(m)
	var dir = aim_cam.project_ray_normal(m)
	if absf(dir.y) < 0.0001:
		return player
	var t = (h - from.y) / dir.y
	if t <= 0.0:
		return player
	return _to2(from + dir * t)


func _floor_at(m: Vector2) -> Vector2:
	return m if aim_cam == null else _plane_at(m, 0.0)


func _place_cam(yaw: float, dist: float) -> void:
	var dir = Vector3(sin(yaw) * cos(cam_pitch), sin(cam_pitch), cos(yaw) * cos(cam_pitch))
	cam.position = cam_target + dir * dist
	cam.look_at(cam_target, Vector3.UP)


func _fit_view(size: Vector2) -> void:
	# Place walls/pylons and find the camera distance that fits the arena
	# between the top HUD and the bottom bar.
	fit_size = size
	var arena = Rect2(15, 100, size.x - 30, size.y - 135)
	origin2d = arena.get_center()
	var hx = arena.size.x / UNIT / 2.0
	var hz = arena.size.y / UNIT / 2.0
	floor_mat.set_shader_parameter("half_size", Vector2(hx, hz))
	var specs = [
		[Vector3(0, 0.12, -hz), Vector3(hx * 2.0 + 0.16, 0.24, 0.08)],
		[Vector3(0, 0.12, hz), Vector3(hx * 2.0 + 0.16, 0.24, 0.08)],
		[Vector3(-hx, 0.12, 0), Vector3(0.08, 0.24, hz * 2.0)],
		[Vector3(hx, 0.12, 0), Vector3(0.08, 0.24, hz * 2.0)],
	]
	var corners = [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for i in range(4):
		walls[i].position = specs[i][0]
		walls[i].mesh.size = specs[i][1]
		pylons[i].position = corners[i] + Vector3(0, 0.9, 0)

	_build_props(hx, hz)
	_build_city(hx, hz)

	var target_rect = Rect2(22, 104, size.x - 44, size.y - 150)
	cam.fov = cam_fov
	cam_target = Vector3(0, 0, 0.5)
	for attempt in range(3):
		var near = 4.0
		var far = 120.0
		for step in range(26):
			var d = (near + far) / 2.0
			_place_cam(0.0, d)
			var fits = true
			for c in corners:
				if not target_rect.has_point(cam.unproject_position(c)):
					fits = false
			if fits:
				far = d
			else:
				near = d
		cam_dist = far
		_place_cam(0.0, cam_dist)
		var top = INF
		var bottom = -INF
		for c in corners:
			var s = cam.unproject_position(c)
			top = minf(top, s.y)
			bottom = maxf(bottom, s.y)
		var shift = target_rect.get_center().y - (top + bottom) / 2.0
		cam_target.z -= shift * (hz * 2.0) / maxf(1.0, bottom - top)


func _prop(group: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(node)
	return node


func _build_props(hx: float, hz: float) -> void:
	# One set of arena dressing per stage, outside the play area only.
	for g in props:
		g.queue_free()
	props.clear()
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("140c22")
	dark.metallic = 0.6
	dark.roughness = 0.4

	var roof = Node3D.new()  # Stage 1: rooftop vents, tanks and blinking masts
	var vent = BoxMesh.new()
	vent.size = Vector3(1.4, 0.7, 1.0)
	var tank = CylinderMesh.new()
	tank.top_radius = 0.7
	tank.bottom_radius = 0.7
	tank.height = 1.6
	var mast = BoxMesh.new()
	mast.size = Vector3(0.08, 3.5, 0.08)
	var bulb = SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	for i in range(7):
		var x = -hx + 1.5 + i * (hx * 2.0 - 3.0) / 6.0
		_prop(roof, vent if i % 2 == 0 else tank, Vector3(x, 0.4 if i % 2 == 0 else 0.8, -hz - 1.4), dark)
	for s in [-1.0, 1.0]:
		_prop(roof, mast, Vector3(s * (hx + 1.3), 1.75, -hz + 1.0), dark)
		_prop(roof, bulb, Vector3(s * (hx + 1.3), 3.5, -hz + 1.0), _mat(PINK, 2.5))
		_prop(roof, vent, Vector3(s * (hx + 1.4), 0.35, 1.5), dark)

	var relay = Node3D.new()  # Stage 2: relay pylons with glowing rings
	var pole = CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.22
	pole.height = 6.0
	var halo = TorusMesh.new()
	halo.inner_radius = 0.5
	halo.outer_radius = 0.6
	for i in range(6):
		var p = Vector3(-hx + 2.0 + i * (hx * 2.0 - 4.0) / 5.0, 3.0, -hz - 2.2) if i < 4 else Vector3((-1.0 if i == 4 else 1.0) * (hx + 1.8), 3.0, -hz + 2.0)
		_prop(relay, pole, p, dark)
		for r in range(2):
			var ring = _prop(relay, halo, p + Vector3(0, 0.6 + r * 1.6, 0), _mat(MINT if r == 0 else PINK, 1.8))
			ring.rotation = Vector3(PI / 2.0, 0, 0)

	var vault = Node3D.new()  # Stage 3: heavy pillars and a giant gold vault ring
	var pillar = BoxMesh.new()
	pillar.size = Vector3(1.3, 7.0, 1.3)
	var trim = BoxMesh.new()
	trim.size = Vector3(1.36, 0.12, 1.36)
	for i in range(8):
		var p = Vector3(-hx + 1.0 + i * (hx * 2.0 - 2.0) / 7.0, 3.5, -hz - 1.8)
		_prop(vault, pillar, p, dark)
		_prop(vault, trim, p + Vector3(0, 1.5, 0), _mat(GOLD, 1.5))
	var big_ring = TorusMesh.new()
	big_ring.inner_radius = 5.5
	big_ring.outer_radius = 6.0
	var gate = _prop(vault, big_ring, Vector3(0, 3.0, -hz - 4.5), _mat(GOLD, 1.0))
	gate.rotation = Vector3(PI / 2.0, 0, 0)

	for g in [roof, relay, vault]:
		g.visible = false
		view.add_child(g)
		props.append(g)


func _compute_preview() -> Dictionary:
	var out = {"hits": 0, "kills": 0, "cut": 0, "looped": false, "marks": [], "cuts": []}
	if not frozen or anchors.size() < 2:
		return out
	var looped = _loop_closed()
	out["looped"] = looped
	for e in enemies:
		var amount = _stitch_damage(e.pos, e.radius, looped)
		if amount > 0:
			var lethal = amount >= e.hp
			out["hits"] += 1
			if lethal:
				out["kills"] += 1
			out["marks"].append({"e": e, "amount": amount, "lethal": lethal})
	for b in bullets:
		if not b.friendly and (_thread_hits(b.pos, 10.0) > 0 or _inside_loop(b.pos, looped)):
			out["cut"] += 1
			out["cuts"].append(b.pos)
	return out


func _update_view(delta: float) -> void:
	var size = get_viewport_rect().size
	if size != fit_size:
		_fit_view(size)
	pv = _compute_preview()
	var repaying = debt > 0.0 and not frozen and state == "play"

	var want_hidden = state == "play"
	if want_hidden != mouse_hidden:
		mouse_hidden = want_hidden
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE

	# Camera: gentle sway on menus, tighter zoom while frozen, shake on impacts.
	var yaw = 0.0
	if state in ["title", "over", "win"]:
		yaw = sin(clock * 0.22) * 0.3
	var want_fov = cam_fov - (2.5 if frozen else 0.0) + (1.5 if repaying else 0.0)
	cam.fov = lerpf(cam.fov, want_fov, minf(1.0, delta * 6.0))
	_place_cam(yaw, cam_dist)
	aim_cam.transform = cam.transform
	aim_cam.fov = cam.fov
	if shake > 0.0 and not low_fx:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.16

	# Time look: frozen drains color; repaying makes the floor rush past in pink.
	env.adjustment_saturation = lerpf(env.adjustment_saturation, 0.6 if frozen else 1.15, minf(1.0, delta * 8.0))
	post_rect.visible = not low_fx
	post_mat.set_shader_parameter("glitch", glitch)
	var si = clampi(stage - 1, 0, 2)
	for i in range(props.size()):
		props[i].visible = i == si
	env.fog_light_color = [Color("0b1430"), Color("071a2a"), Color("1c130c")][si]
	var accent = [Color("00a8c0"), Color("c0207a"), Color("a04a10")][si]  # vault: copper, never bullet-yellow
	var lines = [Color("17123a"), Color("0b2233"), Color("2a1a0c")][si]  # quiet grid: combat is the focus
	if frozen:
		accent = ICE
		lines = Color("2a2266")
	elif repaying:
		accent = PINK * (0.6 + 0.4 * sin(clock * 16.0))
		lines = Color("3a0c26")
		floor_scroll += delta * 5.0 * repay_speed
	floor_mat.set_shader_parameter("accent", accent)
	floor_mat.set_shader_parameter("line_color", lines)
	floor_mat.set_shader_parameter("scroll", floor_scroll)
	var f3 = _to3(player) if state not in ["title", "select"] else Vector3(0, 0, 0.5)
	floor_mat.set_shader_parameter("focus", Vector2(f3.x, f3.z))
	wall_mat.emission = accent
	wall_mat.emission_energy_multiplier = 0.25 if frozen else 0.32  # a quiet boundary, not a light source

	var data = PackedFloat32Array()
	data.resize(16)
	var rgb = PackedFloat32Array()
	rgb.resize(12)
	for i in range(mini(4, ripples.size())):
		var r = ripples[ripples.size() - 1 - i]
		var c = _to3(r.pos)
		data[i * 4] = c.x
		data[i * 4 + 1] = c.z
		data[i * 4 + 2] = r.t * 700.0 / UNIT
		data[i * 4 + 3] = 1.6 * (1.0 - r.t / 0.9)
		rgb[i * 3] = r.color.r
		rgb[i * 3 + 1] = r.color.g
		rgb[i * 3 + 2] = r.color.b
	floor_mat.set_shader_parameter("ripple_data", data)
	floor_mat.set_shader_parameter("ripple_rgb", rgb)

	# Solid objects.
	for pool in pools.values():
		pool.used = 0
	var boss_seen = false
	if state == "select":
		_animate_select(delta)
	elif state != "title":
		_animate_hero(delta, repaying)
		player_light.visible = true
		player_light.position = _to3(player, 1.7)
		player_light.light_color = ICE if frozen else (PINK if repaying else CHARACTERS[char_index].color)
	else:
		for h in heroes:
			h.root.visible = false
		player_light.visible = false

	for e in enemies:
		var base = [PINK, GOLD, GOLD, ORANGE][e.kind]
		var color = base.lerp(ICE, 0.35) if frozen else base
		if e.flash > 0 or (e.kind == 2 and e.mode == "charge" and sin(clock * 30.0) > 0) or (e.kind == 3 and e.mode == "windup" and sin(clock * 30.0) > 0):
			color = Color.WHITE
		var node = _pool_get(["chaser", "shooter", "boss", "charger"][e.kind])
		node.position = _to3(e.pos, _enemy_h(e))
		if e.kind == 3 and e.dir.length() > 0.01:
			node.basis = Basis.looking_at(Vector3(e.dir.x, 0, e.dir.y), Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
		else:
			node.rotation = Vector3(0, e.age * (1.6 if e.kind == 0 else -0.8), 0)
		node.scale = Vector3.ONE * (1.45 if e.elite else 1.0)
		node.material_override = _mat(color, 1.1 if e.kind == 2 else 0.4)  # silhouette first, glow second
		var face = e.pos.direction_to(player)
		if e.kind == 0:
			var eye = _pool_get("eye")  # glowing eye slit looking at the player
			eye.basis = Basis.looking_at(Vector3(face.x, 0, face.y) if face.length() > 0.01 else Vector3.FORWARD, Vector3.UP)
			eye.position = node.position + Vector3(face.x, 0, face.y) * 0.32 * node.scale.x + Vector3(0, 0.05, 0)
			eye.material_override = _mat(Color.WHITE if not frozen else ICE, 3.0)
		elif e.kind == 1 and face.length() > 0.01:
			var barrel = _pool_get("barrel")  # turret barrel tracks the player
			barrel.basis = Basis.looking_at(Vector3(face.x, 0, face.y), Vector3.UP)
			barrel.position = node.position + Vector3(face.x, 0, face.y) * 0.35 + Vector3(0, 0.12, 0)
			barrel.scale = Vector3.ONE * (1.4 if e.elite else 1.0)
			barrel.material_override = _mat(Color.WHITE if e.cooldown < 0.5 else color, 2.5)
		if e.elite:
			var crown = _pool_get("elite_ring")
			crown.position = node.position + Vector3(0, 0.75, 0)
			crown.rotation = Vector3(0.3, clock * 2.0, 0)
			crown.material_override = _mat(GOLD, 3.0)
		if e.kind == 2:
			boss_seen = true
			var ring = _pool_get("boss_ring")
			ring.position = node.position + Vector3(0, 0.15, 0)
			ring.rotation = Vector3(0.45 * sin(e.age), e.age * 1.7, 0.35)
			ring.material_override = _mat(PINK if e.hp <= e.max_hp * 0.5 else GOLD, 3.0)
			boss_light.position = node.position + Vector3(0, 1.4, 0)
	boss_light.visible = boss_seen

	for pool in pools.values():
		for i in range(pool.used, pool.nodes.size()):
			pool.nodes[i].visible = false

	# Bullet pools hold 1000 each and the simulation caps bullets at 900 total,
	# so a dangerous bullet can never exist without being drawn.
	var nf = 0
	var nj = 0
	var nh = 0
	var na = 0
	for b in bullets:
		if b.hijack:
			mm_hijack.set_instance_transform(nj, Transform3D(Basis(), _to3(b.pos, AIM_H)))
			nj += 1
		elif b.friendly and b.kind == 1 and b.vel.length() > 0.01:
			var dir3 = Vector3(b.vel.x, 0, b.vel.y).normalized()
			mm_arrow.set_instance_transform(na, Transform3D(Basis.looking_at(dir3, Vector3.UP), _to3(b.pos, AIM_H)))
			na += 1
		elif b.friendly:
			var s = 0.6 if b.kind == 2 else 1.0
			mm_friend.set_instance_transform(nf, Transform3D(Basis().scaled(Vector3(s, s, s)), _to3(b.pos, AIM_H)))
			nf += 1
		else:
			mm_foe.set_instance_transform(nh, Transform3D(Basis(), _to3(b.pos, BODY_H)))
			nh += 1
	mm_friend.visible_instance_count = nf
	mm_arrow.visible_instance_count = na
	mm_hijack.visible_instance_count = nj
	mm_foe.visible_instance_count = nh

	var nx = 0
	for s in shards:
		var grow = 0.8 + minf(1.2, s.value * 0.15)
		var spin = Basis(Vector3.UP, clock * 3.0 + s.pos.x).scaled(Vector3(grow, grow, grow))
		mm_shard.set_instance_transform(nx, Transform3D(spin, _to3(s.pos, 0.28 + sin(clock * 5.0 + s.pos.y) * 0.06)))
		nx += 1
	mm_shard.visible_instance_count = nx

	var ns = 0
	for s in sparks:
		if ns >= 600:
			break
		var grow = 0.6 + s.life * 2.0
		mm_spark.set_instance_transform(ns, Transform3D(Basis().scaled(Vector3(grow, grow, grow)), _to3(s.pos, 0.3 + s.life * 1.3)))
		mm_spark.set_instance_color(ns, Color(s.color.r * 2.5, s.color.g * 2.5, s.color.b * 2.5, 1.0))
		ns += 1
	mm_spark.visible_instance_count = ns

	_build_fx(repaying)

	if health < last_health:
		hp_flash = 0.7  # health bar reacts to damage
	last_health = health
	hp_flash = maxf(0.0, hp_flash - delta)
	hud_node.queue_redraw()


# --- 3D effect geometry (one additive mesh rebuilt every frame) ---------------

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		fx_mesh.surface_set_color(col)
		fx_mesh.surface_add_vertex(v)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)


func _beam(a: Vector3, b: Vector3, width: float, col: Color) -> void:
	# A glowing strip from a to b that always faces the camera.
	var dir = b - a
	if dir.length() < 0.001 or col.a <= 0.01:
		return
	var side = dir.cross(cam.global_position - (a + b) * 0.5).normalized() * width * 0.5
	_quad(a - side, b - side, b + side, a + side, col)


func _dashed(a: Vector3, b: Vector3, width: float, col: Color, dash: float) -> void:
	var length = a.distance_to(b)
	var count = int(length / dash)
	for i in range(0, count, 2):
		_beam(a.lerp(b, float(i) / count), a.lerp(b, float(i + 1) / count), width, col)


func _ribbon(p: Vector2, q: Vector2, h: float, width_px: float, col: Color) -> void:
	# A flat strip lying on the floor.
	var a = _to3(p, h)
	var b = _to3(q, h)
	var dir = b - a
	if dir.length() < 0.001:
		return
	var side = Vector3(-dir.z, 0, dir.x).normalized() * width_px / UNIT * 0.5
	_quad(a - side, b - side, b + side, a + side, col)


func _ring(c: Vector2, r: float, h: float, width_px: float, col: Color, a0: float = 0.0, a1: float = TAU, segs: int = 40) -> void:
	if r <= 0.5 or col.a <= 0.01:
		return
	var center = _to3(c, h)
	var r0 = maxf(0.0, r - width_px * 0.5) / UNIT
	var r1 = (r + width_px * 0.5) / UNIT
	for i in range(segs):
		var t0 = lerpf(a0, a1, float(i) / segs)
		var t1 = lerpf(a0, a1, float(i + 1) / segs)
		var d0 = Vector3(cos(t0), 0, sin(t0))
		var d1 = Vector3(cos(t1), 0, sin(t1))
		_quad(center + d0 * r0, center + d0 * r1, center + d1 * r1, center + d1 * r0, col)


func _disc(c: Vector2, r: float, h: float, col: Color, segs: int = 28) -> void:
	if r <= 0.5 or col.a <= 0.01:
		return
	var center = _to3(c, h)
	for i in range(segs):
		var d0 = Vector3(cos(TAU * i / segs), 0, sin(TAU * i / segs)) * r / UNIT
		var d1 = Vector3(cos(TAU * (i + 1) / segs), 0, sin(TAU * (i + 1) / segs)) * r / UNIT
		_tri(center, center + d0, center + d1, col)


func _poly(points, h: float, col: Color) -> void:
	var shape = PackedVector2Array(points)
	var idx = Geometry2D.triangulate_polygon(shape)
	for i in range(0, idx.size(), 3):
		_tri(_to3(shape[idx[i]], h), _to3(shape[idx[i + 1]], h), _to3(shape[idx[i + 2]], h), col)


func _build_fx(repaying: bool) -> void:
	fx_mesh.clear_surfaces()
	fx_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Color(0, 0, 0, 0))  # never empty

	for r in ripples:
		var fade = 1.0 - r.t / 0.9
		_ring(r.pos, r.t * 700.0, 0.05, 2.0 + 6.0 * fade, Color(r.color, 0.5 * fade), 0.0, TAU, 72)

	# Spawn warnings: a closing ring and a rising beam of light.
	for p in portals:
		var k = clampf(1.0 - p.time / p.max, 0.0, 1.0)
		var col = PINK if p.kind == 0 else GOLD
		var grow = 2.0 if p.kind == 2 else 1.0
		_ring(p.pos, lerpf(60.0, 18.0, k) * grow, 0.05, 3.0, Color(col, 0.35 + 0.6 * k))
		_disc(p.pos, (6.0 + 10.0 * k) * grow, 0.05, Color(col, 0.35))
		_beam(_to3(p.pos, 0.0), _to3(p.pos, 0.4 + 3.0 * k), (0.08 + 0.3 * k) * grow, Color(col, 0.15 + 0.35 * k))

	for b in blasts:
		var k = 1.0 - b.life / b.max
		var rad = b.radius * (0.3 + 0.7 * k)
		_disc(b.pos, rad, 0.06, Color(PINK, 0.22 * (1.0 - k)), 40)
		_ring(b.pos, rad, 0.07, 2.0 + 6.0 * (1.0 - k), Color(GOLD, 1.0 - k), 0.0, TAU, 48)
		_beam(_to3(b.pos, 0.0), _to3(b.pos, 2.5 * (1.0 - k)), 0.5 * (1.0 - k), Color(GOLD, 0.6 * (1.0 - k)))

	if loop_life > 0.0:
		_poly(loop_poly, 0.06, Color(GOLD, 0.45 * loop_life / 0.6))

	for k in pops:  # crisp kill pop: one bright ring and four shards
		var f = 1.0 - k.life / 0.22
		_ring(k.pos, k.r * (0.6 + 1.2 * f), BODY_H, 1.0 + 3.0 * (1.0 - f), Color(TEXT, 1.0 - f), 0.0, TAU, 28)
		if not low_fx:
			for a in range(4):
				var dir = Vector2.from_angle(TAU * a / 4.0 + k.pos.x)
				_beam(_to3(k.pos + dir * k.r * (0.8 + f), BODY_H), _to3(k.pos + dir * k.r * (1.2 + 1.6 * f), BODY_H), 0.05, Color(TEXT, 1.0 - f))

	# Time Scars: violet flickering seams on the floor (enemy hazards are pink/yellow).
	for s in scars:
		var fade = s.life / s.max
		_ribbon(s.a, s.b, 0.035, 10.0, Color(ICE, 0.16 * fade))
		_ribbon(s.a, s.b, 0.045, 2.5, Color(ICE, (0.55 + 0.35 * sin(clock * 22.0 + s.a.x)) * fade))

	if state not in ["title", "select"]:
		for i in range(1, trail.size()):
			var fade = 1.0 - float(i) / trail.size()
			_disc(trail[i], 12.0 * fade, 0.04, Color(PINK if repaying else MINT, 0.14 * fade), 14)
		_disc(player, 26.0, 0.03, Color(CHARACTERS[char_index].color, 0.1), 24)
		if dash_cooldown <= 0:
			_ring(player, 25.0, 0.05, 2.0, Color(MINT, 0.5))
		if debt > 0.0:
			_ring(player, 33.0, 0.06, 4.0, Color(ICE if frozen else PINK, 0.9), -PI / 2, -PI / 2 + TAU * debt / max_debt, 32)

	for e in enemies:
		_disc(e.pos, e.radius * 1.5, 0.03, Color([PINK, GOLD, GOLD, ORANGE][e.kind], 0.06), 12)
		if e.elite:
			_ring(e.pos, e.radius + 6.0, 0.05, 2.0, Color(GOLD, 0.7))
		if e.kind == 3 and e.mode == "windup":
			# Charger telegraph: the full dash lane, filling up before it goes.
			var k = clampf(1.0 - e.timer / CHARGER_WINDUP, 0.0, 1.0)
			var lane_end = e.pos + e.dir * 270.0
			_ribbon(e.pos, lane_end, 0.05, e.radius * 2.0, Color(PINK, 0.12 + 0.25 * k))
			_ribbon(e.pos, e.pos.lerp(lane_end, k), 0.06, 6.0, Color(PINK, 0.95))
		if e.kind == 1 and e.cooldown < 0.5:
			var k = 1.0 - e.cooldown / 0.5
			var dir = e.pos.direction_to(player)
			_beam(_to3(e.pos + dir * e.radius, 0.5), _to3(e.pos + dir * (e.radius + 80.0 * k), 0.5), 0.07, Color(GOLD, 0.95 * k))
			_ring(e.pos, e.radius + 8.0, 0.05, 2.0, Color(GOLD, 0.7 * k))
		elif e.kind == 2 and e.mode == "charge":
			var k = clampf(1.0 - e.timer / BOSS_CHARGE, 0.0, 1.0)
			var col = Color(GOLD, 0.35 + 0.6 * k)
			if e.pattern == 0:
				_ring(e.pos, e.radius + 20.0 + 140.0 * k, 0.06, 4.0, col, 0.0, TAU, 72)
			elif e.pattern == 1:
				for a in range(3):
					var dir = Vector2.from_angle(e.spin + TAU * a / 3.0)
					_beam(_to3(e.pos + dir * e.radius, 0.6), _to3(e.pos + dir * (e.radius + 30.0 + 110.0 * k), 0.6), 0.12, col)
			else:
				var base = e.pos.direction_to(player).angle()
				for a in range(-2, 3):
					var dir = Vector2.from_angle(base + a * 0.22)
					_dashed(_to3(e.pos + dir * e.radius, 0.5), _to3(e.pos + dir * (e.radius + 40.0 + 220.0 * k), 0.5), 0.07, col, 0.35)

	# Stitch preview: rings, kill crosses and blast radius on marked enemies.
	for m in pv["marks"]:
		var e = m.e
		var mark = Color.WHITE if m.lethal else MINT
		_ring(e.pos, e.radius + 10.0, 0.07, 3.0, mark)
		if m.lethal:
			var r = e.radius + 4.0
			_ribbon(e.pos + Vector2(-r, -r), e.pos + Vector2(r, r), 0.08, 4.0, mark)
			_ribbon(e.pos + Vector2(-r, r), e.pos + Vector2(r, -r), 0.08, 4.0, mark)
			_ring(e.pos, blast_radius, 0.05, 2.0, Color(GOLD, 0.35), 0.0, TAU, 56)
	for bp in pv["cuts"]:
		_ring(bp, 12.0, BODY_H, 2.0, ICE if hijack_level > 0 else Color.WHITE, 0.0, TAU, 16)  # around the bullet itself

	# Threads: needles stuck in the floor, thread strung between their tips.
	if frozen and state != "title":
		_ring(player, reach, 0.04, 2.0, Color(ICE, 0.4), 0.0, TAU, 80)
		if lasso and anchors.size() >= 3:
			if pv["looped"]:
				_poly(anchors, 0.04, Color(GOLD, 0.16))
				_beam(_to3(anchors[anchors.size() - 1], BODY_H), _to3(anchors[0], BODY_H), 0.09, GOLD)
			else:
				_ring(anchors[0], 90.0, 0.05, 2.0, Color(GOLD, 0.5), 0.0, TAU, 48)
		for i in range(anchors.size() - 1):
			var a = _to3(anchors[i], BODY_H)  # the thread cuts at body height: what you see is what it hits
			var b = _to3(anchors[i + 1], BODY_H)
			_beam(a, b, 0.34, Color(MINT, 0.16))
			_beam(a, b, 0.07, Color(MINT, 0.75 + 0.25 * sin(clock * 10.0)))
			_ribbon(anchors[i], anchors[i + 1], 0.04, 3.0, Color(MINT, 0.25))
		for p in anchors:
			_beam(_to3(p, 0.0), _to3(p, PIN_H), 0.05, Color.WHITE)
			_disc(p, 7.0, 0.05, Color(MINT, 0.6), 12)
		var pin = _pin_point()
		if anchors.size() > 0:
			_dashed(_to3(anchors[anchors.size() - 1], BODY_H), _to3(pin, BODY_H), 0.04, Color(MINT, 0.55), 0.25)
		_beam(_to3(pin, 0.0), _to3(pin, PIN_H), 0.04, Color(MINT, 0.6))

	# Trails: stolen shots (violet) and arrows (cyan) are easy to follow.
	for b in bullets:
		if b.hijack or (b.friendly and not frozen):
			if b.vel.length() > 0.01:
				var tail = b.pos - b.vel.normalized() * (52.0 if b.hijack else [26.0, 34.0, 14.0][b.kind])
				_beam(_to3(tail, AIM_H), _to3(b.pos, AIM_H), 0.09 if b.hijack else 0.05, Color(ICE if b.hijack else MINT, 0.6))

	for s in snap_lines:
		var k = s.life / s.max
		var start_h = AIM_H if s.width < 3.0 else BODY_H
		_beam(_to3(s.a, start_h), _to3(s.b, BODY_H), 0.03 + 0.14 * k * s.width / 5.0, Color(s.color, k))

	if state == "play":
		var cursor = _pin_point() if frozen else _mouse()
		_ring(cursor, 11.0, BODY_H, 2.0, Color(ICE if frozen else MINT, 0.9), 0.0, TAU, 24)  # at the cursor
		_disc(cursor, 4.0, 0.05, Color(ICE if frozen else MINT, 0.5), 10)  # its spot on the floor

	fx_mesh.surface_end()


# --- 2D INTERFACE ---------------------------------------------------------------
# Everything 2D is drawn into `ci`, a Node2D on a CanvasLayer ABOVE the screen
# filter, so HUD text is never blurred or glitched by it.

const HEALTH_RED = Color("ff4d6d")
const TEXT_DIM = Color("8d95ad")
const TEXT_SOFT = Color("d8d0c0")
const PANEL_BG = Color(0.03, 0.045, 0.085, 0.9)
const TEXT = Color("f3ecdd")  # warm off-white
const AMBER = Color("ffb547")  # rewards and highlights, used sparingly

var ci: CanvasItem
var hud_node: Node2D
var hp_flash = 0.0
var last_health = 5


func _box(bg: Color, border: Color, radius: int = 4, border_w: int = 1, shadow: int = 8) -> StyleBoxFlat:
	bg.a = snappedf(bg.a, 0.05)
	border.a = snappedf(border.a, 0.05)
	radius = 6 if radius > 2 else radius  # one consistent corner radius
	var key = "%s|%s|%d|%d|%d" % [bg.to_html(), border.to_html(), radius, border_w, shadow]
	if not boxes.has(key):
		var b = StyleBoxFlat.new()
		b.bg_color = bg
		b.border_color = border
		b.set_border_width_all(border_w)
		b.set_corner_radius_all(radius)
		b.shadow_color = Color(0, 0, 0, 0.45)
		b.shadow_size = shadow
		b.anti_aliasing = true
		boxes[key] = b
	return boxes[key]


func _brackets(rect: Rect2, color: Color, length: float = 12.0) -> void:
	# Restrained corner ticks (top-left and bottom-right only).
	var c = Color(color, color.a * 0.6)
	ci.draw_line(rect.position, rect.position + Vector2(length, 0), c, 1.5)
	ci.draw_line(rect.position, rect.position + Vector2(0, length), c, 1.5)
	ci.draw_line(rect.end, rect.end - Vector2(length, 0), c, 1.5)
	ci.draw_line(rect.end, rect.end - Vector2(0, length), c, 1.5)


func _panel(rect: Rect2, accent: Color, radius: int = 6) -> void:
	# House style: deep navy glass, hairline border, one short accent bar.
	ci.draw_style_box(_box(PANEL_BG, Color(accent, minf(0.35, accent.a * 0.8)), radius, 1, 12), rect)
	ci.draw_line(rect.position + Vector2(14, 1), rect.position + Vector2(54, 1), Color(accent, 1.0), 2.0)


func _bar(rect: Rect2, ratio: float, col: Color) -> void:
	ci.draw_style_box(_box(Color("1a1030"), Color(0, 0, 0, 0), 2, 0, 0), rect)
	if ratio > 0.0:
		var fill = Rect2(rect.position, Vector2(maxf(3.0, rect.size.x * clampf(ratio, 0.0, 1.0)), rect.size.y))
		ci.draw_style_box(_box(col, Color(0, 0, 0, 0), 2, 0, 0), fill)
		var x = rect.position.x + 7.0
		while x < fill.end.x:
			ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.03, 0.045, 0.085, 0.75), 2.0)
			x += 8.0


func _width(words: String, size: int, bold: bool = false) -> float:
	return (font_bold if bold else font).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _fit(words: String, max_w: float, size: int, bold: bool = false) -> int:
	# Largest font size (down to 9) that fits the available width.
	var s = size
	while s > 9 and _width(words, s, bold) > max_w:
		s -= 1
	return s


func _text(pos: Vector2, words: String, size: int = 20, color: Color = TEXT, outline: bool = false, bold: bool = false) -> void:
	var f = font_bold if bold else font
	if outline:
		ci.draw_string_outline(f, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(SHADE, color.a * 0.9))
	ci.draw_string(f, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(pos: Vector2, words: String, size: int, color: Color, bold: bool = false) -> void:
	_text(pos - Vector2(_width(words, size, bold), 0), words, size, color, false, bold)


func _center(y: float, words: String, size: int = 24, color: Color = TEXT, bold: bool = false) -> void:
	var w = get_viewport_rect().size.x
	var s = _fit(words, w - 40.0, size, bold)
	_text(Vector2((w - _width(words, s, bold)) / 2.0, y), words, s, color, false, bold)


func _center_at(pos: Vector2, words: String, size: int, color: Color, bold: bool = true) -> void:
	_text(pos - Vector2(_width(words, size, bold) / 2.0, 0), words, size, color, true, bold)


func _glow_text(y: float, words: String, size: int, color: Color) -> void:
	var w = get_viewport_rect().size.x
	size = _fit(words, w - 60.0, size, true)
	var pos = Vector2((w - _width(words, size, true)) / 2.0, y)
	var jitter = 1.0 + (3.0 if fmod(clock, 4.1) < 0.06 else 0.0)  # restrained glitch
	ci.draw_string_outline(font_bold, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 24, Color(color, 0.06))
	ci.draw_string_outline(font_bold, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(color, 0.14))
	ci.draw_string(font_bold, pos + Vector2(-jitter, 0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(PINK, 0.35))
	ci.draw_string(font_bold, pos + Vector2(jitter, 0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(MINT, 0.35))
	ci.draw_string(font_bold, pos, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color.lerp(TEXT, 0.25))


func _diamond(pos: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)]), color)


func _diamond_outline(pos: Vector2, r: float, color: Color) -> void:
	ci.draw_polyline(PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0), pos + Vector2(0, -r)]), color, 1.5, true)


func _chip(x: float, y: float, words: String, color: Color) -> float:
	var w = _width(words, 12, true) + 18
	ci.draw_style_box(_box(Color(color, 0.14), Color(color, 0.6), 3, 1, 0), Rect2(x, y, w, 22))
	_text(Vector2(x + 9, y + 16), words, 12, color, false, true)
	return w


func _key(x: float, y: float, key: String) -> float:
	var kw = _width(key, 12, true) + 14
	ci.draw_style_box(_box(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.45), 3, 1, 0), Rect2(x, y, kw, 20))
	_text(Vector2(x + 7, y + 15), key, 12, TEXT, false, true)
	return kw


func _keycap(x: float, y: float, key: String, label: String, draw_it: bool = true) -> float:
	var kw = _width(key, 12, true) + 14
	if draw_it:
		_key(x, y, key)
		_text(Vector2(x + kw + 6, y + 15), label, 13, TEXT_DIM)
	return kw + 6 + _width(label, 13) + 16


func _pill(center: Vector2, words: String, size: int, color: Color, max_w: float = 0.0) -> void:
	if max_w > 0.0:
		size = _fit(words, max_w - 40.0, size, true)
	var w = _width(words, size, true) + 40
	var h = size + 18.0
	var r = Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h)
	ci.draw_style_box(_box(Color(0.03, 0.045, 0.085, 0.9), Color(color, 0.45), 3, 1, 8), r)
	_brackets(r, color, 8.0)
	_text(Vector2(r.position.x + 20, center.y + size * 0.36), words, size, color, false, true)


func _vignette(size: Vector2, col: Color, m: float) -> void:
	var clear = Color(col, 0.0)
	var o = [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var i = [Vector2(m, m), Vector2(size.x - m, m), size - Vector2(m, m), Vector2(m, size.y - m)]
	for k in range(4):
		var n = (k + 1) % 4
		ci.draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([col, col, clear, clear]))


func _low_health() -> bool:
	return state == "play" and health <= 2


func _draw_ui() -> void:
	ci = hud_node
	if cam == null:
		return
	var size = get_viewport_rect().size
	if state not in ["title", "select"]:
		_draw_world_labels()
	_vignette(size, Color(0, 0, 0, 0.62), 190.0)
	if _low_health():
		# Low health: a steady red edge that breathes slowly (no strobing).
		_vignette(size, Color(HEALTH_RED, 0.22 + 0.08 * sin(clock * 2.5)), 90.0)
	if flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(flash_color, flash * 0.16))
	if state not in ["title", "select"]:
		_draw_hud(size)
	if state == "play":
		_draw_play_overlay(size)
	else:
		_draw_menu(size)


func _draw_world_labels() -> void:
	# Text that belongs to things in the 3D arena, projected onto the screen.
	for e in enemies:
		if e.kind != 2 and e.hp < e.max_hp:
			var s = _screen(e.pos, 1.2)
			ci.draw_rect(Rect2(s.x - 18, s.y, 36, 4), Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(s.x - 18, s.y, 36.0 * maxf(0, e.hp) / e.max_hp, 4), [PINK, GOLD, GOLD, ORANGE][e.kind])
		elif e.kind == 2 and e.mode == "charge":
			_center_at(_screen(e.pos, 2.7), PATTERN_NAMES[e.pattern], 17, GOLD)
	for m in pv["marks"]:
		if not m.lethal:  # doomed enemies already show an X and the top bar counts kills
			_center_at(_screen(m.e.pos, 1.7), "-%d" % m.amount, 15, MINT)
	if frozen and lasso and anchors.size() >= 3 and not pv["looped"]:
		_center_at(_screen(anchors[0], 1.5), "END HERE TO LASSO", 13, GOLD)
	for p in popups:
		_center_at(_screen(p.pos, 1.3), p.text, p.size, Color(p.color, clampf(p.life * 2.5, 0.0, 1.0)))


# --- HUD: layout adapts to the screen width ------------------------------------

func _hud_layout(size: Vector2) -> Dictionary:
	var m = 12.0
	var gap = 10.0
	var side = clampf(size.x * 0.25, 230.0, 330.0)
	var mid_w = maxf(200.0, size.x - 2.0 * m - 2.0 * side - 2.0 * gap)
	var left = Rect2(m, 10, side, 92)
	var right = Rect2(size.x - m - side, 10, side, 92)
	return {
		"left": left,
		"center": Rect2(left.end.x + gap, 10, mid_w, 74),
		"right": right,
		"score": Rect2(m, 108, side, 26),
		"help": Rect2(right.position.x, 108, side, 26),
	}


func _draw_hud(size: Vector2) -> void:
	var lay = _hud_layout(size)
	_draw_player_card(lay.left)
	_draw_objective(lay.center)
	_draw_abilities(lay.right)
	_draw_secondary(lay.score, lay.help)


func _portrait(p: Rect2, kind: int, accent: Color) -> void:
	ci.draw_style_box(_box(Color(accent, 0.1), Color(accent, 0.6), 3, 1, 0), p)
	var c = p.get_center() + Vector2(0, 2)
	var sh = 22.0 if kind == 2 else 17.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sh, 30), c + Vector2(sh, 30), c + Vector2(sh - 5, 10), c + Vector2(-sh + 5, 10)]), Color(accent, 0.45))
	if kind == 1:  # hooded archer
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 8), c + Vector2(14, 8), c + Vector2(9, -16), c + Vector2(0, -22), c + Vector2(-9, -16)]), Color("2a1f4a"))
		ci.draw_circle(c + Vector2(0, -4), 8, Color("d8a888"))
	elif kind == 2:  # helmeted heavy
		ci.draw_rect(Rect2(c + Vector2(-13, -18), Vector2(26, 24)), Color("3a2a22"))
		ci.draw_rect(Rect2(c + Vector2(-2, -10), Vector2(4, 12)), accent)
	else:  # runner: bright hair
		ci.draw_circle(c + Vector2(0, -4), 10, Color("d8a888"))
		ci.draw_rect(Rect2(c + Vector2(-11, -16), Vector2(22, 7)), PINK)
	ci.draw_rect(Rect2(c + Vector2(-9, -7), Vector2(18, 4)), accent)  # visor


func _health_bar(bar: Rect2, low: bool) -> void:
	var n = maxi(1, max_health)
	var gap = 3.0
	var seg = (bar.size.x - gap * (n - 1)) / n
	if low:
		ci.draw_rect(bar.grow(3), Color(HEALTH_RED, 0.3 + 0.2 * sin(clock * 3.0)), false, 2.0)
	for i in range(n):
		var s = Rect2(bar.position.x + i * (seg + gap), bar.position.y, seg, bar.size.y)
		ci.draw_rect(s, Color("2a1a2e"))
		if i < health:
			var col = HEALTH_RED.lerp(TEXT, 0.2 * (0.5 + 0.5 * sin(clock * 3.0))) if low else HEALTH_RED
			ci.draw_rect(s, col)
			ci.draw_rect(Rect2(s.position, Vector2(s.size.x, 3)), Color(1, 1, 1, 0.3))
		elif i == health and hp_flash > 0.0:
			ci.draw_rect(s, Color(1, 1, 1, hp_flash))  # the segment you just lost


func _draw_player_card(r: Rect2) -> void:
	var info = CHARACTERS[char_index]
	var accent = info.color
	var low = _low_health()
	_panel(r, Color(HEALTH_RED, 0.75) if low else Color(accent, 0.4))
	var p = Rect2(r.position + Vector2(10, 10), Vector2(50, r.size.y - 20))
	_portrait(p, char_index, accent)
	var x = p.end.x + 10
	var w = r.end.x - 12 - x
	var top = r.position.y
	_text(Vector2(x, top + 22), info.name, _fit(info.name, w - 54, 15, true), accent, false, true)
	_text_right(Vector2(r.end.x - 12, top + 22), "LV %d" % level, 14, LIME, true)
	_text(Vector2(x, top + 39), "HEALTH", 13, HEALTH_RED, false, true)
	_text_right(Vector2(r.end.x - 12, top + 40), "%d / %d" % [maxi(health, 0), max_health], 18, TEXT, true)
	var bar = Rect2(x, top + 45, w, 16)
	if hp_flash > 0.0:
		bar.position.x += sin(clock * 70.0) * 3.0 * hp_flash
	_health_bar(bar, low)
	var need = _xp_need(level)
	var xp_text = "%d / %d" % [xp, need]
	var tw = _width(xp_text, 13)
	_text(Vector2(x, top + 84), "XP", 13, LIME, false, true)
	_bar(Rect2(x + 26, top + 75, maxf(20.0, w - 34 - tw), 8), float(xp) / need, LIME)
	_text_right(Vector2(r.end.x - 12, top + 84), xp_text, 13, TEXT_DIM)


func _draw_objective(r: Rect2) -> void:
	var top = r.position.y
	var x = r.position.x + 14
	var w = r.size.x - 28
	if boss_phase:
		_panel(r, Color(GOLD, 0.6))
		var boss = null
		for e in enemies:
			if e.kind == 2:
				boss = e
		var title = "BOSS  -  THE COLLECTOR"
		_text(Vector2(x, top + 22), title, _fit(title, w - 90, 15, true), GOLD, false, true)
		var bar = Rect2(x, top + 31, w, 14)
		if boss == null:
			_bar(bar, 0.0, GOLD)
			_text(Vector2(x, top + 64), "The Collector is arriving...", 13, GOLD, false, true)
			return
		var ratio = clampf(float(boss.hp) / boss.max_hp, 0.0, 1.0)
		var enraged = ratio <= 0.5
		_bar(bar, ratio, PINK if enraged else GOLD)
		for mark in [0.66, 0.33]:
			var mx = bar.position.x + bar.size.x * mark
			ci.draw_line(Vector2(mx, bar.position.y - 2), Vector2(mx, bar.end.y + 2), TEXT, 1.0)
		_text_right(Vector2(r.end.x - 14, top + 22), "%d / %d" % [maxi(0, boss.hp), boss.max_hp], 13, TEXT, true)
		var line = "ENRAGED: faster attacks. Steal its bullets!" if enraged else "Destroy the Collector. Thread its bullets to steal them."
		_text(Vector2(x, top + 64), line, _fit(line, w, 13, true), PINK if enraged else TEXT_SOFT, false, true)
		return
	var info = STAGES[stage - 1]
	_panel(r, Color(MINT, 0.35))
	var head = "STAGE %d / 3" % stage
	_text(Vector2(x, top + 22), head, 15, MINT, false, true)
	var hw = _width(head, 15, true) + 12
	_text(Vector2(x + hw, top + 22), info.name, _fit(info.name, w - hw, 13, true), TEXT_SOFT, false, true)
	_bar(Rect2(x, top + 31, w, 10), float(kills_stage) / info.quota, MINT)
	var goal = "Defeat enemies: %d / %d" % [mini(kills_stage, info.quota), info.quota]
	_text(Vector2(x, top + 63), goal, 15, TEXT, false, true)
	var nxt = "Then: THE COLLECTOR" if stage == 3 else "Next: " + STAGES[stage].name
	if _width(goal, 15, true) + _width(nxt, 13) + 24 < w:
		_text_right(Vector2(r.end.x - 14, top + 63), nxt, 13, GOLD if stage == 3 else TEXT_DIM)


func _draw_abilities(r: Rect2) -> void:
	var top = r.position.y
	var x = r.position.x + 12
	var w = r.size.x - 24
	var tcol = MINT
	var status = "READY"
	if frozen:
		tcol = ICE
		status = "FROZEN %.1fs" % maxf(0.0, max_debt - debt)
	elif debt > 0.0:
		tcol = PINK
		status = "REPAYING %.1fs" % debt
	_panel(r, Color(tcol, 0.4 if tcol == MINT else 0.8))
	var kx = x + _key(x, top + 10, "SPACE") + 7
	_text(Vector2(kx, top + 25), "FREEZE", 13, TEXT, false, true)
	var avail = r.end.x - 12 - (kx + _width("FREEZE", 13, true) + 8)
	_text_right(Vector2(r.end.x - 12, top + 25), status, _fit(status, avail, 14, true), tcol, true)
	_text(Vector2(x, top + 47), "DEBT", 13, TEXT_DIM, false, true)
	var bar = Rect2(x + 44, top + 38, w - 44, 9)
	_bar(bar, debt / max_debt, ICE if frozen else PINK)
	for s in range(1, int(max_debt)):
		var sx = bar.position.x + bar.size.x * s / max_debt
		ci.draw_line(Vector2(sx, bar.position.y), Vector2(sx, bar.end.y), Color(0.035, 0.02, 0.07), 2.0)
	var dash_ok = dash_cooldown <= 0.0
	var dx = x + _key(x, top + 53, "SHIFT") + 7
	_text(Vector2(dx, top + 68), "DASH", 13, TEXT, false, true)
	_text_right(Vector2(r.end.x - 12, top + 68), "READY" if dash_ok else "%.1fs" % dash_cooldown, 14, MINT if dash_ok else TEXT_DIM, true)
	if autofire:
		_text(Vector2(x, top + 86), "AUTO-FIRE ON  (F)", 12, LIME, false, true)


func _draw_secondary(sr: Rect2, hr: Rect2) -> void:
	ci.draw_style_box(_box(Color(PANEL_BG, 0.7), Color(1, 1, 1, 0.06), 6, 1, 0), sr)
	_text(Vector2(sr.position.x + 10, sr.position.y + 18), "SCORE %06d" % score, 13, TEXT_SOFT, false, true)
	var r = _rank()
	var rcol = [Color("8a7aaa"), MINT, MINT, ICE, GOLD, GOLD, PINK][r]
	var rank_text = "SYNC RANK %s  x%.2f" % [RANKS[r][0], 1.0 + r * 0.25]
	var room = sr.size.x - 30.0 - _width("SCORE %06d" % score, 13, true)
	_text_right(Vector2(sr.end.x - 10, sr.position.y + 18), rank_text, _fit(rank_text, room, 13, true), rcol, true)

	var msg = ""
	var col = TEXT_SOFT
	if debt > 0.0 and not frozen:
		msg = "Enemies %.1fx faster for %.1fs" % [repay_speed, debt]
		col = PINK
	elif run_time < 40.0 and not frozen:
		msg = "Freezing builds debt: enemies speed up after"
	if msg != "":  # one short line, only when it matters
		ci.draw_style_box(_box(Color(PANEL_BG, 0.8), Color(col, 0.3), 6, 1, 0), hr)
		_text(Vector2(hr.position.x + 10, hr.position.y + 17), msg, _fit(msg, hr.size.x - 20, 13, true), col, false, true)


func _draw_play_overlay(size: Vector2) -> void:
	var w = size.x
	var lay = _hud_layout(size)
	var mouse = get_global_mouse_position()
	var col = ICE if frozen else MINT
	ci.draw_arc(mouse, 7, 0, TAU, 20, col, 1.5, true)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(mouse + d * 10, mouse + d * 16, col, 1.5, true)

	if frozen:
		var msg = "CLICK ENEMIES OR BULLETS TO PIN  (%d)" % anchors.size()
		var mcol = ICE
		if anchors.size() >= 2:
			msg = "RELEASE:  %d HIT  /  %d KILL  /  %d STOLEN" % [pv["hits"], pv["kills"], pv["cut"]]
			if pv["looped"]:
				msg += "  /  LOOP"
			mcol = GOLD if pv["looped"] else MINT
		_pill(Vector2(w / 2.0, 104), msg, 15, mcol, lay.center.size.x)
	elif hint_time > 0.0 and steals == 0:
		_pill(Vector2(w / 2.0, size.y - 74), "SHOOTER!  HOLD SPACE, CLICK ACROSS ITS BULLET, LET GO: YOU STEAL IT", 16, Color(ICE, 0.8 + 0.2 * sin(clock * 5.0)), w - 80.0)
	elif not taught:
		_pill(Vector2(w / 2.0, size.y - 74), "TRY THE STITCH:  HOLD SPACE  >  CLICK 2-3 ENEMIES  >  LET GO", 16, Color(GOLD, 0.8 + 0.2 * sin(clock * 5.0)), w - 80.0)

	if banner_time > 0.0:
		var a = minf(1.0, banner_time * 2.0)
		var by = size.y * 0.3
		var bcol = GOLD if boss_phase or stage == 3 else MINT
		var bw = minf(760.0, w - 40.0)
		var brect = Rect2(w / 2.0 - bw / 2.0, by, bw, 88)
		ci.draw_style_box(_box(Color(0.03, 0.045, 0.085, 0.8 * a), Color(bcol, 0.6 * a), 4, 1, 12), brect)
		_brackets(brect, Color(bcol, a))
		_center(by + 46, banner, 34, Color(bcol, a), true)
		_center(by + 74, banner_sub, 16, Color(1, 1, 1, a))
	if picked_time > 0.0 and picked_text != "":
		_pill(Vector2(w / 2.0, size.y - 110), picked_text, 14, Color(GOLD, minf(1.0, picked_time)), w - 80.0)
	var hint_w = _keycap(0, 0, "ESC", "PAUSE / HELP", false)
	_keycap(w - hint_w, size.y - 30, "ESC", "PAUSE / HELP")


# --- MENUS ------------------------------------------------------------------------

func _draw_menu(size: Vector2) -> void:
	var dim = {"title": 0.42, "select": 0.25, "upgrade": 0.8, "pause": 0.75, "over": 0.7, "win": 0.6, "stage_clear": 0.35}
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.07, dim.get(state, 0.8)))
	match state:
		"title":
			_draw_title(size)
		"select":
			_draw_select(size)
		"stage_clear":
			var cy = size.y / 2.0
			_glow_text(cy - 40, "STAGE %d CLEAR" % stage, 54, GOLD)
			_center(cy - 2, STAGES[stage - 1].name + " purged   /   +2 HP restored   /   XP collected", 17, TEXT_SOFT, true)
			if stage < STAGES.size():
				_center(cy + 40, "NEXT:  STAGE %d  -  %s" % [stage + 1, STAGES[stage].name], 20, MINT, true)
			_bar(Rect2(size.x / 2.0 - 160, cy + 58, 320, 6), 1.0 - transition / 3.2, MINT)
		"upgrade":
			_draw_upgrade(size)
		"pause":
			_draw_pause(size)
		"over", "win":
			_draw_result(size)


func _button(center: Vector2, label: String, accent: Color, primary: bool = true) -> void:
	# House button: primary = lit accent glass, secondary = quiet outline.
	var w = _width(label, 18, true) + 64
	var r = Rect2(center.x - w / 2.0, center.y - 23, w, 46)
	if primary:
		ci.draw_style_box(_box(Color(accent, 0.16), Color(accent, 0.75 + 0.25 * sin(clock * 3.0)), 6, 2, 16), r)
	else:
		ci.draw_style_box(_box(Color(PANEL_BG, 0.7), Color(accent, 0.35), 6, 1, 0), r)
	_text(Vector2(r.position.x + 32, center.y + 7), label, 18, accent if primary else TEXT_SOFT, false, true)


func _keys_row(y: float, keys: Array) -> void:
	# A quiet, centered row of keycaps with labels.
	var total = 0.0
	for k in keys:
		total += _keycap(0, 0, k[0], k[1], false)
	var x = (get_viewport_rect().size.x - total) / 2.0
	for k in keys:
		x += _keycap(x, y, k[0], k[1])


func _draw_title(size: Vector2) -> void:
	var cy = size.y / 2.0
	_glow_text(cy - 70, "BORROWED TIME", 84, MINT)
	_center(cy - 28, "Freeze time. Thread through bullets. Release to steal them.", 20, TEXT_SOFT)
	_button(Vector2(size.x / 2.0, cy + 40), "PRESS ENTER TO PLAY", MINT)
	_keys_row(cy + 100, [["WASD", "MOVE"], ["CLICK", "FIRE"], ["SPACE", "FREEZE"], ["SHIFT", "DASH"], ["ESC", "HELP"]])
	_center(cy + 148, "3 stages   /   level up as you go   /   defeat the Collector", 13, TEXT_DIM)
	if best > 0:
		_center(cy + 174, "BEST  %d" % best, 13, AMBER, true)
	if OS.is_debug_build():
		_center(size.y - 16, "editor test keys:  F2 finish stage   F3 jump to boss   F4 level up", 11, Color("5d6680"))


func _select_card_rect(i: int) -> Rect2:
	var size = get_viewport_rect().size
	var w = minf(280.0, (size.x - 80.0) / 3.0)
	var cx = size.x / 2.0 + (i - 1) * (w + 24.0)
	return Rect2(cx - w / 2.0, size.y - 140.0, w, 120.0)


func _draw_select(size: Vector2) -> void:
	_glow_text(64, "CHOOSE YOUR FIGHTER", 36, MINT)
	_center(92, "Same time powers for everyone. Only the weapon changes.", 14, TEXT_SOFT)
	for i in range(CHARACTERS.size()):
		var info = CHARACTERS[i]
		var r = _select_card_rect(i)
		var chosen = i == select_index  # (drawing never changes the selection)
		var col = info.color
		if chosen:
			ci.draw_style_box(_box(Color(col, 0.1), Color(col, 0.9), 6, 2, 18), r)
		else:
			ci.draw_style_box(_box(Color(PANEL_BG, 0.82), Color(1, 1, 1, 0.1), 6, 1, 8), r)
		ci.draw_line(r.position + Vector2(16, 1), r.position + Vector2(r.size.x - 16, 1), Color(col, 1.0 if chosen else 0.35), 2.0)
		var x = r.position.x + 18
		var inner = r.size.x - 36
		var y = r.position.y
		var kw = _key(x, y + 16, str(i + 1))
		_text(Vector2(x + kw + 10, y + 33), info.name, _fit(info.name, inner - kw - 10, 22, true), col if chosen else TEXT, false, true)
		_text(Vector2(x, y + 60), info.weapon + "    %d HP" % info.hp, 13, TEXT_SOFT if chosen else TEXT_DIM, false, true)
		ci.draw_multiline_string(font, Vector2(x, y + 82), info.line, HORIZONTAL_ALIGNMENT_LEFT, inner, 13, 2, TEXT_SOFT if chosen else TEXT_DIM)
	_keys_row(size.y - 172, [["A / D", "CHOOSE"], ["ENTER", "START"], ["ESC", "BACK"]])


func _draw_upgrade(size: Vector2) -> void:
	var cy = size.y / 2.0
	_glow_text(cy - 166, "LEVEL UP!   LV %d" % (level - pending_levels + 1), 44, LIME)
	_center(cy - 134, "Choose one  -  press 1 / 2 / 3 or click a card. Upgrades stack." + ("     (+%d more)" % (pending_levels - 1) if pending_levels > 1 else ""), 16, TEXT_SOFT)
	var mouse = get_global_mouse_position()
	var armed = upgrade_delay <= 0.0
	for i in range(offers.size()):
		var id = offers[i]
		var info = _info(id)
		var lv = levels.get(id, 0)
		var rect = _card_rect(i)
		var col = MINT if info.tag == "STITCH" else GOLD
		var hover = armed and rect.has_point(mouse)
		if hover:
			rect.position.y -= 6
			ci.draw_style_box(_box(Color(col, 0.05), Color(col, 0.25), 4, 6, 0), rect.grow(5))
		ci.draw_style_box(_box(Color(0.03, 0.045, 0.085, 0.96), Color(col, 1.0 if hover else (0.55 if armed else 0.2)), 3, 2, 14), rect)
		_brackets(rect, col, 12.0)
		var x = rect.position.x + 18
		var y = rect.position.y
		var inner = rect.size.x - 36
		ci.draw_style_box(_box(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.4), 3, 1, 0), Rect2(x, y + 14, 30, 28))
		_text(Vector2(x + 15 - _width(str(i + 1), 17, true) / 2.0, y + 34), str(i + 1), 17, TEXT, false, true)
		var tag_text = "STITCH" if info.tag == "STITCH" else "STAT"
		_chip(rect.end.x - 18 - (_width(tag_text, 12, true) + 18), y + 17, tag_text, col)
		var title = _upgrade_name(id)
		_text(Vector2(x, y + 76), title, _fit(title, inner, 24, true), col, false, true)
		for l in range(info.max):
			var c = Vector2(x + 7 + l * 20, y + 97)
			if l < lv:
				_diamond(c, 6, col)
			elif l == lv:
				_diamond(c, 6.5 + sin(clock * 6.0), TEXT)
			else:
				_diamond_outline(c, 5.5, Color(col, 0.5))
		_text(Vector2(x + info.max * 20 + 8, y + 102), "NEW" if lv == 0 else "LV %d -> %d" % [lv, lv + 1], 13, TEXT_DIM, false, true)
		ci.draw_line(Vector2(x, y + 118), Vector2(rect.end.x - 18, y + 118), Color(col, 0.25), 1)
		var lines = _upgrade_lines(id)
		for j in range(lines.size()):
			_text(Vector2(x, y + 146 + j * 22), lines[j], _fit(lines[j], inner, 15), TEXT if j == 0 else TEXT_SOFT)
	var bw = minf(680.0, size.x - 40.0)
	var br = Rect2(size.x / 2.0 - bw / 2.0, cy + 124, bw, 92)
	_panel(br, Color(MINT, 0.2))
	_text(Vector2(br.position.x + 18, br.position.y + 26), "YOUR BUILD", 13, TEXT_DIM, false, true)
	_build_chips(br.position.x + 110, br.position.y + 10, br.end.x - 18)
	var stats = _stats_lines()
	for j in range(stats.size()):
		_text(Vector2(br.position.x + 18, br.position.y + 52 + j * 16), stats[j], _fit(stats[j], bw - 36, 12), TEXT_DIM)


func _build_chips(x0: float, y: float, x_max: float) -> void:
	var x = x0
	if levels.is_empty():
		_text(Vector2(x, y + 16), "no upgrades yet", 13, Color("6f6290"))
		return
	for u in UPGRADES:
		var lv = levels.get(u.id, 0)
		if lv > 0:
			var label = _upgrade_name(u.id).split(" ")[0] + ("" if u.max == 1 else " %d" % lv)
			if x + _width(label, 12, true) + 18 > x_max:
				break
			x += _chip(x, y, label, MINT if u.tag == "STITCH" else GOLD) + 6


func _draw_pause(size: Vector2) -> void:
	var w = minf(900.0, size.x - 40.0)
	var r = Rect2((size.x - w) / 2.0, size.y / 2.0 - 200, w, 400)
	_panel(r, Color(MINT, 0.45))
	_glow_text(r.position.y + 54, "PAUSED", 44, MINT)
	_center(r.position.y + 82, "ESC  resume        Q  quit to character select", 14, TEXT_SOFT, true)
	var x = r.position.x + 28
	var y = r.position.y + 114
	_text(Vector2(x, y), "CONTROLS", 13, TEXT_DIM, false, true)
	var controls = [["WASD", "Move"], ["MOUSE", "Aim"], ["CLICK", "Fire (hold)"], ["F", "Auto-fire: " + ("ON" if autofire else "OFF")], ["SPACE", "Freeze time + pin threads"], ["SHIFT", "Dash (brief invulnerability)"], ["V", "Effects: " + ("LOW" if low_fx else "HIGH")], ["M", "Sound: " + ("OFF" if muted else "ON")]]
	for i in range(controls.size()):
		var ky = y + 10 + i * 26
		var kw = _key(x, ky, controls[i][0])
		_text(Vector2(x + kw + 10, ky + 15), controls[i][1], 13, TEXT_SOFT)
	var x2 = r.position.x + w * 0.42
	var cw = r.end.x - 28 - x2
	_text(Vector2(x2, y), "HOW IT WORKS", 13, TEXT_DIM, false, true)
	var rules = [
		[ICE, "FREEZE: hold SPACE, click to pin threads (up to %.0fs)." % max_debt],
		[MINT, "RELEASE: threads cut enemies; crossed bullets are stolen."],
		[PINK, "DEBT: afterwards enemies move %.1fx until it clears." % repay_speed],
		[LIME, "XP: gems level you up. Choose an upgrade each level."],
		[GOLD, "SYNC RANK: stitch kills raise your score multiplier."],
	]
	for i in range(rules.size()):
		_text(Vector2(x2, y + 24 + i * 22), rules[i][1], _fit(rules[i][1], cw, 13), rules[i][0])
	var by = y + 24 + rules.size() * 22 + 14
	_text(Vector2(x2, by), "BUILD  -  " + CHARACTERS[char_index].name + " / " + CHARACTERS[char_index].weapon, 13, TEXT_DIM, false, true)
	_build_chips(x2, by + 8, r.end.x - 28)
	var stats = _stats_lines()
	for j in range(stats.size()):
		_text(Vector2(x2, by + 52 + j * 18), stats[j], _fit(stats[j], cw, 12), TEXT_DIM)


func _draw_result(size: Vector2) -> void:
	var w = size.x
	var cy = size.y / 2.0
	var won = state == "win"
	var col = MINT if won else PINK
	var pw = minf(680.0, w - 40.0)
	var r = Rect2(w / 2.0 - pw / 2.0, cy - 160, pw, 330)
	ci.draw_style_box(_box(Color(0.03, 0.045, 0.085, 0.92), Color(col, 0.6), 3, 2, 16), r)
	_brackets(r, col, 14.0)
	_glow_text(cy - 90, "DEBT SETTLED" if won else "TIME'S UP", 58, col)
	_center(cy - 54, "You defeated the Collector." if won else "Freeze near a cluster, pin through it, release. Kills chain.", 17, TEXT_SOFT)
	_center(cy - 2, "%d" % score, 44, GOLD, true)
	_center(cy + 20, "SCORE   -   NEW BEST!" if new_best else "SCORE   -   BEST %d" % best, 13, GOLD if new_best else TEXT_DIM, true)
	var cells = [
		["STAGE", "%d / 3" % stage],
		["TIME", "%d:%02d" % [int(run_time / 60.0), int(run_time) % 60]],
		["BEST STITCH", "x%d" % best_combo],
		["PEAK RANK", RANKS[peak_rank][0]],
		["LEVEL", str(level)],
	]
	var step = minf(128.0, (pw - 40.0) / 5.0)
	for i in range(5):
		var cx = w / 2.0 - step * 2.0 + i * step
		_text(Vector2(cx - _width(cells[i][1], 22, true) / 2.0, cy + 62), cells[i][1], 22, TEXT, false, true)
		_text(Vector2(cx - _width(cells[i][0], 11, true) / 2.0, cy + 80), cells[i][0], 11, TEXT_DIM, false, true)
	_button(Vector2(w / 2.0, cy + 122), "ENTER   PLAY AGAIN AS " + CHARACTERS[char_index].name, col)
	_center(cy + 164, "C   CHANGE FIGHTER", 13, TEXT_DIM, true)
