extends Node

var backend_url = "http://localhost:8080/"
var httpRequest: HTTPRequest
var isFetching = false
var isGettingRequest = false

func _ready() -> void:
	httpRequest = HTTPRequest.new()
	
	if not httpRequest.is_inside_tree():
		add_child(httpRequest)

func send_post_request(route: String, data: Dictionary) -> Dictionary:
	var delay = 0.5
	var url = route
	var json_data = JSON.stringify(data)

	var headers = [
		"Content-Type: application/json"
	]
	
	for tries in range(3):
		isFetching = true
		var err = httpRequest.request(url, headers, HTTPClient.METHOD_POST, json_data)
		
		if err != OK:
			isFetching = false
			print("Failed to send request, tries: %s" % tries)
			await get_tree().create_timer(delay * tries).timeout
			continue

		# Wait for the request to complete
		var result = await httpRequest.request_completed
		var response_code = result[1]
		
		if response_code != 200:
			print("Server responded with code: %s tries: %s" % [response_code, tries])
			await get_tree().create_timer(delay * tries).timeout
			continue
		
		var response_text = result[3].get_string_from_utf8()
		var response_json = JSON.parse_string(response_text)
		isFetching = false
		return response_json

	print("All entries failed")
	return {}

func get_request(route: String) -> Dictionary:
	var delay = 0.5
	var url = route

	var headers = [
		"Accept: application/json"
	]

	for tries in range(3):
		isGettingRequest = true
		var err = httpRequest.request(url, headers, HTTPClient.METHOD_GET)
		
		if err != OK:
			isGettingRequest = false
			print("Failed to send GET request, tries: %s" % tries)
			await get_tree().create_timer(delay * tries).timeout
			continue
			
		# Wait for the request to complete
		var result = await httpRequest.request_completed
		var response_text = result[3].get_string_from_utf8()
		var response_json = JSON.parse_string(response_text)
		
		isGettingRequest = false
		return response_json
		
	print("All tries failed in get request")
	return {}
