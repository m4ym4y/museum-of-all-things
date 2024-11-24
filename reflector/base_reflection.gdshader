shader_type spatial;

// from https://github.com/SIsilicon/Godot-Planar-Reflection-Plugin	
// license MIT
// adapted for godot 4

//PR__UNIFORMS_AND_FUNCTIONS__PR//
uniform sampler2D _pr_viewport;
uniform vec4 _pr_viewport_rect = vec4(-2.0, -2.0, 4.0, 4.0);
uniform float _pr_perturb_scale = 1.0;

vec3 _pr_fresnel(vec3 f0, float cos_theta) {
	vec3 fres = f0 + (vec3(1.0) - f0)*pow(1.0 - abs(cos_theta), 5.0);
	return fres;
}

vec4 _pr_cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 _pr_texture_bicubic(sampler2D sampler, vec2 tex_coords) {
	vec2 tex_size = vec2(textureSize(sampler, 0));
	vec2 inv_tex_size = 1.0 / tex_size;
	
	tex_coords = tex_coords * tex_size - 0.5;
	
	vec2 fxy = fract(tex_coords);
	tex_coords -= fxy;
	
	vec4 xcubic = _pr_cubic(fxy.x);
	vec4 ycubic = _pr_cubic(fxy.y);
	
	vec4 c = tex_coords.xxyy + vec2 (-0.5, +1.5).xyxy;
	
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;
	
	offset *= inv_tex_size.xxyy;
	
	vec4 sample0 = texture(sampler, offset.xz);
	vec4 sample1 = texture(sampler, offset.yz);
	vec4 sample2 = texture(sampler, offset.xw);
	vec4 sample3 = texture(sampler, offset.yw);
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

// Pulled straight from scene.glsl
vec3 _pr_normal_from_normalmap(vec3 normalmap, vec3 normal, vec3 tangent, vec3 binormal, float normaldepth) {
	normalmap.xy = normalmap.xy * 2.0 - 1.0;
	normalmap.z = sqrt(max(0.0, 1.0 - dot(normalmap.xy, normalmap.xy))); //always ignore Z, as it can be RG packed, Z may be pos/neg, etc.
	
	return normalize(mix(normal, tangent * normalmap.x + binormal * normalmap.y + normal * normalmap.z, normaldepth));
}

vec3 _pr_line_plane_intersect(vec3 line_origin, vec3 line_dir, vec3 plane_origin, vec3 plane_normal){
	return line_origin + line_dir * dot(plane_normal, plane_origin - line_origin) / dot(plane_normal, line_dir);
}

//PR__UNIFORMS_AND_FUNCTIONS__PR//

void fragment() {
	ALBEDO = vec3(1.0);
	METALLIC = 1.0;
	ROUGHNESS = 0.0;
	
	//PR__FRAGMENT_CODE__PR//
	vec3 _pr_ray_origin = CAMERA_MATRIX[3].xyz;
	vec3 _pr_plane_origin = WORLD_MATRIX[3].xyz;
	vec3 _pr_plane_normal = WORLD_MATRIX[2].xyz;
	vec3 _pr_final_normal = _pr_normal_from_normalmap(NORMALMAP, NORMAL, TANGENT, BINORMAL, NORMALMAP_DEPTH);
	if(!FRONT_FACING)
		_pr_final_normal *= -1.0;
	
	vec4 _pr_point_on_plane = CAMERA_MATRIX * vec4(VERTEX, 1.0);
	_pr_point_on_plane.xyz += reflect(mat3(CAMERA_MATRIX) * reflect(-VIEW, _pr_final_normal) * _pr_perturb_scale, _pr_plane_normal);
	_pr_point_on_plane.xyz = _pr_line_plane_intersect(_pr_ray_origin, _pr_point_on_plane.xyz - _pr_ray_origin, _pr_plane_origin, _pr_plane_normal);
	
	vec4 _pr_model_pos = inverse(WORLD_MATRIX) * _pr_point_on_plane;
	vec2 _pr_uv = (vec2(_pr_model_pos.x, -_pr_model_pos.y) - _pr_viewport_rect.xy) / _pr_viewport_rect.zw;
	
	vec4 _pr_reflection = _pr_texture_bicubic(_pr_viewport, _pr_uv);
	if(any(isnan(_pr_reflection))) {
		_pr_reflection = vec4(1.0, 1.0, 1.0, 0.0);
	}
	vec3 _pr_reflectiveness = _pr_fresnel(mix(vec3(0.16) * SPECULAR * SPECULAR, ALBEDO, METALLIC), dot(normalize(VERTEX), _pr_final_normal));
	_pr_reflectiveness *= pow(1.0 - ROUGHNESS, 4.0);
	
	ALBEDO = mix(ALBEDO, vec3(0.0), _pr_reflection.a * _pr_reflectiveness);
	ROUGHNESS = mix(ROUGHNESS, 1.0, pow(_pr_reflection.a, 4.0) * mix(_pr_reflectiveness.g, 1.0, METALLIC));
	METALLIC = mix(METALLIC, 1.0, pow(_pr_reflection.a, 4.0) * mix(_pr_reflectiveness.g, 1.0, METALLIC));
	EMISSION += _pr_reflection.rgb * _pr_reflectiveness * _pr_reflection.a;
	//PR__FRAGMENT_CODE__PR//

}
