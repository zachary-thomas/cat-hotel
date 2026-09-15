shader_type spatial;
uniform float motion = 1.0;
uniform vec4 deep_color : source_color = vec4(0.23, 0.57, 0.61, 1.0);
uniform float shore_z = -1000.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float t = TIME * motion;
    vec2 p = world_pos.xz;
    float phase = p.y * 2.1 + sin(p.x * 0.65 + t * 0.23) * 0.8 - t * 0.7;
    float detail = 1.0 - smoothstep(0.3, 1.5, fwidth(phase));
    float wave = sin(phase);
    float broken_crest = 0.55 + 0.45 * sin(p.x * 0.8 - p.y * 0.5 + t * 0.2);
    float ripple = smoothstep(0.82, 0.98, wave) * broken_crest * detail;
    float shore = 1.0 - smoothstep(0.0, 8.0, p.y - shore_z);
    vec3 color = mix(deep_color.rgb, vec3(0.42,0.77,0.76), shore * 0.55);
    ALBEDO = color + vec3(ripple * 0.10 + wave * detail * 0.018);
    ROUGHNESS = 0.72;
    METALLIC = 0.0;
}
