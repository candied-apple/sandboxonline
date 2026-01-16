shader_type sky;

uniform vec3 day_top_color : source_color = vec3(0.1, 0.6, 1.0);
uniform vec3 day_bottom_color : source_color = vec3(0.4, 0.8, 1.0);
uniform vec3 night_top_color : source_color = vec3(0.02, 0.02, 0.05);
uniform vec3 night_bottom_color : source_color = vec3(0.1, 0.1, 0.2);

uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_size : hint_range(0.01, 0.5) = 0.05;
uniform float sun_blur : hint_range(0.01, 0.5) = 0.01;

uniform vec3 moon_color : source_color = vec3(0.8, 0.8, 0.9);
uniform float moon_size : hint_range(0.01, 0.5) = 0.04;

uniform float clouds_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float clouds_offset : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_eye_dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = EYEDIR;
	float horizon = clamp(dir.y * 2.0 + 0.1, 0.0, 1.0);
	
	// Sun & Moon position based on LIGHT0_DIRECTION (we'll set this from GDScript)
	float sun_dot = dot(dir, LIGHT0_DIRECTION);
	float moon_dot = dot(dir, -LIGHT0_DIRECTION);
	
	vec3 sky_color = mix(mix(night_bottom_color, night_top_color, horizon), 
						 mix(day_bottom_color, day_top_color, horizon), 
						 clamp(LIGHT0_DIRECTION.y * 5.0, 0.0, 1.0));
	
	// Sun
	float sun = smoothstep(1.0 - sun_size - sun_blur, 1.0 - sun_size, sun_dot);
	sky_color = mix(sky_color, sun_color, sun);
	
	// Moon
	float moon = smoothstep(1.0 - moon_size - 0.01, 1.0 - moon_size, moon_dot);
	sky_color = mix(sky_color, moon_color, moon);
	
	// Clouds (Simplified Volumetric look)
	vec2 cloud_uv = dir.xz / (dir.y + 0.001);
	float cloud_noise = fbm(cloud_uv * 0.5 + TIME * 0.02 + clouds_offset);
	float cloud_mask = smoothstep(0.4, 0.7, cloud_noise * clouds_intensity);
	
	if (dir.y > 0.0) {
		vec3 cloud_color = mix(vec3(1.0), vec3(0.5), cloud_noise);
		cloud_color *= mix(vec3(0.2, 0.2, 0.3), vec3(1.0), clamp(LIGHT0_DIRECTION.y * 2.0, 0.1, 1.0));
		sky_color = mix(sky_color, cloud_color, cloud_mask * horizon);
	}
	
	COLOR = sky_color;
}
