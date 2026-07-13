shader_type canvas_item;

// A blood stain with an irregular, organic edge - generated purely from
// value noise, no texture asset needed. Each instance gets a different
// seed so no two stains look identical.

uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1)) + seed) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.2;
	float n = value_noise(UV * 5.5) * 0.5 + value_noise(UV * 13.0) * 0.3;
	float edge = 0.7 + n * 0.55;
	float mask = 1.0 - smoothstep(edge - 0.18, edge, dist);
	vec3 blood_color = mix(vec3(0.22, 0.015, 0.015), vec3(0.42, 0.05, 0.04), n);
	COLOR = vec4(blood_color, mask * 0.8 * COLOR.a);
}
