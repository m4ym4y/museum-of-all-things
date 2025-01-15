extends Node

signal wikitext_complete(titles, context)
signal wikitext_failed(titles, message)
signal wikidata_complete(ids, context)
signal images_complete(files, context)
signal commons_images_complete(category, context)

const MAX_BATCH_SIZE = 50
const REQUEST_DELAY_MS = 1000

# TODO: wikimedia support, and category support
const WIKIMEDIA_COMMONS_PREFIX = "https://commons.wikimedia.org/wiki/"
const WIKIPEDIA_PREFIX = "https://wikipedia.org/wiki/"
const WIKIDATA_PREFIX = "https://www.wikidata.org/wiki/"

const WIKIDATA_COMMONS_CATEGORY = "P373"
const WIKIDATA_COMMONS_GALLERY = "P935"

var wikitext_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=revisions|extracts|pageprops&ppprop=wikibase_item&explaintext=true&rvprop=content&format=json&redirects=1&titles="
var images_endpoint = "https://en.wikipedia.org/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640&iiextmetadatafilter=LicenseShortName|Artist&format=json&redirects=1&titles="
var wikidata_endpoint = "https://www.wikidata.org/w/api.php?action=wbgetclaims&format=json&entity="

var wikimedia_commons_category_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=categorymembers&gcmtype=file&gcmlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&gcmtitle="
var wikimedia_commons_gallery_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=images&gimlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&titles="

var _fs_lock = Mutex.new()
var _results_lock = Mutex.new()
var _results = {}

var _network_request_thread = Thread.new()
var NETWORK_QUEUE = "Network"

func _ready():
  _network_request_thread.start(_network_request_thread_loop)

func _exit_tree():
  WorkQueue.set_quitting()
  _network_request_thread.wait_to_finish()

func _delayed_advance_queue():
  OS.delay_msec(REQUEST_DELAY_MS)

func _network_request_thread_loop():
  while not WorkQueue.get_quitting():
    var item = WorkQueue.process_queue(NETWORK_QUEUE)
    if not item:
      continue
    elif item[0] == "fetch_wikitext":
      _fetch_wikitext(item[1], item[2])
    elif item[0] == "fetch_images":
      _fetch_images(item[1], item[2])
    elif item[0] == "fetch_commons_images":
      _fetch_commons_images(item[1], item[2])
    elif item[0] == "fetch_wikidata":
      _fetch_wikidata(item[1], item[2])
    elif item[0] == "fetch_continue":
      _dispatch_request(item[1], item[2], item[3])

func fetch(titles, ctx):
  # queue wikitext fetch in front of queue to improve next exhibit load time
  WorkQueue.add_item(NETWORK_QUEUE, ["fetch_wikitext", titles, ctx], null, true)

func fetch_images(titles, ctx):
  WorkQueue.add_item(NETWORK_QUEUE, ["fetch_images", titles, ctx])

func fetch_wikidata(titles, ctx):
  WorkQueue.add_item(NETWORK_QUEUE, ["fetch_wikidata", titles, ctx])

func fetch_commons_images(titles, ctx):
  WorkQueue.add_item(NETWORK_QUEUE, ["fetch_commons_images", titles, ctx])

func _fetch_continue(url, ctx, caller_ctx, queue):
  WorkQueue.add_item(NETWORK_QUEUE, ["fetch_continue", url, ctx, caller_ctx], queue)

const LOCATION_STR = "location: "
func _get_location_header(headers):
  for header in headers:
    if header.begins_with(LOCATION_STR):
      return header.substr(LOCATION_STR.length())

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
    fetch_images(new_files.slice(MAX_BATCH_SIZE), context)
    new_files = new_files.slice(0, MAX_BATCH_SIZE)

  var url = images_endpoint + _join_titles(new_files)
  var ctx = {
    "files": files,
    "new_files": new_files,
    "queue": WorkQueue.get_current_exhibit()
  }

  _dispatch_request(url, ctx, context)

func _get_commons_url(category):
  if category.begins_with("Category:"):
    return wikimedia_commons_category_images_endpoint
  else:
    return wikimedia_commons_gallery_images_endpoint

func _fetch_commons_images(category, context):
  var new_category = _get_uncached_titles([category], WIKIMEDIA_COMMONS_PREFIX)

  if len(new_category) == 0:
    var result = get_result(category)
    if result and result.has("images"):
      for image in result.images:
        if not _read_from_cache(image, WIKIMEDIA_COMMONS_PREFIX):
          push_error("unable to read image from cache. category=%s image=%s" % [category, image])
      call_deferred("emit_signal", "commons_images_complete", result.images, context)
      return

  var url = _get_commons_url(category) + category.uri_encode()
  var ctx = {
    "category": category,
    "queue": WorkQueue.get_current_exhibit()
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
    _delayed_advance_queue()
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
    _delayed_advance_queue()

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
  elif ctx.url.begins_with(wikimedia_commons_category_images_endpoint):
    return _on_commons_images_request_complete(res, ctx, caller_ctx)
  elif ctx.url.begins_with(wikimedia_commons_gallery_images_endpoint):
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

  _fetch_continue(continue_url, ctx, caller_ctx, ctx.queue)
  return false

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
    _cache_all(file_batch, WIKIMEDIA_COMMONS_PREFIX)
    call_deferred("emit_signal", "commons_images_complete", file_batch, caller_ctx)

  # handle continues
  if res.has("continue"):
    return _dispatch_continue(res.continue, _get_commons_url(ctx.category), ctx.category, ctx, caller_ctx)
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
    if res.claims.has(WIKIDATA_COMMONS_GALLERY):
      var claims = res.claims[WIKIDATA_COMMONS_GALLERY]
      if len(claims) > 0:
        var claim = claims[0]
        var value = claim.mainsnak.datavalue.value
        _set_page_field(ctx.entity, "commons_gallery", value)

  _cache_all([ ctx.entity ], WIKIDATA_PREFIX)
  call_deferred("emit_signal", "wikidata_complete", ctx.entity, caller_ctx)
  return true
