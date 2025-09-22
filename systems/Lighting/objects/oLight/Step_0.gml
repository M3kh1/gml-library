// Extra 
if follow 
{
	x = mouse_x;
	y = mouse_y;
}


if (light_flicker_amount > 0)
{
    light_brightness = 1.0 - random(light_flicker_amount);
}

light_cone_dir++;
