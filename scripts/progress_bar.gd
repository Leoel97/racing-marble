extends Control
## Barra di avanzamento della gara: un pallino per ogni biglia.

const INK := Color(0.114, 0.169, 0.325)

var fractions: Array = []     # avanzamento 0..1 di ogni concorrente
var colors: Array = []        # colore di ogni concorrente (il giocatore e' il primo)


func set_racers(new_fractions: Array, new_colors: Array) -> void:
	fractions = new_fractions
	colors = new_colors
	queue_redraw()


func _draw() -> void:
	var pad: float = 18.0
	var y: float = size.y * 0.5
	var x0: float = pad
	var x1: float = size.x - pad
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(INK, 0.85), 14.0, true)
	draw_circle(Vector2(x0, y), 7.0, Color(INK, 0.85))
	draw_circle(Vector2(x1, y), 7.0, Color(INK, 0.85))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.35), 4.0, true)
	# bandierina del traguardo
	for row in range(3):
		for col in range(2):
			var c: Color = Color.WHITE if (row + col) % 2 == 0 else INK
			draw_rect(Rect2(x1 - 6.0 + col * 7.0, y - 10.5 + row * 7.0, 7.0, 7.0), c)
	# pallini: prima gli avversari, il giocatore per ultimo (sopra tutti)
	for n in range(fractions.size() - 1, -1, -1):
		var f: float = clampf(fractions[n], 0.0, 1.0)
		var col_n: Color = colors[n]
		var pos := Vector2(lerpf(x0, x1, f), y)
		var r: float = 13.0 if n == 0 else 9.0
		draw_circle(pos, r + 3.0, INK)
		draw_circle(pos, r, col_n)
		if n == 0:
			draw_circle(pos, 4.0, Color.WHITE)
