class_name PurgeCycle
extends RefCounted

## The running ranked season ("Purge Cycle"), worked out from the date exactly
## like server/online/seasons.js, so every screen can show it, even offline.

const CYCLE_DAYS: int = 182
const NAMES: Array[String] = [
	"Cyber-Zero", "Black ICE", "Ghost Protocol", "Null Pointer", "Kernel Panic",
	"Dark Net", "Stack Overflow", "Blue Screen", "Zero Day", "Root Access",
]
const DAY_SECONDS: int = 86400


static func _start() -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 26, "hour": 0, "minute": 0, "second": 0}))


static func index() -> int:
	return maxi(0, floori(float(int(Time.get_unix_time_from_system()) - _start()) / float(CYCLE_DAYS * DAY_SECONDS)))


static func number() -> int:
	return index() + 1


static func cycle_name() -> String:
	return NAMES[index() % NAMES.size()]


static func days_left() -> int:
	var ends := _start() + (index() + 1) * CYCLE_DAYS * DAY_SECONDS
	return maxi(0, ceili(float(ends - int(Time.get_unix_time_from_system())) / float(DAY_SECONDS)))


## "PURGE CYCLE 01: CYBER-ZERO  ·  noch 184 Tage"
static func banner() -> String:
	return "PURGE CYCLE %02d: %s  ·  noch %d Tage" % [number(), cycle_name().to_upper(), days_left()]
