extends Node3D
## Player.gd — lane-based movement for the rescue runner.
## Input: swipe/drag on touch, arrow keys on desktop (NO tilt — small kids and
## reviewers both hate tilt). Holds the carried gem color for the Rescue Run
## mechanic: grab a gem -> carry its color -> swipe into a same-color cage to
## rescue the critter inside.

var lanes_count: int = 3
var lane_width: float = 2.0
var current_lane: int = 1
var move_speed: float = 12.0          # how fast we slide between lanes
var carried_color: String = ""

var _target_x: float = 0.0
var _swipe_start_x: float = 0.0
var _swipe_start_y: float = 0.0
var _swiping: bool = false
var _swiped_this_touch: bool = false
var _vstate := "ground"               # "ground" | "jump" | "slide"
var _vtime := 0.0
var _jump_height := 1.6
var _jump_seconds := 0.55
var _slide_seconds := 0.55
var _lean_tween: Tween                  # active lean; killed before a new one starts
var _swipe_threshold: float = 40.0      # px before a drag counts as a swipe (themed)
var _tap_dead_zone_frac: float = 0.12   # ignore taps within this frac of center
var _lane_cooldown_time: float = 0.0    # min seconds between lane changes (themed)
var _lane_cooldown: float = 0.0         # remaining cooldown
var _buffered_dir: int = 0              # one queued lane step taken during cooldown
var _carry_glow: float = 1.4            # carried-badge emission energy (themed)
var _carry_badge_scale: float = 1.0     # carried-badge size multiplier (themed)
var _carry_pulse: Tween                 # looping glow while carrying

## The theme's player model, if one is present (else we keep the placeholder box
## and tint it by the carried color). Loaded fail-soft via ThemeModels.
var _model: Node3D = null

# Breadcrumb of recent positions so the rescue Trail can snake behind us.
var _history: Array[Vector3] = []
const HISTORY_MAX := 240
var _bob_t: float = 0.0

func _ready() -> void:
	lanes_count = int(ThemeManager.get_val("lanes", 3))
	lane_width = float(ThemeManager.get_val("lane_width", 2.0))
	move_speed = float(ThemeManager.get_val("move_speed", 12.0))   # lane-slide feel
	_swipe_threshold = float(ThemeManager.get_val("swipe_threshold_px", 40.0))
	_tap_dead_zone_frac = float(ThemeManager.get_val("tap_dead_zone_frac", 0.12))
	_lane_cooldown_time = float(ThemeManager.get_val("lane_change_cooldown", 0.0))
	_carry_glow = float(ThemeManager.get_val("carry_glow", 1.4))
	_carry_badge_scale = float(ThemeManager.get_val("carry_badge_scale", 1.0))
	_jump_height = float(ThemeManager.get_val("jump_height", 1.6))
	_jump_seconds = float(ThemeManager.get_val("jump_seconds", 0.55))
	_slide_seconds = float(ThemeManager.get_val("slide_seconds", 0.55))
	current_lane = lanes_count / 2       # integer center lane
	_target_x = _lane_to_x(current_lane)
	position.x = _target_x
	_load_theme_model()
	_update_carry_visual()   # show the friendly base color immediately on the menu
	GameCore.run_started.connect(_on_run_started)
	GameCore.returned_to_menu.connect(_on_run_started)

## Swap in the theme's player model if it exists; otherwise the placeholder box
## stays (and gets tinted by the carried color). Fail-soft.
func _load_theme_model() -> void:
	_model = ThemeModels.instance(ThemeManager.asset("player_model"))
	if _model == null:
		# No .glb: build a themed procedural character/vehicle (not a bare box).
		# Treated exactly like a loaded model — _body() returns it, so bob/lean,
		# the root carry badge, and the sibling collision Area3D are all unaffected.
		_model = ThemeModels.player_visual(
			str(ThemeManager.get_val("player_shape", "critter")),
			ThemeManager.color("accent", Color(0.95, 0.6, 0.62)))
		_model.name = "ProcModel"
	if _model:
		add_child(_model)
		var placeholder := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if placeholder:
			placeholder.visible = false

## The node to lean on a turn: the real model if present, else the placeholder.
func _body() -> Node3D:
	return _model if _model else get_node_or_null("MeshInstance3D") as Node3D

func _on_run_started() -> void:
	current_lane = lanes_count / 2
	_target_x = _lane_to_x(current_lane)
	position.x = _target_x
	_lane_cooldown = 0.0
	_buffered_dir = 0
	_vstate = "ground"
	_vtime = 0.0
	_history.clear()
	clear_color()

