// Light Object Settings

follow = false;


var _r = irandom(255);
var _g = irandom(255);
var _b = irandom(255);

light_color = make_color_rgb(_r, _g, _b);  // Default color
//show_debug_message($" Light Color: (R:{_r}, G:{_g}, B{_b}) - {light_color}");


image_blend = light_color;

light_cone_angle	= 360; // if its 0 there wont be any light [1,180]
//light_cone_angle	= 40 + irandom(65); // if its 0 there wont be any light [1,180]
light_cone_dir		= 0;

light_brightness	= 1;		// [0,1]
light_intensity		= 0.9;		// [0,1]
light_softness		= 0.1;		// [0,1]


light_radius		= 30 + irandom(35);		// [0.1, infinity]
light_flicker_amount = 0.0;		// [0,1]



with(oShadowRender)
{
	//ds_map_add(light_map, other.id, other.all_light_data);
	current_active_lights++;
}

