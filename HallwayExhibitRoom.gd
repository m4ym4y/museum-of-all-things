extends StaticBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var floorbox = get_node('CSGCombiner/CSGBox2')

	var material = SpatialMaterial.new()
	var texture = ImageTexture.new()
	var image = Image.new()

	image.load("res://art/wood.png")
	texture.create_from_image(image)
	material.albedo_texture = texture
	material.uv1_scale = Vector3(
			floorbox.width / 10,
			floorbox.height / 10,
			floorbox.depth / 10)
	material.uv1_triplanar = true
	floorbox.material_override = material
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
