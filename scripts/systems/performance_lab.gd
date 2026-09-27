extends Node
class_name PerformanceLab

# ═══════════════════════════════════════════════════════════════════════════════
# ⚡ PERFORMANCE LAB V1 (GODOT 4.7 CPU SUBSYSTEM, FUNCTION PROFILER & GPU)
#
# TIMING & SUBSYSTEM DEFINITIONS:
# - Total Frame Time: Full frame duration in ms (wall-clock delta).
# - CPU Frame Time: Total CPU frame execution time.
#   ├─ Physics Time: TIME_PHYSICS_PROCESS (physics tick, raycasts, collisions).
#   ├─ Scripts / Game Loop: TIME_PROCESS (GDScript _process callbacks & node logic).
#   ├─ Render Prep / CPU Render: viewport_get_measured_render_time_cpu + get_frame_setup_time_cpu
#   │  (scene traversal, culling, batching, GPU draw command recording).
#   ├─ Animation Time: Folded into TIME_PROCESS in Godot 4.7 engine core; marked N/A / null.
#   └─ Other Time: OS input polling, audio mix tick, frame sync.
# - GPU Frame Time: Hardware GPU execution time via viewport_get_measured_render_time_gpu.
# - Function-Level CPU Scope Profiling: Microsecond instrumentation via Profiler.begin_scope / end_scope.
# ═══════════════════════════════════════════════════════════════════════════════

signal recording_started
signal recording_stopped(summary: Dictionary)
signal spike_detected(spike_info: Dictionary)
signal warmup_completed(results: Dictionary)
signal profiling_toggled(is_enabled: bool)

static var instance: PerformanceLab = null

# ── Viewport Timing Handle ───────────────────────────────────────────────────
var _main_vp_rid: RID = RID()
var is_gpu_timing_available: bool = false
var _gpu_check_frames: int = 0

# ── Live Metrics Cache ────────────────────────────────────────────────────────
var live_fps: float = 60.0
var live_frame_time_ms: float = 16.6
var live_cpu_frame_time_ms: float = 4.0
var live_gpu_frame_time_ms: float = 0.0

# Subsystem Live Breakdown (in ms)
var live_cpu_physics_ms: float = 0.0
var live_cpu_scripts_ms: float = 0.0
var live_cpu_render_prep_ms: float = 0.0
var live_cpu_animation_ms: Variant = null
var live_cpu_other_ms: float = 0.0

# ── Function-Level Scope Profiling State ─────────────────────────────────────
var is_scope_profiling_enabled: bool = false
var _scope_start_times: Dictionary = {} # scope_name -> int (usec)
var _scope_data: Dictionary = {}        # scope_name -> { "calls": int, "total_usec": int, "worst_usec": int }
var _frame_scope_data: Dictionary = {}  # scope_name -> int (usec spent in current frame)

# ── 300-Frame Ring Buffers (Zero Allocations Per Frame) ────────────────────────
const HISTORY_CAPACITY: int = 300
var history_frame_time: PackedFloat32Array = PackedFloat32Array()
var history_cpu_time: PackedFloat32Array = PackedFloat32Array()
var history_gpu_time: PackedFloat32Array = PackedFloat32Array()
var history_physics_time: PackedFloat32Array = PackedFloat32Array()
var history_scripts_time: PackedFloat32Array = PackedFloat32Array()
var history_render_prep_time: PackedFloat32Array = PackedFloat32Array()

var history_head: int = 0
var history_count: int = 0

var rolling_avg_ms: float = 16.6
var rolling_cpu_avg_ms: float = 4.0
var rolling_gpu_avg_ms: float = 0.0

# ── Recording State ──────────────────────────────────────────────────────────
var is_recording: bool = false
var record_time: float = 0.0
var frame_counter: int = 0