func _lane_to_x(lane: int) -> float:
	return (lane - (lanes_count - 1) / 2.0) * lane_width

func move_lane(dir: int) -> void:
	# During the brief post-move cooldown, remember the latest intent and apply it
	# when the cooldown ends — so a quick double-swipe queues instead of dropping.
	# The buffer holds a single step, so input can never run away.
	if _lane_cooldown > 0.0:
		_buffered_dir = dir
		return
	_apply_lane_move(dir)

func _apply_lane_move(dir: int) -> void:
	var before := current_lane
	current_lane = clampi(current_lane + dir, 0, lanes_count - 1)
	_target_x = _lane_to_x(current_lane)
	if current_lane != before:
		_lean(dir)
		_lane_cooldown = _lane_cooldown_time
		Effects.haptic("light")
		AudioManager.play_sfx("whoosh")

## Tick the lane cooldown and release a buffered step when it expires. Called each
## frame while running (extracted so headless tests can pump it directly).
func _tick_cooldown(delta: float) -> void:
	if _lane_cooldown <= 0.0:
		return
	_lane_cooldown = maxf(_lane_cooldown - delta, 0.0)
	if _lane_cooldown == 0.0 and _buffered_dir != 0:
		var d := _buffered_dir
		_buffered_dir = 0
		_apply_lane_move(d)

## Up = a short hop (clears a hurdle); Down = a quick duck/slide (passes under an
## overhang). One vertical action at a time; gentle and brief.
func jump() -> void:
	if _vstate != "ground":
		return
	_vstate = "jump"
	_vtime = 0.0
	Effects.haptic("light")
	AudioManager.play_sfx("whoosh")

func slide() -> void:
	if _vstate != "ground":
		return
	_vstate = "slide"
	_vtime = 0.0
	Effects.haptic("light")
	AudioManager.play_sfx("whoosh")

func is_airborne() -> bool:
	return _vstate == "jump"

func is_sliding() -> bool:
	return _vstate == "slide"

## Drive the hop/duck (and the idle bob when grounded). Jump/slide are GAMEPLAY,
## so the brief deliberate motion shows even under reduce_motion; only the ambient
## idle bob is motion-gated.
func _update_vertical(delta: float) -> void:
	var b := _body()
	if b == null:
		return
	match _vstate:
		"jump":
			_vtime += delta
			if _vtime >= _jump_seconds:
				_vstate = "ground"
				b.position.y = 0.0
				b.scale.y = 1.0
			else:
				b.position.y = sin((_vtime / _jump_seconds) * PI) * _jump_height
		"slide":
			_vtime += delta
			b.scale.y = 0.55
			b.position.y = -0.15
			if _vtime >= _slide_seconds:
				_vstate = "ground"
				b.scale.y = 1.0
				b.position.y = 0.0
		_:
			b.scale.y = 1.0
			if not bool(SaveManager.settings.get("reduce_motion", false)):
				# Shared run-time phase — synced with gems/power-ups (choreographed).
				b.position.y = sin(GameCore.elapsed * 3.0) * 0.06
			else:
				b.position.y = 0.0

## A quick lean into the turn that settles back — makes movement feel alive.
func _lean(dir: int) -> void:
	if bool(SaveManager.settings.get("reduce_motion", false)):
		return
	var mesh := _body()
	if mesh == null:
		return
	# Kill any in-flight lean so rapid lane changes don't stack overlapping
	# tweens (which fight over rotation:z and leave the body crooked).
	if _lean_tween and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_lean_tween.tween_property(mesh, "rotation:z", deg_to_rad(-14.0 * dir), 0.08)
	_lean_tween.tween_property(mesh, "rotation:z", 0.0, 0.16)

## Position from `steps` frames ago (clamped). Used by Trail.gd.
func history_point(steps: int) -> Vector3:
	if _history.is_empty():
		return global_position
	return _history[mini(steps, _history.size() - 1)]

