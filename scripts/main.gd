extends Node2D

## Portrait Flappy Bird-style game with a Radiator Springs look. Everything
## apart from the optional baby_head.png is drawn in native Godot code for
## crisp Android rendering.

const VIEW_W := 1080.0
const VIEW_H := 2400.0
const BIRD_X := 285.0
const BIRD_RADIUS := 95.0
const BIRD_HOME_Y := 1170.0
const FLOOR_Y := 2220.0
const HORIZON_Y := 1915.0
const CEILING_Y := 130.0
const PIPE_WIDTH := 250.0
const SHAFT_HALF := 103.0
const COLLAR_HALF := 112.0
const CAR_H := 180.0
const GAP_HEIGHT := 660.0
const PIPE_SPEED := 355.0
const GRAVITY := 1800.0
const FLAP_VELOCITY := -670.0
const EYE_LEFT := Vector2(-33, 42)
const EYE_RIGHT := Vector2(33, 42)

const MCQ_RED := Color("#e0141e")
const MCQ_RED_LIGHT := Color("#ff5040")
const MCQ_RED_DARK := Color("#8e0a13")
const INK := Color("#2a0708")
const BOLT_YELLOW := Color("#ffe13d")
const BOLT_ORANGE := Color("#ff7a12")
const CHROME := Color("#f1f5f8")
const CHROME_SHADE := Color("#8d98a4")
const SKY_STOPS := [[0.0, "#1b5aa8"], [850.0, "#3f9ae0"], [1450.0, "#8fcdef"], [1780.0, "#ffe0a8"], [HORIZON_Y, "#ffc98a"]]
const SHAFT_STOPS := [[-103.0, "#5e070d"], [-86.0, "#b0101a"], [-60.0, "#ff5a48"], [-38.0, "#e3141f"], [38.0, "#cc111c"], [84.0, "#980c15"], [103.0, "#55060b"]]

enum GameState { READY, PLAYING, GAME_OVER }

var state: GameState = GameState.READY
var bird_y := BIRD_HOME_Y
var bird_velocity := 0.0
var bird_angle := 0.0
var world_time := 0.0
var scroll := 0.0
var score := 0
var best_score := 0
var run_start_best := 0
var new_best := false
var pipes: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var shake := 0.0
var flash := 0.0
var cam := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var voice_rng := RandomNumberGenerator.new()
var baby_texture: Texture2D
var font: Font
var title_font: FontVariation
var bold_font: FontVariation
var score_voice_player: AudioStreamPlayer
var failure_voice_player: AudioStreamPlayer
var score_voice_streams: Array[AudioStream] = [
	preload("res://assets/sfx/mama.wav"),
	preload("res://assets/sfx/dada.wav"),
	preload("res://assets/sfx/mcqueen.wav"),
	preload("res://assets/sfx/cars.wav"),
	preload("res://assets/sfx/mater.wav"),
	preload("res://assets/sfx/chef.wav"),
	preload("res://assets/sfx/red.wav"),
	preload("res://assets/sfx/fire_truck.wav"),
	preload("res://assets/sfx/yeah.wav"),
]
var failure_voice_stream: AudioStream = preload("res://assets/sfx/dat_one.wav")

# Shapes are built once in local coordinates and placed with draw transforms.
var car_body: PackedVector2Array
var car_cabin: PackedVector2Array
var car_windshield: PackedVector2Array
var car_hitbox: PackedVector2Array
var eye_shape: PackedVector2Array
var lid_left: PackedVector2Array
var lid_right: PackedVector2Array
var mouth_shape: PackedVector2Array
var teeth_shape: PackedVector2Array
var tongue_shape: PackedVector2Array
var bolt_shape: PackedVector2Array
var bolt_border: PackedVector2Array
var shield_shape: PackedVector2Array
var far_mesas: Array[PackedVector2Array] = []
var cadillac_fins: Array[PackedVector2Array] = []
var logo_layers: Array = []
var number_layers: Array = []
var chrome_layers: Array = []
var card_box: StyleBoxFlat
var button_box: StyleBoxFlat
var gloss_box: StyleBoxFlat
var rusteze_box: StyleBoxFlat
var lightyear_box: StyleBoxFlat
var cactus_box: StyleBoxFlat

