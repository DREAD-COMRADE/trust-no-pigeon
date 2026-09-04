class_name Profiler

## Lightweight Function-Level CPU Scope Profiler for Godot 4.7
## Usage:
##   Profiler.begin_scope("ExplosionDamage")
##   # ... expensive logic ...
##   Profiler.end_scope("ExplosionDamage")

static func begin_scope(scope_name: String) -> void:
	if PerformanceLab.instance and PerformanceLab.instance.is_scope_profiling_enabled:
		PerformanceLab.instance._scope_start_times[scope_name] = Time.get_ticks_usec()

static func end_scope(scope_name: String) -> void:
	if PerformanceLab.instance and PerformanceLab.instance.is_scope_profiling_enabled:
		var end_time = Time.get_ticks_usec()
		var start_time = PerformanceLab.instance._scope_start_times.get(scope_name, -1)
		if start_time >= 0:
			PerformanceLab.instance._record_scope_elapsed(scope_name, end_time - start_time)

static func is_enabled() -> bool:
	return PerformanceLab.instance != null and PerformanceLab.instance.is_scope_profiling_enabled

static func set_enabled(enabled: bool) -> void:
	if PerformanceLab.instance:
		PerformanceLab.instance.is_scope_profiling_enabled = enabled