shader_type canvas_item;

uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;

uniform float glow_strength : hint_range(0.0, 3.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform vec4 glow_color : source_color = vec4(0.70, 0.20, 1.00, 1.0); // brighter purple

uniform float sepia_speed : hint_range(0.0, 10.0) = 1.5;
uniform float sepia_max : hint_range(0.0, 1.0) = 0.0;

uniform float edge_width : hint_range(0.0, 0.25) = 0.12;   // thicker edge band
uniform float aura_strength : hint_range(0.0, 3.0) = 0.9;  // center aura

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * COLOR;

	float sepia_amount = (sin(TIME * sepia_speed) * 0.5 + 0.5) * sepia_max;
	mat3 sepia_matrix = mat3(
		vec3(0.393, 0.769, 0.189),
		vec3(0.349, 0.686, 0.168),
		vec3(0.272, 0.534, 0.131)
	);
	vec3 sepia_color = sepia_matrix * base.rgb;
	base.rgb = mix(base.rgb, sepia_color, sepia_amount);

	// Invert
	vec3 inv = vec3(1.0) - base.rgb;
	vec3 col = mix(base.rgb, inv, invert_amount);

	// Pulse 0..1
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	pulse = pulse * pulse; // stronger peaks

	// Edge glow (rectangle distance)
	float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = smoothstep(edge_width, 0.0, d);

	// Aura glow (radial, adds “energy” feel)
	vec2 c = UV - vec2(0.5);
	float r = length(c);
	float aura = smoothstep(0.65, 0.20, r);

	float mask = max(edge, aura * aura_strength);
	col += glow_color.rgb * (glow_strength * mask * pulse);

	COLOR = vec4(col, base.a);
}
