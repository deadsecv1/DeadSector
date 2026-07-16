shader_type canvas_item;

// A red vignette that's fully clear in the center and fades in toward
// the screen edges - used for the "you're taking damage" hit
// indicator. `intensity` (0-1, driven from GDScript) controls how far
// the red reaches in and how strong it gets; 0 is fully invisible.
//
// `hit_dir` (screen-space, normalized, world-space direction toward the
// attacker - the camera never rotates in this game so no transform is
// needed) biases the vignette to read stronger on the edge of the
// screen the damage actually came from. (0,0) - the default for hits
// with no known source, e.g. radiation/hunger - falls back to the
// original perfectly even ring.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_dir = vec2(0.0, 0.0);

void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float dist = length(centered);
	// Pulled the start/end points further out so only a thinner ring
	// right at the screen edges lights up, instead of creeping halfway
	// across the view - bumped the alpha up a bit to compensate so it's
	// still an unmistakable "you got hit" cue despite covering less area.
	float edge = smoothstep(0.72, 1.25, dist);
	float directional_boost = 1.0;
	float hit_dir_len = length(hit_dir);
	if (hit_dir_len > 0.01 && dist > 0.01) {
		float align = dot(centered / dist, hit_dir / hit_dir_len);
		directional_boost = mix(0.35, 1.7, smoothstep(-0.3, 1.0, align));
	}
	float alpha = edge * intensity * 0.78 * directional_boost;
	COLOR = vec4(0.85, 0.05, 0.05, alpha);
}
