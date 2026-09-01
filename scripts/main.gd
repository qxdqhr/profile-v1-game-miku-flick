extends Control
## Stage-C polish: pause/reset, 5-lane scroll, accuracy HUD, global flick coords.

enum Status { READY, PLAYING, PAUSED, ENDED }

const W := 360.0
const H := 640.0
const HIT_Y := 400.0
const TOP_Y := 100.0
const LANE_COUNT := 5

var _notes: Array = []
var _status: Status = Status.READY
var _score: Dictionary = {}
var _now_ms: int = 0
var _start_usec: int = 0
var _paused_accum_ms: int = 0
var _pause_start_usec: int = 0
var _feedback: String = "点击开始，然后在假名键上滑动"

var _pointer_kana: String = ""
var _pointer_start: Vector2 = Vector2.ZERO
var _kana_buttons: Array[Button] = []

@onready var _lane: Control = $Lane
@onready var _hud: Label = $UI/HUD
@onready var _feedback_label: Label = $UI/Feedback
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _start_btn: Button = $UI/Overlay/VBox/StartBtn
@onready var _retry_btn: Button = $UI/Overlay/VBox/RetryBtn
@onready var _kana_grid: GridContainer = $UI/KanaGrid
@onready var _pause_btn: Button = $UI/Controls/PauseBtn
@onready var _reset_btn: Button = $UI/Controls/ResetBtn

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	_start_btn.pressed.connect(_on_start)
	_retry_btn.pressed.connect(_on_retry)
	_pause_btn.pressed.connect(_toggle_pause)
	_reset_btn.pressed.connect(_on_reset_to_ready)
	_overlay.visible = true
	_over_msg.text = "Miku Flick\nみくみくにしてあげるよ"
	_start_btn.visible = true
	_retry_btn.visible = false
	_build_kana_keys()
	_reset_chart()
	_lane.draw.connect(_draw_lane)

