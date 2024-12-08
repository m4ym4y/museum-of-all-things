extends Node

signal wikitext_complete(titles, context)
signal wikitext_failed(titles, message)
signal wikidata_complete(ids, context)
signal images_complete(files, context)
signal commons_images_complete(category, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY = 1.0
const USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"

# TODO: wikimedia support, and category support
const WIKIMEDIA_COMMONS_PREFIX = "https://commons.wikimedia.org/wiki/"
const WIKIPEDIA_PREFIX = "https://wikipedia.org/wiki/"
const WIKIDATA_PREFIX = "https://www.wikidata.org/wiki/"

const WIKIDATA_COMMONS_CATEGORY = "P373"

var COMMON_HEADERS

var wikitext_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions|extracts|pageprops&ppprop=wikibase_item&explaintext=true&rvprop=content&format=json&redirects=1&titles="
var images_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640&iiextmetadatafilter=LicenseShortName|Artist&format=json&redirects=1&titles="
var wikidata_endpoint = "https://www.wikidata.org/w/api.php?action=wbgetclaims&property=P373&format=json&entity="
var wikimedia_commons_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=categorymembers&gcmtype=file&gcmlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&gcmtitle="

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
		if next_fetch[0] == "fetch_wikidata":
			fetch_wikidata(next_fetch[1], next_fetch[2])
		elif next_fetch[0] == "fetch_images":
			fetch_images(next_fetch[1], next_fetch[2])
		elif next_fetch[0] == "fetch_commons_images":
			fetch_commons_images(next_fetch[1], next_fetch[2])
		else:
			push_error("unknown queue item. type=", next_fetch[0])

func _join_titles(titles):
	return "|".join(titles.map(func(t): return t.uri_encode()))

func _read_from_cache(title, prefix=WIKIPEDIA_PREFIX):
	var json = DataManager.load_json_data(prefix + title)
	if json:
		_results[title] = json
	return json

func _get_uncached_titles(titles, prefix=WIKIPEDIA_PREFIX):
	var new_titles = []
	for title in titles:
		if title == "":
			continue
		if not get_result(title):
			var cached = _read_from_cache(title, prefix)
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

func fetch_commons_images(category, context):
	var new_category = _get_uncached_titles([category], WIKIMEDIA_COMMONS_PREFIX)

	if len(new_category) == 0:
		emit_signal("commons_images_complete", category, context)
		return

	# queue if another request is in flight
	if _request_in_flight:
		_request_queue.append([ "fetch_commons_images", category, context ])
		return
	_request_in_flight = true

	var url = wikimedia_commons_images_endpoint + category.uri_encode()
	var ctx = {
		"category": category,
		"image_titles": []
	}

	_dispatch_request(url, ctx, context)

func fetch_wikidata(entity, context):
	var new_entity = _get_uncached_titles([entity], WIKIDATA_PREFIX)

	if len(new_entity) == 0:
		emit_signal("wikidata_complete", entity, context)
		return

	# queue if another request is in flight
	if _request_in_flight:
		_request_queue.append([ "fetch_wikidata", entity, context ])
		return
	_request_in_flight = true

	var url = wikidata_endpoint + entity.uri_encode()
	var ctx = {
		"entity": entity
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

	if res.has("query"):
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

	# wikipedia request must have "query" object.
	# wikidata does not need to have it
	elif not ctx.url.begins_with(wikidata_endpoint):
		print("RETURN TRUE BC NO QUERY")
		return true

	if ctx.url.begins_with(wikitext_endpoint):
		return _on_wikitext_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(images_endpoint):
		return _on_images_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(wikidata_endpoint):
		print("DISPATCH ON WIKIDATA REQUEST COMPLETE")
		return _on_wikidata_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(wikimedia_commons_images_endpoint):
		return _on_commons_images_request_complete(res, ctx, caller_ctx)

func _dispatch_continue(continue_fields, base_url, titles, ctx, caller_ctx):
	var continue_url = base_url
	if typeof(titles) == TYPE_ARRAY:
		continue_url += _join_titles(titles)
	else:
		continue_url += titles.uri_encode()

	for field in continue_fields.keys():
		continue_url += "&" + field + "=" + continue_fields[field].uri_encode()
	ctx.url = continue_url
	_dispatch_request(continue_url, ctx, caller_ctx)

func _cache_all(titles, prefix=WIKIPEDIA_PREFIX):
	for title in titles:
		var result = get_result(title)
		if result != null:
			DataManager.save_json_data(prefix + title, result)

func _on_wikitext_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	if res.query.has("pages"):
		var pages = res.query.pages
		for page_id in pages.keys():
			var page = pages[page_id]
			if page.has("revisions"):
				var revisions = page.revisions
				_set_page_field(page.title, "wikitext", revisions[0]["*"])
			if page.has("extract"):
				_set_page_field(page.title, "extract", page.extract)
			if page.has("pageprops") and page.pageprops.has("wikibase_item"):
				var item = page.pageprops.wikibase_item
				_set_page_field(page.title, "wikidata_entity", item)

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

func _on_commons_images_request_complete(res, ctx, caller_ctx):
	var image_titles = ctx.image_titles
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
				image_titles.append(file)
				_append_page_field(ctx.category, "images", [ file ])

	# handle continues
	if res.has("continue"):
		_dispatch_continue(res.continue, wikimedia_commons_images_endpoint, ctx.category, ctx, caller_ctx)
		return false
	else:
		_cache_all(ctx.image_titles, WIKIMEDIA_COMMONS_PREFIX)
		_cache_all([ ctx.category ], WIKIMEDIA_COMMONS_PREFIX)
		emit_signal("commons_images_complete", ctx.category, caller_ctx)
		return true

func _on_wikidata_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	if res.has("claims"):
		if res.claims.has(WIKIDATA_COMMONS_CATEGORY):
			var claims = res.claims[WIKIDATA_COMMONS_CATEGORY]
			if len(claims) > 0:
				var claim = claims[0]
				var value = claim.mainsnak.datavalue.value
				_set_page_field(ctx.entity, "commons_category", "Category:" + value)

	_cache_all([ ctx.entity ], WIKIDATA_PREFIX)
	emit_signal("wikidata_complete", ctx.entity, caller_ctx)
	return true
