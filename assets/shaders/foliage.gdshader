shader_type spatial;
uniform vec4 tint : source_color = vec4(0.4, 0.6, 0.3, 1.0);
uniform float motion = 1.0;
varying float tip;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    tip = clamp(VERTEX.y * 0.20 + 0.55, 0.0, 1.0);
    // A continuous field gives shared crown vertices the same displacement.
    VERTEX.x += sin(TIME * 0.9 + world.x * 0.55 + world.z * 0.35) * 0.018 * motion;
    VERTEX.z += cos(TIME * 0.75 + world.z * 0.45) * 0.012 * motion;
}
void fragment() {
    ALBEDO = tint.rgb * COLOR.rgb * (0.95 + tip * 0.09);
    ROUGHNESS = 0.95;
}
