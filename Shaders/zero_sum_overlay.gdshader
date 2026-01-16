shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(0.2, 0.6, 1.0, 0.55);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(tex, overlay_color, overlay_color.a);
}
