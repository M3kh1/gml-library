// Shadow Renderer Stuff

show_debug_overlay(true,true);


#region Helper Functs


// Function to check if a given (x, y) position is within the grid bounds
function is_within_bounds(_grid, _x, _y)
{
    // Get the grid dimensions
    var gridWidth = ds_grid_width(_grid);
    var gridHeight = ds_grid_height(_grid);
    
    // Check if the position (x, y) is within the valid grid range
    if (_x >= 0 && _x < gridWidth && _y >= 0 && _y < gridHeight)
    {
        return true;  // Inside bounds
    }
    else
    {
        return false; // Out of bounds
    }
}

#endregion


#region Shader Vertex Buffer




// (call whenever grid changes)
function build_edge_vbuff(_buffer, _grid, _tileSize)
{
    var startX = 0;
    var startY = 0;
    var endX = ds_grid_width(_grid) - 1;
    var endY = ds_grid_height(_grid) - 1;

    // Loop through all the grid tiles
    for (var yy = startY; yy <= endY; yy++)
    {
        for (var xx = startX; xx <= endX; xx++)
        {
            var cell = ds_grid_get(_grid, xx, yy);
            
            // Only walls cast shadows
            if (cell != tile_type.wall) continue;
            
            var _l = xx * _tileSize;
            var _r = _l + _tileSize;
            var _t = yy * _tileSize;
            var _b = _t + _tileSize;
            
            // Check neighboring tiles with bounds checking using is_within_bounds
            var top_exposed = is_within_bounds(_grid, xx, yy-1) && ds_grid_get(_grid, xx, yy-1) != tile_type.wall;
            var right_exposed = is_within_bounds(_grid, xx+1, yy) && ds_grid_get(_grid, xx+1, yy) != tile_type.wall;
            var bottom_exposed = is_within_bounds(_grid, xx, yy+1) && ds_grid_get(_grid, xx, yy+1) != tile_type.wall;
            var left_exposed = is_within_bounds(_grid, xx-1, yy) && ds_grid_get(_grid, xx-1, yy) != tile_type.wall;
            
            // Only add shadow edges for exposed edges
            if (top_exposed)    add_edge_to_vbuff(_buffer, _l, _t, _r, _t); // Top edge
            if (right_exposed)  add_edge_to_vbuff(_buffer, _r, _t, _r, _b); // Right edge
            if (bottom_exposed) add_edge_to_vbuff(_buffer, _r, _b, _l, _b); // Bottom edge
            if (left_exposed)   add_edge_to_vbuff(_buffer, _l, _b, _l, _t); // Left edge
        }
    }
}


// Helper function to add an edge quad as two trianglesM
function add_edge_to_vbuff(vbuff, x1, y1, x2, y2)
{
    var _z = 10000; // Extrusion distance
    
    // Triangle 1 (CCW winding)
    vertex_position_3d(vbuff, x1, y1, _z); // Extruded start
    vertex_position_3d(vbuff, x2, y2, _z); // Extruded end
    vertex_position_3d(vbuff, x2, y2, 0);  // Base end
    
    // Triangle 2
    vertex_position_3d(vbuff, x2, y2, 0);  // Base end
    vertex_position_3d(vbuff, x1, y1, 0);  // Base start
    vertex_position_3d(vbuff, x1, y1, _z); // Extruded start
}



#endregion


#region Shader Based Shadows

#region INITIALIZATION - VERTEX BUFFER & SURFACES

// 1. First create vertex format
vertex_format_begin();
vertex_format_add_position_3d(); // Only need position (x,y,z)
vf_shadow = vertex_format_end();

// 2. Create and build vertex buffer
vb_shadow = vertex_create_buffer();
vertex_begin(vb_shadow, vf_shadow);

// Build the buffer with your wall edges
build_edge_vbuff(vb_shadow, oGenRoom.maze, CELL_SIZE);

// Finalize the buffer
vertex_end(vb_shadow);
vertex_freeze(vb_shadow); // Critical for performance!

// 3. Create surfaces for rendering
surf_shadow = surface_create(room_width, room_height);
surf_light_effects = surface_create(room_width, room_height);
surf_gradient  = surface_create(room_width, room_height);
surf_final  = surface_create(room_width, room_height);
surf_blur  = surface_create(room_width, room_height);

#endregion

#region SHADER UNIFORMS - SHADOW

u_shadow_pos = shader_get_uniform(shShadow, "light_pos");
u_shadow_opacity = shader_get_uniform(shShadow, "u_shadow_opacity");
u_shadow_light_radius = shader_get_uniform(shShadow, "u_light_radius");

#endregion

#region SHADER UNIFORMS - BLUR

u_resolution_h = shader_get_uniform(shBlur_h, "u_resolution");
u_blur_size_h = shader_get_uniform(shBlur_h, "u_blur_size");
u_resolution_v = shader_get_uniform(shBlur_v, "u_resolution");
u_blur_size_v = shader_get_uniform(shBlur_v, "u_blur_size");

#endregion

#region SHADER UNIFORMS - LIGHT

u_sh_light_pos        = shader_get_uniform(shLight, "u_light_pos");
u_sh_light_radius     = shader_get_uniform(shLight, "u_light_radius");

u_sh_light_dir = shader_get_uniform(shLight, "u_light_dir");
u_sh_light_angle = shader_get_uniform(shLight, "u_light_angle");


u_sh_light_intensity  = shader_get_uniform(shLight, "u_light_intensity");
u_sh_light_softness   = shader_get_uniform(shLight, "u_light_softness");
u_sh_light_color      = shader_get_uniform(shLight, "u_light_color");
u_sh_light_brightness = shader_get_uniform(shLight, "u_light_brightness");


#endregion

#region LIGHTING SETTINGS

ambient_light_level = 0.3; // Value between 0 and 1, where 0 is pitch black and 1 is fully lit
ambient_light_color = c_black;
//ambient_light_color = make_color_rgb(3, 8, 30); // A dark blue works well for night scenes

shadow_opacity		= 1;		// [0,1]

// Blur settings for shadows
blur_size = 0.5; // Pixel size to blur (don't go too crazy with small values)
blur_size = clamp(blur_size, 0.25, 3); 
current_active_lights = 0;

depth = -999;

#endregion

#endregion

