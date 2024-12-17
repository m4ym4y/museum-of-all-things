extends Node

signal wikitext_complete(titles, context)
signal wikitext_failed(titles, message)
signal wikidata_complete(ids, context)
signal images_complete(files, context)
signal commons_images_complete(category, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY = 1.0

# TODO: wikimedia support, and category support
const WIKIMEDIA_COMMONS_PREFIX = "https://commons.wikimedia.org/wiki/"
const WIKIPEDIA_PREFIX = "https://wikipedia.org/wiki/"
const WIKIDATA_PREFIX = "https://www.wikidata.org/wiki/"

const WIKIDATA_COMMONS_CATEGORY = "P373"

var wikitext_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions|extracts|pageprops&ppprop=wikibase_item&explaintext=true&rvprop=content&format=json&redirects=1&titles="
var images_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640&iiextmetadatafilter=LicenseShortName|Artist&format=json&redirects=1&titles="
var wikidata_endpoint = "https://www.wikidata.org/w/api.php?action=wbgetclaims&property=P373&format=json&entity="
var wikimedia_commons_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=categorymembers&gcmtype=file&gcmlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&gcmtitle="

var _request_queue_lock = Mutex.new()
var _request_queue_map = {}
var _request_queue_title = "$Lobby"
var _request_queue_finished = false

var _fs_lock = Mutex.new()
var _results_lock = Mutex.new()
var _results = {}

var _network_request_thread = Thread.new()
var NETWORK_QUEUE = "Network"

func _ready():
	_network_request_thread.start(_network_request_thread_loop)

func _delayed_advance_queue():
	get_tree().create_timer(REQUEST_DELAY).timeout.connect(_advance_queue)

func _network_request_thread_loop():
	while true:
		var item = WorkQueue.process_queue(NETWORK_QUEUE)
		if item[0] == "fetch_wikitext":
			_fetch_wikitext(item[1], item[2])
		elif item[0] == "fetch_images":
			_fetch_images(item[1], item[2])
		elif item[0] == "fetch_commons_images":
			_fetch_commons_images(item[1], item[2])
		elif item[0] == "fetch_wikidata":
			_fetch_wikidata(item[1], item[2])

func fetch(titles, ctx):
	WorkQueue.add_item(NETWORK_QUEUE, ["fetch_wikitext", titles, ctx])

func fetch_images(titles, ctx):
	WorkQueue.add_item(NETWORK_QUEUE, ["fetch_images", titles, ctx])

func fetch_wikidata(titles, ctx):
	WorkQueue.add_item(NETWORK_QUEUE, ["fetch_wikidata", titles, ctx])

func fetch_commons_images(titles, ctx):
	WorkQueue.add_item(NETWORK_QUEUE, ["fetch_commons_images", titles, ctx])

const LOCATION_STR = "location: "
func _get_location_header(headers):
	for header in headers:
		if header.begins_with(LOCATION_STR):
			return header.substr(LOCATION_STR.length())

func switch_active_queue(title):
	if not _request_queue_map.has(title):
		_request_queue_map[title] = []
	_request_queue_title = title
	if _request_queue_finished:
		_advance_queue()

# TODO: should the queue batch together all the upcoming requests?
func _advance_queue():
	_request_queue_lock.lock()
	var next_fetch = _request_queue_map[_request_queue_title].pop_front()
	_request_queue_lock.unlock()
	if next_fetch != null:
		_request_queue_finished = false
		next_fetch.call()
	else:
		_request_queue_finished = true

func _join_titles(titles):
	return "|".join(titles.map(func(t): return t.uri_encode()))

func _read_from_cache(title, prefix=WIKIPEDIA_PREFIX):
	_fs_lock.lock()
	var json = DataManager.load_json_data(prefix + title)
	_fs_lock.unlock()
	if json:
		_results_lock.lock()
		_results[title] = json
		_results_lock.unlock()
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

func _fetch_images(files, context):
	var new_files = _get_uncached_titles(files)

	if len(new_files) == 0:
		call_deferred("emit_signal", "images_complete", files, context)
		return

	if len(new_files) > MAX_BATCH_SIZE:
		_request_queue_lock.lock()
		_request_queue_map[_request_queue_title].append(fetch_images.bind(
			new_files.slice(MAX_BATCH_SIZE),
			context
		))
		_request_queue_lock.unlock()
		new_files = new_files.slice(0, MAX_BATCH_SIZE)

	var url = images_endpoint + _join_titles(new_files)
	var ctx = {
		"files": files,
		"new_files": new_files,
		"queue": _request_queue_title
	}

	_dispatch_request(url, ctx, context)

func _fetch_commons_images(category, context):
	var new_category = _get_uncached_titles([category], WIKIMEDIA_COMMONS_PREFIX)

	if len(new_category) == 0:
		var result = get_result(category)
		if result and result.has("images"):
			var complete = true
			for image in result.images:
				if not _read_from_cache(image, WIKIMEDIA_COMMONS_PREFIX):
					complete = false
			if complete:
				call_deferred("emit_signal", "commons_images_complete", result.images, context)
				return

	var url = wikimedia_commons_images_endpoint + category.uri_encode()
	var ctx = {
		"category": category,
		"queue": _request_queue_title
	}

	_dispatch_request(url, ctx, context)

func _fetch_wikidata(entity, context):
	var new_entity = _get_uncached_titles([entity], WIKIDATA_PREFIX)

	if len(new_entity) == 0:
		call_deferred("emit_signal", "wikidata_complete", entity, context)
		return

	var url = wikidata_endpoint + entity.uri_encode()
	var ctx = {
		"entity": entity
	}

	_dispatch_request(url, ctx, context)

func _fetch_wikitext(titles, context):
	var new_titles = _get_uncached_titles(titles)

	if len(new_titles) == 0:
		call_deferred("emit_signal", "wikitext_complete", titles, context)
		return

	if len(new_titles) > MAX_BATCH_SIZE:
		push_error("Too many page requests at once")
		return

	var url = wikitext_endpoint + _join_titles(new_titles)
	var ctx = {
		"titles": titles,
		"new_titles": new_titles,
	}

	# dispatching mediawiki request
	_dispatch_request(url, ctx, context)

func get_result(title):
	var res = null
	_results_lock.lock()
	if _results.has(title):
		var result = _results[title]
		if result.has("normalized"):
			if _results.has(result.normalized):
				res = _results[result.normalized]
			else:
				res = null
		else:
			res = result
	_results_lock.unlock()
	return res

func _dispatch_request(url, ctx, caller_ctx):
	ctx.url = url
	var result = RequestSync.request(url)

	if result[0] != OK:
		push_error("failed to send http request ", result[0], " ", url)
		call_deferred("_delayed_advance_queue")
	else:
		_on_request_completed_wrapper(result[0], result[1], result[2], result[3], ctx, caller_ctx)

func _set_page_field(title, field, value):
	_results_lock.lock()
	if not _results.has(title):
		_results[title] = {}
	_results[title][field] = value
	_results_lock.unlock()

func _append_page_field(title, field, values):
	_results_lock.lock()
	if not _results.has(title):
		_results[title] = {}
	if not _results[title].has(field):
		_results[title][field] = []
	_results[title][field].append_array(values)
	_results_lock.unlock()

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
		call_deferred("_delayed_advance_queue")

func _on_request_completed(result, response_code, headers, body, ctx, caller_ctx):
	if result != 0 or response_code != 200:
		if response_code != 404:
			push_error("error in request ", result, " ", response_code, " ", ctx.url)
		if ctx.url.begins_with(wikitext_endpoint):
			call_deferred("emit_signal", "wikitext_failed", ctx.new_titles, str(response_code))
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
		return true

	if ctx.url.begins_with(wikitext_endpoint):
		return _on_wikitext_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(images_endpoint):
		return _on_images_request_complete(res, ctx, caller_ctx)
	elif ctx.url.begins_with(wikidata_endpoint):
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

	# continue right now if we're still the active article
	if ctx.queue == _request_queue_title:
		_dispatch_request(continue_url, ctx, caller_ctx)
		return false
	elif _request_queue_map.has(ctx.queue):
		var continue_call = _dispatch_request.bind(continue_url, ctx, caller_ctx)
		_request_queue_lock.lock()
		_request_queue_map[ctx.queue].append(continue_call)
		_request_queue_lock.unlock()
		return true

func _cache_all(titles, prefix=WIKIPEDIA_PREFIX):
	for title in titles:
		var result = get_result(title)
		if result != null:
			_fs_lock.lock()
			DataManager.save_json_data(prefix + title, result)
			_fs_lock.unlock()

func _get_original_title(query, title):
	if query.has("normalized"):
		for t in query.normalized:
			if t.to == title:
				return t.from
	if query.has("redirects"):
		for t in query.redirects:
			if t.to == title:
				return t.from
	return title

func _on_wikitext_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	if res.query.has("pages"):
		var pages = res.query.pages
		for page_id in pages.keys():
			var page = pages[page_id]

			# emit failed signal for a missing page
			if page.has("missing"):
				var original_title = _get_original_title(res.query, page.title)
				call_deferred("emit_signal", "wikitext_failed", [original_title], "Missing")
				ctx.new_titles.erase(original_title)
				ctx.titles.erase(original_title)
				continue

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
		return _dispatch_continue(res.continue, wikitext_endpoint, ctx.new_titles, ctx, caller_ctx)
	else:
		_cache_all(ctx.new_titles)
		call_deferred("emit_signal", "wikitext_complete", ctx.titles, caller_ctx)
		# wikitext ignores queue, so return false to prevent queue advance after completion
		return false

func _on_images_request_complete(res, ctx, caller_ctx):
	# store the information we did get
	var file_batch = []

	if res.query.has("pages"):
		var pages = res.query.pages
		for page_id in pages.keys():
			var page = pages[page_id]
			var file = page.title
			if not page.has("imageinfo"):
				continue
			file_batch.append(_get_original_title(res.query, file))
			for info in page.imageinfo:
				if info.has("extmetadata"):
					var md = info.extmetadata
					if md.has("LicenseShortName"):
						_set_page_field(file, "license_short_name", md.LicenseShortName.value)
					if md.has("Artist"):
						_set_page_field(file, "artist", md.Artist.value)
				if info.has("thumburl"):
					_set_page_field(file, "src", info.thumburl)

	if len(file_batch) > 0:
		_cache_all(file_batch)
		call_deferred("emit_signal", "images_complete", file_batch, caller_ctx)

	# handle continues
	if res.has("continue"):
		return _dispatch_continue(res.continue, images_endpoint, ctx.new_files, ctx, caller_ctx)
	else:
		return true

func _on_commons_images_request_complete(res, ctx, caller_ctx):
	var file_batch = []

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
				file_batch.append(file)
				_append_page_field(ctx.category, "images", [ file ])

	if len(file_batch) > 0:
		_cache_all(file_batch)
		call_deferred("emit_signal", "commons_images_complete", file_batch, caller_ctx)

	# handle continues
	if res.has("continue"):
		return _dispatch_continue(res.continue, wikimedia_commons_images_endpoint, ctx.category, ctx, caller_ctx)
	else:
		_cache_all([ ctx.category ], WIKIMEDIA_COMMONS_PREFIX)
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
	call_deferred("emit_signal", "wikidata_complete", ctx.entity, caller_ctx)
	return true
