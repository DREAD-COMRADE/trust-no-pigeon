extends CanvasLayer
class_name PerformanceLabHUD

@onready var live_pill: PanelContainer = $LivePill
@onready var live_label: Label = $LivePill/Margin/LiveLabel

@onready var lab_panel: PanelContainer = $LabPanel
@onready var close_btn: Button = $LabPanel/Margin/VBox/Header/CloseBtn

# Recording Controls
@onready var btn_record_toggle: Button = $LabPanel/Margin/VBox/ControlsHBox/BtnRecordToggle
@onready var record_status_label: Label = $LabPanel/Margin/VBox/ControlsHBox/RecordStatusLabel
@onready var btn_warmup: Button = $LabPanel/Margin/VBox/ControlsHBox/BtnWarmup
@onready var btn_export: Button = $LabPanel/Margin/VBox/ControlsHBox/BtnExport

# Stats Display
@onready var stats_grid_label: RichTextLabel = $LabPanel/Margin/VBox/StatsSection/StatsText
@onready var spikes_log_label: RichTextLabel = $LabPanel/Margin/VBox/SpikeSection/SpikesText
@onready var export_status_label: Label = $LabPanel/Margin/VBox/ExportStatusLabel

# Markers & Stress Buttons
@onready var btn_m_baseline: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnBaseline
@onready var btn_m_spawn20: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnSpawn20
@onready var btn_m_spawn100: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnSpawn100
@onready var btn_m_explosion: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnExplosion
@onready var btn_m_drone: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnDrone
@onready var btn_m_night: Button = $LabPanel/Margin/VBox/StressSection/Grid/BtnNight

var perf_lab: PerformanceLab = null
var update_timer: float = 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	# Ensure PerformanceLab node exists
	perf_lab = PerformanceLab.instance
	if not perf_lab:
		perf_lab = PerformanceLab.new()
		perf_lab.name = "PerformanceLabEngine"
		add_child(perf_lab)

	perf_lab.recording_started.connect(_on_recording_started)
	perf_lab.recording_stopped.connect(_on_recording_stopped)
	perf_lab.spike_detected.connect(_on_spike_detected)
	perf_lab.warmup_completed.connect(_on_warmup_completed)

	if close_btn:
		close_btn.pressed.connect(func(): lab_panel.visible = false)

	if btn_record_toggle:
		btn_record_toggle.pressed.connect(_on_toggle_record_pressed)

	if btn_warmup:
		btn_warmup.pressed.connect(func(): perf_lab.run_shader_warmup())

	if btn_export:
		btn_export.pressed.connect(_on_export_pressed)

	# Marker buttons
	if btn_m_baseline: btn_m_baseline.pressed.connect(func(): perf_lab.set_marker("BASELINE"))
	if btn_m_spawn20: btn_m_spawn20.pressed.connect(func(): _stress_spawn_pigeons(20))
	if btn_m_spawn100: btn_m_spawn100.pressed.connect(func(): _stress_spawn_pigeons(100))
	if btn_m_explosion: btn_m_explosion.pressed.connect(_stress_trigger_explosion)
	if btn_m_drone: btn_m_drone.pressed.connect(_stress_spawn_drone)
	if btn_m_night: btn_m_night.pressed.connect(_stress_toggle_night)

	live_pill.visible = true
	lab_panel.visible = false

	_update_comparison_display()

	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			live_pill.visible = !live_pill.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			toggle_lab_panel()
			get_viewport().set_input_as_handled()

func toggle_lab_panel() -> void:
	lab_panel.visible = !lab_panel.visible
	if lab_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_comparison_display()

func _process(delta: float) -> void:
	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = 0.1 # 10Hz live update
		_update_live_hud()

	if perf_lab and perf_lab.is_recording and record_status_label:
		record_status_label.text = "🔴 RECORDING [%.1fs] | Current Marker: [%s]" % [perf_lab.record_time, perf_lab.current_marker_name]

