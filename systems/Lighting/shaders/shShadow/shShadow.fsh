uniform float u_light_radius;
uniform float u_shadow_opacity;
varying float v_distance;
void main()
{   
    gl_FragColor = vec4(vec3(0.0), u_shadow_opacity);
}