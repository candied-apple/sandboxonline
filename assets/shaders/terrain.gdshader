shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap;

uniform float uv_scale = 0.25; // Tiling scale
uniform float macro_scale = 0.02; // Macro noise scale

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	vec3 normal = abs(world_normal);
	normal /= (normal.x + normal.y + normal.z); // Normalize weights

	// Triplanar UVs
	vec3 tri_pos = world_pos * uv_scale;
	
	vec4 color = triplanar_texture(albedo_texture, normal, tri_pos);
	
	// Macro Variation
	vec3 macro_pos = world_pos * macro_scale;
	float noise_val = triplanar_texture(macro_noise, normal, macro_pos).r;
	
	// Blend noise: Darken some areas
	float variation = mix(0.6, 1.4, noise_val);
	
	ALBEDO = color.rgb * variation;
}
