extends Node

var port = 443
var protocol = "https://"
var DELAY_MS = 10
var USER_AGENT = "https://github.com/m4ym4y/wikipedia-museum"
var COMMON_HEADERS = [
  "accept: application/json; charset=utf-8",
  "user-agent: " + USER_AGENT
]

# TODO: a version where we reuse the http client
func request(url, headers=COMMON_HEADERS, verbose=true):
  if OS.is_debug_build() and verbose:
    print("fetching url ", url)

  var http_client = HTTPClient.new()
  var host_idx = url.find("/", len(protocol)) # first slash after protocol
  var host = url.substr(0, host_idx)
  var path = url.substr(host_idx)

  var err = http_client.connect_to_host(host, port, TLSOptions.client())
  if err != OK:
    return [err, 0, null]

  while (
    http_client.get_status() == HTTPClient.STATUS_CONNECTING or
    http_client.get_status() == HTTPClient.STATUS_RESOLVING
  ):
    http_client.poll()
    Util.delay_msec(DELAY_MS)

  if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
    return [FAILED, 0, null, null]

  http_client.request(HTTPClient.METHOD_GET, path, headers)

  while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
    http_client.poll()
    Util.delay_msec(DELAY_MS)

  if http_client.get_status() != HTTPClient.STATUS_BODY:
    return [FAILED, 0, null, null]

  var response = PackedByteArray()
  while http_client.get_status() == HTTPClient.STATUS_BODY:
    http_client.poll()
    var chunk = http_client.read_response_body_chunk()
    if chunk.size() > 0:
      response.append_array(chunk)
    Util.delay_msec(DELAY_MS)

  var response_code = http_client.get_response_code()
  var response_headers = http_client.get_response_headers()
  return [OK, response_code, response_headers, response]

class ResponseAsync:
  signal completed (result)

func request_async(url, headers=COMMON_HEADERS, verbose=true):
  if OS.is_debug_build() and verbose:
    print("fetching url ", url)

  if Util.is_web():
    # Headers don't always work from the web, let's just not send any.
    headers = []

  var resp = ResponseAsync.new()

  var req = HTTPRequest.new()
  req.use_threads = Util.is_using_threads() and not Util.is_web()
  req.request_completed.connect(_on_async_request_completed.bind(req, resp))

  var do_request = func(parent):
    parent.add_child(req)
    req.request(url, headers)

  do_request.call_deferred(self)

  return resp

func _on_async_request_completed(result, response_code, headers, body, req, resp):
  resp.completed.emit([result, response_code, headers, body])
  req.queue_free()
