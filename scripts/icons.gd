extends RefCounted
## Piccole icone disegnate da codice (nessun file immagine).

static var _cache: Dictionary = {}


static func lock(size: int, color: Color) -> ImageTexture:
	var key: String = "lock%d%s" % [size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s: float = size / 40.0
	for y in range(size):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5) / s
			var a: float = 0.0
			# corpo
			if p.x >= 8.0 and p.x <= 32.0 and p.y >= 18.0 and p.y <= 36.0:
				a = 1.0
			# archetto
			var d: float = p.distance_to(Vector2(20.0, 18.0))
			if p.y < 18.5 and d <= 10.0 and d >= 6.0:
				a = 1.0
			# serratura
			if p.distance_to(Vector2(20.0, 26.0)) < 2.6:
				a = 0.0
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func dot(size: int, fill: Color, border: Color, border_px: float) -> ImageTexture:
	var key: String = "dot%d%s%s%.1f" % [size, fill.to_html(), border.to_html(), border_px]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var c: Color = fill.lerp(border, clampf(d - (r - border_px), 0.0, 1.0))
			c.a = clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
