class_name Shots
extends Node3D
## Everything in flight: the tank's rounds, flak, missiles, alien bombs and supply crates.

class Shot:
	extends Cutout
	var kind := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var friendly := false
	var dmg := 1.0
	var hp := 1.0
	var radius := 0.12
	var pierce := 0
	var splash := 0.0
	var life := 6.0
	var dead := false
	var target: Alien
	## Instance ids of aliens a piercing round has already gone through.
	var hit: Array[int] = []


const KINDS := {
	"bullet": {"tex": "bullet", "friendly": true, "radius": 0.12},
	"flak": {"tex": "bullet", "friendly": true, "radius": 0.1, "scale": 0.75, "tint": "7fe3ff"},
	"missile": {"tex": "missile", "friendly": true, "radius": 0.2},
	"bomb": {"tex": "bomb", "radius": 0.24, "scale": 1.5, "hp": 1.0, "dmg": 1.0},
	"big": {"tex": "bigbomb", "radius": 0.42, "scale": 1.4, "hp": 3.0, "dmg": 2.0},
	"spit": {"tex": "spit", "radius": 0.22, "scale": 1.5, "hp": 1.0, "dmg": 1.0},
	"crate": {"tex": "crate", "radius": 0.4},
}

var game
var list: Array[Shot] = []


func clear() -> void:
	for s in list:
		s.queue_free()
	list.clear()


func fire(kind: String, at: Vector2, vel: Vector2, dmg := 1.0, pierce := 0, splash := 0.0) -> Shot:
	var def: Dictionary = KINDS[kind]
	var s := Shot.new()
	s.setup(def.tex)
	s.set_border(0.0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.mat.set_shader_parameter("glow", 1.0)
	s.kind = kind
	s.pos = at
	s.vel = vel
	s.friendly = def.get("friendly", false)
	s.radius = def.radius
	s.hp = def.get("hp", 1.0)
	s.dmg = dmg if s.friendly else float(def.get("dmg", 0.0))
	s.pierce = pierce
	s.splash = splash
	s.scale = Vector3.ONE * float(def.get("scale", 1.0))
	if def.has("tint"):
		s.set_tint(Color(def.tint))
	s.position = Vector3(at.x, at.y, 0.0)
	_aim(s)
	add_child(s)
	list.append(s)
	return s


func update(delta: float) -> void:
	# Shots fired during the pass are appended, so walking backwards from the old end is safe.
	var i := list.size() - 1
	while i >= 0:
		var s := list[i]
		if s.dead or _advance(s, delta):
			s.queue_free()
			list.remove_at(i)
		i -= 1


## Bombs and spit still in the air (crates aren't a threat).
func hostile() -> int:
	var n := 0
	for s in list:
		if not s.friendly and s.kind != "crate" and not s.dead:
			n += 1
	return n


func _aim(s: Shot) -> void:
	if s.kind == "crate" or s.kind == "big" or s.kind == "spit":
		return
	# Friendly art points up, bombs point down.
	s.rotation.z = s.vel.angle() - PI * 0.5 if s.friendly else s.vel.angle() + PI * 0.5


## Moves one shot and resolves what it hits. Returns true when the shot is spent.
func _advance(s: Shot, delta: float) -> bool:
	s.life -= delta
	if s.kind == "missile":
		if s.target == null or s.target.dead:
			s.target = game.swarm.nearest(s.pos)
		if s.target != null:
			var want: Vector2 = (s.target.pos - s.pos).normalized() * 13.0
			s.vel = s.vel.lerp(want, 1.0 - exp(-4.5 * delta))
		if s.life <= 0.0:
			game.explode(s.pos, s.splash, s.dmg * 0.6)
			return true
		_aim(s)
	elif s.kind == "crate":
		s.pos.x += sin(s.life * 2.5) * 0.6 * delta
		s.rotation.z = sin(s.life * 2.5) * 0.2
	elif s.kind == "big":
		s.rotation.z += delta * 3.0
	s.pos += s.vel * delta
	s.position.x = s.pos.x
	s.position.y = s.pos.y
	if absf(s.pos.x) > City.HALF + 6.0 or s.pos.y > game.diorama.play_top + 4.0 or s.pos.y < -0.6:
		return true

	if s.kind == "crate":
		if game.player.overlaps(s.pos, s.radius):
			game.collect_crate(s.pos)
			return true
		return s.pos.y < 0.35

	if s.friendly:
		var struck: Alien = null
		for a: Alien in game.swarm.aliens:
			if not a.dead and absf(a.pos.x - s.pos.x) < a.hx + s.radius and absf(a.pos.y - s.pos.y) < a.hy + s.radius \
					and not s.hit.has(a.get_instance_id()):
				struck = a
				break
		if struck != null:
			s.hit.append(struck.get_instance_id())
			game.hit_alien(struck, s.dmg, s.pos)
			if s.splash > 0.0:
				game.explode(s.pos, s.splash, maxf(1.0, s.dmg * 0.5), struck)
			if s.pierce <= 0 or s.kind == "missile":
				return true
			s.pierce -= 1
		if s.kind == "bullet":
			for e in list:
				if not e.friendly and not e.dead and e.kind != "crate" and e.pos.distance_to(s.pos) < e.radius + s.radius + 0.12:
					e.hp -= s.dmg
					if e.hp <= 0.0:
						e.dead = true
						game.bomb_shot_down(e.pos)
					return true
		return false

	# Alien fire: drift back toward the building it is falling on, so it lands on the cut-out.
	var under: City.Building = game.city.column_at(s.pos.x)
	if under != null:
		s.position.z = (under.z + 0.08) * clampf(1.0 - (s.pos.y - under.top()) / 3.0, 0.0, 1.0)
	if game.defenses.dome_blocks(s.pos, s.kind == "big"):
		return true
	if game.player.overlaps(s.pos, s.radius):
		game.hurt_player()
		return true
	var b: City.Building = game.city.building_at(s.pos.x, s.pos.y)
	if b != null:
		game.hurt_building(b, int(s.dmg), Vector3(s.pos.x, s.pos.y, b.z + 0.1))
		return true
	if s.pos.y <= 0.15:
		game.fx.burst(Vector3(s.pos.x, 0.1, 0.0), Color("8a8f7a"), 6, 2.5)
		return true
	return false
