extends Node
class_name PerformanceLab

signal recording_started
signal recording_stopped(summary: Dictionary)
signal spike_detected(spike_info: Dictionary)
signal warmup_completed(results: Dictionary)

static var instance: PerformanceLab = null

# ── Live Tracking State ───────────────────────────────────────────────────────
var is_recording: bool = false
var record_time: float = 0.0
var frame_counter: int = 0

var rolling_frame_times: Array[float] = []
const ROLLING_WINDOW_SIZE: int = 30
var rolling_avg_ms: float = 16.6

# ── Current Run Data ─────────────────────────────────────────────────────────
var current_frame_times: Array[float] = []
var current_spikes: Array[Dictionary] = []
var current_markers: Array[Dictionary] = []
var current_marker_name: String = "BASELINE"
var marker_active_time: float = 0.0

var first_seen_events: Dictionary = {}

# ── Comparison State ─────────────────────────────────────────────────────────
var last_benchmark: Dictionary = {}
var previous_benchmark: Dictionary = {}

# ── Shader Warmup Scenes ─────────────────────────────────────────────────────
const WARMUP_SCENE_PATHS: Array[String] = [
	"res://scenes/effects/GovernmentPigeonHit.tscn",
	"res://scenes/effects/NormalPigeonHit.tscn",
	"res://scenes/effects/GovernmentPigeonPlayerExplosion.tscn",
	"res://scenes/effects/BulletTracer.tscn",
	"res://scenes/pigeons/GovernmentPigeon.tscn",
	"res://scenes/pigeons/NormalPigeon.tscn",
	"res://scenes/objects/PackageDrone.tscn",
	"res://scenes/objects/GuidedMissile.tscn",
	"res://scenes/objects/UFO.tscn"
]

func _init() -> void:
	instance = self

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_load_previous_benchmark()

func _process(delta: float) -> void:
	frame_counter += 1
	var raw_frame_time_ms = delta * 1000.0

	# Update rolling average
	rolling_frame_times.append(raw_frame_time_ms)
	if rolling_frame_times.size() > ROLLING_WINDOW_SIZE:
		rolling_frame_times.pop_front()

	var sum: float = 0.0
	for ft in rolling_frame_times:
		sum += ft
	rolling_avg_ms = sum / max(1, rolling_frame_times.size())

	# Spike Detection (Jump >= 14ms above rolling avg or absolute >= 28ms)
	if (raw_frame_time_ms - rolling_avg_ms >= 14.0) or (raw_frame_time_ms >= 28.0 and raw_frame_time_ms > rolling_avg_ms * 1.5):
		_handle_spike(rolling_avg_ms, raw_frame_time_ms)

	# Recording Tick
	if is_recording:
		record_time += delta
		current_frame_times.append(raw_frame_time_ms)

func _handle_spike(before_ms: float, peak_ms: float) -> void:
	var is_first_use = false
	if current_marker_name != "BASELINE" and not first_seen_events.has(current_marker_name):
		first_seen_events[current_marker_name] = true
		is_first_use = true

	var spike = {
		"time": record_time if is_recording else (Time.get_ticks_msec() / 1000.0),
		"frame": frame_counter,
		"before_ms": snapped(before_ms, 0.1),
		"peak_ms": snapped(peak_ms, 0.1),
		"marker": current_marker_name,
		"is_first_use": is_first_use
	}

	if is_recording:
		current_spikes.append(spike)

	spike_detected.emit(spike)

# ── Test Markers ─────────────────────────────────────────────────────────────
func set_marker(marker_name: String) -> void:
	current_marker_name = marker_name
	marker_active_time = record_time

	if is_recording:
		current_markers.append({
			"time": snapped(record_time, 0.01),
			"frame": frame_counter,
			"name": marker_name
		})

# ── Recording Controls ───────────────────────────────────────────────────────
func start_recording() -> void:
	is_recording = true
	record_time = 0.0
	current_frame_times.clear()
	current_spikes.clear()
	current_markers.clear()
	current_marker_name = "BASELINE"
	set_marker("BASELINE")
	recording_started.emit()

