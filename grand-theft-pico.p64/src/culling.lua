--[[pod_format="raw"]]
-- culling.lua - Frustum and wall face culling

-- Check if building is within screen bounds (frustum culling)
function is_building_visible(b)
	local sx, sy = world_to_screen(b.x, b.y)
	local sx2, sy2 = world_to_screen(b.x + b.w, b.y + b.h)

	if sx2 < -CULL_MARGIN then return false end
	if sx > SCREEN_W + CULL_MARGIN then return false end
	if sy2 < -CULL_MARGIN then return false end
	if sy > SCREEN_H + CULL_MARGIN then return false end

	return true
end