func _ready() -> void:
	font = ThemeDB.fallback_font
	title_font = FontVariation.new()
	title_font.base_font = font
	title_font.variation_embolden = 1.1
	title_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	bold_font = FontVariation.new()
	bold_font.base_font = font
	bold_font.variation_embolden = 0.7
	rng.seed = 4815162342
	voice_rng.randomize()
	score_voice_player = AudioStreamPlayer.new()
	score_voice_player.name = "ScoreVoice"
	score_voice_player.volume_db = -2.0
	add_child(score_voice_player)
	failure_voice_player = AudioStreamPlayer.new()
	failure_voice_player.name = "FailureVoice"
	failure_voice_player.stream = failure_voice_stream
	failure_voice_player.volume_db = 1.0
	add_child(failure_voice_player)
	_load_best_score()
	if ResourceLoader.exists("res://assets/baby_head.png"):
		baby_texture = load("res://assets/baby_head.png") as Texture2D
	_build_shapes()
	_build_styles()
	_spawn_pipe(1260.0)
	_spawn_pipe(1930.0)
	queue_redraw()

func _build_shapes() -> void:
	car_body = PackedVector2Array([Vector2(-116, 70), Vector2(116, 70), Vector2(128, 84), Vector2(132, 126), Vector2(124, 150), Vector2(-124, 150), Vector2(-132, 126), Vector2(-128, 84)])
	car_cabin = PackedVector2Array([Vector2(-58, 2), Vector2(58, 2), Vector2(70, 8), Vector2(102, 74), Vector2(-102, 74), Vector2(-70, 8)])
	car_windshield = PackedVector2Array([Vector2(-50, 12), Vector2(50, 12), Vector2(82, 68), Vector2(-82, 68)])
	car_hitbox = PackedVector2Array([Vector2(-58, 2), Vector2(58, 2), Vector2(70, 8), Vector2(102, 70), Vector2(128, 84), Vector2(134, 126), Vector2(134, 178), Vector2(-134, 178), Vector2(-134, 126), Vector2(-128, 84), Vector2(-102, 70), Vector2(-70, 8)])
	eye_shape = _ellipse(Vector2.ZERO, Vector2(27, 22), 32)
	# Upper lids slope down toward the nose for McQueen's determined look.
	var lid_cut := PackedVector2Array([Vector2(-70, 0), Vector2(4, 0), Vector2(4, 36), Vector2(-70, 25)])
	lid_left = Geometry2D.intersect_polygons(Transform2D(0.0, EYE_LEFT) * eye_shape, lid_cut)[0]
	lid_right = PackedVector2Array()
	for point in lid_left:
		lid_right.append(Vector2(-point.x, point.y))
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var teeth_lower := PackedVector2Array()
	for i in range(17):
		var t := -1.0 + i / 8.0
		var top_y := 112.0 + 4.0 * (1.0 - t * t)
		var bottom_y := 112.0 + 32.0 * (1.0 - t * t)
		upper.append(Vector2(64.0 * t, top_y))
		lower.append(Vector2(64.0 * t, bottom_y))
		teeth_lower.append(Vector2(64.0 * t, top_y + minf(9.0, (bottom_y - top_y) * 0.42)))
	lower.reverse()
	teeth_lower.reverse()
	mouth_shape = upper + lower
	teeth_shape = upper + teeth_lower
	tongue_shape = _ellipse(Vector2(0, 137.5), Vector2(22, 6.5), 20)
	bolt_shape = PackedVector2Array([Vector2(-55, 0), Vector2(60, 0), Vector2(18, 150), Vector2(78, 150), Vector2(-60, 420), Vector2(-10, 220), Vector2(-72, 220)])
	bolt_border = Geometry2D.offset_polygon(bolt_shape, 8.0, Geometry2D.JOIN_MITER)[0]
	shield_shape = PackedVector2Array([Vector2(-44, -52), Vector2(-30, -46), Vector2(-15, -54), Vector2(0, -47), Vector2(15, -54), Vector2(30, -46), Vector2(44, -52), Vector2(46, -20), Vector2(36, 14), Vector2(0, 50), Vector2(-36, 14), Vector2(-46, -20)])
	far_mesas = [
		PackedVector2Array([Vector2(10, 1925), Vector2(34, 1790), Vector2(66, 1764), Vector2(214, 1764), Vector2(238, 1800), Vector2(256, 1925)]),
		PackedVector2Array([Vector2(318, 1925), Vector2(344, 1690), Vector2(368, 1668), Vector2(440, 1668), Vector2(460, 1700), Vector2(474, 1925)]),
		PackedVector2Array([Vector2(560, 1925), Vector2(588, 1812), Vector2(624, 1796), Vector2(830, 1796), Vector2(862, 1832), Vector2(880, 1925)]),
		PackedVector2Array([Vector2(930, 1925), Vector2(958, 1726), Vector2(984, 1710), Vector2(1036, 1710), Vector2(1058, 1738), Vector2(1074, 1925)]),
	]
	# Cadillac Range: a row of tail-fin rocks leaning the same way.
	cadillac_fins = []
	var heights := [190.0, 250.0, 290.0, 270.0, 230.0, 175.0]
	for i in range(heights.size()):
		var base_x := 560.0 + i * 68.0
		var h: float = heights[i]
		cadillac_fins.append(PackedVector2Array([Vector2(base_x, 1940), Vector2(base_x + 10, 1940 - h * 0.55), Vector2(base_x + 34, 1940 - h), Vector2(base_x + 50, 1940 - h + 22), Vector2(base_x + 56, 1940 - h * 0.45), Vector2(base_x + 60, 1940)]))
	logo_layers = [
		[Vector2(8, 12), 58, Color(0.16, 0.04, 0.02, 0.5)],
		[Vector2.ZERO, 58, INK],
		[Vector2(0, 5), 40, CHROME_SHADE],
		[Vector2(0, -1), 38, CHROME],
		[Vector2.ZERO, 18, Color("#ffb51f")],
		[Vector2(0, 4), 0, MCQ_RED_DARK],
		[Vector2(0, -3), 0, Color("#ff7b5c")],
		[Vector2.ZERO, 0, MCQ_RED],
	]
	number_layers = [
		[Vector2(5, 8), 40, Color(0.12, 0.02, 0.02, 0.45)],
		[Vector2.ZERO, 40, INK],
		[Vector2.ZERO, 24, MCQ_RED],
		[Vector2(0, 5), 0, BOLT_ORANGE],
		[Vector2(0, -1), 0, BOLT_YELLOW],
	]
	chrome_layers = [
		[Vector2(0, 4), 18, Color(0, 0, 0, 0.45)],
		[Vector2.ZERO, 16, INK],
		[Vector2(0, 3), 0, CHROME_SHADE],
		[Vector2.ZERO, 0, CHROME],
	]

