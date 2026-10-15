extends RefCounted

static var _grids: Dictionary = {}
# Internal read-only adjacency. Reuse it within searches rather than allocating
# four neighbors and matching direction strings for every visited cell.
static func grid(width: int, height: int, order: Array) -> Array:
	var key: String = str(width) + "x" + str(height) + str(order)
	if not _grids.has(key):
		if _grids.size() >= 8: _grids.clear()
		var cells: Array = []
		for pos in range(width * height): cells.append(neighbors(pos, width, height, order))
		_grids[key] = cells
	return _grids[key]

static func flood(start: int, width: int, height: int, passable: Callable, order: Array) -> Dictionary:
	var adjacent: Array = grid(width, height, order)
	var distances: Dictionary = {start: 0}
	var previous: Dictionary = {start: -1}
	var queue: Array = [start]
	var cursor: int = 0
	while cursor < queue.size():
		var pos: int = queue[cursor]; cursor += 1
		for next in adjacent[pos]:
			if distances.has(next) or not passable.call(next): continue
			distances[next] = int(distances[pos]) + 1; previous[next] = pos; queue.append(next)
	return {"distance": distances, "previous": previous, "start": start}

# Dijkstra with a stable insertion tie-break. A negative entering cost is a wall.
static func cost_tree(start: int, width: int, height: int, cost: Callable, order: Array = ["up", "left", "right", "down"], target: int = -1) -> Dictionary:
	var adjacent: Array = grid(width, height, order)
	var distances: Dictionary = {start: 0}
	var previous: Dictionary = {start: -1}
	var weights: PackedInt32Array = PackedInt32Array(); weights.resize(width * height); weights.fill(-2147483648)
	var heap: Array = [[0, 0, start]]
	var sequence: int = 0
	while not heap.is_empty():
		var item: Array = _heap_pop(heap)
		var current: int = item[2]
		if item[0] != distances[current]: continue
		if current == target: break
		for next in adjacent[current]:
			if weights[next] == -2147483648: weights[next] = int(cost.call(next))
			var weight: int = weights[next]
			if weight < 0: continue
			var distance: int = int(item[0]) + maxi(1, weight)
			if distances.has(next) and int(distances[next]) <= distance: continue
			distances[next] = distance; previous[next] = current
			sequence += 1
			_heap_push(heap, [distance, sequence, next])
	return {"distance": distances, "previous": previous, "start": start}

static func route(tree: Dictionary, target: int) -> Array:
	if not tree.previous.has(target) or target == tree.start: return []
	var result: Array = []
	var cursor: int = target
	while cursor != tree.start:
		result.push_front(cursor)
		cursor = tree.previous[cursor]
	return result

static func _heap_less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _heap_less(heap[index], heap[parent]): break
		var swap: Array = heap[parent]; heap[parent] = heap[index]; heap[index] = swap
		index = parent

static func _heap_pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return result
	heap[0] = last
	var index: int = 0
	while index * 2 + 1 < heap.size():
		var child: int = index * 2 + 1
		if child + 1 < heap.size() and _heap_less(heap[child + 1], heap[child]): child += 1
		if not _heap_less(heap[child], heap[index]): break
		var swap: Array = heap[index]; heap[index] = heap[child]; heap[child] = swap
		index = child
	return result

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
	var adjacent: Array = grid(width, height, order)
	var queue: Array = [start]
	var visited: Dictionary = {start: -1}
	var cursor := 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		for next in adjacent[current]:
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
