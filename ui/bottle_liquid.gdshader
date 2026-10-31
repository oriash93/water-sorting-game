shader_type canvas_item;

// Draws stacked liquid layers inside a bottle. Layer boundaries are levels along
// `up` (the world's up direction in the bottle's local space), so the surface stays
// level in the world however the bottle is rotated.

const int MAX_LAYERS = 8;

uniform vec2 body_size = vec2(100.0, 100.0);
uniform vec4 interior = vec4(0.0, 0.0, 100.0, 100.0); // x0, y0, x1, y1 in local pixels
uniform float bottom_radius = 34.0;
uniform vec2 up = vec2(0.0, -1.0);
uniform int layer_count = 0;
uniform vec4 layer_colors[MAX_LAYERS];
uniform float layer_bounds[MAX_LAYERS + 1];

float bottle_distance(vec2 p) {
	vec2 center = vec2(interior.x + interior.z, interior.y + interior.w) * 0.5;
	vec2 half_size = vec2(interior.z - interior.x, interior.w - interior.y) * 0.5;
	vec2 q = p - center;
	float radius = q.y > 0.0 ? bottom_radius : 2.0;
	vec2 d = abs(q) - half_size + vec2(radius);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - radius;
}

void fragment() {
	vec2 p = UV * body_size;
	float height = dot(p, up);
	float edge = max(fwidth(height), 0.35);
	float shape_edge = max(fwidth(bottle_distance(p)), 0.35);
	float inside = 1.0 - smoothstep(-shape_edge, shape_edge, bottle_distance(p));

	vec3 color_sum = vec3(0.0);
	float coverage = 0.0;
	for (int i = 0; i < MAX_LAYERS; i++) {
		if (i >= layer_count) {
			break;
		}
		float low = i == 0 ? -100000.0 : layer_bounds[i];
		float high = layer_bounds[i + 1];
		float weight = smoothstep(low - edge, low + edge, height) * (1.0 - smoothstep(high - edge, high + edge, height));
		color_sum += layer_colors[i].rgb * weight;
		coverage += weight;
	}
	COLOR = vec4(color_sum / max(coverage, 0.0001), min(coverage, 1.0) * inside);
}