func _update_live_hud() -> void:
	if not live_pill.visible or not live_label:
		return

	var fps = int(Performance.get_monitor(Performance.TIME_FPS))
	var ft_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var cpu_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mem_mb = int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	var vram_mb = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	var objs = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var fps_color = "#44ff88" if fps >= 58 else ("#ffcc00" if fps >= 30 else "#ff4444")
	live_label.text = "FPS: %d (%.1fms) | CPU: %.1fms | Draw: %d | RAM: %dMB | VRAM: %dMB | Objs: %d" % [
		fps, ft_ms, cpu_ms, draw_calls, mem_mb, vram_mb, objs
	]
	live_label.modulate = Color(fps_color)

func _on_toggle_record_pressed() -> void:
	if not perf_lab:
		return
	if perf_lab.is_recording:
		perf_lab.stop_recording()
	else:
		perf_lab.start_recording()

func _on_recording_started() -> void:
	if btn_record_toggle:
		btn_record_toggle.text = "⏹ STOP BENCHMARK"
		btn_record_toggle.modulate = Color(1.0, 0.4, 0.4, 1.0)
	if spikes_log_label:
		spikes_log_label.text = "[color=#888888]Live Spike Log initialized...[/color]\n"

func _on_recording_stopped(_summary: Dictionary) -> void:
	if btn_record_toggle:
		btn_record_toggle.text = "⏺ START BENCHMARK (10-30s)"
		btn_record_toggle.modulate = Color(0.3, 0.9, 1.0, 1.0)
	if record_status_label:
		record_status_label.text = "Benchmark Complete ✅"
	_update_comparison_display()

func _on_spike_detected(s: Dictionary) -> void:
	if not spikes_log_label:
		return
	var first_tag = " [color=#ffcc00][b]⚠ FIRST-USE / SHADER COMPILATION HITCH[/b][/color]" if s.get("is_first_use", false) else ""
	var line = "[color=#ff4444]🔴 Frame Spike:[/color] [b]%.1fms ➔ %.1fms[/b] (at %.2fs, frame %d) [%s]%s\n" % [
		s.get("before_ms", 0.0),
		s.get("peak_ms", 0.0),
		s.get("time", 0.0),
		s.get("frame", 0),
		s.get("marker", "IDLE"),
		first_tag
	]
	spikes_log_label.append_text(line)

func _on_warmup_completed(res: Dictionary) -> void:
	if export_status_label:
		export_status_label.text = "Shader Warmup Complete: %d pipelines compiled in %.2fs ✅" % [res.get("compiled", 0), res.get("time_sec", 0.0)]
		export_status_label.modulate = Color(0.3, 1.0, 0.4, 1.0)

func _on_export_pressed() -> void:
	if not perf_lab:
		return
	var path = perf_lab.export_report()
	if export_status_label:
		export_status_label.text = "Report exported to: %s" % path
		export_status_label.modulate = Color(0.3, 1.0, 0.5, 1.0)

