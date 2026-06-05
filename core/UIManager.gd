extends Node
## UIManager (autoload singleton)
## Owns the front-end screen flow so gameplay scenes stay focused on gameplay:
##   StartScreen -> (Play) -> run -> GameOver -> (Play Again | Shop)
##   Shop is ALWAYS gated behind the ParentalGate (Apple Kids requirement).
## Screens are built in code from the active theme so they reskin for free.

const UILayer := preload("res://ui/UIScreens.gd")

var _layer: CanvasLayer
var _current: Control

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	# Wait one frame so other autoloads (ThemeManager) are ready, then mount UI.
	add_child(_layer)
	GameCore.run_started.connect(_on_run_started)
	GameCore.run_ended.connect(_on_run_ended)
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

func _show_start() -> void:
	var s := UILayer.make_start_screen()
	s.play_pressed.connect(GameCore.start_run)
	_show(s)

func _on_run_started() -> void:
	_clear()

func _on_run_ended(score: int, is_high: bool) -> void:
	var s := UILayer.make_game_over(score, is_high, GameCore.rescued_this_run.size())
	s.play_again_pressed.connect(GameCore.start_run)
	s.shop_pressed.connect(_open_shop_gated)
	_show(s)

func _open_shop_gated() -> void:
	var gate := UILayer.make_parental_gate()
	gate.passed.connect(_open_shop)
	gate.cancelled.connect(_on_run_ended.bind(GameCore.score, false))
	_show(gate)

func _open_shop() -> void:
	var shop := UILayer.make_shop()
	shop.closed.connect(_on_run_ended.bind(GameCore.score, false))
	_show(shop)
