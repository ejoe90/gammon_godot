shader_type canvas_item;

uniform vec4 tint_top : source_color = vec4(0.05, 0.02, 0.10, 1.0);
uniform vec4 tint_bottom : source_color = vec4(0.02, 0.02, 0.06, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float star_strength : hint_range(0.0, 2.0) = 0.45;
uniform float density : hint_range(0.1, 1.0) = 0.55;

uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform float shimmer : hint_range(0.0, 2.0) = 0.75;

uniform float scale1 : hint_range(0.001, 0.2) = 0.020;
uniform float scale2 : hint_range(0.001, 0.2) = 0.045;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float star_layer(vec2 p, float scale) {
    vec2 uv = p * scale;
    vec2 id = floor(uv);
    vec2 gv = fract(uv) - 0.5;

    float n = hash(id);
    // star exists? (rarer as density decreases)
    float exists = smoothstep(1.0 - density, 1.0, n);

    // small bright center
    float d = length(gv);
    float core = smoothstep(0.18, 0.0, d);

    // twinkle
    float tw = 0.6 + 0.4 * sin(TIME * (2.5 + 3.5 * n) + n * 6.2831);
    core *= mix(1.0, tw, shimmer);

    return exists * core;
}

void fragment() {
    // pixel coords so scaling/resizing looks consistent
    vec2 p = UV / SCREEN_PIXEL_SIZE;

    // falling (increase y over time)
    p.y += TIME * speed * 60.0;

    float s1 = star_layer(p, scale1);
    float s2 = 0.6 * star_layer(p + vec2(123.0, 77.0), scale2);

    float stars = (s1 + s2) * star_strength;

    vec3 grad = mix(tint_top.rgb, tint_bottom.rgb, UV.y);

    // subtle blue-purple star tint
    vec3 star_col = vec3(0.35, 0.55, 1.00) * stars;

    vec3 out_col = grad + star_col;
    COLOR = vec4(out_col, opacity);
}
