extends Node3D

signal fetch_complete(exhibit_data, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY = 1.0
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"
var COMMON_HEADERS

# TODO: add image description via extended metadata
# var all_info_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=images|info|links|extracts&exintro=true&explaintext=true&pllimit=max&imlimit=max&format=json&redirects=1&titles="
var all_info_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=info|links|extracts&exintro=true&explaintext=true&pllimit=max&imlimit=max&format=json&redirects=1&titles="
var _request_queue = []
var _request_in_flight = false
var _results = {}

func _ready():
	if OS.get_name() != "HTML5":
		COMMON_HEADERS = [ "accept: application/json; charset=utf-8", "user-agent: " + USER_AGENT ]
	else:
		COMMON_HEADERS = [ "accept: application/json; charset=utf-8" ]

# TODO: should the queue batch together all the upcoming requests?
func _advance_queue():
	_request_in_flight = false
	var next_fetch = _request_queue.pop_front()
	if next_fetch != null:
		fetch(next_fetch[0], next_fetch[1])

func _join_titles(titles):
	return "|".join(titles.map(func(t): return t.uri_encode()))

func fetch(titles: PackedStringArray, context):
	# TODO: check cache
	var new_titles = []
	for title in titles:
		if not get_result(title):
			new_titles.append(title)
	if len(new_titles) == 0:
		emit_signal("fetch_complete", titles, context)
		return

	# TODO: break this up into multiple batches
	if len(new_titles) > MAX_BATCH_SIZE:
		push_error("Too many page requests at once")
		return

	# queue if another request is in flight
	if _request_in_flight:
		_request_queue.append([ titles, context ])
		return
	_request_in_flight = true

	var url = all_info_endpoint + _join_titles(new_titles)
	var ctx = {
		"url": url,
		"titles": titles,
		"new_titles": new_titles,
	}
	_dispatch_request(url, ctx, context)

func get_result(title):
	if _results.has(title):
		var result = _results[title]
		if result.has("normalized"):
			result = _results[result.normalized]
		return result
	else:
		return null

func _dispatch_request(url, ctx, caller_ctx):
	var request = HTTPRequest.new()
	request.max_redirects = 0
	request.request_completed.connect(_on_request_completed.bind(ctx, caller_ctx))
	add_child(request)
	ctx.request = request
	print("fetching url ", url)
	var result = request.request(url, COMMON_HEADERS)
	if result != OK:
		push_error("failed to send http request ", result, " ", url)
		request.queue_free()

func _set_page_field(title, field, value):
	if not _results.has(title):
		_results[title] = {}
	_results[title][field] = value

func _append_page_field(title, field, values):
	if not _results.has(title):
		_results[title] = {}
	if not _results[title].has(field):
		_results[title][field] = []
	_results[title][field].append_array(values)

func _get_json(body):
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	return test_json_conv.get_data()

func _filter_links_ns(links):
	var agg = []
	for link in links:
		if link.has("ns") and link.has("title") and link.ns == 0:
			agg.append(link.title)
	return agg

func _on_request_completed(result, response_code, headers, body, ctx, caller_ctx):
	if result != 0 or response_code != 200:
		push_error("error in request ", response_code, " ", ctx.url)
		call_deferred("_advance_queue")
		return

	var res = _get_json(body)

	if not res.has("query"):
		return

	var query = res.query

	# handle the canonical names
	if query.has("normalized"):
		var normalized = query.normalized
		for title in normalized:
			_set_page_field(title.from, "normalized", title.to)

	if query.has("redirects"):
		var redirects = query.redirects
		for title in redirects:
			_set_page_field(title.from, "normalized", title.to)

	# store the information we did get
	if query.has("pages"):
		var pages = query.pages
		for page_id in pages.keys():
			var page = pages[page_id]
			if page.has("images"):
				_append_page_field(page.title, "images", page.images.map(func(i): i.title))
			if page.has("links"):
				_append_page_field(page.title, "links", _filter_links_ns(page.links))
			if page.has("extract"):
				_set_page_field(page.title, "extract", page.extract)

	# handle continues
	if res.has("continue"):
		var continue_url = all_info_endpoint + _join_titles(ctx.new_titles)
		for field in res.continue.keys():
			continue_url += "&" + field + "=" + res.continue[field]
		ctx.url = continue_url
		_dispatch_request(continue_url, ctx, caller_ctx)
	else:
		get_tree().create_timer(REQUEST_DELAY).timeout.connect(_advance_queue)
		emit_signal("fetch_complete", ctx.titles, caller_ctx)
