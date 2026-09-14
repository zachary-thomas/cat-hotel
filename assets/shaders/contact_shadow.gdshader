shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.26;
void fragment() {
    float radius = length((UV - vec2(0.5)) * 2.0);
    ALBEDO = vec3(0.20, 0.15, 0.08);
    ALPHA = (1.0 - smoothstep(0.15, 1.0, radius)) * strength;
}
