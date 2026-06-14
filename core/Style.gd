extends RefCounted
class_name Style
## Style.gd — ONE place that builds every procedural material, so the whole game
## shares a cohesive, professional finish: a soft rim edge-light on surfaces,
## controlled roughness/specular, and consistent emission for glows. Themes and
## biomes still tint freely (the colour is passed in) — only the FINISH is
## unified here, which is what reads as "structured / high quality".

## A solid surface with a gentle rim edge-light and soft, even shading.
static func surface(color: Color, rough := 0.72) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	m.specular = 0.35
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.35
	return m

## An emissive surface (gems, power-ups, glows). `energy` drives the bloom.
static func emissive(color: Color, energy := 0.8) -> StandardMaterial3D:
	var m := surface(color, 0.55)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
