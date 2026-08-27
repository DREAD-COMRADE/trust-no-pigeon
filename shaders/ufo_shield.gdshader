shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 shield_color : source_color = vec4(0.2, 0.85, 1.0, 0.45);
uniform vec4 rim_color : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform float scanline_frequency : hint_range(1.0, 50.0) = 24.0;
uniform float scanline_speed : hint_range(0.1, 20.0) = 6.0;
uniform float fresnel_power : hint_range(0.5, 10.0) = 2.5;
uniform float flicker_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	// Fresnel rim effect
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	// Animated scanline pulse
	float scanline = sin(VERTEX.y * scanline_frequency - TIME * scanline_speed) * 0.5 + 0.5;
	
	// Energy shimmer wave
	float wave = sin(TIME * 8.0 + VERTEX.x * 4.0 + VERTEX.z * 4.0) * 0.15 + 0.85;
	
	vec3 final_color = mix(shield_color.rgb, rim_color.rgb, fresnel) * (1.0 + scanline * pulse_intensity) * wave;
	float final_alpha = (shield_color.a * 0.5 + fresnel * 0.6 + scanline * 0.25) * flicker_alpha;
	
	ALBEDO = final_color;
	EMISSION = final_color * (1.5 + fresnel * 2.0);
	ALPHA = clamp(final_alpha, 0.0, 0.95);
}
