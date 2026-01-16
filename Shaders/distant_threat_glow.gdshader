shader_type canvas_item;

uniform float pulse_speed = 2.6;
uniform float glow_strength = 0.65;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5);
	vec3 glow = mix(tex.rgb, vec3(1.0), glow_strength * pulse);
	COLOR = vec4(glow, tex.a);
}
