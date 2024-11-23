/*
    Asset: Godot Simple Portal System
    File: portal.gdshader
    Description: Shader used by the simple portal system.
    Repository: https://github.com/Donitzo/godot-simple-portal-system
    License: CC0 License
*/

shader_type spatial;
render_mode unshaded;

uniform float fade_out_distance_max = 10.0;
uniform float fade_out_distance_min = 8.0;
uniform vec4 fade_out_color = vec4(0.0);

uniform sampler2D albedo:hint_default_black, source_color;

varying float pixel_distance;

void vertex() {
    // Calculate the world-space distance between the pixel and camera.
    // Pass the distance to the fragment shader using a varying attribute.
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 camera_position = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    
    pixel_distance = distance(world_position, camera_position);
}

void fragment() {
    // The portal color is simply the screen-space color of the exit camera render target.
    // This is because the exit camera views the exit portal from the perspective of the player watching
    // the entrance portal, meaning the exit portal will occupy the same screen-space as the entrance portal.
    vec3 portal_color = texture(albedo, SCREEN_UV).rgb;
    
    // Fade-out color
    float t = smoothstep(fade_out_distance_min, fade_out_distance_max, pixel_distance);
    ALBEDO = mix(portal_color, fade_out_color.rgb, t);
    ALPHA = 1.0;
}
