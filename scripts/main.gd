extends Node2D

## Portrait Flappy Bird-style game. Everything apart from the optional
## baby_head.png is drawn in native Godot code for crisp Android rendering.

const VIEW_W := 1080.0
const VIEW_H := 2400.0
const BIRD_X := 285.0
const BIRD_RADIUS := 95.0
const FLOOR_Y := 2220.0
const SKYLINE_BASE_Y := 2075.0
const CEILING_Y := 130.0
const PIPE_WIDTH := 250.0
const GAP_HEIGHT := 660.0
const PIPE_SPEED := 355.0
const GRAVITY := 1800.0
const FLAP_VELOCITY := -670.0

enum GameState { READY, PLAYING, GAME_OVER }

var state: GameState = GameState.READY
var bird_y := 1170.0
var bird_velocity := 0.0
var bird_angle := 0.0
var world_time := 0.0
var score := 0
var best_score := 0
var pipes: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var shake := 0.0
var flash := 0.0
var rng := RandomNumberGenerator.new()
var voice_rng := RandomNumberGenerator.new()
var baby_texture: Texture2D
var font: Font
var score_voice_player: AudioStreamPlayer
var failure_voice_player: AudioStreamPlayer
var score_voice_streams: Array[AudioStream] = [
	preload("res://assets/sfx/mama.wav"),
	preload("res://assets/sfx/dada.wav"),
]
var failure_voice_stream: AudioStream = preload("res://assets/sfx/dat_one.wav")

func _ready() -> void:
	font = ThemeDB.fallback_font
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
	_spawn_pipe(1260.0)
	_spawn_pipe(1930.0)
	queue_redraw()

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
		bird_y = 1170.0 + sin(world_time * 2.2) * 24.0
		bird_angle = sin(world_time * 2.2) * 0.035
	elif state == GameState.GAME_OVER:
		bird_velocity += GRAVITY * dt
		bird_y = minf(FLOOR_Y - BIRD_RADIUS, bird_y + bird_velocity * dt)
		bird_angle = minf(1.35, bird_angle + dt * 1.8)
	queue_redraw()

func _spawn_pipe(x: float) -> void:
	pipes.append({"x": x, "gap_y": rng.randf_range(770.0, 1510.0), "passed": false})

func _check_pipe_collision() -> void:
	for pipe in pipes:
		var px := float(pipe.x)
		if BIRD_X + BIRD_RADIUS > px and BIRD_X - BIRD_RADIUS < px + PIPE_WIDTH:
			var gap_y := float(pipe.gap_y)
			if bird_y - BIRD_RADIUS < gap_y - GAP_HEIGHT * 0.5 or bird_y + BIRD_RADIUS > gap_y + GAP_HEIGHT * 0.5:
				_end_game(true)
				return

func _end_game(hit_pillar: bool = false) -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
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
		bird_velocity = FLAP_VELOCITY
		_spawn_flap_particles()
	else:
		bird_velocity = FLAP_VELOCITY
		_spawn_flap_particles()

func _restart_game() -> void:
	failure_voice_player.stop()
	state = GameState.PLAYING
	score = 0
	bird_y = 1170.0
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
		particles.append({"p": Vector2(x, y), "v": Vector2(rng.randf_range(-170.0, 170.0), rng.randf_range(-170.0, 170.0)), "life": 0.8, "max": 0.8, "c": Color("#ffe08a")})

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

