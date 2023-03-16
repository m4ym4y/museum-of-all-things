extends Spatial

signal fetch_complete(exhibit_data)

const media_endpoint = 'https://en.wikipedia.org/api/rest_v1/page/media-list/'
const summary_endpoint = 'https://en.wikipedia.org/api/rest_v1/page/summary/'

const RESULT_INCOMPLETE = -1 
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"
const COMMON_HEADERS = [
	"accept: application/json; charset=utf-8",
	# "user-agent: " + USER_AGENT
]

# TODO: experimental endpoint. use different API?
# const links_endpoint = 'https://en.wikipedia.org/api/rest_v1/page/related/'
const links_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=links&pllimit=max&format=json&origin=*&titles="

var exhibit_data = {}
var media_result = RESULT_INCOMPLETE
var summary_result = RESULT_INCOMPLETE
var links_result = RESULT_INCOMPLETE

func reset_results():
	exhibit_data = {
		"items": [],
		"doors": []
	}

	media_result = RESULT_INCOMPLETE
	summary_result = RESULT_INCOMPLETE
	links_result = RESULT_INCOMPLETE
	linked_request_limit = 10
	link_results = []

func fetch(title):
	reset_results()

	# var title = title_.percent_encode()
	var request_data = [
		{ "endpoint": media_endpoint + title + "?redirect=false", "handler": "_on_media_request_complete" },
		{ "endpoint": summary_endpoint + title + "?redirect=false", "handler": "_on_summary_request_complete" },
		{ "endpoint": links_endpoint + title, "handler": "_on_links_request_complete" }
	]

	for data in request_data:
		var request = HTTPRequest.new()
		request.connect("request_completed", self, data.handler, [ data.endpoint ])
		add_child(request)
		request.request(data.endpoint, COMMON_HEADERS)
		print("DISPATCHED_REQUEST", data)

func all_requests_finished():
	return media_result != RESULT_INCOMPLETE and summary_result != RESULT_INCOMPLETE and links_result != RESULT_INCOMPLETE

func emit_if_finished():
	# TODO: also handle if one or more requests ended in error
	if all_requests_finished():
		emit_signal("fetch_complete", exhibit_data)

func get_json(body):
	return JSON.parse(body.get_string_from_utf8()).result

func _on_media_request_complete(result, response_code, headers, body, _url):
	media_result = response_code
	print("MEDIA RESULT RETURNED ", media_result)
	var res = get_json(body)

	# TODO: validate response and json
	for item in res.items:
		if not item.has("title"):
			print("TITLELESS ITEM", JSON.print(item))
			continue
		if item.title.ends_with(".jpg") or item.title.ends_with(".png"):
			var exhibit_item = { "type": "image" }
			exhibit_item.src = item.srcset[0].src
			if item.has("caption"):
				exhibit_item.text = item.caption.text
			else:
				# TODO: ???
				exhibit_item.text = "no caption provided"
			exhibit_data.items.push_back(exhibit_item)

	emit_if_finished()

var link_results = []
var linked_request_limit = 10

func _on_links_request_complete(result, response_code, headers, body, original_url):
	var res = get_json(body)

	# print("GOT PAGES", res.query.pages)
	for page in res.query.pages.keys():
		for link in res.query.pages[page].links:
			link_results.push_back(link.title.replace(" ", "_").percent_encode())
	
	if res.has("continue") or linked_request_limit == 0:
		linked_request_limit -= 1
		var continue_request = HTTPRequest.new()
		continue_request.connect("request_completed", self, "_on_links_request_complete", [ original_url ])
		add_child(continue_request)
		continue_request.request(original_url + "&plcontinue=" + res.continue.plcontinue.percent_encode(), COMMON_HEADERS)
	else:
		links_result = response_code
		link_results.shuffle()
		exhibit_data.doors = link_results
		link_results = []
		emit_if_finished()

func _on_summary_request_complete(result, response_code, headers, body, _url):
	summary_result = response_code
	print("SUMMARY RESULT RETURNED ", summary_result)
	var res = get_json(body)

	exhibit_data.items.push_front({
		"type": "text",
		"text": res.extract
	})

	emit_if_finished()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