# Benchmark Sample Arrays
var rec_frame_times: Array[float] = []
var rec_cpu_times: Array[float] = []
var rec_gpu_times: Array[float] = []
var rec_physics_times: Array[float] = []
var rec_scripts_times: Array[float] = []
var rec_render_prep_times: Array[float] = []
var rec_other_times: Array[float] = []
var rec_markers: Array[String] = []
var rec_spikes: Array[Dictionary] = []
var current_marker_name: String = "BASELINE"

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

	history_frame_time.resize(HISTORY_CAPACITY)
	history_cpu_time.resize(HISTORY_CAPACITY)
	history_gpu_time.resize(HISTORY_CAPACITY)
	history_physics_time.resize(HISTORY_CAPACITY)
	history_scripts_time.resize(HISTORY_CAPACITY)
	history_render_prep_time.resize(HISTORY_CAPACITY)

	history_frame_time.fill(16.6)
	history_cpu_time.fill(4.0)
	history_gpu_time.fill(0.0)
	history_physics_time.fill(0.0)
	history_scripts_time.fill(2.0)
	history_render_prep_time.fill(2.0)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	var vp = get_viewport()
	if vp:
		_main_vp_rid = vp.get_viewport_rid()
		if _main_vp_rid.is_valid():
			RenderingServer.viewport_set_measure_render_time(_main_vp_rid, true)

	_load_previous_benchmark()

# ── Function Scope Profiling Internals ───────────────────────────────────────
static func begin_scope(scope_name: String) -> void:
	if instance and instance.is_scope_profiling_enabled:
		instance._scope_start_times[scope_name] = Time.get_ticks_usec()

static func end_scope(scope_name: String) -> void:
	if instance and instance.is_scope_profiling_enabled:
		var end_time = Time.get_ticks_usec()
		var start_time = instance._scope_start_times.get(scope_name, -1)
		if start_time >= 0:
			instance._record_scope_elapsed(scope_name, end_time - start_time)

func _record_scope_elapsed(scope_name: String, elapsed_usec: int) -> void:
	var data = _scope_data.get(scope_name)
	if not data:
		data = { "calls": 0, "total_usec": 0, "worst_usec": 0 }
		_scope_data[scope_name] = data

	data["calls"] += 1
	data["total_usec"] += elapsed_usec
	if elapsed_usec > data["worst_usec"]:
		data["worst_usec"] = elapsed_usec

	_frame_scope_data[scope_name] = _frame_scope_data.get(scope_name, 0) + elapsed_usec

func set_scope_profiling_enabled(enabled: bool) -> void:
	is_scope_profiling_enabled = enabled
	if not enabled:
		_scope_start_times.clear()
	profiling_toggled.emit(enabled)

func reset_scope_data() -> void:
	_scope_data.clear()
	_scope_start_times.clear()
	_frame_scope_data.clear()

