shader_type canvas_item;

// Masks a texture to a rounded rectangle - used for the Global Chat
// background gradient, which was a plain hard-cornered rect before.
// rect_size must be kept in sync with the node's actual pixel size
// from GDScript (Control doesn't expose that to shaders on its own).

uniform vec2 rect_size = vec2(200.0, 40.0);
uniform float radius = 10.0;

// Standard rounded-box signed distance field (Inigo Quilez's formula):
// distance from p to the edge of a box of half-size b with corner
// radius r, centered at the origin. Negative inside, positive outside.
float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 half_size = rect_size * 0.5;
	float d = sd_rounded_box(p, half_size, radius);
	// ~1.5px antialiased falloff at the edge instead of a hard cutoff.
	float alpha = 1.0 - smoothstep(-1.5, 1.5, d);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
