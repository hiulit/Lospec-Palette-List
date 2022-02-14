extends Node
class_name Filter


static func includes(type: String, base_array: Array, filter_array: Array, filter_key: String = "") -> Array:
	var filtered_array := []

	for base_item in base_array:
		var count = 0
		var search_item = base_item

		if filter_key:
			search_item = base_item[filter_key]

		if type == "every":
			for filter_item in filter_array:
				if filter_item in search_item:
					count += 1
			if count == filter_array.size():
				filtered_array.append(base_item)
		elif type == "some":
			for filter_item in filter_array:
				if filter_item in search_item:
					filtered_array.append(base_item)
					break

	return filtered_array