# ── Frame Processing ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	frame_counter += 1

	var raw_ft_ms = delta * 1000.0

	var scripts_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var cpu_render_ms = 0.0
	var cpu_setup_ms = 0.0
	if _main_vp_rid.is_valid():
		cpu_render_ms = RenderingServer.viewport_get_measured_render_time_cpu(_main_vp_rid)
		cpu_setup_ms = RenderingServer.get_frame_setup_time_cpu()
	var render_prep_ms = cpu_render_ms + cpu_setup_ms

	var cpu_total_ms = scripts_ms + physics_ms + render_prep_ms
	if cpu_total_ms < 0.01:
		cpu_total_ms = raw_ft_ms * 0.5
		scripts_ms = cpu_total_ms * 0.6
		render_prep_ms = cpu_total_ms * 0.4

	var other_ms = max(0.0, raw_ft_ms - (scripts_ms + physics_ms + render_prep_ms))

	var gpu_ft_ms = 0.0
	if _main_vp_rid.is_valid():
		gpu_ft_ms = RenderingServer.viewport_get_measured_render_time_gpu(_main_vp_rid)

	if gpu_ft_ms > 0.001:
		is_gpu_timing_available = true
	else:
		_gpu_check_frames += 1
		if _gpu_check_frames > 60 and not is_gpu_timing_available:
			is_gpu_timing_available = false

	live_fps = Performance.get_monitor(Performance.TIME_FPS)
	live_frame_time_ms = raw_ft_ms
	live_cpu_frame_time_ms = cpu_total_ms
	live_gpu_frame_time_ms = gpu_ft_ms if is_gpu_timing_available else -1.0

	live_cpu_physics_ms = physics_ms
	live_cpu_scripts_ms = scripts_ms
	live_cpu_render_prep_ms = render_prep_ms
	live_cpu_other_ms = other_ms

	# Update 300-frame ring buffers
	history_frame_time[history_head] = raw_ft_ms
	history_cpu_time[history_head] = cpu_total_ms
	history_gpu_time[history_head] = gpu_ft_ms if is_gpu_timing_available else 0.0
	history_physics_time[history_head] = physics_ms
	history_scripts_time[history_head] = scripts_ms
	history_render_prep_time[history_head] = render_prep_ms

	history_head = (history_head + 1) % HISTORY_CAPACITY
	if history_count < HISTORY_CAPACITY:
		history_count += 1

	var window = min(30, history_count)
	var sum_ft = 0.0
	var sum_cpu = 0.0
	var sum_gpu = 0.0
	for i in range(window):
		var idx = (history_head - 1 - i + HISTORY_CAPACITY) % HISTORY_CAPACITY
		sum_ft += history_frame_time[idx]
		sum_cpu += history_cpu_time[idx]
		sum_gpu += history_gpu_time[idx]
	rolling_avg_ms = sum_ft / max(1, window)
	rolling_cpu_avg_ms = sum_cpu / max(1, window)
	rolling_gpu_avg_ms = sum_gpu / max(1, window)

	# Spike Detection
	if (raw_ft_ms - rolling_avg_ms >= 14.0) or (raw_ft_ms >= 28.0 and raw_ft_ms > rolling_avg_ms * 1.5):
		_handle_spike(rolling_avg_ms, raw_ft_ms, cpu_total_ms, gpu_ft_ms, physics_ms, scripts_ms, render_prep_ms, other_ms)

	# Recording Tick
	if is_recording:
		record_time += delta
		rec_frame_times.append(raw_ft_ms)
		rec_cpu_times.append(cpu_total_ms)
		rec_gpu_times.append(gpu_ft_ms if is_gpu_timing_available else -1.0)
		rec_physics_times.append(physics_ms)
		rec_scripts_times.append(scripts_ms)
		rec_render_prep_times.append(render_prep_ms)
		rec_other_times.append(other_ms)
		rec_markers.append(current_marker_name)

	# Clear per-frame function scope measurements
	_frame_scope_data.clear()

func _handle_spike(before_ms: float, peak_ms: float, cpu_ms: float, gpu_ms: float, physics_ms: float, scripts_ms: float, render_prep_ms: float, other_ms: float) -> void:
	var is_first_use = false
	if current_marker_name != "BASELINE" and not first_seen_events.has(current_marker_name):
		first_seen_events[current_marker_name] = true
		is_first_use = true

	var bottleneck = classify_bottleneck(cpu_ms, gpu_ms if is_gpu_timing_available else -1.0, peak_ms)

	# Capture top profiled functions during this spike frame
	var spike_funcs: Array[Dictionary] = []
	if is_scope_profiling_enabled and not _frame_scope_data.is_empty():
		for s_name in _frame_scope_data.keys():
			spike_funcs.append({
				"name": s_name,
				"time_ms": snapped(_frame_scope_data[s_name] / 1000.0, 0.1)
			})
		spike_funcs.sort_custom(func(a, b): return a["time_ms"] > b["time_ms"])

	var spike = {
		"time": snapped(record_time if is_recording else (Time.get_ticks_msec() / 1000.0), 0.01),
		"frame": frame_counter,
		"marker": current_marker_name,
		"frame_time_ms": snapped(peak_ms, 0.1),
		"before_ms": snapped(before_ms, 0.1),
		"cpu_frame_time_ms": snapped(cpu_ms, 0.1),
		"gpu_frame_time_ms": snapped(gpu_ms, 0.1) if is_gpu_timing_available else null,
		"physics_ms": snapped(physics_ms, 0.1),
		"scripts_ms": snapped(scripts_ms, 0.1),
		"animation_ms": null,
		"render_prep_ms": snapped(render_prep_ms, 0.1),
		"other_ms": snapped(other_ms, 0.1),
		"top_functions": spike_funcs,
		"bottleneck": bottleneck,
		"is_first_use": is_first_use
	}

	if is_recording:
		rec_spikes.append(spike)

	spike_detected.emit(spike)

