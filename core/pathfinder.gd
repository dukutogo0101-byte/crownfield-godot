extends RefCounted

static func neighbors(pos: int, width: int, height: int, order: Array = ["up", "left", "right", "down"]) -> Array:
	var result: Array = []
	var x: int = pos % width
	var y: int = pos / width
	for direction in order:
		match direction:
			"up":
				if y > 0: result.append(pos - width)
			"left":
				if x > 0: result.append(pos - 1)
			"right":
				if x < width - 1: result.append(pos + 1)
			"down":
				if y < height - 1: result.append(pos + width)
	return result

static func path(start: int, target: int, width: int, height: int, passable: Callable, order: Array = ["up", "left", "right", "down"]) -> Array:
	if start == target: return []
	var queue: Array = [start]
	var visited: Dictionary = {start: -1}
	var cursor := 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		for next in neighbors(current, width, height, order):
			if visited.has(next) or not passable.call(next): continue
			visited[next] = current
			if next == target:
				var result: Array = [next]
				var previous: int = current
				while previous != start:
					result.push_front(previous)
					previous = visited[previous]
				return result
			queue.append(next)
	return []
