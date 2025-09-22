

#region Create ALL Surfaces Once

if (!surface_exists(surf_light_effects)) surf_light_effects = surface_create(room_width, room_height);
if (!surface_exists(surf_shadow))        surf_shadow        = surface_create(room_width, room_height);
if (!surface_exists(surf_gradient))      surf_gradient      = surface_create(room_width, room_height);
if (!surface_exists(surf_final))         surf_final         = surface_create(room_width, room_height);
if (!surface_exists(surf_blur))          surf_blur          = surface_create(room_width, room_height);

#endregion


#region --- Temp Vars ---

// Surface Shortcuts
var _ss = surf_shadow;
var _sg = surf_gradient;
var _sl = surf_light_effects;
var _sf = surf_final;
var _sb = surf_blur;
var _vbs = vb_shadow;


// Guassian Blur
// Shader uniforms (cached outside loop)
var _blur_size = blur_size;
var _ubsv = u_blur_size_v;
var _ubsh = u_blur_size_h;
var _urv = u_resolution_v;
var _urh = u_resolution_h;

// Shadow
var _u_shadow_pos = u_shadow_pos;
var _u_shadow_opacity = u_shadow_opacity;
var _u_shadow_light_radius = u_shadow_light_radius;

var _sh_o = shadow_opacity;



// Light
var _u_sh_light_pos        = u_sh_light_pos;
var _u_sh_light_radius     = u_sh_light_radius;
var _u_sh_light_dir		   = u_sh_light_dir;
var _u_sh_light_angle	   = u_sh_light_angle;
var _u_sh_light_intensity  = u_sh_light_intensity;
var _u_sh_light_softness   = u_sh_light_softness;
var _u_sh_light_color      = u_sh_light_color;
var _u_sh_light_brightness = u_sh_light_brightness;



#endregion


// Clear final surface once with ambient
surface_set_target(_sf);
draw_clear_alpha(ambient_light_color, ambient_light_level);
surface_reset_target();


#region --- Process Each Light ---

with (oLight)
{
	
	// 6 vbatches to the gpu + 1 vertex_submit so 7 tbatches
	// lets try and get it lower vertex_submit is staying
	
    #region ----- Shadow Map -----
	
    surface_set_target(_ss);
    draw_clear_alpha(c_white, 1); // Start fully lit
    shader_set(shShadow);
	
    shader_set_uniform_f(_u_shadow_pos, x, y);
	shader_set_uniform_f(_u_shadow_light_radius, light_radius);
	shader_set_uniform_f(_u_shadow_opacity, _sh_o);
	
	
    vertex_submit(_vbs, pr_trianglelist, -1); 
	
    shader_reset();
    surface_reset_target();
	
	
	#endregion
	
    #region ----- Blur Shadow Map -----
	
	if (_blur_size > 0)
	{
	    // HORIZONTAL PASS: _ss → _sb
		surface_set_target(_sb);
		draw_clear_alpha(c_white, 0);
		shader_set(shBlur_h);
		shader_set_uniform_f(_ubsh, _blur_size);
		shader_set_uniform_f(_urh, room_width, room_height);
		draw_surface(_ss, 0, 0);
		shader_reset();
		surface_reset_target();

		// VERTICAL PASS: _sb → _ss
		surface_set_target(_ss);
		draw_clear_alpha(c_white, 0);
		shader_set(shBlur_v);
		shader_set_uniform_f(_ubsv, _blur_size);
		shader_set_uniform_f(_urv, room_width, room_height);
		draw_surface(_sb, 0, 0);
		shader_reset();
		surface_reset_target();
	}
	
	

	
	#endregion


    #region ----- Light Gradient Pass -----
	
    surface_set_target(_sg);
    draw_clear_alpha(c_white, 0); // Clean gradient
    shader_set(shLight);

    shader_set_uniform_f(_u_sh_light_pos, x, y);
	shader_set_uniform_f(_u_sh_light_radius, light_radius);
	shader_set_uniform_f(_u_sh_light_dir, dcos(light_cone_dir), dsin(light_cone_dir)); // direction must be normalized
	shader_set_uniform_f(_u_sh_light_angle, degtorad(light_cone_angle)); // e.g., 30 = 60° cone

	shader_set_uniform_f(_u_sh_light_intensity, light_intensity); // formerly shadow_opacity
	shader_set_uniform_f(_u_sh_light_softness, light_softness);
	shader_set_uniform_f(_u_sh_light_color,
	    color_get_red(light_color) / 255,
	    color_get_green(light_color) / 255,
	    color_get_blue(light_color) / 255);
	shader_set_uniform_f(_u_sh_light_brightness, light_brightness);

    draw_rectangle(0, 0, room_width, room_height, false);
    shader_reset();
    surface_reset_target();
	
	#endregion

    #region ----- Combine Shadow + Gradient (Per Light) -----
	
    surface_set_target(_sl);
	
    draw_clear_alpha(c_black, 0); // Start dark
	
    gpu_set_blendmode(bm_add);
    draw_surface(_ss, 0, 0); // Mask

    gpu_set_blendmode_ext(bm_dest_color, bm_zero); // Multiply gradient by shadow
    draw_surface(_sg, 0, 0);
	
	gpu_set_blendmode(bm_normal);
    surface_reset_target();
	
	#endregion
	
    #region ----- Add Light to Final Surface -----
	
    surface_set_target(_sf);
    gpu_set_blendmode(bm_add);
    draw_surface(_sl, 0, 0);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();
	
	#endregion
	
}


#endregion

// -----------------------------
// Draw Final Light Surface
// -----------------------------
gpu_set_blendmode_ext(bm_dest_color, bm_src_color);
draw_surface(_sf, 0, 0);
gpu_set_blendmode(bm_normal);

//draw_surface(_ss, 0, 0);

// -----------------------------
// Draw World Below
// -----------------------------
with (oBlock) draw_self();