func _build_styles() -> void:
	card_box = _rounded_box(Color(0.08, 0.085, 0.11, 0.95), Color("#ffc21a"), 40, 7)
	card_box.shadow_color = Color(0, 0, 0, 0.45)
	card_box.shadow_size = 24
	card_box.shadow_offset = Vector2(0, 14)
	button_box = _rounded_box(MCQ_RED, Color("#ffc21a"), 70, 9)
	button_box.shadow_color = Color(0.16, 0.03, 0.02, 0.55)
	button_box.shadow_size = 6
	button_box.shadow_offset = Vector2(0, 12)
	gloss_box = _rounded_box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 40, 0)
	rusteze_box = _rounded_box(Color("#f5e4bb"), Color("#7a2c10"), 16, 5)
	lightyear_box = _rounded_box(Color("#15161b"), Color("#ffd23f"), 26, 3)
	cactus_box = _rounded_box(Color("#4f8a3c"), Color("#2f5c26"), 18, 3)

func _load_best_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://g_mcqueen.cfg") == OK:
		best_score = int(cfg.get_value("scores", "best", 0))

func _save_best_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save("user://g_mcqueen.cfg")

func _process(delta: float) -> void:
	var dt := minf(delta, 0.045)
	world_time += dt
	shake = maxf(0.0, shake - dt * 5.5)
	flash = maxf(0.0, flash - dt * 2.2)
	_update_particles(dt)
	if state != GameState.GAME_OVER:
		scroll += PIPE_SPEED * dt
	if state == GameState.PLAYING:
		bird_velocity += GRAVITY * dt
		bird_y += bird_velocity * dt
		bird_angle = lerpf(bird_angle, clampf(bird_velocity / 1050.0, -0.55, 1.12), dt * 8.0)
		for pipe in pipes:
			pipe.x = float(pipe.x) - PIPE_SPEED * dt
			if not pipe.passed and pipe.x + PIPE_WIDTH < BIRD_X - BIRD_RADIUS:
				pipe.passed = true
				score += 1
				if score > best_score:
					best_score = score
				_save_best_score()
				_play_random_score_voice()
				_spawn_score_burst(pipe.x + PIPE_WIDTH * 0.5, float(pipe.gap_y))
		if pipes.size() > 0 and float(pipes[0].x) < -PIPE_WIDTH - 80.0:
			pipes.pop_front()
		if pipes.size() == 0 or float(pipes[-1].x) < 680.0:
			_spawn_pipe(1260.0)
		if bird_y - BIRD_RADIUS < CEILING_Y or bird_y + BIRD_RADIUS > FLOOR_Y:
			_end_game()
		else:
			_check_pipe_collision()
	elif state == GameState.READY:
		bird_y = BIRD_HOME_Y + sin(world_time * 2.2) * 24.0
		bird_angle = sin(world_time * 2.2) * 0.035
	elif state == GameState.GAME_OVER:
		bird_velocity += GRAVITY * dt
		bird_y = minf(FLOOR_Y - BIRD_RADIUS, bird_y + bird_velocity * dt)
		bird_angle = minf(1.35, bird_angle + dt * 1.8)
	queue_redraw()

