extends RefCounted

# Rectangles and returned platform segments use world-window local coordinates.
# Window records must be in compositor front-to-back order.
static func visible_tops(windows: Array, screen_rect: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var occluders: Array[Rect2] = []
	for record: Dictionary in windows:
		var rect: Rect2 = record["bounds"]
		if not rect.intersects(screen_rect):
			continue
		var visible := rect.intersection(screen_rect)
		if rect.position.y >= screen_rect.position.y and rect.position.y < screen_rect.end.y - 8:
			var spans: Array[Vector2] = [Vector2(visible.position.x, visible.end.x)]
			for cover: Rect2 in occluders:
				if cover.position.y <= rect.position.y and cover.end.y > rect.position.y:
					spans = subtract_interval(spans, Vector2(cover.position.x, cover.end.x))
			for span: Vector2 in spans:
				if span.y - span.x >= 12:
					result.append(Rect2(span.x, rect.position.y, span.y - span.x, 4))
		occluders.append(visible)
	return result

static func subtract_interval(spans: Array[Vector2], cover: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for span: Vector2 in spans:
		if cover.y <= span.x or cover.x >= span.y:
			result.append(span)
			continue
		if cover.x > span.x:
			result.append(Vector2(span.x, minf(cover.x, span.y)))
		if cover.y < span.y:
			result.append(Vector2(maxf(cover.y, span.x), span.y))
	return result

static func map_rect(rect: Rect2, native_screen: Rect2, world_size: Vector2) -> Rect2:
	var ratio := world_size / native_screen.size
	return Rect2((rect.position - native_screen.position) * ratio, rect.size * ratio)

static func local_to_desktop(local: Vector2, origin: Vector2) -> Vector2:
	return local + origin

static func desktop_to_local(desktop: Vector2, origin: Vector2) -> Vector2:
	return desktop - origin