func _build_kana_keys() -> void:
	for c in _kana_grid.get_children():
		c.queue_free()
	_kana_buttons.clear()
	for k in FlickConfig.KANA_KEYS:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(62, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.gui_input.connect(_on_kana_gui_input.bind(k))
		_kana_grid.add_child(b)
		_kana_buttons.append(b)

func _reset_chart() -> void:
	_notes = FlickLogic.build_phrase_chart()
	_score = FlickLogic.initial_score()
	_now_ms = 0
	_status = Status.READY
	_pointer_kana = ""
	_update_ui()

func _on_start() -> void:
	_notes = FlickLogic.build_phrase_chart()
	_score = FlickLogic.initial_score()
	_now_ms = 0
	_start_usec = Time.get_ticks_usec()
	_paused_accum_ms = 0
	_status = Status.PLAYING
	_overlay.visible = false
	_feedback = "开始！按音符在对应假名键上滑动"
	_update_ui()

func _on_retry() -> void:
	_on_reset_to_ready()

func _on_reset_to_ready() -> void:
	_reset_chart()
	_overlay.visible = true
	_over_msg.text = "Miku Flick\nみくみくにしてあげるよ"
	_start_btn.visible = true
	_retry_btn.visible = false
	_feedback = "已重置，点击开始"
	_lane.queue_redraw()
	_update_ui()

func _toggle_pause() -> void:
	if _status == Status.PLAYING:
		_status = Status.PAUSED
		_pause_start_usec = Time.get_ticks_usec()
		_feedback = "已暂停"
		_pause_btn.text = "继续"
	elif _status == Status.PAUSED:
		_paused_accum_ms += int((Time.get_ticks_usec() - _pause_start_usec) / 1000)
		_status = Status.PLAYING
		_feedback = "继续"
		_pause_btn.text = "暂停"
	_update_ui()

func _process(_delta: float) -> void:
	if _status != Status.PLAYING:
		return
	_now_ms = int((Time.get_ticks_usec() - _start_usec) / 1000) - _paused_accum_ms
	var missed: Array = FlickLogic.sweep_missed(_notes, _now_ms)
	if not missed.is_empty():
		for r in missed:
			_score = FlickLogic.apply_score(_score, r)
		_feedback = ("Miss x%d" % missed.size()) if missed.size() > 1 else "Miss"
	if _all_judged():
		_status = Status.ENDED
		_overlay.visible = true
		var acc := FlickLogic.calculate_accuracy(_score) * 100.0
		_over_msg.text = "谱面结束\n分数 %d  MaxCombo %d\n准确率 %.1f%%\nP%d G%d Go%d M%d" % [
			int(_score.score), int(_score.max_combo), acc,
			int(_score.perfect), int(_score.great), int(_score.good), int(_score.miss),
		]
		_start_btn.visible = false
		_retry_btn.visible = true
		_pause_btn.text = "暂停"
	_lane.queue_redraw()
	_update_ui()

func _all_judged() -> bool:
	for n in _notes:
		if not n.judged:
			return false
	return true

func _on_kana_gui_input(event: InputEvent, kana: String) -> void:
	if _status != Status.PLAYING:
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_pointer_kana = kana
			_pointer_start = e.global_position
		elif not _pointer_kana.is_empty():
			# Allow release off-button; score against the press kana
			var end_pos := e.global_position
			var dir: String = FlickLogic.detect_flick(_pointer_start.x, _pointer_start.y, end_pos.x, end_pos.y)
			var press_kana := _pointer_kana
			_pointer_kana = ""
			if dir.is_empty():
				_feedback = "滑动距离不足"
			else:
				_submit(press_kana, dir)
	elif event is InputEventScreenTouch:
		var e2 := event as InputEventScreenTouch
		if e2.pressed:
			_pointer_kana = kana
			_pointer_start = e2.position
		elif not _pointer_kana.is_empty():
			var dir2: String = FlickLogic.detect_flick(_pointer_start.x, _pointer_start.y, e2.position.x, e2.position.y)
			var press_kana2 := _pointer_kana
			_pointer_kana = ""
			if dir2.is_empty():
				_feedback = "滑动距离不足"
			else:
				_submit(press_kana2, dir2)

func _unhandled_input(event: InputEvent) -> void:
	# Catch mouse release that left the button
	if _status != Status.PLAYING or _pointer_kana.is_empty():
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			var dir: String = FlickLogic.detect_flick(_pointer_start.x, _pointer_start.y, e.global_position.x, e.global_position.y)
			var press_kana := _pointer_kana
			_pointer_kana = ""
			if dir.is_empty():
				_feedback = "滑动距离不足"
			else:
				_submit(press_kana, dir)

func _submit(kana: String, direction: String) -> void:
	var result: Dictionary = FlickLogic.judge_input(_notes, kana, direction, _now_ms)
	_score = FlickLogic.apply_score(_score, result)
	if bool(result.get("ok", false)):
		var g: String = str(result.grade)
		var gt := "Perfect" if g == "perfect" else ("Great" if g == "great" else "Good")
		_feedback = "%s %s%s" % [gt, kana, FlickConfig.arrow(direction)]
	else:
		var expected: Variant = _next_note()
		if expected != null:
			var ex: Dictionary = expected
			_feedback = "Miss 预期 %s%s" % [ex.kana, FlickConfig.arrow(str(ex.direction))]
		else:
			_feedback = "Miss"
	_lane.queue_redraw()
	_update_ui()

func _next_note() -> Variant:
	for n in _notes:
		if not n.judged:
			return n
	return null

func _status_text() -> String:
	match _status:
		Status.READY:
			return "就绪"
		Status.PLAYING:
			return "游玩中"
		Status.PAUSED:
			return "暂停"
		_:
			return "结束"

func _chart_end_ms() -> int:
	if _notes.is_empty():
		return 0
	return int(_notes[_notes.size() - 1].time_ms)

func _update_ui() -> void:
	var acc := FlickLogic.calculate_accuracy(_score) * 100.0
	_hud.text = "状态：%s  时间 %d/%dms  BPM %d  音符 %d\n分数 %d  连击 %d  Max %d  准确率 %.1f%%\nP:%d G:%d Go:%d M:%d" % [
		_status_text(),
		_now_ms,
		_chart_end_ms(),
		FlickConfig.BPM,
		_notes.size(),
		int(_score.score), int(_score.combo), int(_score.max_combo), acc,
		int(_score.perfect), int(_score.great), int(_score.good), int(_score.miss),
	]
	_feedback_label.text = _feedback
	_pause_btn.disabled = _status != Status.PLAYING and _status != Status.PAUSED
	_reset_btn.disabled = false

func _lane_x(lane: int) -> float:
	var margin := 28.0
	var usable := W - margin * 2.0
	return margin + (float(lane) + 0.5) * (usable / float(LANE_COUNT))

func _draw_lane() -> void:
	var c := _lane
	for i in LANE_COUNT:
		var x := _lane_x(i)
		c.draw_line(Vector2(x, TOP_Y - 10), Vector2(x, HIT_Y + 20), Color(0.75, 0.8, 0.9, 0.35), 1.0)
	c.draw_line(Vector2(16, HIT_Y), Vector2(W - 16, HIT_Y), Color(0.2, 0.7, 0.95), 3.0)
	for n in _notes:
		if n.judged:
			continue
		var delta := int(n.time_ms) - _now_ms
		if delta > FlickConfig.PREVIEW_WINDOW_MS or delta < -FlickConfig.MISS_MS:
			continue
		var t := float(delta) / FlickConfig.SCROLL_WINDOW_MS
		var y := HIT_Y - t * (HIT_Y - TOP_Y)
		var lane := FlickLogic.kana_lane(str(n.kana))
		var x2 := _lane_x(lane)
		var col := Color(0.98, 0.45, 0.75) if delta >= -FlickConfig.GOOD_MS else Color(0.6, 0.6, 0.65, 0.5)
		c.draw_circle(Vector2(x2, y), 20, col)
		c.draw_string(ThemeDB.fallback_font, Vector2(x2 - 10, y + 6), str(n.kana), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		c.draw_string(ThemeDB.fallback_font, Vector2(x2 + 12, y + 6), FlickConfig.arrow(str(n.direction)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 1, 1))