# ── Automatic Bottleneck Classification ───────────────────────────────────────
func classify_bottleneck(cpu_ms: float, gpu_ms: float, total_ms: float) -> String:
	if not is_gpu_timing_available or gpu_ms < 0.0:
		if cpu_ms >= total_ms * 0.70 or cpu_ms >= 18.0:
			return "CPU BOUND"
		return "UNKNOWN"

	if cpu_ms >= 14.0 and gpu_ms >= 14.0:
		if abs(cpu_ms - gpu_ms) < 4.0:
			return "CPU + GPU"

	if cpu_ms >= gpu_ms * 1.4 and cpu_ms >= 8.0:
		return "CPU BOUND"
	elif gpu_ms >= cpu_ms * 1.4 and gpu_ms >= 8.0:
		return "GPU BOUND"

	if cpu_ms > gpu_ms + 4.0:
		return "CPU BOUND"
	elif gpu_ms > cpu_ms + 4.0:
		return "GPU BOUND"

	return "BALANCED"

# ── Test Markers ─────────────────────────────────────────────────────────────
func set_marker(marker_name: String) -> void:
	current_marker_name = marker_name

# ── Recording Controls ───────────────────────────────────────────────────────
func start_recording() -> void:
	is_recording = true
	record_time = 0.0
	rec_frame_times.clear()
	rec_cpu_times.clear()
	rec_gpu_times.clear()
	rec_physics_times.clear()
	rec_scripts_times.clear()
	rec_render_prep_times.clear()
	rec_other_times.clear()
	rec_markers.clear()
	rec_spikes.clear()
	reset_scope_data()
	current_marker_name = "BASELINE"
	recording_started.emit()

func stop_recording() -> Dictionary:
	if not is_recording:
		return last_benchmark

	is_recording = false
	var summary = _calculate_benchmark_summary()

	if not last_benchmark.is_empty():
		previous_benchmark = last_benchmark.duplicate(true)
	last_benchmark = summary.duplicate(true)

	_save_benchmark_cache()
	recording_stopped.emit(summary)
	return summary

