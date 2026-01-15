shader_type canvas_item;

uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Include Control modulate/tint (CanvasItem COLOR)
    vec4 base = tex * COLOR;

    vec3 inv = vec3(1.0) - base.rgb;
    COLOR = vec4(mix(base.rgb, inv, invert_amount), base.a);
}
