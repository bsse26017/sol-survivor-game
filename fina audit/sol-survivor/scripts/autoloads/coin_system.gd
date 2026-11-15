## Autoload: keeps the player's coin total and announces every change.
##
## Rewards (Sol Survivor - Points to Add):
##   main repair completed   +20
##   optional field task     +10  (2 per sol, in different places)
##   survive the night       +25
##   win the game            +50
extends Node

signal coins_changed(total: int, delta: int, reason: String)

const REWARD_REPAIR := 20
const REWARD_FIELD_TASK := 10
const REWARD_NIGHT := 25
const REWARD_WIN := 50

## Coin total for the whole run.
var total: int = 0
## Coins earned since the current sol started (shown in the night summary).
var earned_this_sol: int = 0


func award(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	total += amount
	earned_this_sol += amount
	coins_changed.emit(total, amount, reason)


## New run: everything back to zero.
func reset() -> void:
	total = 0
	earned_this_sol = 0
	coins_changed.emit(total, 0, "reset")


## A sol (or a retried sol) begins: its per-sol earnings start from zero.
func begin_sol() -> void:
	earned_this_sol = 0


## Retry rewinds the coin total too, so retrying can never be used to farm coins.
func restore(saved_total: int) -> void:
	total = saved_total
	earned_this_sol = 0
	coins_changed.emit(total, 0, "restore")
