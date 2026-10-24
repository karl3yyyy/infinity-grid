class_name ChessClock
extends Node

## Display of the ranked chess clock. The server alone keeps time and decides
## a loss on time; this node only counts the running bank down between the
## server's "clock" messages and takes over every new server state as is.

signal ticked(own_seconds: int, opponent_seconds: int, own_running: bool)

var viewer_team: int = 0
var _left: Array[float] = [0.0, 0.0]
var _to_move: int = -1
var _shown: Array[int] = [-1, -1]


func _ready() -> void:
	set_process(false)


## left_ms: both banks in milliseconds as the server saw them on sending.
func sync(left_ms: Array, to_move: int) -> void:
	_left = [float(left_ms[0]) / 1000.0, float(left_ms[1]) / 1000.0]
	_to_move = to_move
	_shown = [-1, -1]
	set_process(true)
	_emit()


func stop() -> void:
	_to_move = -1
	set_process(false)
	ticked.emit(-1, -1, false)


func _process(delta: float) -> void:
	if _to_move < 0:
		return
	_left[_to_move] = maxf(_left[_to_move] - delta, 0.0)
	_emit()


func _emit() -> void:
	var whole: Array[int] = [ceili(_left[0]), ceili(_left[1])]
	if whole != _shown:
		_shown = whole
		ticked.emit(whole[viewer_team], whole[1 - viewer_team], _to_move == viewer_team)
