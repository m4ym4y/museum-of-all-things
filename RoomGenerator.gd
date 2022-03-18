extends Node
signal room_ready

const SUMMARY_API = "https://en.wikipedia.org/api/rest_v1/page/summary/"
const RELATED_API = "https://en.wikipedia.org/api/rest_v1/page/related/"
const USER_AGENT = "https://github.com/m4ym4y/library-of-babel"
const COMMON_HEADERS = [
	"accept: application/json; charset=utf-8",
	"user-agent: " + USER_AGENT
]

const WALL_ENUM = [
	"NorthWall",
	"EastWall",
	"SouthWall",
	"WestWall"
]

var summary_response
var related_response
var prefetched_summaries = {}

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	$SummaryHTTPRequest.connect("request_completed", self, "_on_summary_request_completed")
	$RelatedHTTPRequest.connect("request_completed", self, "_on_related_request_completed")

func fetch_room(room_name):
	summary_response = null
	related_response = null

	$RelatedHTTPRequest.request(RELATED_API + room_name.percent_encode(),
			COMMON_HEADERS)

	if prefetched_summaries.has(room_name):
		summary_response = prefetched_summaries[room_name]
	else:
		$SummaryHTTPRequest.request(SUMMARY_API + room_name.percent_encode(),
				COMMON_HEADERS)

	# these are stale now
	prefetched_summaries = {}

func _on_summary_request_completed(result, response_code, headers, body):
	summary_response = JSON.parse(body.get_string_from_utf8()).result
	if related_response:
		_on_room_ready()

func _on_related_request_completed(result, response_code, headers, body):
	related_response = JSON.parse(body.get_string_from_utf8()).result
	if summary_response:
		_on_room_ready()

func _on_room_ready():
	var door_spec = {}
	var wall_index = 0

	for related_summary in related_response.pages:
		prefetched_summaries[related_summary.title] = related_summary
		door_spec[related_summary.title] = {
			wall = WALL_ENUM[wall_index % WALL_ENUM.size()],
			left = 1 + 2 * (wall_index / WALL_ENUM.size()),
			width = 1,
			height = 2
		}
		wall_index += 1

	var room_spec = {
		name = summary_response.title,
		width = 24,
		height = 4,
		length = 24,
		doors = door_spec
	}

	if summary_response.has("originalimage"):
		room_spec.image = summary_response.originalimage.source

	emit_signal("room_ready", room_spec)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
