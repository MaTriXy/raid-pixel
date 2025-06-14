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
	if not isFetching:
		var url = route
		var json_data = JSON.stringify(data)

		var headers = [
			"Content-Type: application/json"
		]
		
		isFetching = true
		var err = httpRequest.request(url, headers, HTTPClient.METHOD_POST, json_data)
		
		if err != OK:
			isFetching = false
			print("Failed to send request")
			return {}

		# Wait for the request to complete
		var result = await httpRequest.request_completed
		var response_code = result[1]
		
		if response_code != 200:
			print("Server responded with code: ", response_code)
			return {}
		
		var response_text = result[3].get_string_from_utf8()
		var response_json = JSON.parse_string(response_text)
		isFetching = false
		return response_json
	else:
		return {}

func get_request(route: String) -> Dictionary:
	if not isGettingRequest:
		var url = route

		var headers = [
			"Accept: application/json"
		]

		isGettingRequest = true
		var err = httpRequest.request(url, headers, HTTPClient.METHOD_GET)
		
		if err != OK:
			isGettingRequest = false
			print("Failed to send GET request")
			return {}
			
		# Wait for the request to complete
		var result = await httpRequest.request_completed
		var response_text = result[3].get_string_from_utf8()
		var response_json = JSON.parse_string(response_text)
		
		isGettingRequest = false
		return response_json if typeof(response_json) == TYPE_DICTIONARY else {}
	else:
		return {}
