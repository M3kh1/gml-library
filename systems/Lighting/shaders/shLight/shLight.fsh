varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec2 v_pos;

uniform vec2 u_light_pos;
uniform float u_light_radius;
uniform float u_light_intensity;
uniform float u_light_softness;
uniform vec3 u_light_color;
uniform float u_light_brightness;

uniform vec2 u_light_dir;     // Should be normalized!
uniform float u_light_angle;  // Half-angle in radians

void main()
{
    vec2 to_pixel = v_pos - u_light_pos;
    float d = length(to_pixel);
    
    // Keep your original exponential falloff
    float base_falloff = exp(-d * d / (1.2 * u_light_radius * u_light_radius));
    
    // Apply softness by blending between original falloff and a softer version
    float soft_falloff = 1.0 - smoothstep(0.0, u_light_radius, d);
    float falloff = mix(base_falloff, soft_falloff, u_light_softness);
    
	
	// Alternative edge softening
	//float edge = d / u_light_radius;
	//float falloff = base_falloff * (1.0 - u_light_softness * smoothstep(0.8, 1.0, edge));
	
	#region     [Directional Lights]
	
    float directional_strength = 1.0;

    if (u_light_angle < 3.1459)
	{ // Only apply if < 180 degrees
        vec2 to_dir = normalize(to_pixel);
        float dot_angle = dot(u_light_dir, to_dir); // cos(angle between)
        float angle_falloff = smoothstep(cos(u_light_angle), cos(u_light_angle * 0.75), dot_angle);
        directional_strength = angle_falloff;
    }
	
	#endregion

    // Final lighting
    float final = falloff * directional_strength;
    vec3 color = u_light_color * u_light_brightness * final;
    float alpha = final * u_light_intensity;

    gl_FragColor = vec4(color, alpha);
}
