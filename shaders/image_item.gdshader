shader_type spatial;

uniform vec3 background : source_color;
uniform sampler2D texture_albedo : hint_default_white;

void fragment() {
  vec4 tex_color = texture(texture_albedo, UV);
  ALBEDO = mix(background, tex_color.rgb, tex_color.a);
}
