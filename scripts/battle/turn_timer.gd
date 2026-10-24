class_name TurnTimer
extends Node

## Countdown for one turn. Ticks once per whole second so the HUD can show it;
## `expired` fires when it reaches zero. What happens then is the battle
## manager's decision.

signal ticked(seconds_left: int)
signal expired

var _left: float = 0.0
var _running: bool = false
var _shown: int = -1


func start(seconds: float) -> void:
	_left = seconds
	_shown = -1
	_running = true
	set_process(true)
	_emit_tick()


func stop() -> void:
	_running = false
	set_process(false)
	ticked.emit(-1)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	_emit_tick()
	if _left <= 0.0:
		_running = false
		set_process(false)
		expired.emit()


func _emit_tick() -> void:
	var whole := maxi(ceili(_left), 0)
	if whole != _shown:
		_shown = whole
		ticked.emit(whole)