func _spawn_pipe(x: float) -> void:
	pipes.append({"x": x, "gap_y": rng.randf_range(770.0, 1510.0), "passed": false})

func _car_y(gap_y: float, top: bool) -> float:
	return gap_y - GAP_HEIGHT * 0.5 - CAR_H if top else gap_y + GAP_HEIGHT * 0.5

func _check_pipe_collision() -> void:
	var bird := Vector2(BIRD_X, bird_y)
	for pipe in pipes:
		var cx := float(pipe.x) + PIPE_WIDTH * 0.5
		if absf(bird.x - cx) > 140.0 + BIRD_RADIUS:
			continue
		for top: bool in [true, false]:
			var car_y := _car_y(float(pipe.gap_y), top)
			var shaft := Rect2(cx - SHAFT_HALF, -400.0, SHAFT_HALF * 2.0, car_y + 400.0) if top else Rect2(cx - SHAFT_HALF, car_y + CAR_H, SHAFT_HALF * 2.0, FLOOR_Y - car_y - CAR_H)
			if _circle_hits_rect(bird, shaft) or _circle_hits_polygon(bird - Vector2(cx, car_y), car_hitbox):
				_end_game(true)
				return

func _circle_hits_rect(center: Vector2, rect: Rect2) -> bool:
	var closest := center.clamp(rect.position, rect.end)
	return center.distance_squared_to(closest) < BIRD_RADIUS * BIRD_RADIUS

func _circle_hits_polygon(center: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for i in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(center, polygon[i], polygon[(i + 1) % polygon.size()])
		if center.distance_squared_to(closest) < BIRD_RADIUS * BIRD_RADIUS:
			return true
	return false

func _end_game(hit_pillar: bool = false) -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
	new_best = score > run_start_best
	if hit_pillar:
		failure_voice_player.play()
	shake = 1.0
	flash = 1.0
	_spawn_crash_burst()
	_save_best_score()

func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
	if not pressed:
		return
	if state == GameState.GAME_OVER:
		_restart_game()
		return
	if state == GameState.READY:
		state = GameState.PLAYING
		run_start_best = best_score
	bird_velocity = FLAP_VELOCITY
	_spawn_flap_particles()

func _restart_game() -> void:
	failure_voice_player.stop()
	state = GameState.PLAYING
	score = 0
	run_start_best = best_score
	bird_y = BIRD_HOME_Y
	bird_velocity = FLAP_VELOCITY
	bird_angle = -0.25
	pipes.clear()
	_spawn_pipe(1260.0)
	_spawn_pipe(1930.0)
	particles.clear()
	_spawn_flap_particles()

func _spawn_flap_particles() -> void:
	for i in range(8):
		particles.append({"p": Vector2(BIRD_X - 64.0, bird_y + rng.randf_range(-35.0, 35.0)), "v": Vector2(rng.randf_range(-150.0, -30.0), rng.randf_range(-120.0, 120.0)), "life": 0.55, "max": 0.55, "c": Color("#ffd166")})

func _spawn_score_burst(x: float, y: float) -> void:
	for i in range(14):
		particles.append({"p": Vector2(x, y), "v": Vector2(rng.randf_range(-170.0, 170.0), rng.randf_range(-170.0, 170.0)), "life": 0.8, "max": 0.8, "c": [BOLT_YELLOW, BOLT_ORANGE][i % 2]})

func _play_random_score_voice() -> void:
	if score_voice_streams.is_empty():
		return
	score_voice_player.stream = score_voice_streams[voice_rng.randi_range(0, score_voice_streams.size() - 1)]
	score_voice_player.pitch_scale = voice_rng.randf_range(0.97, 1.04)
	score_voice_player.play()

func _spawn_crash_burst() -> void:
	for i in range(24):
		particles.append({"p": Vector2(BIRD_X, bird_y), "v": Vector2(rng.randf_range(-370.0, 370.0), rng.randf_range(-430.0, 260.0)), "life": rng.randf_range(0.45, 1.0), "max": 1.0, "c": [Color("#ff4d3d"), Color("#ffd166"), Color("#ffffff")][i % 3]})

func _update_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.p = particle.p + particle.v * dt
		particle.v = particle.v + Vector2(0, 300) * dt
		particle.life = float(particle.life) - dt
		particles[i] = particle
		if float(particle.life) <= 0.0:
			particles.remove_at(i)

# --- Drawing helpers -------------------------------------------------------

func _xf(origin: Vector2, rotation_angle := 0.0, scale_by := Vector2.ONE) -> void:
	draw_set_transform(cam + origin, rotation_angle, scale_by)

func _reset_xf() -> void:
	draw_set_transform(cam, 0.0, Vector2.ONE)

func _rounded_box(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box

func _ellipse(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * i / segments
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _grad_poly(points: PackedVector2Array, from: Color, to: Color, horizontal := false) -> void:
	var lo := INF
	var hi := -INF
	for p in points:
		var v := p.x if horizontal else p.y
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var colors := PackedColorArray()
	for p in points:
		colors.append(from.lerp(to, inverse_lerp(lo, hi, p.x if horizontal else p.y)))
	draw_polygon(points, colors)

func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _vgrad_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))

func _layered_text(f: Font, center_x: float, baseline_y: float, text: String, size: int, layers: Array) -> void:
	for layer in layers:
		var pos := Vector2(center_x - 1000.0, baseline_y) + (layer[0] as Vector2)
		if int(layer[1]) > 0:
			draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 2000.0, size, int(layer[1]), layer[2])
		else:
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 2000.0, size, layer[2])

