class_name TurnManager
extends Node

signal state_changed(state: BattleState)
signal round_changed(round_number: int)

enum BattleState {
	BATTLE_START,
	PLAYER_TURN_START,
	PLAYER_SELECT_UNIT,
	PLAYER_SELECT_MOVE,
	PLAYER_SELECT_ACTION,
	PLAYER_SELECT_TARGET,
	UNIT_MOVING,
	UNIT_ATTACKING,
	ENEMY_TURN_START,
	ENEMY_ACTING,
	CHECK_BATTLE_RESULT,
	VICTORY,
	DEFEAT,
}

var state: BattleState = BattleState.BATTLE_START
var round_number: int = 1


func set_state(new_state: BattleState) -> void:
	state = new_state
	state_changed.emit(state)


func start_player_round(increment_round: bool = false) -> void:
	if increment_round:
		round_number += 1
		round_changed.emit(round_number)
	set_state(BattleState.PLAYER_TURN_START)


func state_name() -> String:
	return BattleState.keys()[state].capitalize()

