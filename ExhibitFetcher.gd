extends Node3D

signal fetch_complete(exhibit_data)

const media_endpoint = 'https://en.wikipedia.org/api/rest_v1/page/media-list/'
const summary_endpoint = 'https://en.wikipedia.org/api/rest_v1/page/summary/'
const links_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=links&pllimit=max&format=json&origin=*&titles="

# TODO: do we really want full text?
#const content_endpoint = "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&formatversion=2&exintro=1&exlimit=max&explaintext=1&titles="
const content_endpoint = "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&formatversion=2&exlimit=max&origin=*&explaintext=1&titles="

const RESULT_INCOMPLETE = -1 
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"

var COMMON_HEADERS
func _ready():
	if OS.get_name() != "HTML5":
		COMMON_HEADERS = [
			"accept: application/json; charset=utf-8",
			"user-agent: " + USER_AGENT
		]
	else:
		COMMON_HEADERS = [
			"accept: application/json; charset=utf-8",
		]

var exhibit_data = {}
var media_result = RESULT_INCOMPLETE
var summary_result = RESULT_INCOMPLETE
var links_result = RESULT_INCOMPLETE
var content_result = RESULT_INCOMPLETE

const LOCATION_STR = "location: "
func get_location_header(headers):
	for header in headers:
		if header.begins_with(LOCATION_STR):
			return header.substr(LOCATION_STR.length())

func reset_results():
	exhibit_data = {
		"secondary_items": [],
		"items": [],
		"doors": []
	}

	media_result = RESULT_INCOMPLETE
	summary_result = RESULT_INCOMPLETE
	links_result = RESULT_INCOMPLETE
	content_result = RESULT_INCOMPLETE
	linked_request_limit = 10
	link_results = []
	links_url_redirected = null

func fetch(title):
	reset_results()

	# var title = title_.percent_encode()
	var request_data = [
		{ "endpoint": media_endpoint + title, "handler": "_on_media_request_complete" },
		{ "endpoint": summary_endpoint + title, "handler": "_on_summary_request_complete" },
		{ "endpoint": content_endpoint + title, "handler": "_on_content_request_complete" },
		{ "endpoint": links_endpoint + title, "handler": "_on_links_request_complete" }
	]

	for data in request_data:
		var request = HTTPRequest.new()
		request.max_redirects = 0
		request.connect("request_completed", Callable(self, data.handler).bind(data.endpoint))
		add_child(request)
		request.request(data.endpoint, COMMON_HEADERS)

func all_requests_finished():
	return media_result != RESULT_INCOMPLETE and \
		summary_result != RESULT_INCOMPLETE and \
		links_result != RESULT_INCOMPLETE and \
		content_result != RESULT_INCOMPLETE

func emit_if_finished():
	# TODO: also handle if one or more requests ended in error
	if all_requests_finished():
		emit_signal("fetch_complete", exhibit_data)

func get_json(body):
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8()).result
	return test_json_conv.get_data()

func _on_media_request_complete(result, response_code, headers, body, _url):
	if result == 11:
		var redirected_request = HTTPRequest.new()
		var redirected_url = media_endpoint + get_location_header(headers)
		redirected_request.max_redirects = 0
		redirected_request.connect("request_completed", Callable(self, "_on_media_request_complete").bind(redirected_url))
		add_child(redirected_request)
		redirected_request.request(redirected_url, COMMON_HEADERS)

	if result != 0 or response_code != 200:
		push_error("error in media request")
		return

	media_result = response_code
	var res = get_json(body)

	# TODO: validate response and json
	for item in res.items:
		if not item.has("title"):
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

const CHARS_PER_TEXT_ITEM = 250

func _on_content_request_complete(result, response_code, headers, body, _url):
	if result == 11:
		var redirected_request = HTTPRequest.new()
		var redirected_url = content_endpoint + get_location_header(headers)
		redirected_request.max_redirects = 0
		redirected_request.connect("request_completed", Callable(self, "_on_content_request_complete").bind(redirected_url))
		add_child(redirected_request)
		redirected_request.request(redirected_url, COMMON_HEADERS)
	
	var res = get_json(body)
	if res.query.pages.has("-1"):
		return

	var content = res.query.pages[0].extract

	var content_sentences = content.split(".")
	var current_item = ""

	for sentence in content_sentences:
		current_item += sentence + "."
		if current_item.length() >= CHARS_PER_TEXT_ITEM:
			exhibit_data.secondary_items.push_back({
				"type": "text",
				"text": current_item
			})
			current_item = ""

	if current_item.length() > 0:
		exhibit_data.secondary_items.push_back({
			"type": "text",
			"text": current_item
		})

	content_result = response_code
	emit_if_finished()

var link_results = []
var linked_request_limit = 10
var links_url_redirected = null

func _on_links_request_complete(result, response_code, headers, body, original_url):
	if result != 0 or response_code != 200:
		push_error("error in links request")
		return

	if links_url_redirected != null and links_url_redirected != original_url:
		return

	var res = get_json(body)
	if res.query.pages.has("-1"):
		return

	for page in res.query.pages.keys():
		for link in res.query.pages[page].links:
			link_results.push_back(link.title.replace(" ", "_").uri_encode())
	
	if res.has("continue") or linked_request_limit == 0:
		linked_request_limit -= 1
		var continue_request = HTTPRequest.new()
		continue_request.max_redirects = 0
		continue_request.connect("request_completed", Callable(self, "_on_links_request_complete").bind(original_url))
		add_child(continue_request)
		continue_request.request(original_url + "&plcontinue=" + res.continue.plcontinue.uri_encode(), COMMON_HEADERS)
	else:
		links_result = response_code
		link_results.shuffle()
		exhibit_data.doors = link_results
		link_results = []
		emit_if_finished()

func _on_summary_request_complete(result, response_code, headers, body, _url):
	if result == 11:
		var redirected_request = HTTPRequest.new()
		var redirected_url = summary_endpoint + get_location_header(headers)
		redirected_request.max_redirects = 0
		redirected_request.connect("request_completed", Callable(self, "_on_summary_request_complete").bind(redirected_url))
		add_child(redirected_request)
		redirected_request.request(redirected_url, COMMON_HEADERS)

		var redirected_links_request = HTTPRequest.new()
		var redirected_links_url = links_endpoint + get_location_header(headers)

		links_url_redirected = redirected_links_url
		link_results = []
		links_result = RESULT_INCOMPLETE

		redirected_links_request.max_redirects = 0
		redirected_links_request.connect("request_completed", Callable(self, "_on_links_request_complete").bind(redirected_links_url))
		add_child(redirected_links_request)
		redirected_links_request.request(redirected_links_url, COMMON_HEADERS)

	if result != 0 or response_code != 200:
		push_error("error in summary request")
		return

	summary_result = response_code
	var res = get_json(body)

	exhibit_data.items.push_front({
		"type": "text",
		"text": res.extract
	})

	emit_if_finished()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