func stop_recording() -> Dictionary:
	if not is_recording:
		return last_benchmark

	is_recording = false
	var summary = _calculate_benchmark_summary(current_frame_times, current_spikes, current_markers)

	# Shift last -> previous, current -> last
	if not last_benchmark.is_empty():
		previous_benchmark = last_benchmark.duplicate(true)
	last_benchmark = summary.duplicate(true)

	_save_benchmark_cache()
	recording_stopped.emit(summary)
	return summary

func _calculate_benchmark_summary(times: Array[float], spikes: Array[Dictionary], markers: Array[Dictionary]) -> Dictionary:
	if times.is_empty():
		return {
			"avg_fps": 0.0,
			"low_1_percent_fps": 0.0,
			"min_fps": 0.0,
			"avg_frame_time_ms": 0.0,
			"worst_frame_time_ms": 0.0,
			"total_frames": 0,
			"duration_sec": 0.0,
			"spikes": [],
			"markers": []
		}

	var total_frames = times.size()
	var total_ms: float = 0.0
	var max_ft: float = 0.0

	for ft in times:
		total_ms += ft
		if ft > max_ft:
			max_ft = ft

	var avg_ft = total_ms / float(total_frames)
	var avg_fps = 1000.0 / avg_ft if avg_ft > 0.0 else 0.0
	var min_fps = 1000.0 / max_ft if max_ft > 0.0 else 0.0

	# 1% Low FPS Calculation
	# Sort frame times descending (worst first), take top 1% worst frames, average them
	var sorted_times = times.duplicate()
	sorted_times.sort_custom(func(a, b): return a > b)

	var count_1_percent = max(1, int(float(total_frames) * 0.01))
	var sum_1_percent_ms: float = 0.0
	for i in range(count_1_percent):
		sum_1_percent_ms += sorted_times[i]

	var avg_1_percent_ft = sum_1_percent_ms / float(count_1_percent)
	var low_1_percent_fps = 1000.0 / avg_1_percent_ft if avg_1_percent_ft > 0.0 else 0.0

	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"avg_fps": snapped(avg_fps, 0.1),
		"low_1_percent_fps": snapped(low_1_percent_fps, 0.1),
		"min_fps": snapped(min_fps, 0.1),
		"avg_frame_time_ms": snapped(avg_ft, 0.2),
		"worst_frame_time_ms": snapped(max_ft, 0.2),
		"total_frames": total_frames,
		"duration_sec": snapped(record_time, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"ram_mb": snapped(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"vram_mb": snapped(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"spikes": spikes.duplicate(true),
		"markers": markers.duplicate(true)
	}

# ── Shader / Pipeline Warmup ─────────────────────────────────────────────────
func run_shader_warmup() -> Dictionary:
	var start_ticks = Time.get_ticks_msec()
	var detected_count: int = 0
	var warmed_count: int = 0

	# Create a dedicated off-screen SubViewport so shaders are dispatched to GPU
	var warmup_vp = SubViewport.new()
	warmup_vp.size = Vector2i(128, 128)
	warmup_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(warmup_vp)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 5)
	warmup_vp.add_child(cam)

	var root_3d = Node3D.new()
	warmup_vp.add_child(root_3d)

	for path in WARMUP_SCENE_PATHS:
		if ResourceLoader.exists(path):
			detected_count += 1
			var scene: PackedScene = load(path)
			if scene:
				var instance_node = scene.instantiate()
				if instance_node:
					root_3d.add_child(instance_node)
					if instance_node is Node3D:
						instance_node.position = Vector3(0, 0, 0)
					warmed_count += 1

	# Force rendering server to sync and compile pipelines
	RenderingServer.force_draw(true)

	var elapsed_sec = (Time.get_ticks_msec() - start_ticks) / 1000.0

	# Clean up warmup viewport
	warmup_vp.queue_free()

	var results = {
		"detected": detected_count,
		"compiled": warmed_count,
		"time_sec": snapped(elapsed_sec, 0.01)
	}

	warmup_completed.emit(results)
	return results

# ── Report Export ────────────────────────────────────────────────────────────
func export_report() -> String:
	var benchmark_data = last_benchmark if not last_benchmark.is_empty() else _calculate_benchmark_summary(rolling_frame_times, [], [])

	var dir_path = "user://perf_reports"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var json_path = "%s/perf_report_%s.json" % [dir_path, timestamp]
	var txt_path = "%s/perf_report_%s.txt" % [dir_path, timestamp]

	var hardware_info = {
		"os": OS.get_name(),
		"processor": OS.get_processor_name() if OS.has_method("get_processor_name") else "Unknown",
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"viewport_size": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	}

	var full_report = {
		"hardware": hardware_info,
		"graphics_settings": {
			"difficulty": SettingsManager.current_difficulty,
			"fov": SettingsManager.field_of_view,
			"fog_enabled": SettingsManager.distance_fog_enabled,
			"vsync": SettingsManager.vsync_enabled,
			"fps_cap": SettingsManager.fps_cap
		},
		"benchmark": benchmark_data,
		"previous_benchmark": previous_benchmark
	}

	# Write JSON
	var f_json = FileAccess.open(json_path, FileAccess.WRITE)
	if f_json:
		f_json.store_string(JSON.stringify(full_report, "\t"))
		f_json.close()

	# Write Human-Readable Text Summary
	var f_txt = FileAccess.open(txt_path, FileAccess.WRITE)
	if f_txt:
		f_txt.store_line("==================================================")
		f_txt.store_line("🎯 GOVERNMENT PIGEONS - PERFORMANCE LAB REPORT")
		f_txt.store_line("==================================================")
		f_txt.store_line("Timestamp:       %s" % benchmark_data.get("timestamp", "N/A"))
		f_txt.store_line("GPU:             %s (%s)" % [hardware_info.video_adapter, hardware_info.video_vendor])
		f_txt.store_line("OS / Processor:  %s | %s" % [hardware_info.os, hardware_info.processor])
		f_txt.store_line("Engine / Res:    %s | %s" % [hardware_info.godot_version, hardware_info.viewport_size])
		f_txt.store_line("--------------------------------------------------")
		f_txt.store_line("📊 FPS & TIMINGS:")
		f_txt.store_line("  Average FPS:       %.1f FPS" % benchmark_data.get("avg_fps", 0.0))
		f_txt.store_line("  1%% Low FPS:        %.1f FPS (Stutter Metric)" % benchmark_data.get("low_1_percent_fps", 0.0))
		f_txt.store_line("  Minimum FPS:       %.1f FPS" % benchmark_data.get("min_fps", 0.0))
		f_txt.store_line("  Avg Frame Time:    %.2f ms" % benchmark_data.get("avg_frame_time_ms", 0.0))
		f_txt.store_line("  Worst Frame Time:  %.2f ms" % benchmark_data.get("worst_frame_time_ms", 0.0))
		f_txt.store_line("--------------------------------------------------")
		f_txt.store_line("📦 RENDER & MEMORY:")
		f_txt.store_line("  Draw Calls:        %d" % benchmark_data.get("draw_calls", 0))
		f_txt.store_line("  RAM Used:          %.1f MB" % benchmark_data.get("ram_mb", 0.0))
		f_txt.store_line("  VRAM Used:         %.1f MB" % benchmark_data.get("vram_mb", 0.0))
		f_txt.store_line("--------------------------------------------------")

		var spikes = benchmark_data.get("spikes", [])
		f_txt.store_line("🚨 DETECTED SPIKES (%d total):" % spikes.size())
		if spikes.is_empty():
			f_txt.store_line("  No significant frame spikes detected! (Solid performance)")
		else:
			for s in spikes:
				var first_flag = " [FIRST-USE / SHADER COMPILATION HITCH]" if s.get("is_first_use", false) else ""
				f_txt.store_line("  • At %.2fs (Frame %d): %.1fms -> %.1fms [%s]%s" % [
					s.get("time", 0.0),
					s.get("frame", 0),
					s.get("before_ms", 0.0),
					s.get("peak_ms", 0.0),
					s.get("marker", "UNKNOWN"),
					first_flag
				])

		f_txt.store_line("==================================================")
		f_txt.close()

	return json_path

# ── Persistence ──────────────────────────────────────────────────────────────
func _save_benchmark_cache() -> void:
	var path = "user://perf_previous_run.json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(last_benchmark))
		f.close()

func _load_previous_benchmark() -> void:
	var path = "user://perf_previous_run.json"
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		if f:
			var text = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				previous_benchmark = parsed