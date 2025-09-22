attribute vec3 in_Position;  // x, y = position, z = extrusion factor
uniform vec2 light_pos;

varying float v_distance;

void main()
{
    vec2 toLight = in_Position.xy - light_pos;
	
    v_distance = length(toLight);  // Distance from light

    vec2 extrudedPos = in_Position.xy + toLight * in_Position.z;
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(extrudedPos, 0.0, 1.0);
}
