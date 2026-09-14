shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.13;
uniform bool window_panes = false;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float glow = pow(max(0.0, 1.0 - dot(p, p)), 2.0);
    if (window_panes) {
        glow = (1.0 - smoothstep(0.82, 1.0, abs(p.x))) * (1.0 - smoothstep(0.5, 1.0, abs(p.y)));
        glow *= smoothstep(0.035, 0.085, abs(p.x)) * smoothstep(0.045, 0.10, abs(p.y));
    }
    ALBEDO = vec3(1.0, 0.75, 0.38);
    ALPHA = glow * strength;
}
