shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.57, 1.0);
void fragment() {
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * 0.15;
}
