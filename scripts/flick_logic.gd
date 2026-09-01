class_name FlickLogic
extends RefCounted

static func build_phrase_chart(phrase: String = FlickConfig.DEFAULT_PHRASE) -> Array:
	var chars := phrase.strip_edges().replace(" ", "").split("")
	var filtered: Array[String] = []
	for c in chars:
		if c.length() > 0:
			filtered.append(c)
	var notes: Array = []
	var beat := FlickConfig.beat_interval_ms()
	for i in filtered.size():
		notes.append({
			"id": "note-%d" % (i + 1),
			"kana": filtered[i],
			"direction": FlickConfig.DIRECTIONS[i % FlickConfig.DIRECTIONS.size()],
			"time_ms": FlickConfig.START_LEAD_IN_MS + int(i * beat * FlickConfig.NOTE_GAP_BEATS),
			"judged": false,
			"grade": "",
		})
	return notes

static func detect_flick(sx: float, sy: float, ex: float, ey: float) -> String:
	var dx := ex - sx
	var dy := ey - sy
	var ax := absf(dx)
	var ay := absf(dy)
	var th := FlickConfig.FLICK_THRESHOLD_PX
	if ax < th and ay < th:
		return ""
	if ax > ay:
		return "right" if dx > 0 else "left"
	return "down" if dy > 0 else "up"

static func grade_for_offset(abs_ms: float) -> String:
	if abs_ms <= FlickConfig.PERFECT_MS:
		return "perfect"
	if abs_ms <= FlickConfig.GREAT_MS:
		return "great"
	if abs_ms <= FlickConfig.GOOD_MS:
		return "good"
	return "miss"

static func can_judge(offset_ms: float) -> bool:
	return absf(offset_ms) <= float(FlickConfig.MISS_MS)

static func judge_input(notes: Array, kana: String, direction: String, input_ms: int) -> Dictionary:
	var best_idx := -1
	var best_abs := INF
	for i in notes.size():
		var n: Dictionary = notes[i]
		if n.judged:
			continue
		if str(n.kana) != kana or str(n.direction) != direction:
			continue
		var offset := float(input_ms - int(n.time_ms))
		if not can_judge(offset):
			continue
		var ab := absf(offset)
		if ab < best_abs:
			best_abs = ab
			best_idx = i
	if best_idx < 0:
		return {"ok": false, "grade": "miss", "offset": INF}
	var note: Dictionary = notes[best_idx]
	var offset_ms := float(input_ms - int(note.time_ms))
	var grade := grade_for_offset(absf(offset_ms))
	note.judged = true
	note.grade = grade
	note["timing_offset_ms"] = offset_ms
	notes[best_idx] = note
	return {"ok": grade != "miss", "grade": grade, "offset": offset_ms, "id": note.id}

static func sweep_missed(notes: Array, now_ms: int) -> Array:
	var out: Array = []
	for i in notes.size():
		var n: Dictionary = notes[i]
		if n.judged:
			continue
		if now_ms > int(n.time_ms) + FlickConfig.MISS_MS:
			n.judged = true
			n.grade = "miss"
			notes[i] = n
			out.append({"ok": false, "grade": "miss"})
	return out

static func apply_score(score: Dictionary, result: Dictionary) -> Dictionary:
	var s := score.duplicate()
	var grade: String = str(result.grade)
	if grade == "miss":
		s.combo = 0
		s.miss += 1
		return s
	s.combo += 1
	s.max_combo = maxi(int(s.max_combo), int(s.combo))
	var bonus := mini(150, int(s.combo) * 5)
	var base := 300 if grade == "perfect" else (180 if grade == "great" else 100)
	s.score += base + bonus
	if grade == "perfect":
		s.perfect += 1
	elif grade == "great":
		s.great += 1
	else:
		s.good += 1
	return s

static func initial_score() -> Dictionary:
	return {
		"score": 0, "combo": 0, "max_combo": 0,
		"perfect": 0, "great": 0, "good": 0, "miss": 0,
	}

static func calculate_accuracy(score: Dictionary) -> float:
	var hit := int(score.perfect) + int(score.great) + int(score.good)
	var total := hit + int(score.miss)
	if total == 0:
		return 0.0
	var weighted := float(score.perfect) * 1.0 + float(score.great) * 0.7 + float(score.good) * 0.4
	return weighted / float(total)

static func kana_lane(kana: String) -> int:
	var idx := FlickConfig.KANA_KEYS.find(kana)
	if idx < 0:
		return 2
	return idx % 5
