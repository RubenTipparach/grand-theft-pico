--[[pod_format="raw"]]
-- utils.lua - Utility functions

-- Quicksort implementation for Picotron
-- Sorts array in place by Y position (for painter's algorithm)
function quicksort_by_y(arr, low, high)
	if low < high then
		local pivot_idx = partition_by_y(arr, low, high)
		quicksort_by_y(arr, low, pivot_idx - 1)
		quicksort_by_y(arr, pivot_idx + 1, high)
	end
end

-- Partition helper for quicksort (sorts by .y ascending)
function partition_by_y(arr, low, high)
	local pivot = arr[high].y
	local i = low - 1

	for j = low, high - 1 do
		if arr[j].y <= pivot then
			i = i + 1
			arr[i], arr[j] = arr[j], arr[i]
		end
	end

	arr[i + 1], arr[high] = arr[high], arr[i + 1]
	return i + 1
end

-- Convenience wrapper to sort entire array by Y
function sort_by_y(arr)
	if #arr > 1 then
		quicksort_by_y(arr, 1, #arr)
	end
end

-- Generic quicksort with custom compare function
-- compare(a, b) returns true if a should come before b
function quicksort(arr, low, high, compare)
	if low < high then
		local pivot_idx = partition(arr, low, high, compare)
		quicksort(arr, low, pivot_idx - 1, compare)
		quicksort(arr, pivot_idx + 1, high, compare)
	end
end

-- Generic partition helper
function partition(arr, low, high, compare)
	local pivot = arr[high]
	local i = low - 1

	for j = low, high - 1 do
		if compare(arr[j], pivot) then
			i = i + 1
			arr[i], arr[j] = arr[j], arr[i]
		end
	end

	arr[i + 1], arr[high] = arr[high], arr[i + 1]
	return i + 1
end

-- Convenience wrapper for generic sort
function sort_list(arr, compare)
	if #arr > 1 then
		quicksort(arr, 1, #arr, compare)
	end
end
