shader_type canvas_item;
render_mode unshaded;
uniform vec2 center = vec2(0.5);
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 delta = (SCREEN_UV - center) * viewport_size;
	float distance_px = length(delta);
	float radius = progress * length(viewport_size);
	float band = exp(-pow((distance_px - radius) / 55.0, 2.0));
	float fade = sin(progress * 3.14159265);
	vec3 rainbow = 0.5 + 0.5 * cos(vec3(0.0, 2.094, 4.189) + distance_px * 0.035 - progress * 12.0);
	float ripple = 0.7 + 0.3 * sin((distance_px - radius) * 0.09);
	COLOR = vec4(rainbow, band * fade * ripple * 0.65);
}