func _draw() -> void:
	var camera_offset := Vector2.ZERO
	if shake > 0.0:
		camera_offset = Vector2(sin(world_time * 61.0), cos(world_time * 73.0)) * shake * 9.0
	draw_set_transform(camera_offset, 0.0, Vector2.ONE)
	_draw_background()
	for pipe in pipes:
		_draw_race_car_pillar(float(pipe.x), float(pipe.gap_y), true)
		_draw_race_car_pillar(float(pipe.x), float(pipe.gap_y), false)
	_draw_floor()
	for particle in particles:
		var alpha := clampf(float(particle.life) / float(particle.max), 0.0, 1.0)
		draw_circle(particle.p, 9.0 * alpha + 2.0, Color(particle.c, alpha))
	_draw_bird()
	_draw_hud()
	if flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(1, 0.22, 0.18, flash * 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color("#101a3a"))
	var bands := ["122044", "15264b", "182e55", "1d355d", "263b63", "30446b", "3b4d70", "4e5a78", "62677c", "787282", "927c82", "a68483"]
	for band in range(12):
		draw_rect(Rect2(0, band * 180.0, VIEW_W, 190.0), Color("#" + bands[band]))
	draw_circle(Vector2(815, 430), 135, Color(0.95, 0.87, 0.68, 0.10))
	draw_circle(Vector2(815, 430), 92, Color("#fbe7a9"))
	draw_circle(Vector2(850, 400), 92, Color("#27365b"))
	for star in [Vector2(92, 290), Vector2(210, 520), Vector2(970, 690), Vector2(620, 215), Vector2(470, 410), Vector2(1010, 180)]:
		draw_circle(star, 5.0, Color(1, 0.91, 0.65, 0.55 + 0.35 * sin(world_time * 2.0 + star.x)))
	var hill := PackedVector2Array([Vector2(0, 1810), Vector2(180, 1670), Vector2(345, 1810), Vector2(530, 1605), Vector2(700, 1790), Vector2(900, 1640), Vector2(1080, 1790), Vector2(1080, 2220), Vector2(0, 2220)])
	draw_colored_polygon(hill, Color("#1a3150"))
	for x in range(30, 1100, 82):
		var building_height := 40.0 + float((x * 17) % 100)
		var building_rect := Rect2(float(x), SKYLINE_BASE_Y - building_height, 38.0, building_height)
		var light_y := building_rect.position.y + 15.0
		draw_rect(building_rect, Color("#274363"))
		draw_rect(Rect2(building_rect.position.x + 8.0, light_y, 7.0, 8.0), Color("#f6cf73"))
		draw_rect(Rect2(building_rect.position.x + 23.0, light_y, 7.0, 8.0), Color("#f6cf73"))

func _draw_floor() -> void:
	draw_rect(Rect2(0, FLOOR_Y, VIEW_W, VIEW_H - FLOOR_Y), Color("#101927"))
	draw_rect(Rect2(0, FLOOR_Y, VIEW_W, 24), Color("#f3b23c"))
	draw_rect(Rect2(0, FLOOR_Y + 24, VIEW_W, 18), Color("#c46c2d"))
	for x in range(-80, 1200, 160):
		draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y + 42), Vector2(x + 72, FLOOR_Y + 42), Vector2(x + 12, FLOOR_Y + 132), Vector2(x - 60, FLOOR_Y + 132)]), Color("#1c2b43"))

func _draw_race_car_pillar(x: float, gap_y: float, top: bool) -> void:
	var edge := gap_y - GAP_HEIGHT * 0.5 if top else gap_y + GAP_HEIGHT * 0.5
	var shaft_rect: Rect2 = Rect2(x + 22, 0, PIPE_WIDTH - 44, edge) if top else Rect2(x + 22, edge, PIPE_WIDTH - 44, FLOOR_Y - edge)
	draw_rect(shaft_rect, Color("#a8212a"))
	draw_rect(Rect2(shaft_rect.position + Vector2(24, 0), Vector2(24, shaft_rect.size.y)), Color("#df3940"))
	draw_rect(Rect2(shaft_rect.position + Vector2(shaft_rect.size.x - 48, 0), Vector2(24, shaft_rect.size.y)), Color("#751d2b"))
	if shaft_rect.size.y > 100:
		draw_rect(Rect2(x + PIPE_WIDTH * 0.48, shaft_rect.position.y, 18, shaft_rect.size.y), Color("#f7c943"))
	var cap_y := edge - 156.0 if top else edge
	var cap := Rect2(x - 10, cap_y, PIPE_WIDTH + 20, 156.0)
	draw_style_box(_rounded_box(Color("#e83235"), Color("#761a2b"), 9, 22), cap)
	var windshield_y := cap_y + 33.0
	draw_colored_polygon(PackedVector2Array([Vector2(x + 52, windshield_y + 3), Vector2(x + 102, windshield_y - 23), Vector2(x + 166, windshield_y - 23), Vector2(x + 202, windshield_y + 3)]), Color("#102b4c"))
	draw_line(Vector2(x + 130, windshield_y - 20), Vector2(x + 130, windshield_y + 5), Color("#5d9fc1"), 5)
	for eye_x in [x + 88, x + 174]:
		draw_circle(Vector2(eye_x, windshield_y + 5), 16, Color("#f8f3d7"))
		draw_circle(Vector2(eye_x + 2, windshield_y + 7), 7, Color("#182234"))
	var bolt_x := x + 36.0
	var bolt_y := cap_y + 76.0
	draw_colored_polygon(PackedVector2Array([Vector2(bolt_x, bolt_y), Vector2(bolt_x + 30, bolt_y), Vector2(bolt_x + 16, bolt_y + 22), Vector2(bolt_x + 47, bolt_y + 22), Vector2(bolt_x + 4, bolt_y + 71), Vector2(bolt_x + 14, bolt_y + 39), Vector2(bolt_x - 13, bolt_y + 39)]), Color("#ffdc3f"))
	draw_string(font, Vector2(x + 76, cap_y + 120), "95", HORIZONTAL_ALIGNMENT_LEFT, 0, 48, Color("#fff1a8"))
	draw_rect(Rect2(x + 22, cap_y + 138, PIPE_WIDTH - 44, 18), Color("#7e1725"))
	for wheel_x in [x + 20, x + PIPE_WIDTH - 20]:
		draw_circle(Vector2(wheel_x, cap_y + 132), 31, Color("#080d18"))
		draw_circle(Vector2(wheel_x, cap_y + 132), 16, Color("#a4aeb6"))
		draw_circle(Vector2(wheel_x, cap_y + 132), 8, Color("#384456"))