func _calculate_benchmark_summary() -> Dictionary:
	if rec_frame_times.is_empty():
		return {
			"avg_fps": 0.0,
			"low_1_percent_fps": 0.0,
			"min_fps": 0.0,
			"avg_frame_time_ms": 0.0,
			"worst_frame_time_ms": 0.0,
			"cpu_frame_time_avg_ms": 0.0,
			"cpu_frame_time_worst_ms": 0.0,
			"cpu_frame_time_1_percent_low_ms": 0.0,
			"cpu_physics_avg_ms": 0.0,
			"cpu_physics_worst_ms": 0.0,
			"cpu_scripts_avg_ms": 0.0,
			"cpu_scripts_worst_ms": 0.0,
			"cpu_render_prep_avg_ms": 0.0,
			"cpu_render_prep_worst_ms": 0.0,
			"cpu_animation_avg_ms": null,
			"cpu_other_avg_ms": 0.0,
			"cpu_other_worst_ms": 0.0,
			"gpu_frame_time_avg_ms": null,
			"gpu_frame_time_worst_ms": null,
			"gpu_frame_time_1_percent_low_ms": null,
			"total_frames": 0,
			"duration_sec": 0.0,
			"spikes": [],
			"event_summaries": {},
			"function_profiles": {}
		}

	var total_frames = rec_frame_times.size()
	var total_ft: float = 0.0
	var max_ft: float = 0.0

	var total_cpu: float = 0.0
	var max_cpu: float = 0.0

	var total_physics: float = 0.0
	var max_physics: float = 0.0

	var total_scripts: float = 0.0
	var max_scripts: float = 0.0

	var total_render_prep: float = 0.0
	var max_render_prep: float = 0.0

	var total_other: float = 0.0
	var max_other: float = 0.0

	var total_gpu: float = 0.0
	var max_gpu: float = 0.0
	var valid_gpu_count: int = 0

	for i in range(total_frames):
		var ft = rec_frame_times[i]
		var cpu = rec_cpu_times[i]
		var gpu = rec_gpu_times[i]
		var phys = rec_physics_times[i]
		var sc = rec_scripts_times[i]
		var rp = rec_render_prep_times[i]
		var oth = rec_other_times[i]

		total_ft += ft
		if ft > max_ft: max_ft = ft

		total_cpu += cpu
		if cpu > max_cpu: max_cpu = cpu

		total_physics += phys
		if phys > max_physics: max_physics = phys

		total_scripts += sc
		if sc > max_scripts: max_scripts = sc

		total_render_prep += rp
		if rp > max_render_prep: max_render_prep = rp

		total_other += oth
		if oth > max_other: max_other = oth

		if gpu >= 0.0:
			total_gpu += gpu
			if gpu > max_gpu: max_gpu = gpu
			valid_gpu_count += 1

	var avg_ft = total_ft / float(total_frames)
	var avg_fps = 1000.0 / avg_ft if avg_ft > 0.0 else 0.0
	var min_fps = 1000.0 / max_ft if max_ft > 0.0 else 0.0

	var avg_cpu = total_cpu / float(total_frames)
	var avg_physics = total_physics / float(total_frames)
	var avg_scripts = total_scripts / float(total_frames)
	var avg_render_prep = total_render_prep / float(total_frames)
	var avg_other = total_other / float(total_frames)

	# 1% Low Calculations
	var count_1_pct = max(1, int(float(total_frames) * 0.01))

	var sorted_ft = rec_frame_times.duplicate()
	sorted_ft.sort_custom(func(a, b): return a > b)
	var sum_1_pct_ft = 0.0
	for i in range(count_1_pct):
		sum_1_pct_ft += sorted_ft[i]
	var low_1_percent_fps = 1000.0 / (sum_1_pct_ft / float(count_1_pct)) if count_1_pct > 0 else 0.0

	var sorted_cpu = rec_cpu_times.duplicate()
	sorted_cpu.sort_custom(func(a, b): return a > b)
	var sum_1_pct_cpu = 0.0
	for i in range(count_1_pct):
		sum_1_pct_cpu += sorted_cpu[i]
	var cpu_1_pct_worst = sum_1_pct_cpu / float(count_1_pct)

	var avg_gpu_val = null
	var worst_gpu_val = null
	var gpu_1_pct_worst_val = null

	if is_gpu_timing_available and valid_gpu_count > 0:
		avg_gpu_val = snapped(total_gpu / float(valid_gpu_count), 0.2)
		worst_gpu_val = snapped(max_gpu, 0.2)

		var sorted_gpu = []
		for g in rec_gpu_times:
			if g >= 0.0: sorted_gpu.append(g)
		sorted_gpu.sort_custom(func(a, b): return a > b)

		var gpu_count_1_pct = max(1, int(float(sorted_gpu.size()) * 0.01))
		var sum_1_pct_gpu = 0.0
		for i in range(gpu_count_1_pct):
			sum_1_pct_gpu += sorted_gpu[i]
		gpu_1_pct_worst_val = snapped(sum_1_pct_gpu / float(gpu_count_1_pct), 0.2)

	# Event Performance Summary Breakdown
	var event_groups: Dictionary = {}
	for i in range(total_frames):
		var m_name = rec_markers[i] if i < rec_markers.size() else "BASELINE"
		if not event_groups.has(m_name):
			event_groups[m_name] = []
		event_groups[m_name].append(i)

	var event_summaries: Dictionary = {}
	for m_name in event_groups.keys():
		var indices: Array = event_groups[m_name]
		var e_total_ft = 0.0
		var e_total_cpu = 0.0
		var e_total_phys = 0.0
		var e_total_sc = 0.0
		var e_total_rp = 0.0
		var e_total_oth = 0.0
		var e_total_gpu = 0.0
		var e_gpu_count = 0

		for idx in indices:
			e_total_ft += rec_frame_times[idx]
			e_total_cpu += rec_cpu_times[idx]
			e_total_phys += rec_physics_times[idx]
			e_total_sc += rec_scripts_times[idx]
			e_total_rp += rec_render_prep_times[idx]
			e_total_oth += rec_other_times[idx]

			var g_val = rec_gpu_times[idx]
			if g_val >= 0.0:
				e_total_gpu += g_val
				e_gpu_count += 1

		var e_avg_ft = e_total_ft / float(indices.size())
		var e_avg_cpu = e_total_cpu / float(indices.size())
		var e_avg_phys = e_total_phys / float(indices.size())
		var e_avg_sc = e_total_sc / float(indices.size())
		var e_avg_rp = e_total_rp / float(indices.size())
		var e_avg_oth = e_total_oth / float(indices.size())
		var e_avg_gpu = (e_total_gpu / float(e_gpu_count)) if (is_gpu_timing_available and e_gpu_count > 0) else null

		var e_bottleneck = classify_bottleneck(e_avg_cpu, e_avg_gpu if e_avg_gpu != null else -1.0, e_avg_ft)

		event_summaries[m_name] = {
			"samples": indices.size(),
			"avg_frame_time_ms": snapped(e_avg_ft, 0.2),
			"cpu_frame_time_ms": snapped(e_avg_cpu, 0.2),
			"physics_ms": snapped(e_avg_phys, 0.2),
			"scripts_ms": snapped(e_avg_sc, 0.2),
			"animation_ms": null,
			"render_prep_ms": snapped(e_avg_rp, 0.2),
			"other_ms": snapped(e_avg_oth, 0.2),
			"gpu_frame_time_ms": snapped(e_avg_gpu, 0.2) if e_avg_gpu != null else null,
			"bottleneck": e_bottleneck
		}

	# ── Function Profiles Summary Calculation ────────────────────────────────
	var function_profiles: Dictionary = {}
	for s_name in _scope_data.keys():
		var d = _scope_data[s_name]
		var calls = d.get("calls", 0)
		var total_ms = d.get("total_usec", 0) / 1000.0
		var worst_ms = d.get("worst_usec", 0) / 1000.0
		var avg_ms = (total_ms / float(calls)) if calls > 0 else 0.0

		function_profiles[s_name] = {
			"calls": calls,
			"total_ms": snapped(total_ms, 0.2),
			"average_ms": snapped(avg_ms, 0.3),
			"worst_ms": snapped(worst_ms, 0.2)
		}

	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"avg_fps": snapped(avg_fps, 0.1),
		"low_1_percent_fps": snapped(low_1_percent_fps, 0.1),
		"min_fps": snapped(min_fps, 0.1),
		"avg_frame_time_ms": snapped(avg_ft, 0.2),
		"worst_frame_time_ms": snapped(max_ft, 0.2),
		"cpu_frame_time_avg_ms": snapped(avg_cpu, 0.2),
		"cpu_frame_time_worst_ms": snapped(max_cpu, 0.2),
		"cpu_frame_time_1_percent_low_ms": snapped(cpu_1_pct_worst, 0.2),
		"cpu_physics_avg_ms": snapped(avg_physics, 0.2),
		"cpu_physics_worst_ms": snapped(max_physics, 0.2),
		"cpu_scripts_avg_ms": snapped(avg_scripts, 0.2),
		"cpu_scripts_worst_ms": snapped(max_scripts, 0.2),
		"cpu_render_prep_avg_ms": snapped(avg_render_prep, 0.2),
		"cpu_render_prep_worst_ms": snapped(max_render_prep, 0.2),
		"cpu_animation_avg_ms": null,
		"cpu_other_avg_ms": snapped(avg_other, 0.2),
		"cpu_other_worst_ms": snapped(max_other, 0.2),
		"gpu_frame_time_avg_ms": avg_gpu_val,
		"gpu_frame_time_worst_ms": worst_gpu_val,
		"gpu_frame_time_1_percent_low_ms": gpu_1_pct_worst_val,
		"gpu_timing_available": is_gpu_timing_available,
		"total_frames": total_frames,
		"duration_sec": snapped(record_time, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"ram_mb": snapped(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"vram_mb": snapped(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"spikes": rec_spikes.duplicate(true),
		"event_summaries": event_summaries,
		"function_profiles": function_profiles
	}

# ── Shader / Pipeline Warmup ─────────────────────────────────────────────────
func run_shader_warmup() -> Dictionary:
	var start_ticks = Time.get_ticks_msec()
	var detected_count: int = 0
	var warmed_count: int = 0

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

	RenderingServer.force_draw(true)

	var elapsed_sec = (Time.get_ticks_msec() - start_ticks) / 1000.0
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
	var benchmark_data = last_benchmark if not last_benchmark.is_empty() else _calculate_benchmark_summary()

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
		"godot_version": Engine.get_version_info().get("string", "4.7"),
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
		f_txt.store_line("  Average FPS:            %.1f FPS" % benchmark_data.get("avg_fps", 0.0))
		f_txt.store_line("  1%% Low FPS:             %.1f FPS (Stutter Metric)" % benchmark_data.get("low_1_percent_fps", 0.0))
		f_txt.store_line("  Minimum FPS:            %.1f FPS" % benchmark_data.get("min_fps", 0.0))
		f_txt.store_line("  Avg Frame Time:         %.2f ms" % benchmark_data.get("avg_frame_time_ms", 0.0))
		f_txt.store_line("  Worst Frame Time:       %.2f ms" % benchmark_data.get("worst_frame_time_ms", 0.0))
		f_txt.store_line("  CPU Avg Frame Time:     %.2f ms" % benchmark_data.get("cpu_frame_time_avg_ms", 0.0))
		f_txt.store_line("  CPU Worst Frame Time:   %.2f ms" % benchmark_data.get("cpu_frame_time_worst_ms", 0.0))
		f_txt.store_line("  CPU 1%% Worst Time:      %.2f ms" % benchmark_data.get("cpu_frame_time_1_percent_low_ms", 0.0))
		f_txt.store_line("--------------------------------------------------")
		f_txt.store_line("⚙️ CPU SUBSYSTEMS BREAKDOWN:")
		f_txt.store_line("  • Physics Time:         Avg: %.2f ms | Worst: %.2f ms" % [benchmark_data.get("cpu_physics_avg_ms", 0.0), benchmark_data.get("cpu_physics_worst_ms", 0.0)])
		f_txt.store_line("  • Scripts / Logic:      Avg: %.2f ms | Worst: %.2f ms" % [benchmark_data.get("cpu_scripts_avg_ms", 0.0), benchmark_data.get("cpu_scripts_worst_ms", 0.0)])
		f_txt.store_line("  • Render Prep / Scene:  Avg: %.2f ms | Worst: %.2f ms" % [benchmark_data.get("cpu_render_prep_avg_ms", 0.0), benchmark_data.get("cpu_render_prep_worst_ms", 0.0)])
		f_txt.store_line("  • Animation:            Unavailable (Folded in Scripts/Process in Godot 4.7)")
		f_txt.store_line("  • Other / OS Events:    Avg: %.2f ms | Worst: %.2f ms" % [benchmark_data.get("cpu_other_avg_ms", 0.0), benchmark_data.get("cpu_other_worst_ms", 0.0)])

		var funcs: Dictionary = benchmark_data.get("function_profiles", {})
		if not funcs.is_empty():
			f_txt.store_line("--------------------------------------------------")
			f_txt.store_line("🔬 CPU FUNCTION PROFILE (%d instrumented scopes):" % funcs.size())
			for f_name in funcs.keys():
				var fd = funcs[f_name]
				f_txt.store_line("  • %s" % f_name)
				f_txt.store_line("    calls: %d | total: %.2f ms | average: %.3f ms | worst: %.2f ms" % [
					fd.get("calls", 0),
					fd.get("total_ms", 0.0),
					fd.get("average_ms", 0.0),
					fd.get("worst_ms", 0.0)
				])

		var gpu_avg = benchmark_data.get("gpu_frame_time_avg_ms")
		var gpu_worst = benchmark_data.get("gpu_frame_time_worst_ms")
		var gpu_1_pct = benchmark_data.get("gpu_frame_time_1_percent_low_ms")
		f_txt.store_line("--------------------------------------------------")
		if gpu_avg != null:
			f_txt.store_line("🎮 GPU TIMINGS:")
			f_txt.store_line("  GPU Avg Frame Time:     %.2f ms" % gpu_avg)
			f_txt.store_line("  GPU Worst Frame Time:   %.2f ms" % gpu_worst)
			f_txt.store_line("  GPU 1%% Worst Time:      %.2f ms" % gpu_1_pct)
		else:
			f_txt.store_line("🎮 GPU TIMINGS:           GPU timing unavailable")

		f_txt.store_line("--------------------------------------------------")
		f_txt.store_line("📦 RENDER & MEMORY:")
		f_txt.store_line("  Draw Calls:             %d" % benchmark_data.get("draw_calls", 0))
		f_txt.store_line("  RAM Used:               %.1f MB" % benchmark_data.get("ram_mb", 0.0))
		f_txt.store_line("  VRAM Used:              %.1f MB" % benchmark_data.get("vram_mb", 0.0))
		f_txt.store_line("--------------------------------------------------")

		# Event Performance Summary Breakdown
		var events: Dictionary = benchmark_data.get("event_summaries", {})
		f_txt.store_line("🧪 EVENT PERFORMANCE BREAKDOWN (%d events):" % events.size())
		if events.is_empty():
			f_txt.store_line("  No event markers recorded.")
		else:
			for ev_name in events.keys():
				var ev_data = events[ev_name]
				var ev_gpu_str = ("%.1f ms" % ev_data.gpu_frame_time_ms) if ev_data.get("gpu_frame_time_ms") != null else "N/A"
				f_txt.store_line("  • EVENT: %s (%d samples)" % [ev_name, ev_data.get("samples", 0)])
				f_txt.store_line("    Frame: %.1f ms | CPU: %.1f ms (Phys: %.1fms, Scripts: %.1fms, RenderPrep: %.1fms, Other: %.1fms) | GPU: %s | Bottleneck: %s" % [
					ev_data.get("avg_frame_time_ms", 0.0),
					ev_data.get("cpu_frame_time_ms", 0.0),
					ev_data.get("physics_ms", 0.0),
					ev_data.get("scripts_ms", 0.0),
					ev_data.get("render_prep_ms", 0.0),
					ev_data.get("other_ms", 0.0),
					ev_gpu_str,
					ev_data.get("bottleneck", "UNKNOWN")
				])

		f_txt.store_line("--------------------------------------------------")
		var spikes = benchmark_data.get("spikes", [])
		f_txt.store_line("🚨 DETECTED SPIKES (%d total):" % spikes.size())
		if spikes.is_empty():
			f_txt.store_line("  No significant frame spikes detected! (Solid performance)")
		else:
			for s in spikes:
				var first_flag = " [FIRST-USE / SHADER COMPILATION HITCH]" if s.get("is_first_use", false) else ""
				var s_gpu_str = ("GPU: %.1fms" % s.gpu_frame_time_ms) if s.get("gpu_frame_time_ms") != null else "GPU: N/A"
				f_txt.store_line("  • At %.2fs (Frame %d): Frame: %.1fms | CPU: %.1fms | %s | [%s] [%s]%s" % [
					s.get("time", 0.0),
					s.get("frame", 0),
					s.get("frame_time_ms", 0.0),
					s.get("cpu_frame_time_ms", 0.0),
					s_gpu_str,
					s.get("marker", "UNKNOWN"),
					s.get("bottleneck", "UNKNOWN"),
					first_flag
				])
				f_txt.store_line("    CPU Subsystems: Physics: %.1fms | Scripts: %.1fms | RenderPrep: %.1fms | Other: %.1fms" % [
					s.get("physics_ms", 0.0),
					s.get("scripts_ms", 0.0),
					s.get("render_prep_ms", 0.0),
					s.get("other_ms", 0.0)
				])
				var top_funcs = s.get("top_functions", [])
				if not top_funcs.is_empty():
					var func_strs = []
					for tf in top_funcs:
						func_strs.append("%s: %.1fms" % [tf.name, tf.time_ms])
					f_txt.store_line("    Top Profiled Scopes in Spike: " + ", ".join(func_strs))

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