func _update_comparison_display() -> void:
	if not stats_grid_label or not perf_lab:
		return

	var cur = perf_lab.last_benchmark
	var prev = perf_lab.previous_benchmark

	if cur.is_empty():
		stats_grid_label.text = "[color=#aaaaaa]No benchmark recorded yet. Click [b]Start Benchmark[/b] to record a 10-30s run![/color]"
		return

	var cur_fps = cur.get("avg_fps", 0.0)
	var prev_fps = prev.get("avg_fps", 0.0)
	var cur_low = cur.get("low_1_percent_fps", 0.0)
	var prev_low = prev.get("low_1_percent_fps", 0.0)
	var cur_ft = cur.get("avg_frame_time_ms", 0.0)
	var prev_ft = prev.get("avg_frame_time_ms", 0.0)
	var cur_worst = cur.get("worst_frame_time_ms", 0.0)
	var prev_worst = prev.get("worst_frame_time_ms", 0.0)
	var cur_draw = cur.get("draw_calls", 0)
	var prev_draw = prev.get("draw_calls", 0)
	var cur_ram = cur.get("ram_mb", 0.0)
	var prev_ram = prev.get("ram_mb", 0.0)

	var text = "[table=4]"
	text += "[cell][b]METRIC[/b][/cell][cell][b]CURRENT[/b][/cell][cell][b]PREVIOUS[/b][/cell][cell][b]CHANGE[/b][/cell]"

	text += _format_row("Average FPS", "%.1f FPS" % cur_fps, "%.1f FPS" % prev_fps, cur_fps - prev_fps, true)
	text += _format_row("1% Low FPS (Stutter)", "%.1f FPS" % cur_low, "%.1f FPS" % prev_low, cur_low - prev_low, true)
	text += _format_row("Avg Frame Time", "%.2f ms" % cur_ft, "%.2f ms" % prev_ft, -(cur_ft - prev_ft), true)
	text += _format_row("Worst Frame Spike", "%.2f ms" % cur_worst, "%.2f ms" % prev_worst, -(cur_worst - prev_worst), true)
	text += _format_row("Draw Calls", "%d" % cur_draw, "%d" % prev_draw, -(cur_draw - prev_draw), true)
	text += _format_row("RAM Memory", "%.1f MB" % cur_ram, "%.1f MB" % prev_ram, -(cur_ram - prev_ram), true)
	text += "[/table]"

	stats_grid_label.text = text

func _format_row(metric_name: String, cur_str: String, prev_str: String, diff: float, higher_is_better: bool) -> String:
	var diff_str = ""
	var color = "#cccccc"

	if prev_str.begins_with("0.0") or prev_str.begins_with("0"):
		diff_str = "Baseline"
	else:
		if abs(diff) < 0.1:
			diff_str = "— 0.0"
			color = "#ffffff"
		elif (diff > 0 and higher_is_better) or (diff < 0 and not higher_is_better):
			diff_str = "+%.1f 🟢" % abs(diff)
			color = "#44ff88"
		else:
			diff_str = "-%.1f 🔴" % abs(diff)
			color = "#ff5555"

	return "[cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][cell][color=%s]%s[/color][/cell]" % [
		metric_name, cur_str, prev_str, color, diff_str
	]

# ── Stress Testing Action Helpers ────────────────────────────────────────────
func _stress_spawn_pigeons(count: int) -> void:
	perf_lab.set_marker("SPAWN_%d_PIGEONS" % count)
	var main = get_tree().current_scene
	if main and main.has_node("Systems/PigeonSpawner"):
		var spawner = main.get_node("Systems/PigeonSpawner")
		if spawner and spawner.has_method("spawn_flock"):
			spawner.spawn_flock(count, int(count * 0.3))

func _stress_trigger_explosion() -> void:
	perf_lab.set_marker("EXPLOSION")
	var hit_scene = preload("res://scenes/effects/GovernmentPigeonPlayerExplosion.tscn")
	if hit_scene:
		var fx = hit_scene.instantiate()
		var scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
		scene.add_child(fx)
		var cam = get_viewport().get_camera_3d()
		if cam:
			fx.global_position = cam.global_position + (-cam.global_transform.basis.z * 4.0)

func _stress_spawn_drone() -> void:
	perf_lab.set_marker("SPAWN_DRONE")
	var main = get_tree().current_scene
	if main and main.has_node("Systems/EventManager"):
		var em = main.get_node("Systems/EventManager")
		if em and em.has_method("trigger_event"):
			em.trigger_event("Supply drone drop")

func _stress_toggle_night() -> void:
	perf_lab.set_marker("NIGHT_MODE")
	var main = get_tree().current_scene
	if main and main.has_node("Systems/DayNightManager"):
		var dnm = main.get_node("Systems/DayNightManager")
		if dnm and dnm.has_method("set_starting_phase"):
			dnm.set_starting_phase(15.0 / 30.0 + 0.01)