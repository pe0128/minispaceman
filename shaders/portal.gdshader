shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5);
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 delta = (SCREEN_UV - center) * viewport_size;
	float distance_px = length(delta);
	float radius = progress * length(viewport_size);
	float band = exp(-pow((distance_px - radius) / 55.0, 2.0));
	float fade = sin(progress * 3.14159265);
	vec2 direction = delta / max(distance_px, 1.0);
	vec2 displacement = direction * sin((distance_px - radius) * 0.09) * band * 12.0 * fade / viewport_size;
	vec3 rainbow = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.189) + distance_px * 0.035 - progress * 12.0);
	vec3 base = texture(screen_texture, SCREEN_UV + displacement).rgb;
	COLOR = vec4(mix(base, rainbow, band * fade * 0.6), 1.0);
}
