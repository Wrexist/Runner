extends Node
## UIManager (autoload singleton)
## Owns the front-end screen flow so gameplay scenes stay focused on gameplay:
##   Start -> (Play) -> [first time: Tutorial] -> run -> GameOver -> (Again | Shop)
##   Pause overlay appears on pause (manual or auto on app backgrounding).
##   Shop is ALWAYS gated behind the ParentalGate (Apple Kids requirement).
## Screens are built in code from the active theme so they reskin for free.

const UILayer := preload("res://ui/UIScreens.gd")

var _layer: CanvasLayer
var _current: Control

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	GameCore.run_started.connect(_on_run_started)
	GameCore.run_ended.connect(_on_run_ended)
	GameCore.paused_changed.connect(_on_paused_changed)
	GameCore.returned_to_menu.connect(_show_start)
	# Wait one frame so other autoloads (ThemeManager) are ready, then mount UI.
	call_deferred("_show_start")

func _show(screen: Control) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_current = screen
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(screen)

func _clear() -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
		_current = null

# ---------------------------------------------------------------- Start / menu
func _show_start() -> void:
	var s := UILayer.make_start_screen()
	s.play_pressed.connect(_on_play_pressed)
	s.settings_pressed.connect(func(): _show_settings(_show_start))
	s.album_pressed.connect(_show_album)
	_show(s)

## First-ever Play shows a one-time "how to play" card; afterward it plays directly.
func _on_play_pressed() -> void:
	if SaveManager.seen_tutorial:
		GameCore.start_run()
	else:
		var t := UILayer.make_tutorial()
		t.start_pressed.connect(func():
			SaveManager.seen_tutorial = true
			SaveManager.save_game()
			GameCore.start_run())
		_show(t)

func _on_run_started() -> void:
	_clear()

func _on_run_ended(score: int, is_high: bool) -> void:
	var s := UILayer.make_game_over(score, is_high, GameCore.rescued_this_run.size())
	s.play_again_pressed.connect(_on_play_pressed)
	s.album_pressed.connect(_show_album)
	_show(s)

# ---------------------------------------------------------------- Pause
func _on_paused_changed(is_paused: bool) -> void:
	if is_paused:
		_show_pause()
	else:
		# Resume / go-to-menu both clear the overlay; go-to-menu then shows start
		# via the returned_to_menu signal.
		if _current is UIScreens.Pause:
			_clear()

func _show_pause() -> void:
	var p := UILayer.make_pause()
	p.resume_pressed.connect(GameCore.resume)
	p.home_pressed.connect(GameCore.go_to_menu)
	p.settings_pressed.connect(func(): _show_settings(_show_pause))
	_show(p)

# ---------------------------------------------------------------- Settings / album
func _show_settings(on_close: Callable) -> void:
	var s := UILayer.make_settings()
	s.closed.connect(on_close)
	_show(s)

func _show_album() -> void:
	var a := UILayer.make_album()
	a.closed.connect(_show_start)
	a.unlock_pressed.connect(func(): _open_shop_gated(_show_album))
	_show(a)

# ---------------------------------------------------------------- Shop (gated)
## The parental gate ALWAYS precedes the Shop. `on_close` is where Back/cancel
## returns (e.g. the album), so we never rebuild a stale screen from live state.
func _open_shop_gated(on_close: Callable) -> void:
	var gate := UILayer.make_parental_gate()
	gate.passed.connect(func(): _open_shop(on_close))
	gate.cancelled.connect(on_close)
	_show(gate)

func _open_shop(on_close: Callable) -> void:
	var shop := UILayer.make_shop()
	shop.closed.connect(on_close)
	_show(shop)