func _unhandled_input(event: InputEvent) -> void:
	if not GameCore.is_running():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			move_lane(-1)
		elif event.keycode == KEY_RIGHT:
			move_lane(1)
		elif event.keycode == KEY_UP:
			jump()
		elif event.keycode == KEY_DOWN:
			slide()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_swipe_start_x = touch.position.x
			_swipe_start_y = touch.position.y
			_swiping = true
			_swiped_this_touch = false
		else:
			# A tap (no swipe) moves toward the side of the screen tapped — the
			# most forgiving control for tiny, imprecise hands. A small dead zone
			# around center ignores accidental near-center taps.
			if not _swiped_this_touch:
				var half := get_viewport().get_visible_rect().size.x * 0.5
				var off := touch.position.x - half
				if absf(off) >= half * _tap_dead_zone_frac:
					move_lane(1 if off > 0.0 else -1)
			_swiping = false
	elif event is InputEventScreenDrag and _swiping and not _swiped_this_touch:
		var drag := event as InputEventScreenDrag
		var dx := drag.position.x - _swipe_start_x
		var dy := drag.position.y - _swipe_start_y
		# Pick the dominant axis: left/right changes lane; up/down hops/ducks.
		if absf(dx) >= _swipe_threshold and absf(dx) >= absf(dy):
			move_lane(1 if dx > 0.0 else -1)
			_swiped_this_touch = true   # one action per swipe; release to act again
		elif absf(dy) >= _swipe_threshold and absf(dy) > absf(dx):
			if dy < 0.0:
				jump()                  # swipe up (screen y grows downward)
			else:
				slide()
			_swiped_this_touch = true

func _process(delta: float) -> void:
	if not GameCore.is_running():
		return
	_tick_cooldown(delta)
	position.x = move_toward(position.x, _target_x, move_speed * delta)
	_update_vertical(delta)   # hop / duck, plus the motion-safe idle bob
	_history.push_front(global_position)
	if _history.size() > HISTORY_MAX:
		_history.resize(HISTORY_MAX)

# --- Rescue Run color carrying (called by Collectible) ---
func carry_color(c: String) -> void:
	carried_color = c
	_update_carry_visual()

func clear_color() -> void:
	carried_color = ""
	_update_carry_visual()

## Show what color/shape the player is carrying — without this the core decision
## ("do I have the right color for the cage ahead?") is invisible and unmakeable.
func _update_carry_visual() -> void:
	# With a real model we leave its own materials alone and show the carried
	# color via the floating badge only (tinting a whole fox green looks wrong).
	# With the placeholder box, tint the body itself so the carry reads clearly.
	if _model == null:
		var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			# Carried color while prepared; a friendly themed base color otherwise
			# (so the placeholder reads as a character, not a blank white box).
			var col := ThemeManager.gem_color(carried_color) if carried_color != "" \
				else ThemeManager.color("accent", Color(0.95, 0.6, 0.62))
			mesh.material_override = Style.surface(col)
	_update_carry_badge()

func _update_carry_badge() -> void:
	var badge := get_node_or_null("CarryBadge") as MeshInstance3D
	if carried_color == "":
		if _carry_pulse and _carry_pulse.is_valid():
			_carry_pulse.kill()
		if badge:
			badge.visible = false
		return
	if badge == null:
		badge = MeshInstance3D.new()
		badge.name = "CarryBadge"
		badge.material_override = Style.surface(Color.WHITE)
		badge.position = Vector3(0, 1.0, 0)
		add_child(badge)
	# A bright, glowing badge in the carried color so "I'm prepared (with THIS
	# color)" reads at a glance — the whole Rescue Run decision hinges on it.
	var col := ThemeManager.gem_color(carried_color)
	var m := badge.material_override as StandardMaterial3D
	m.albedo_color = col.lightened(0.3)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = _carry_glow
	badge.mesh = Shapes.badge(ThemeManager.gem_symbol(carried_color))
	badge.scale = Vector3.ONE * _carry_badge_scale
	badge.visible = true
	Effects.pop(badge, 1.4)
	_start_carry_pulse(badge)

## A soft, looping glow pulse while carrying (motion-safe). Killed on clear.
func _start_carry_pulse(badge: MeshInstance3D) -> void:
	if _carry_pulse and _carry_pulse.is_valid():
		_carry_pulse.kill()
	if bool(SaveManager.settings.get("reduce_motion", false)):
		return
	var m := badge.material_override as StandardMaterial3D
	_carry_pulse = create_tween().set_loops()
	_carry_pulse.tween_property(m, "emission_energy_multiplier", _carry_glow * 1.5, 0.6) \
		.set_trans(Tween.TRANS_SINE)
	_carry_pulse.tween_property(m, "emission_energy_multiplier", _carry_glow, 0.6) \
		.set_trans(Tween.TRANS_SINE)
