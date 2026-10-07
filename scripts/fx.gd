class_name Fx
extends Node3D
## Throwaway effects: confetti bursts, beams, lightning and floating words.

var font: Font
## Tests that run faster than real time turn effects off, since they are cleaned up on a real-time clock.
var muted := false

var _confetti: QuadMesh
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_confetti = QuadMesh.new()
	_confetti.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	_confetti.material = m


## A pop of paper confetti.
func burst(at: Vector3, color: Color, amount := 14, speed := 4.5) -> void:
	if muted:
		return
	var p := CPUParticles3D.new()
	p.mesh = _confetti
	p.amount = amount
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -10.0, 0.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color = color
	p.hue_variation_min = -0.04
	p.hue_variation_max = 0.04
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


## A straight glowing line that thins away over `life` seconds.
func beam(a: Vector3, b: Vector3, color: Color, width := 0.2, life := 0.25) -> void:
	if muted:
		return
	var dir := b - a
	if dir.length() < 0.01:
		return
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, dir.length())
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	quad.material = m
	node.mesh = quad
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	node.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	add_child(node)
	var tw := node.create_tween()
	tw.tween_property(node, "scale:x", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## A jagged lightning bolt.
func bolt(a: Vector3, b: Vector3, color: Color, width := 0.12) -> void:
	var steps := maxi(2, int(a.distance_to(b) / 0.7))
	var side := (b - a).cross(Vector3.BACK).normalized()
	var from := a
	for i in range(1, steps + 1):
		var to := a.lerp(b, float(i) / steps)
		if i < steps:
			to += side * _rng.randf_range(-0.35, 0.35)
		beam(from, to, color, width, 0.22)
		from = to


## A word that floats up and fades.
func text(at: Vector3, words: String, color := Color.WHITE, size := 56) -> void:
	if muted:
		return
	var l := Label3D.new()
	l.text = words
	l.font = font
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 14
	l.outline_modulate = Color("22223b")
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", at.y + 1.2, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(l.queue_free)
