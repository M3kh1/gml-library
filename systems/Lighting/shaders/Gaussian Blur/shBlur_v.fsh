varying vec2 v_vTexcoord;
uniform float u_blur_size;
uniform vec2 u_resolution;

void main() {
    vec4 sum = vec4(0.0);
    float blur = u_blur_size / u_resolution.y;

    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0, -4.0 * blur)) * 0.05;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0, -3.0 * blur)) * 0.09;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0, -2.0 * blur)) * 0.12;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0, -1.0 * blur)) * 0.15;
    sum += texture2D(gm_BaseTexture, v_vTexcoord                             ) * 0.18;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0,  1.0 * blur)) * 0.15;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0,  2.0 * blur)) * 0.12;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0,  3.0 * blur)) * 0.09;
    sum += texture2D(gm_BaseTexture, v_vTexcoord + vec2(0.0,  4.0 * blur)) * 0.05;

    gl_FragColor = sum;
}
