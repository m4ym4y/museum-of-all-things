extends Node
signal room_ready

const SUMMARY_API = "https://en.wikipedia.org/api/rest_v1/page/summary/"
const RELATED_API = "https://en.wikipedia.org/api/rest_v1/page/related/"
const LINKS_API = "https://en.wikipedia.org/w/api.php?action=query&prop=links&pllimit=max&format=json"

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
var linked_pages
var linked_pages_complete = false
var linked_pages_original_request
var linked_request_limit
var fetching_room_name

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func wikify (string):
	return string.replace(" ", "_").percent_encode()

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	$SummaryHTTPRequest.connect("request_completed", self, "_on_summary_request_completed")
	$RelatedHTTPRequest.connect("request_completed", self, "_on_related_request_completed")

func fetch_room(room_name):
	print("fetch room ", room_name)
	fetching_room_name = room_name
	summary_response = null
	linked_pages = []
	linked_pages_complete = false
	linked_pages_original_request = LINKS_API + "&titles=" + room_name.percent_encode()
	linked_request_limit = 5

	$RelatedHTTPRequest.request(linked_pages_original_request, COMMON_HEADERS)
	$SummaryHTTPRequest.request(SUMMARY_API + wikify(room_name), COMMON_HEADERS)

func _on_summary_request_completed(result, response_code, headers, body):
	summary_response = JSON.parse(body.get_string_from_utf8()).result
	if linked_pages_complete:
		print("room ready from summary ", summary_response == null)
		if summary_response == null:
			print("invalid JSON response: ", response_code, " ", body.get_string_from_utf8())
		_on_room_ready()

func _on_related_request_completed(result, response_code, headers, body):
	var response_batch = JSON.parse(body.get_string_from_utf8()).result

	if not response_batch:
		print("error with response batch: ", body.get_string_from_utf8())
	
	for page in response_batch.query.pages:
		if page != "-1":
			linked_pages += response_batch.query.pages[page].links

	if response_batch.has('continue') and linked_request_limit > 0:
		linked_request_limit -= 1
		$RelatedHTTPRequest.request(linked_pages_original_request +
				"&plcontinue=" + response_batch.continue.plcontinue.percent_encode(), COMMON_HEADERS)
	else:
		linked_pages_complete = true
		if summary_response != null:
			print('room ready ', summary_response == null)
			_on_room_ready()

func _on_room_ready():
	var door_spec = {}
	var wall_index = 0

	linked_pages.shuffle()

	for i in range(1, min(linked_pages.size(), 20)):
		door_spec[linked_pages[i].title] = {
			wall = WALL_ENUM[wall_index % WALL_ENUM.size()],
			left = 1 + 2 * (wall_index / WALL_ENUM.size()),
			width = 1,
			height = 2
		}
		wall_index += 1

	if fetching_room_name != summary_response.title:
		print("got mismatched room names: original=" + fetching_room_name +
				" got=" + summary_response.title)

	var room_spec = {
		name = fetching_room_name,
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
