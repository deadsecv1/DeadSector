shader_type canvas_item;

// Procedural grit for the raid view: animated film grain plus a soft
// vignette, both generated purely from noise/math - no textures needed.
// Renders as a transparent overlay (pure alpha blending), so it never
// needs to sample the screen itself.

uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 centered = UV - 0.5;
	float dist = length(centered * vec2(1.0, 0.8));
	float vignette_alpha = smoothstep(0.35, 0.82, dist) * vignette_strength;

	float grain = random(UV * 900.0 + vec2(TIME * 47.0, TIME * 31.0));
	float grain_alpha = abs(grain - 0.5) * grain_amount;

	COLOR = vec4(0.01, 0.01, 0.01, clamp(vignette_alpha + grain_alpha, 0.0, 0.92));
}
