extends Node

signal wikitext_complete(titles, context)
signal wikitext_failed(titles, message)
signal images_complete(files, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY = 1.0
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"

# TODO: wikimedia support, and category support
const WIKIMEDIA_PREFIX = "https://commons.wikimedia.org/wiki/"
const WIKIPEDIA_PREFIX = "https://wikipedia.org/wiki/"
var COMMON_HEADERS

var wikitext_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&redirects=1&titles="
var images_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640&iiextmetadatafilter=LicenseShortName|Artist&format=json&redirects=1&titles="

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
		if next_fetch[0] == "fetch_wikitext":
			fetch(next_fetch[1], next_fetch[2])
		elif next_fetch[0] == "fetch_images":
			fetch_images(next_fetch[1], next_fetch[2])
		else:
			push_error("unknown queue item. type=", next_fetch[0])

func _join_titles(titles):
	return "|".join(titles.map(func(t): return t.uri_encode()))

func _read_from_cache(title):
	var json = DataManager.load_json_data(WIKIPEDIA_PREFIX + title)
	if json:
		_results[title] = json
	return json

func _get_uncached_titles(titles):
	var new_titles = []
	for title in titles:
		if title == "":
			continue
		if not get_result(title):
			var cached = _read_from_cache(title)
			if not cached:
				new_titles.append(title)
	return new_titles

func fetch_images(files, context):
	var new_files = _get_uncached_titles(files)

	if len(new_files) == 0:
		emit_signal("images_complete", files, context)
		return

	if len(new_files) > MAX_BATCH_SIZE:
		_request_queue.append([ "fetch_images", new_files.slice(MAX_BATCH_SIZE), context ])
		new_files = new_files.slice(0, MAX_BATCH_SIZE)

	# queue if another request is in flight
	if _request_in_flight:
		_request_queue.append([ "fetch_images", new_files, context ])
		return
	_request_in_flight = true

	var url = images_endpoint + _join_titles(new_files)
	var ctx = {
		"files": files,
		"new_files": new_files,
	}

	_dispatch_request(url, ctx, context)

func fetch(titles, context):
	var new_titles = _get_uncached_titles(titles)

	if len(new_titles) == 0:
		emit_signal("wikitext_complete", titles, context)
		return

	if len(new_titles) > MAX_BATCH_SIZE:
		push_error("Too many page requests at once")
		return

	# queue if another request is in flight
	if _request_in_flight:
		_request_queue.append([ "fetch_wikitext", new_titles, context ])
		return
	_request_in_flight = true

	var url = wikitext_endpoint + _join_titles(new_titles)
	var ctx = {
		"titles": titles,
		"new_titles": new_titles,
	}

	# dispatching mediawiki request
	_dispatch_request(url, ctx, context)

func get_result(title):
	if _results.has(title):
		var result = _results[title]
		if result.has("normalized"):
			if _results.has(result.normalized):
				result = _results[result.normalized]
			else:
				return null
		return result
	else:
		return null

func _dispatch_request(url, ctx, caller_ctx):
	var request = HTTPRequest.new()
	request.max_redirects = 0
	request.request_completed.connect(_on_request_completed_wrapper.bind(ctx, caller_ctx))
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

func _on_request_completed_wrapper(result, response_code, headers, body, ctx, caller_ctx):
	if _on_request_completed(result, response_code, headers, body, ctx, caller_ctx):
		get_tree().create_timer(REQUEST_DELAY).timeout.connect(_advance_queue)

func _on_request_completed(result, response_code, headers, body, ctx, caller_ctx):
	if result != 0 or response_code != 200:
		if response_code != 404:
			push_error("error in request ", result, " ", response_code, " ", ctx.url)
		if ctx.url.begins_with(wikitext_endpoint):
			emit_signal("wikitext_failed", ctx.new_titles, str(response_code))
		return true

	var res = _get_json(body)

	if not res.has("query"):
		return true

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

	if ctx.url.begins_with(wikitext_endpoint):
		return _on_wikitext_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(images_endpoint):
		return _on_images_request_complete(res, ctx, caller_ctx)

func _dispatch_continue(continue_fields, base_url, titles, ctx, caller_ctx):
	var continue_url = base_url + _join_titles(titles)
	for field in continue_fields.keys():
		continue_url += "&" + field + "=" + continue_fields[field].uri_encode()
	ctx.url = continue_url
	_dispatch_request(continue_url, ctx, caller_ctx)

func _cache_all(titles):
	for title in titles:
		var result = get_result(title)
		if result != null:
			DataManager.save_json_data(WIKIPEDIA_PREFIX + title, result)

func _on_wikitext_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	if res.query.has("pages"):
		var pages = res.query.pages
		for page_id in pages.keys():
			var page = pages[page_id]
			if page.has("revisions"):
				var revisions = page.revisions
				_set_page_field(page.title, "wikitext", revisions[0]["*"])

	# handle continues
	if res.has("continue"):
		_dispatch_continue(res.continue, wikitext_endpoint, ctx.new_titles, ctx, caller_ctx)
		return false
	else:
		_cache_all(ctx.new_titles)
		emit_signal("wikitext_complete", ctx.titles, caller_ctx)
		return true

func _on_images_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	if res.query.has("pages"):
		var pages = res.query.pages
		for page_id in pages.keys():
			var page = pages[page_id]
			var file = page.title
			if not page.has("imageinfo"):
				continue
			for info in page.imageinfo:
				if info.has("extmetadata"):
					var md = info.extmetadata
					if md.has("LicenseShortName"):
						_set_page_field(file, "license_short_name", md.LicenseShortName.value)
					if md.has("Artist"):
						_set_page_field(file, "artist", md.Artist.value)
				if info.has("thumburl"):
					_set_page_field(file, "src", info.thumburl)

	# handle continues
	if res.has("continue"):
		_dispatch_continue(res.continue, images_endpoint, ctx.new_files, ctx, caller_ctx)
		return false
	else:
		_cache_all(ctx.new_files)
		emit_signal("images_complete", ctx.files, caller_ctx)
		return true
