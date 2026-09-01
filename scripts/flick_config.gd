class_name FlickConfig
extends RefCounted

const BPM := 128
const FLICK_THRESHOLD_PX := 24.0
const PREVIEW_WINDOW_MS := 2400
const SCROLL_WINDOW_MS := 2000.0
const NOTE_GAP_BEATS := 1.0
const START_LEAD_IN_MS := 1000
const PERFECT_MS := 45
const GREAT_MS := 95
const GOOD_MS := 150
const MISS_MS := 210

const DEFAULT_PHRASE := "みくみくにしてあげるよ"
const KANA_KEYS: Array[String] = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]
const DIRECTIONS: Array[String] = ["up", "right", "down", "left"]

static func beat_interval_ms() -> float:
	return 60000.0 / float(BPM)

static func arrow(dir: String) -> String:
	match dir:
		"up": return "↑"
		"right": return "→"
		"down": return "↓"
		_: return "←"
