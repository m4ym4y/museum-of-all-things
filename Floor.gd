extends StaticBody

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
const PREVIEW_WIDTH = 10.0
const PREVIEW_LENGTH = 10.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(width, length):
	scale = Vector3((width + 2) / PREVIEW_WIDTH, 1, (length + 2) / PREVIEW_LENGTH)

	var material = SpatialMaterial.new()
	var texture = ImageTexture.new()
	var image = Image.new()
	image.load("res://art/wood.png")
	texture.create_from_image(image)
	material.albedo_texture = texture
	material.uv1_scale = Vector3(width / 10, width / 10, width / 10)
	material.uv1_triplanar = true
	$MeshInstance.material_override = material

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
