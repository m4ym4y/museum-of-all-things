extends Control

signal resume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalMenuEvents.open_terminal_menu.connect(reset)
	GlobalMenuEvents.terminal_result_ready.connect(_on_terminal_result_ready)
	GlobalMenuEvents.ui_cancel_pressed.connect(_resume)
	ExhibitFetcher.search_complete.connect(_show_page_result)
	ExhibitFetcher.random_complete.connect(_show_page_result)
	reset()

func _resume():
	emit_signal("resume")

func reset():
	$MarginContainer/StartPage/RandomExhibit.disabled = false
	$MarginContainer/SearchPage/SearchExhibit.disabled = false
	_switch_to_page("StartPage")
	$MarginContainer/StartPage/EnterExhibit.grab_focus()

func _switch_to_page(page):
	for vbox in $MarginContainer.get_children():
		vbox.visible = false
	get_node("MarginContainer/" + page).visible = true

func _go_to_search_page():
	_switch_to_page("SearchPage")
	GlobalMenuEvents.emit_reset_custom_door()
	$MarginContainer/SearchPage/ExhibitTitle.grab_focus()

func _get_random_page():
	$MarginContainer/StartPage/RandomExhibit.disabled = true
	GlobalMenuEvents.emit_reset_custom_door()
	ExhibitFetcher.fetch_random(null)

func _search_exhibit():
	var search_text = $MarginContainer/SearchPage/ExhibitTitle.text
	if len(search_text) > 0:
		$MarginContainer/SearchPage/SearchExhibit.disabled = true
		ExhibitFetcher.fetch_search($MarginContainer/SearchPage/ExhibitTitle.text, null)

func _show_page_result(page, _ctx):
	_on_terminal_result_ready(not page, page)

func _on_terminal_result_ready(error: bool, page: String):
	if error:
		_switch_to_page("ErrorPage")
		$MarginContainer/ErrorPage/Reset.grab_focus()
	else:
		_switch_to_page("ResultPage")
		GlobalMenuEvents.emit_set_custom_door(page)
		$MarginContainer/ResultPage/ResultLabel.text = "Exhibit Found: \"%s\"" % page
		$MarginContainer/ResultPage/Reset.grab_focus()

func _on_reset_pressed():
	reset()
	_resume()
