shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(1.0);
uniform float grain = 0.009;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() {
    local_pos = VERTEX;
    local_normal = NORMAL;
}
void fragment() {
    vec3 p = abs(local_pos);
    vec2 face = abs(local_normal.y) > 0.5 ? local_pos.xz : (abs(local_normal.x) > 0.5 ? local_pos.zy : local_pos.xy);
    float edge = smoothstep(0.47, 0.499, max(abs(face.x), abs(face.y)));
    float fibres = sin(face.x * 36.0 + sin(face.y * 8.0) * 2.0) * sin(face.y * 13.0);
    float shade = 1.0 + fibres * grain + edge * 0.06;
    ALBEDO = tint.rgb * shade;
    ROUGHNESS = 0.88;
}

