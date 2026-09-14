shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
    vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
    scene = (scene - 0.5) * 1.035 + 0.5;
    scene *= vec3(1.018, 1.005, 0.97);
    float vignette = smoothstep(0.30, 0.83, length((UV - vec2(0.5)) * vec2(0.8, 1.0)));
    scene *= 1.0 - vignette * 0.12;
    COLOR = vec4(scene, 1.0);
}

