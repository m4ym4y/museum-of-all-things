extends Node

signal fetch_complete(exhibit_data, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY = 1.0
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"
# TODO: wikimedia support, and category support
const WIKIMEDIA_PREFIX = "https://commons.wikimedia.org/wiki/"
const WIKIPEDIA_PREFIX = "https://wikipedia.org/wiki/"
var COMMON_HEADERS

# TODO: add image description via extended metadata
# var all_info_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=images|info|links|extracts&exintro=true&explaintext=true&pllimit=max&imlimit=max&format=json&redirects=1&titles="
# var all_info_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=info|extlinks|links|extracts&exintro=true&explaintext=true&pllimit=max&imlimit=max&format=json&redirects=1&titles="
var all_info_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=info|links|extracts&exintro=true&explaintext=true&pllimit=max&format=json&redirects=1&titles="
# var wiki_commons_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&gcmtitle=Category:Fossils&generator=categorymembers&gcmtype=file|subcat&prop=imageinfo|categories&iiprop=url|user|comment|extmetadata&gcmlimit=max&cllimit=max&format=json"
var media_list_endpoint = "https://en.wikipedia.org/api/rest_v1/page/media-list/"

var _request_queue = []
var _request_in_flight = false
var _results = {}

func _ready():
	if OS.get_name() != "HTML5":
		COMMON_HEADERS = [ "accept: application/json; charset=utf-8", "user-agent: " + USER_AGENT ]
	else:
		COMMON_HEADERS = [ "accept: application/json; charset=utf-8" ]

const LOCATION_STR = "location: "
func _get_location_header(headers):
	for header in headers:
		if header.begins_with(LOCATION_STR):
			return header.substr(LOCATION_STR.length())

# TODO: should the queue batch together all the upcoming requests?
func _advance_queue():
	_request_in_flight = false
	var next_fetch = _request_queue.pop_front()
	if next_fetch != null:
		fetch(next_fetch[0], next_fetch[1])

func _join_titles(titles):
	return "|".join(titles.map(func(t): return t.uri_encode()))

func fetch(titles, context):
	# TODO: check cache
	var new_titles = []
	for title in titles:
		if not get_result(title):
			var cached = _read_from_cache(title)
			if not cached:
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
		"titles": titles,
		"new_titles": new_titles,
	}

	# dispatching mediawiki request
	_dispatch_request(url, ctx, context)

	# dispatching media list request to REST
	for title in new_titles:
		var rest_url = media_list_endpoint + title.uri_encode()
		var media_ctx = {
			# TODO: we need to look at content location to get canonical name
			"original_title": title,
			"title": title,
			"titles": titles
		}
		_dispatch_request(rest_url, media_ctx, context)

func get_result(title):
	if _results.has(title):
		var result = _results[title]
		if result.has("normalized"):
			if _results.has(result.normalized):
				result = _results[result.normalized]
		if result.has("media_wiki_complete") and result.has("media_list_complete"):
			return result
		return null
	else:
		return null

func _dispatch_request(url, ctx, caller_ctx):
	var request = HTTPRequest.new()
	request.max_redirects = 0
	request.request_completed.connect(_on_request_completed.bind(ctx, caller_ctx))
	add_child(request)
	ctx.request = request
	ctx.url = url
	if OS.is_debug_build():
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
	var body_string = body.get_string_from_utf8()
	test_json_conv.parse(body_string)
	return test_json_conv.get_data()

func _filter_links_ns(links):
	var agg = []
	for link in links:
		if link.has("ns") and link.has("title") and link.ns == 0:
			agg.append(link.title)
	return agg

func _filter_extlinks(links):
	var agg = []
	for link in links:
		if link.has("*") and link["*"].begins_with(WIKIMEDIA_PREFIX):
			agg.append(link["*"])
	return agg

func _normalize_article_title(title):
	var new_title = title.replace("_", " ").uri_decode()
	var title_fragments = new_title.split("#")
	return title_fragments[0]

func _on_request_completed(result, response_code, headers, body, ctx, caller_ctx):
	if result != 0 or response_code != 200:
		if response_code >= 300 and response_code < 400:
			if ctx.url.begins_with(media_list_endpoint):
				var title_header = _get_location_header(headers)
				var redirected_url = media_list_endpoint + title_header
				var new_title = _normalize_article_title(title_header)
				_set_page_field(ctx.title, "normalized", new_title)
				ctx.title = new_title
				_dispatch_request(redirected_url, ctx, caller_ctx)
				return
		push_error("error in request ", result, " ", response_code, " ", ctx.url)
		if ctx.url.begins_with(all_info_endpoint):
				get_tree().create_timer(REQUEST_DELAY).timeout.connect(_advance_queue)
				return
		return

	var res = _get_json(body)

	if ctx.url.begins_with(all_info_endpoint):
		return _on_mediawiki_request_completed(res, ctx, caller_ctx)
	elif ctx.url.begins_with(media_list_endpoint):
		return _on_media_list_request_completed(res, ctx, caller_ctx)

func _on_mediawiki_request_completed(res, ctx, caller_ctx):
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
			if page.has("links"):
				_append_page_field(page.title, "links", _filter_links_ns(page.links))
			if page.has("extlinks"):
				_append_page_field(page.title, "links", _filter_extlinks(page.extlinks))
			if page.has("extract"):
				_set_page_field(page.title, "extract", page.extract)
			# TODO: will this work if we already finished that field in an earlier request?
			if res.has("batchcomplete"):
				_set_page_field(page.title, "media_wiki_complete", true)

	# handle continues
	if res.has("continue"):
		var continue_url = all_info_endpoint + _join_titles(ctx.new_titles)
		for field in res.continue.keys():
			continue_url += "&" + field + "=" + res.continue[field].uri_encode()
		ctx.url = continue_url
		_dispatch_request(continue_url, ctx, caller_ctx)
	else:
		get_tree().create_timer(REQUEST_DELAY).timeout.connect(_advance_queue)
		for title in ctx.titles:
			_cache_if_complete(title)
		_check_complete_and_emit(ctx.titles, caller_ctx)

func _cache_if_complete(title):
	var result = get_result(title)
	if result != null:
		DataManager.save_json_data(WIKIPEDIA_PREFIX + title, result)

func _read_from_cache(title):
	var json = DataManager.load_json_data(WIKIPEDIA_PREFIX + title)
	if json:
		_results[title] = json
	return json

func _on_media_list_request_completed(res, ctx, caller_ctx):
	_set_page_field(ctx.title, "media_list_complete", true)
	_cache_if_complete(ctx.original_title)

	if not res.has("items"):
		return

	var images = []
	for item in res.items:
		if item.type != "image" or not item.has("srcset"):
			continue
		var image = { "src": "", "text": "" }
		if item.has("caption"):
			image.text = item.caption.text
		image.src = item.srcset[0].src
		images.append(image)

	_append_page_field(ctx.title, "images", images)
	_check_complete_and_emit(ctx.titles, caller_ctx)

func _check_complete_and_emit(titles, caller_ctx):
	for title in titles:
		if get_result(title) == null:
			return
	emit_signal("fetch_complete", titles, caller_ctx)
