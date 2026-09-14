shader_type spatial;
uniform float motion = 1.0;
uniform vec4 deep_color : source_color = vec4(0.23, 0.57, 0.61, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float t = TIME * motion;
    float wave = sin(world_pos.x * 5.0 + world_pos.z * 4.0 + t * 0.8);
    float cross_wave = sin(world_pos.x * 3.5 - world_pos.z * 6.0 - t);
    float glint = pow(max(0.0, wave * cross_wave), 9.0);
    ALBEDO = deep_color.rgb + vec3(glint * 0.19 + wave * 0.022);
    ROUGHNESS = 0.35;
    METALLIC = 0.12;
}
