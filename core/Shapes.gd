extends RefCounted
class_name Shapes
## Shapes.gd — builds small primitive "symbol badges" so each gem/cage color is
## also distinguishable by SHAPE. This is the color-blind accessibility layer:
## ~1 in 12 boys is color-blind and the whole mechanic is color-matching, so the
## carried color and every collectible carries a redundant, language-free shape.
## Primitive meshes always render (no font/emoji risk).

static func badge(symbol: String, size: float = 0.34) -> Mesh:
	match symbol:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3(size, size, size)
			return b
		"sphere":
			var s := SphereMesh.new()
			s.radius = size * 0.55
			s.height = size * 1.1
			return s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = size * 0.5
			c.bottom_radius = size * 0.5
			c.height = size
			return c
		"prism":
			var p := PrismMesh.new()
			p.size = Vector3(size, size, size)
			return p
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = size * 0.28
			t.outer_radius = size * 0.6
			return t
		"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = size * 0.35
			cap.height = size * 1.2
			return cap
		_:
			var d := SphereMesh.new()
			d.radius = size * 0.55
			d.height = size * 1.1
			return d
