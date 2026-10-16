shader_type canvas_item;

// A one-to-two pixel rim around a sprite's silhouette. The ground art is dark
// and busy and so are most bodies on it; the rim is what separates them.
uniform vec4 outline_color : source_color = vec4(0.95, 0.25, 0.14, 0.85);
uniform float width = 1.5;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + px * 0.7).a);
	a = max(a, texture(TEXTURE, UV - px * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
	float rim = clamp(a - base.a, 0.0, 1.0) * outline_color.a * COLOR.a;
	COLOR = vec4(mix(outline_color.rgb, base.rgb, base.a), max(base.a, rim));
}