func _race_number(center: Vector2, text: String, size: int) -> void:
	_layered_text(title_font, center.x, center.y + size * 0.36, text, size, number_layers)

func _chrome_text(center: Vector2, text: String, size: int) -> void:
	_layered_text(bold_font, center.x, center.y + size * 0.36, text, size, chrome_layers)

## Cars-movie style title: chrome-rimmed red italic letters set on an arch.
func _draw_cars_logo(center: Vector2, text: String, size: int, arch: float, max_width: float) -> void:
	var total := title_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var fit := minf(1.0, max_width / total)
	var half := total * fit * 0.5
	var radius := (half * half + arch * arch) / (2.0 * arch)
	var glyphs: Array = []
	for i in range(text.length()):
		var ch := text[i]
		if ch == " ":
			continue
		var left := title_font.get_string_size(text.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var width := title_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var along := (left + width * 0.5) * fit - half
		var angle := along / radius
		glyphs.append([ch, width, center + Vector2(sin(angle) * radius, radius - cos(angle) * radius), angle])
	for layer in logo_layers:
		for glyph in glyphs:
			_xf(glyph[2], glyph[3], Vector2(fit, fit))
			var pos := Vector2(-float(glyph[1]) * 0.5, size * 0.36) + (layer[0] as Vector2)
			if int(layer[1]) > 0:
				draw_string_outline(title_font, pos, glyph[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(layer[1]), layer[2])
			else:
				draw_string(title_font, pos, glyph[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, layer[2])
	_reset_xf()

# --- Scene -----------------------------------------------------------------

func _draw() -> void:
	cam = Vector2.ZERO
	if shake > 0.0:
		cam = Vector2(sin(world_time * 61.0), cos(world_time * 73.0)) * shake * 9.0
	_reset_xf()
	_draw_background()
	for pipe in pipes:
		_draw_mcqueen_pillar(float(pipe.x), float(pipe.gap_y), true)
		_draw_mcqueen_pillar(float(pipe.x), float(pipe.gap_y), false)
	_draw_floor()
	for particle in particles:
		var alpha := clampf(float(particle.life) / float(particle.max), 0.0, 1.0)
		draw_circle(particle.p, 9.0 * alpha + 2.0, Color(particle.c, alpha))
	_draw_bird()
	match state:
		GameState.READY:
			_draw_title_menu()
		GameState.PLAYING:
			_draw_play_hud()
		GameState.GAME_OVER:
			_draw_race_over()
	if flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(1, 0.22, 0.18, flash * 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _parallax(factor: float) -> float:
	return -fposmod(scroll * factor, VIEW_W)

func _draw_background() -> void:
	for i in range(SKY_STOPS.size() - 1):
		_vgrad_rect(Rect2(-20, SKY_STOPS[i][0], VIEW_W + 40, SKY_STOPS[i + 1][0] - SKY_STOPS[i][0]), Color(SKY_STOPS[i][1]), Color(SKY_STOPS[i + 1][1]))
	draw_circle(Vector2(790, 1640), 230, Color(1, 0.93, 0.7, 0.18))
	draw_circle(Vector2(790, 1640), 120, Color("#fff4cf"))
	for i in range(5):
		var cloud_x := fposmod(140.0 + i * 310.0 - world_time * 14.0 - scroll * 0.03, VIEW_W + 420.0) - 210.0
		_draw_cloud(Vector2(cloud_x, 300.0 + float((i * 263) % 700)), 0.8 + 0.12 * (i % 3))
	var far := _parallax(0.06)
	for tile in range(2):
		_xf(Vector2(far + tile * VIEW_W, 0))
		for mesa in far_mesas:
			_grad_poly(mesa, Color("#f2b583"), Color("#c97b52"))
			draw_polyline(PackedVector2Array([mesa[1], mesa[2], mesa[3], mesa[4]]), Color("#ffd2a3"), 5, true)
	var mid := _parallax(0.14)
	for tile in range(2):
		_xf(Vector2(mid + tile * VIEW_W, 0))
		_grad_poly(PackedVector2Array([Vector2(520, 1950), Vector2(560, 1872), Vector2(1000, 1872), Vector2(1040, 1950)]), Color("#c4643a"), Color("#9c4527"))
		for fin in cadillac_fins:
			_grad_poly(fin, Color("#e07a45"), Color("#a5472a"))
			draw_polyline(PackedVector2Array([fin[1], fin[2], fin[3]]), Color("#f7a46a"), 5, true)
		_grad_poly(PackedVector2Array([Vector2(60, 1950), Vector2(92, 1846), Vector2(118, 1830), Vector2(208, 1830), Vector2(230, 1858), Vector2(260, 1950)]), Color("#d06d3e"), Color("#a24a2a"))
	_reset_xf()
	_vgrad_rect(Rect2(-20, HORIZON_Y, VIEW_W + 40, FLOOR_Y - HORIZON_Y), Color("#f0b878"), Color("#d98a4a"))
	for band in range(4):
		draw_rect(Rect2(-20, HORIZON_Y + 30.0 + band * 72.0, VIEW_W + 40, 6), Color(0.72, 0.4, 0.2, 0.18))
	var near := _parallax(0.45)
	for tile in range(2):
		var base := near + tile * VIEW_W
		_draw_cactus(Vector2(base + 120, 2120), 1.0)
		_draw_cactus(Vector2(base + 520, 2060), 0.7)
		_draw_route_66_sign(Vector2(base + 850, 2010))
		for bush: Vector2 in [Vector2(300, 2150), Vector2(690, 2110), Vector2(980, 2170)]:
			draw_circle(Vector2(base, 0) + bush, 20, Color("#9c8d4c"))
			draw_circle(Vector2(base + 18, 6) + bush, 14, Color("#8a7c40"))

func _draw_cloud(pos: Vector2, size: float) -> void:
	for puff: Vector3 in [Vector3(-70, 14, 40), Vector3(-25, -12, 56), Vector3(32, -4, 50), Vector3(78, 14, 36)]:
		draw_circle(pos + Vector2(puff.x, puff.y + 8) * size, puff.z * size, Color("#cfe6f7"))
	for puff: Vector3 in [Vector3(-70, 14, 40), Vector3(-25, -12, 56), Vector3(32, -4, 50), Vector3(78, 14, 36)]:
		draw_circle(pos + Vector2(puff.x, puff.y) * size, puff.z * size, Color(1, 1, 1, 0.97))

func _draw_cactus(base: Vector2, size: float) -> void:
	_xf(base, 0.0, Vector2(size, size))
	cactus_box.draw(get_canvas_item(), Rect2(-18, -170, 36, 175))
	cactus_box.draw(get_canvas_item(), Rect2(-62, -110, 28, 70))
	cactus_box.draw(get_canvas_item(), Rect2(-62, -62, 60, 26))
	cactus_box.draw(get_canvas_item(), Rect2(34, -140, 28, 80))
	cactus_box.draw(get_canvas_item(), Rect2(4, -82, 58, 26))
	_reset_xf()

func _draw_route_66_sign(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 5, pos.y, 10, 120), Color("#6b5a48"))
	_xf(pos)
	draw_colored_polygon(Geometry2D.offset_polygon(shield_shape, 6.0)[0], Color("#16171b"))
	draw_colored_polygon(shield_shape, Color("#fbfbf7"))
	draw_string(bold_font, Vector2(-44, -24), "ROUTE", HORIZONTAL_ALIGNMENT_CENTER, 88, 15, Color("#16171b"))
	draw_string(bold_font, Vector2(-44, 22), "66", HORIZONTAL_ALIGNMENT_CENTER, 88, 46, Color("#16171b"))
	_reset_xf()

func _draw_floor() -> void:
	_vgrad_rect(Rect2(-20, FLOOR_Y, VIEW_W + 40, VIEW_H - FLOOR_Y), Color("#3a3b42"), Color("#1d1e23"))
	var curb_offset := -fposmod(scroll, 140.0)
	for i in range(10):
		var curb_x := curb_offset + i * 140.0 - 20.0
		draw_rect(Rect2(curb_x, FLOOR_Y, 70, 30), Color("#e3241f"))
		draw_rect(Rect2(curb_x + 70, FLOOR_Y, 70, 30), Color("#f4f1ea"))
	draw_rect(Rect2(-20, FLOOR_Y + 30, VIEW_W + 40, 6), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-20, FLOOR_Y + 48, VIEW_W + 40, 5), Color(1, 1, 1, 0.45))
	var dash_offset := -fposmod(scroll, 180.0)
	for i in range(8):
		draw_rect(Rect2(dash_offset + i * 180.0, FLOOR_Y + 108, 100, 12), Color("#f6c432"))

# --- McQueen pillars -------------------------------------------------------

func _draw_mcqueen_pillar(x: float, gap_y: float, top: bool) -> void:
	var cx := x + PIPE_WIDTH * 0.5
	var car_y := _car_y(gap_y, top)
	var shaft_from := -40.0 if top else car_y + CAR_H
	var shaft_to := car_y if top else FLOOR_Y
	for i in range(SHAFT_STOPS.size() - 1):
		var x0: float = cx + SHAFT_STOPS[i][0]
		var x1: float = cx + SHAFT_STOPS[i + 1][0]
		var c0 := Color(SHAFT_STOPS[i][1])
		var c1 := Color(SHAFT_STOPS[i + 1][1])
		draw_polygon(PackedVector2Array([Vector2(x0, shaft_from), Vector2(x1, shaft_from), Vector2(x1, shaft_to), Vector2(x0, shaft_to)]), PackedColorArray([c0, c1, c1, c0]))
	var dir := -1.0 if top else 1.0
	var start_y := car_y if top else car_y + CAR_H
	_draw_shaft_decals(cx, start_y, dir)
	var collar_y := car_y - 12.0 if top else car_y + CAR_H - 8.0
	draw_polygon(PackedVector2Array([Vector2(cx - COLLAR_HALF, collar_y), Vector2(cx + COLLAR_HALF, collar_y), Vector2(cx + COLLAR_HALF, collar_y + 22), Vector2(cx - COLLAR_HALF, collar_y + 22)]), PackedColorArray([CHROME, CHROME_SHADE, Color("#5d6670"), Color("#c9d1d8")]))
	draw_rect(Rect2(cx - COLLAR_HALF, collar_y, COLLAR_HALF * 2.0, 22), INK, false, 3.0)
	_draw_mcqueen_face(Vector2(cx, car_y))

## Side livery read along the pillar: race number, lightning bolt, sponsors.
func _draw_shaft_decals(cx: float, start_y: float, dir: float) -> void:
	_race_number(Vector2(cx - 4, start_y + dir * 120.0), "95", 118)
	var bolt_start := start_y + dir * 215.0
	_xf(Vector2(cx, bolt_start), 0.0, Vector2(1.0, dir))
	draw_colored_polygon(bolt_border, INK)
	_grad_poly(bolt_shape, BOLT_YELLOW, BOLT_ORANGE)
	_reset_xf()
	var rusteze_y := start_y + dir * 720.0
	rusteze_box.draw(get_canvas_item(), Rect2(cx - 88, rusteze_y - 32, 176, 64))
	draw_string(bold_font, Vector2(cx - 88, rusteze_y + 12), "RUST-EZE", HORIZONTAL_ALIGNMENT_CENTER, 176, 32, Color("#a3330f"))
	var lightyear_y := start_y + dir * 815.0
	lightyear_box.draw(get_canvas_item(), Rect2(cx - 84, lightyear_y - 25, 168, 50))
	draw_string(title_font, Vector2(cx - 84, lightyear_y + 10), "LIGHTYEAR", HORIZONTAL_ALIGNMENT_CENTER, 168, 27, Color("#ffd23f"))

## Front view of McQueen: eyes in the windshield and a grin in the bumper.
func _draw_mcqueen_face(origin: Vector2) -> void:
	_xf(origin)
	for side: float in [-1.0, 1.0]:
		var tire := Rect2(side * 112.0 - 24.0, 112, 48, 66)
		draw_rect(tire, Color("#111317"))
		for tread in range(5):
			draw_line(Vector2(tire.position.x + 4, 152 + tread * 6), Vector2(tire.end.x - 4, 152 + tread * 6), Color("#2e323a"), 2)
	_grad_poly(car_body, MCQ_RED_LIGHT, MCQ_RED_DARK)
	_outline(car_body, INK, 3)
	_grad_poly(car_cabin, MCQ_RED_LIGHT, MCQ_RED)
	_outline(car_cabin, INK, 3)
	_grad_poly(car_windshield, Color("#8ccaf0"), Color("#eaf8ff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-40, 14), Vector2(-18, 14), Vector2(-54, 66), Vector2(-76, 66)]), Color(1, 1, 1, 0.35))
	var look := (Vector2(BIRD_X, bird_y) - origin - Vector2(0, 42)).limit_length(1.0)
	var iris_offset := Vector2(look.x * 8.0, look.y * 5.0)
	for eye: Vector2 in [EYE_LEFT, EYE_RIGHT]:
		draw_colored_polygon(Transform2D(0.0, eye) * eye_shape, Color("#fdfdf8"))
		draw_circle(eye + iris_offset, 13.5, Color("#1d4f99"))
		draw_circle(eye + iris_offset, 10.5, Color("#3d8ff0"))
		draw_circle(eye + iris_offset, 6.0, Color("#0b0d12"))
		draw_circle(eye + iris_offset + Vector2(-4, -4), 3.2, Color.WHITE)
		_outline(Transform2D(0.0, eye) * eye_shape, INK, 2.5)
	for lid: PackedVector2Array in [lid_left, lid_right]:
		draw_colored_polygon(lid, MCQ_RED)
		_outline(lid, INK, 2.5)
	_outline(car_windshield, INK, 3)
	for side: float in [-1.0, 1.0]:
		var outer := PackedVector2Array([Vector2(side * 114, 88), Vector2(side * 74, 92), Vector2(side * 78, 108), Vector2(side * 116, 104)])
		draw_colored_polygon(outer, Color("#ffd84a"))
		draw_colored_polygon(PackedVector2Array([Vector2(side * 106, 92), Vector2(side * 82, 95), Vector2(side * 84, 103), Vector2(side * 108, 101)]), Color("#fffbe6"))
		_outline(outer, INK, 2)
	draw_colored_polygon(mouth_shape, Color("#3b0b12"))
	draw_colored_polygon(tongue_shape, Color("#c9485a"))
	draw_colored_polygon(teeth_shape, Color("#fbf8f0"))
	_outline(mouth_shape, INK, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(-120, 150), Vector2(120, 150), Vector2(108, 168), Vector2(-108, 168)]), MCQ_RED_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(-104, 166), Vector2(104, 166), Vector2(96, 177), Vector2(-96, 177)]), Color("#17181d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-44, 5), Vector2(34, 5), Vector2(28, 9), Vector2(-46, 9)]), Color(1, 1, 1, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(-110, 75), Vector2(-40, 75), Vector2(-48, 81), Vector2(-113, 84)]), Color(1, 1, 1, 0.3))
	_reset_xf()

func _draw_bird() -> void:
	_xf(Vector2(BIRD_X, bird_y), bird_angle)
	if baby_texture != null:
		draw_texture_rect(baby_texture, Rect2(-BIRD_RADIUS, -BIRD_RADIUS, BIRD_RADIUS * 2.0, BIRD_RADIUS * 2.0), false)
	else:
		draw_circle(Vector2.ZERO, BIRD_RADIUS, Color("#f1b28f"))
		draw_circle(Vector2(-32, -14), 12, Color("#281d25"))
		draw_circle(Vector2(32, -14), 12, Color("#281d25"))
		draw_arc(Vector2.ZERO, 34, 0.15, 3.0, 18, Color("#b6494d"), 10)
	_reset_xf()

# --- Menus and HUD ---------------------------------------------------------

func _draw_title_menu() -> void:
	_draw_cars_logo(Vector2(540, 560), "G McQUEEN", 150, 40.0, 940.0)
	_draw_race_button(Vector2(540, 1560), Vector2(640, 140), "TAP TO RACE", 64, 1.0 + sin(world_time * 4.0) * 0.03)
	if best_score > 0:
		_chrome_text(Vector2(540, 1710), "BEST  %d" % best_score, 40)

func _draw_play_hud() -> void:
	_race_number(Vector2(540, 290), str(score), 160)

func _draw_race_over() -> void:
	card_box.draw(get_canvas_item(), Rect2(140, 800, 800, 600))
	_draw_cars_logo(Vector2(540, 920), "RACE OVER", 104, 12.0, 700.0)
	_chrome_text(Vector2(360, 1040), "SCORE", 30)
	_race_number(Vector2(360, 1135), str(score), 130)
	if new_best:
		_layered_text(bold_font, 720, 1051, "NEW BEST", 30, [[Vector2.ZERO, 16, INK], [Vector2.ZERO, 0, BOLT_YELLOW]])
	else:
		_chrome_text(Vector2(720, 1040), "BEST", 30)
	_race_number(Vector2(720, 1135), str(best_score), 130)
	_draw_race_button(Vector2(540, 1295), Vector2(520, 110), "RACE AGAIN", 50, 1.0 + sin(world_time * 4.0) * 0.03)

func _draw_race_button(center: Vector2, size: Vector2, text: String, font_size: int, pulse: float) -> void:
	_xf(center, 0.0, Vector2(pulse, pulse))
	var rect := Rect2(-size * 0.5, size)
	button_box.draw(get_canvas_item(), rect)
	var gloss := Rect2(rect.position + Vector2(40, 16), Vector2(rect.size.x - 80, rect.size.y * 0.28))
	gloss_box.draw(get_canvas_item(), gloss)
	_layered_text(title_font, 0.0, font_size * 0.36, text, font_size, [[Vector2(0, 5), 16, INK], [Vector2.ZERO, 16, INK], [Vector2.ZERO, 0, Color.WHITE]])
	_reset_xf()
