shader_type canvas_item;

// A red vignette that's fully clear in the center and fades in toward
// the screen edges - used for the "you're taking damage" hit
// indicator. `intensity` (0-1, driven from GDScript) controls how far
// the red reaches in and how strong it gets; 0 is fully invisible.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float dist = length(centered);
	// Pulled the start/end points further out so only a thinner ring
	// right at the screen edges lights up, instead of creeping halfway
	// across the view - bumped the alpha up a bit to compensate so it's
	// still an unmistakable "you got hit" cue despite covering less area.
	float edge = smoothstep(0.72, 1.25, dist);
	float alpha = edge * intensity * 0.78;
	COLOR = vec4(0.85, 0.05, 0.05, alpha);
}