func _rounded_box(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box

func _draw_bird() -> void:
	var pos := Vector2(BIRD_X, bird_y)
	draw_set_transform(pos, bird_angle, Vector2.ONE)
	if baby_texture != null:
		draw_texture_rect(baby_texture, Rect2(-BIRD_RADIUS, -BIRD_RADIUS, BIRD_RADIUS * 2.0, BIRD_RADIUS * 2.0), false)
	else:
		draw_circle(Vector2.ZERO, BIRD_RADIUS, Color("#f1b28f"))
		draw_circle(Vector2(-32, -14), 12, Color("#281d25"))
		draw_circle(Vector2(32, -14), 12, Color("#281d25"))
		draw_arc(Vector2.ZERO, 34, 0.15, 3.0, 18, Color("#b6494d"), 10)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hud() -> void:
	var panel := Rect2(48, 62, VIEW_W - 96, 132)
	draw_style_box(_rounded_box(Color(0.03, 0.07, 0.16, 0.70), Color(0.42, 0.66, 0.83, 0.35), 26, 3), panel)
	draw_string(font, Vector2(88, 122), "G McQueen", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#ffd166"))
	draw_string(font, Vector2(88, 166), "TAP TO FLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#9db7d4"))
	draw_string(font, Vector2(860, 120), "BEST", HORIZONTAL_ALIGNMENT_CENTER, 140, 24, Color("#9db7d4"))
	draw_string(font, Vector2(860, 168), str(best_score), HORIZONTAL_ALIGNMENT_CENTER, 140, 46, Color("#ffffff"))
	if state == GameState.PLAYING:
		draw_string(font, Vector2(0, 410), str(score), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 126, Color(1, 1, 1, 0.96))
		draw_string(font, Vector2(0, 462), "SCORE", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 24, Color(1, 0.93, 0.69, 0.74))
	elif state == GameState.READY:
		_draw_center_card("G McQueen", "Tap, click, or press SPACE to flap", "DODGE THE LIGHTNING RACERS", Color("#ffd166"))
	elif state == GameState.GAME_OVER:
		_draw_center_card("RACE OVER", "Score  %d    •    Best  %d" % [score, best_score], "Tap to race again", Color("#ff6b5d"))

func _draw_center_card(title: String, subtitle: String, hint: String, accent: Color) -> void:
	var card := Rect2(92, 860, VIEW_W - 184, 500)
	draw_style_box(_rounded_box(Color(0.035, 0.075, 0.16, 0.94), Color(accent, 0.65), 38, 5), card)
	draw_string(font, Vector2(0, 1020), title, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 78, accent)
	draw_string(font, Vector2(140, 1114), subtitle, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W - 280, 31, Color("#edf5ff"))
	draw_string(font, Vector2(140, 1192), hint, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W - 280, 25, Color("#9db7d4"))
	var pulse := 1.0 + sin(world_time * 4.0) * 0.05
	draw_circle(Vector2(540, 1280), 58 * pulse, Color(accent, 0.16))
	draw_string(font, Vector2(0, 1298), "✦", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 46, accent)
