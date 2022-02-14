extends Node
class_name Sort


static func alphabetical(a, b):
	if a.title < b.title:
		return true
	return false


static func downloads(a, b):
	if int(a.downloads) > int(b.downloads):
		return true
	return false


static func newest(a, b):
	if a.createdAt > b.createdAt:
		return true
	return false
