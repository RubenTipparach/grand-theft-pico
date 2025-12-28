--[[pod_format="raw"]]
-- worldgen.lua - Parse sprite 255 map to generate world data

-- Parsed world data (populated by parse_world_map)
WORLD_DATA = {
	tiles = nil,        -- 2D userdata of tile types (grass/water/road)
	roads = {},         -- Generated road segments for ROADS table
	countryside_roads = {}, -- Generated dirt roads for COUNTRYSIDE_ROADS
	water_tiles = {},   -- List of water tile positions for rendering
}

-- Tile type constants for parsed map
MAP_TILE_GRASS = 0
MAP_TILE_WATER = 1
MAP_TILE_MAIN_ROAD = 2
MAP_TILE_DIRT_ROAD = 3
MAP_TILE_SIDEWALK_NS = 4  -- sidewalk running north-south (along vertical roads)
MAP_TILE_SIDEWALK_EW = 5  -- sidewalk running east-west (along horizontal roads)
MAP_TILE_BUILDING_ZONE = 6  -- zone where buildings can spawn

-- Loading progress (0-100)
loading_progress = 0
loading_message = ""

-- Draw loading screen
function draw_loading_screen()
	cls(0)
	local bar_w = 200
	local bar_h = 16
	local bar_x = (480 - bar_w) / 2
	local bar_y = 135

	-- Draw loading text
	print(loading_message, bar_x, bar_y - 20, 33)

	-- Draw progress bar background
	rectfill(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 1)

	-- Draw progress bar fill
	local fill_w = (loading_progress / 100) * bar_w
	rectfill(bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, 11)

	-- Draw border
	rect(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 7)

	-- Draw percentage
	local pct_text = tostr(flr(loading_progress)) .. "%"
	print(pct_text, bar_x + bar_w / 2 - 8, bar_y + 4, 33)

	flip()
end

-- Parse sprite 255 and generate world data
function parse_world_map()
	local cfg = MAP_CONFIG
	local map_spr = get_spr(cfg.sprite_id)
	local w = cfg.map_width
	local h = cfg.map_height
	local tile_size = cfg.tile_size
	local colors = cfg.colors

	printh("Parsing world map from sprite " .. cfg.sprite_id)
	printh("Map sprite type: " .. type(map_spr))

	if not map_spr then
		printh("ERROR: Could not load sprite " .. cfg.sprite_id .. "! Using fallback roads.")
		-- Keep default ROADS from config.lua
		return
	end

	-- Check sprite dimensions
	local spr_w = map_spr:width()
	local spr_h = map_spr:height()
	printh("Sprite dimensions: " .. spr_w .. "x" .. spr_h)

	printh("Looking for colors: grass=" .. colors.grass .. ", water=" .. colors.water ..
	       ", main_road=" .. colors.main_road .. ", dirt_road=" .. colors.dirt_road)

	-- Create tile grid (stores tile type for each map pixel)
	-- Initialize all tiles to grass (0)
	WORLD_DATA.tiles = userdata("u8", w, h)
	for init_y = 0, h - 1 do
		for init_x = 0, w - 1 do
			WORLD_DATA.tiles:set(init_x, init_y, MAP_TILE_GRASS)
		end
	end

	-- Debug: sample a few pixels to see what colors we're actually getting
	printh("DEBUG: Sampling sprite pixels using :get() method...")
	for test_y = 0, min(spr_h - 1, 255), 64 do
		for test_x = 0, min(spr_w - 1, 255), 64 do
			local test_color = map_spr:get(test_x, test_y)
			printh("  Pixel (" .. test_x .. "," .. test_y .. ") = color " .. tostr(test_color))
		end
	end

	-- Parse each pixel and categorize
	local water_count = 0
	local grass_count = 0
	local main_road_count = 0
	local dirt_road_count = 0
	local building_zone_count = 0
	local color_histogram = {}  -- track all colors found

	-- Use actual sprite dimensions, clamped to expected map size
	local parse_w = min(w, spr_w)
	local parse_h = min(h, spr_h)

	for my = 0, parse_h - 1 do
		-- Update loading bar every 16 rows
		if my % 16 == 0 then
			loading_progress = (my / parse_h) * 50  -- 0-50% for parsing
			loading_message = "Parsing map..."
			draw_loading_screen()
		end

		for mx = 0, parse_w - 1 do
			local color = map_spr:get(mx, my)

			-- Skip nil colors (tile already initialized to grass)
			if color ~= nil then
				-- Track histogram
				color_histogram[color] = (color_histogram[color] or 0) + 1

				if color == colors.water then
					WORLD_DATA.tiles:set(mx, my, MAP_TILE_WATER)
					water_count = water_count + 1
				elseif color == colors.main_road then
					WORLD_DATA.tiles:set(mx, my, MAP_TILE_MAIN_ROAD)
					main_road_count = main_road_count + 1
				elseif color == colors.dirt_road then
					WORLD_DATA.tiles:set(mx, my, MAP_TILE_DIRT_ROAD)
					dirt_road_count = dirt_road_count + 1
				elseif color == colors.building_zone then
					WORLD_DATA.tiles:set(mx, my, MAP_TILE_BUILDING_ZONE)
					building_zone_count = building_zone_count + 1
				else
					-- Already grass from initialization
					grass_count = grass_count + 1
				end
			else
				grass_count = grass_count + 1  -- nil = grass
			end
		end
	end

	-- Print color histogram
	printh("DEBUG: Color histogram:")
	for col, count in pairs(color_histogram) do
		printh("  Color " .. tostr(col) .. ": " .. count .. " pixels")
	end

	printh("Map parsed: " .. water_count .. " water, " .. grass_count .. " grass, " ..
	       main_road_count .. " main road, " .. dirt_road_count .. " dirt road, " ..
	       building_zone_count .. " building zone")

	-- Generate sidewalks around main roads
	loading_progress = 55
	loading_message = "Generating sidewalks..."
	draw_loading_screen()
	generate_sidewalks()

	-- Generate road segments from parsed data
	loading_progress = 60
	loading_message = "Generating roads..."
	draw_loading_screen()
	generate_roads_from_map()

	-- Update WATER_CONFIG bounds based on parsed map
	loading_progress = 70
	loading_message = "Calculating bounds..."
	draw_loading_screen()
	update_water_bounds()
end

-- Generate sidewalks around main roads
-- Sidewalks are placed on grass tiles adjacent to main roads
function generate_sidewalks()
	local w = MAP_CONFIG.map_width
	local h = MAP_CONFIG.map_height
	local tiles = WORLD_DATA.tiles
	local sidewalk_count = 0

	-- Scan all tiles and add sidewalks where grass is adjacent to main road
	for my = 0, h - 1 do
		for mx = 0, w - 1 do
			local tile = tiles:get(mx, my)

			-- Only process grass tiles
			if tile == MAP_TILE_GRASS then
				-- Check adjacent tiles for main roads
				local road_north = my > 0 and tiles:get(mx, my - 1) == MAP_TILE_MAIN_ROAD
				local road_south = my < h - 1 and tiles:get(mx, my + 1) == MAP_TILE_MAIN_ROAD
				local road_west = mx > 0 and tiles:get(mx - 1, my) == MAP_TILE_MAIN_ROAD
				local road_east = mx < w - 1 and tiles:get(mx + 1, my) == MAP_TILE_MAIN_ROAD

				-- Determine sidewalk orientation based on adjacent road
				if road_north or road_south then
					-- Road is above or below, sidewalk runs east-west
					tiles:set(mx, my, MAP_TILE_SIDEWALK_EW)
					sidewalk_count = sidewalk_count + 1
				elseif road_west or road_east then
					-- Road is left or right, sidewalk runs north-south
					tiles:set(mx, my, MAP_TILE_SIDEWALK_NS)
					sidewalk_count = sidewalk_count + 1
				end
			end
		end
	end

	printh("Generated " .. sidewalk_count .. " sidewalk tiles")
end

-- Convert map coordinates to world coordinates
-- Map center (128,128) = world (0,0)
function map_to_world(mx, my)
	local tile_size = MAP_CONFIG.tile_size
	local half_w = MAP_CONFIG.map_width / 2
	local half_h = MAP_CONFIG.map_height / 2
	return (mx - half_w) * tile_size, (my - half_h) * tile_size
end

-- Convert world coordinates to map coordinates
-- World (0,0) = map center (128,128)
function world_to_map(wx, wy)
	local tile_size = MAP_CONFIG.tile_size
	local half_w = MAP_CONFIG.map_width / 2
	local half_h = MAP_CONFIG.map_height / 2
	return flr(wx / tile_size) + half_w, flr(wy / tile_size) + half_h
end

-- Get tile type at world position (from parsed map)
function get_map_tile_at_world(wx, wy)
	local mx, my = world_to_map(wx, wy)
	return get_map_tile(mx, my)
end

-- Get tile type at map coordinates
function get_map_tile(mx, my)
	local w = MAP_CONFIG.map_width
	local h = MAP_CONFIG.map_height

	if mx < 0 or mx >= w or my < 0 or my >= h then
		return MAP_TILE_WATER  -- outside map = water
	end

	if WORLD_DATA.tiles then
		return WORLD_DATA.tiles:get(mx, my)
	end
	return MAP_TILE_GRASS
end

-- Check if world position is water (from map)
function is_water_from_map(wx, wy)
	return get_map_tile_at_world(wx, wy) == MAP_TILE_WATER
end

-- Check if world position is a main road (from map)
function is_main_road_from_map(wx, wy)
	return get_map_tile_at_world(wx, wy) == MAP_TILE_MAIN_ROAD
end

-- Check if world position is a dirt road (from map)
function is_dirt_road_from_map(wx, wy)
	return get_map_tile_at_world(wx, wy) == MAP_TILE_DIRT_ROAD
end

-- Check if world position is any road (from map)
function is_any_road_from_map(wx, wy)
	local tile = get_map_tile_at_world(wx, wy)
	return tile == MAP_TILE_MAIN_ROAD or tile == MAP_TILE_DIRT_ROAD
end

-- Generate road segments by scanning the map for contiguous road pixels
-- This creates horizontal and vertical road segments for the ROADS table
function generate_roads_from_map()
	local cfg = MAP_CONFIG
	local w = cfg.map_width
	local h = cfg.map_height
	local tile_size = cfg.tile_size
	local sidewalk_w = ROAD_CONFIG.sidewalk_width

	WORLD_DATA.roads = {}
	WORLD_DATA.countryside_roads = {}

	-- Track visited road pixels to avoid duplicates
	local visited_h = {}  -- for horizontal scans
	local visited_v = {}  -- for vertical scans

	local function key(x, y)
		return y * w + x
	end

	-- Scan for horizontal road segments (main roads)
	for my = 0, h - 1 do
		local mx = 0
		while mx < w do
			local tile = get_map_tile(mx, my)
			if tile == MAP_TILE_MAIN_ROAD and not visited_h[key(mx, my)] then
				-- Found start of horizontal road segment
				local start_x = mx
				while mx < w and get_map_tile(mx, my) == MAP_TILE_MAIN_ROAD do
					visited_h[key(mx, my)] = true
					mx = mx + 1
				end
				local end_x = mx

				-- Only create segment if it spans multiple pixels horizontally
				if end_x - start_x >= 2 then
					local wx1, wy = map_to_world(start_x, my)
					local wx2 = map_to_world(end_x, my)
					-- Check if this is part of a wider road (check pixels above/below)
					local road_width = tile_size
					-- Count vertical extent
					local y_up = my - 1
					while y_up >= 0 and get_map_tile(start_x, y_up) == MAP_TILE_MAIN_ROAD do
						y_up = y_up - 1
					end
					local y_down = my + 1
					while y_down < h and get_map_tile(start_x, y_down) == MAP_TILE_MAIN_ROAD do
						y_down = y_down + 1
					end
					road_width = (y_down - y_up - 1) * tile_size

					-- Only add if this is a meaningful horizontal segment
					if end_x - start_x > y_down - y_up - 1 then
						add(WORLD_DATA.roads, {
							direction = "horizontal",
							y = wy + road_width / 2,
							x1 = wx1 - sidewalk_w,
							x2 = wx2 + sidewalk_w,
							width = road_width,
							tile_type = 2,  -- TILE_DIRT_MEDIUM
						})
					end
				end
			else
				mx = mx + 1
			end
		end
	end

	-- Scan for vertical road segments (main roads)
	for mx = 0, w - 1 do
		local my = 0
		while my < h do
			local tile = get_map_tile(mx, my)
			if tile == MAP_TILE_MAIN_ROAD and not visited_v[key(mx, my)] then
				-- Found start of vertical road segment
				local start_y = my
				while my < h and get_map_tile(mx, my) == MAP_TILE_MAIN_ROAD do
					visited_v[key(mx, my)] = true
					my = my + 1
				end
				local end_y = my

				-- Only create segment if it spans multiple pixels vertically
				if end_y - start_y >= 2 then
					local wx, wy1 = map_to_world(mx, start_y)
					local _, wy2 = map_to_world(mx, end_y)
					-- Check if this is part of a wider road (check pixels left/right)
					local road_width = tile_size
					local x_left = mx - 1
					while x_left >= 0 and get_map_tile(x_left, start_y) == MAP_TILE_MAIN_ROAD do
						x_left = x_left - 1
					end
					local x_right = mx + 1
					while x_right < w and get_map_tile(x_right, start_y) == MAP_TILE_MAIN_ROAD do
						x_right = x_right + 1
					end
					road_width = (x_right - x_left - 1) * tile_size

					-- Only add if this is a meaningful vertical segment
					if end_y - start_y > x_right - x_left - 1 then
						add(WORLD_DATA.roads, {
							direction = "vertical",
							x = wx + road_width / 2,
							y1 = wy1 - sidewalk_w,
							y2 = wy2 + sidewalk_w,
							width = road_width,
							tile_type = 2,  -- TILE_DIRT_MEDIUM
						})
					end
				end
			else
				my = my + 1
			end
		end
	end

	-- Similar scan for dirt roads (countryside)
	visited_h = {}
	visited_v = {}

	-- Horizontal dirt roads
	for my = 0, h - 1 do
		local mx = 0
		while mx < w do
			local tile = get_map_tile(mx, my)
			if tile == MAP_TILE_DIRT_ROAD and not visited_h[key(mx, my)] then
				local start_x = mx
				while mx < w and get_map_tile(mx, my) == MAP_TILE_DIRT_ROAD do
					visited_h[key(mx, my)] = true
					mx = mx + 1
				end
				local end_x = mx

				if end_x - start_x >= 2 then
					local wx1, wy = map_to_world(start_x, my)
					local wx2 = map_to_world(end_x, my)
					add(WORLD_DATA.countryside_roads, {
						direction = "horizontal",
						y = wy + tile_size / 2,
						x1 = wx1,
						x2 = wx2,
						width = tile_size,
						tile_type = 3,  -- TILE_DIRT_HEAVY
						countryside = true,
					})
				end
			else
				mx = mx + 1
			end
		end
	end

	-- Vertical dirt roads
	for mx = 0, w - 1 do
		local my = 0
		while my < h do
			local tile = get_map_tile(mx, my)
			if tile == MAP_TILE_DIRT_ROAD and not visited_v[key(mx, my)] then
				local start_y = my
				while my < h and get_map_tile(mx, my) == MAP_TILE_DIRT_ROAD do
					visited_v[key(mx, my)] = true
					my = my + 1
				end
				local end_y = my

				if end_y - start_y >= 2 then
					local wx, wy1 = map_to_world(mx, start_y)
					local _, wy2 = map_to_world(mx, end_y)
					add(WORLD_DATA.countryside_roads, {
						direction = "vertical",
						x = wx + tile_size / 2,
						y1 = wy1,
						y2 = wy2,
						width = tile_size,
						tile_type = 3,  -- TILE_DIRT_HEAVY
						countryside = true,
					})
				end
			else
				my = my + 1
			end
		end
	end

	printh("Generated " .. #WORLD_DATA.roads .. " main roads, " ..
	       #WORLD_DATA.countryside_roads .. " countryside roads")
end

-- Update WATER_CONFIG bounds based on parsed map
function update_water_bounds()
	local cfg = MAP_CONFIG
	local w = cfg.map_width
	local h = cfg.map_height
	local tile_size = cfg.tile_size

	-- Find land bounds by scanning for non-water tiles
	local min_x, max_x = w, 0
	local min_y, max_y = h, 0

	for my = 0, h - 1 do
		for mx = 0, w - 1 do
			local tile = get_map_tile(mx, my)
			if tile ~= MAP_TILE_WATER then
				if mx < min_x then min_x = mx end
				if mx > max_x then max_x = mx end
				if my < min_y then min_y = my end
				if my > max_y then max_y = my end
			end
		end
	end

	-- Convert to world coordinates with some padding
	local padding = tile_size * 2
	WATER_CONFIG.land_min_x = min_x * tile_size - padding
	WATER_CONFIG.land_max_x = (max_x + 1) * tile_size + padding
	WATER_CONFIG.land_min_y = min_y * tile_size - padding
	WATER_CONFIG.land_max_y = (max_y + 1) * tile_size + padding

	printh("Land bounds: " .. WATER_CONFIG.land_min_x .. "," .. WATER_CONFIG.land_min_y ..
	       " to " .. WATER_CONFIG.land_max_x .. "," .. WATER_CONFIG.land_max_y)
end

-- Check if a map position is inside a downtown block (bounded by main roads on all 4 sides)
function is_in_downtown_block(mx, my)
	-- Search outward in all 4 directions to find main roads
	local found_north, found_south, found_east, found_west = false, false, false, false
	local search_limit = 20  -- max tiles to search in each direction

	-- Search north
	for dy = 1, search_limit do
		local check_y = my - dy
		if check_y < 0 then break end
		local tile = get_map_tile(mx, check_y)
		if tile == MAP_TILE_MAIN_ROAD then
			found_north = true
			break
		elseif tile == MAP_TILE_WATER then
			break  -- hit water, no road this direction
		end
	end

	-- Search south
	for dy = 1, search_limit do
		local check_y = my + dy
		if check_y >= MAP_CONFIG.map_height then break end
		local tile = get_map_tile(mx, check_y)
		if tile == MAP_TILE_MAIN_ROAD then
			found_south = true
			break
		elseif tile == MAP_TILE_WATER then
			break
		end
	end

	-- Search west
	for dx = 1, search_limit do
		local check_x = mx - dx
		if check_x < 0 then break end
		local tile = get_map_tile(check_x, my)
		if tile == MAP_TILE_MAIN_ROAD then
			found_west = true
			break
		elseif tile == MAP_TILE_WATER then
			break
		end
	end

	-- Search east
	for dx = 1, search_limit do
		local check_x = mx + dx
		if check_x >= MAP_CONFIG.map_width then break end
		local tile = get_map_tile(check_x, my)
		if tile == MAP_TILE_MAIN_ROAD then
			found_east = true
			break
		elseif tile == MAP_TILE_WATER then
			break
		end
	end

	-- Must have main roads in all 4 directions to be a valid downtown block
	return found_north and found_south and found_east and found_west
end

-- Find all building zone rectangles from the tilemap
-- Returns list of {mx1, my1, mx2, my2, wx, wy, w, h} for each zone
function find_building_zones()
	local w = MAP_CONFIG.map_width
	local h = MAP_CONFIG.map_height
	local tile_size = MAP_CONFIG.tile_size
	local tiles = WORLD_DATA.tiles
	local zones = {}

	-- Track which tiles we've already assigned to a zone
	local visited = {}
	local function key(mx, my)
		return my * w + mx
	end

	-- Scan for building zone tiles and flood-fill to find rectangles
	for my = 0, h - 1 do
		for mx = 0, w - 1 do
			local tile = tiles:get(mx, my)
			if tile == MAP_TILE_BUILDING_ZONE and not visited[key(mx, my)] then
				-- Found start of a zone, expand to find the rectangle
				local x1, x2 = mx, mx
				local y1, y2 = my, my

				-- Expand right while still building zone
				while x2 < w - 1 and tiles:get(x2 + 1, my) == MAP_TILE_BUILDING_ZONE do
					x2 = x2 + 1
				end

				-- Expand down while the entire row is building zone
				local can_expand = true
				while can_expand and y2 < h - 1 do
					-- Check if next row from x1 to x2 is all building zone
					for check_x = x1, x2 do
						if tiles:get(check_x, y2 + 1) ~= MAP_TILE_BUILDING_ZONE then
							can_expand = false
							break
						end
					end
					if can_expand then
						y2 = y2 + 1
					end
				end

				-- Mark all tiles in this zone as visited
				for vy = y1, y2 do
					for vx = x1, x2 do
						visited[key(vx, vy)] = true
					end
				end

				-- Convert to world coordinates
				local wx1, wy1 = map_to_world(x1, y1)
				local wx2, wy2 = map_to_world(x2 + 1, y2 + 1)  -- +1 to get far edge

				add(zones, {
					mx1 = x1, my1 = y1,
					mx2 = x2, my2 = y2,
					x = wx1,
					y = wy1,
					w = wx2 - wx1,
					h = wy2 - wy1,
				})
			end
		end
	end

	printh("Found " .. #zones .. " building zones from tilemap")
	return zones
end

-- Generate buildings inside building zone rectangles (color=4)
-- Buildings must fit entirely within zones, including all corners
function generate_buildings_from_map()
	local cfg = MAP_CONFIG
	local bcfg = cfg.building
	local tile_size = cfg.tile_size

	-- Find all building zones from tilemap
	local zones = find_building_zones()
	if #zones == 0 then
		printh("WARNING: No building zones found in tilemap!")
		return {}
	end

	local generated = {}
	local buildings_per_zone = max(1, flr(bcfg.target_count / #zones))

	printh("Generating buildings in " .. #zones .. " zones, ~" .. buildings_per_zone .. " per zone...")

	for _, zone in ipairs(zones) do
		local zone_buildings = 0
		local attempts = 0
		local max_attempts = buildings_per_zone * 30

		while zone_buildings < buildings_per_zone and attempts < max_attempts do
			attempts = attempts + 1

			-- Random building size (clamped to fit in zone)
			local max_bw = min(bcfg.max_size, zone.w - 8)  -- leave 4px margin each side
			local max_bh = min(bcfg.max_size, zone.h - 8)
			if max_bw < bcfg.min_size or max_bh < bcfg.min_size then
				-- Zone too small for buildings
				break
			end

			local bw = bcfg.min_size + flr(rnd(max_bw - bcfg.min_size + 1))
			local bh = bcfg.min_size + flr(rnd(max_bh - bcfg.min_size + 1))

			-- Random position within zone (ensuring building fits entirely inside)
			local margin = 4  -- small margin from zone edges
			local max_x = zone.x + zone.w - bw - margin
			local max_y = zone.y + zone.h - bh - margin
			local min_x = zone.x + margin
			local min_y = zone.y + margin

			if max_x < min_x or max_y < min_y then
				-- Zone too small for this building
				break
			end

			local wx = min_x + flr(rnd(max_x - min_x + 1))
			local wy = min_y + flr(rnd(max_y - min_y + 1))

			-- Verify all corners are inside a building zone tile
			local valid = true
			local check_points = {
				{ wx, wy },                  -- top-left
				{ wx + bw - 1, wy },         -- top-right
				{ wx, wy + bh - 1 },         -- bottom-left
				{ wx + bw - 1, wy + bh - 1 }, -- bottom-right
			}

			for _, pt in ipairs(check_points) do
				local t = get_map_tile_at_world(pt[1], pt[2])
				if t ~= MAP_TILE_BUILDING_ZONE then
					valid = false
					break
				end
			end

			-- Check against existing buildings (no overlap)
			if valid then
				for _, b in ipairs(generated) do
					if wx < b.x + b.w + 8 and wx + bw > b.x - 8 and
					   wy < b.y + b.h + 8 and wy + bh > b.y - 8 then
						valid = false
						break
					end
				end
			end

			if valid then
				-- Determine building type based on distance from center
				local cx = bcfg.center_x
				local cy = bcfg.center_y
				local dist = sqrt((wx - cx) * (wx - cx) + (wy - cy) * (wy - cy))

				local btype
				if dist < bcfg.inner_radius then
					-- Downtown core - tall buildings
					local types = { "TECHNO_TOWER", "GLASS_TOWER", "BULKHEAD_TOWER", "CORPORATE_HQ" }
					btype = types[flr(rnd(#types)) + 1]
				elseif dist < bcfg.outer_radius then
					-- Mid-ring - mixed
					local types = { "MARBLE", "OFFICE", "INDUSTRIAL", "GREEN", "WAREHOUSE" }
					btype = types[flr(rnd(#types)) + 1]
				else
					-- Outer - smaller buildings
					local types = { "BRICK", "MARBLE", "OFFICE", "CONCRETE", "WAREHOUSE" }
					btype = types[flr(rnd(#types)) + 1]
				end

				add(generated, {
					x = wx,
					y = wy,
					w = bw,
					h = bh,
					type = btype,
				})
				zone_buildings = zone_buildings + 1
			end
		end
	end

	printh("Generated " .. #generated .. " buildings from map (zone-based)")
	return generated
end

-- Find all intersection positions from tilemap
-- An intersection is where main roads cross (horizontal meets vertical road)
-- Returns list of {mx, my, wx, wy} for each intersection center
function find_intersections_from_map()
	local w = MAP_CONFIG.map_width
	local h = MAP_CONFIG.map_height
	local tile_size = MAP_CONFIG.tile_size
	local tiles = WORLD_DATA.tiles
	local intersections = {}

	-- Track which intersection centers we've already found
	local found = {}
	local function key(mx, my)
		return my * w + mx
	end

	-- Scan for intersection centers: look for road tiles that have
	-- road tiles in all 4 cardinal directions
	for my = 1, h - 2 do
		for mx = 1, w - 2 do
			local tile = tiles:get(mx, my)
			if tile == MAP_TILE_MAIN_ROAD and not found[key(mx, my)] then
				-- Check if this is an intersection center
				-- (has roads in all 4 directions for at least some distance)
				local has_north = tiles:get(mx, my - 1) == MAP_TILE_MAIN_ROAD
				local has_south = tiles:get(mx, my + 1) == MAP_TILE_MAIN_ROAD
				local has_west = tiles:get(mx - 1, my) == MAP_TILE_MAIN_ROAD
				local has_east = tiles:get(mx + 1, my) == MAP_TILE_MAIN_ROAD

				-- Intersection = road extends in all 4 directions
				if has_north and has_south and has_west and has_east then
					-- Found potential intersection, now find its center
					-- Expand outward to find the full extent of the intersection
					local x1, x2 = mx, mx
					local y1, y2 = my, my

					-- Expand west while still road
					while x1 > 0 and tiles:get(x1 - 1, my) == MAP_TILE_MAIN_ROAD and
					      tiles:get(x1 - 1, my - 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(x1 - 1, my + 1) == MAP_TILE_MAIN_ROAD do
						x1 = x1 - 1
					end
					-- Expand east while still road
					while x2 < w - 1 and tiles:get(x2 + 1, my) == MAP_TILE_MAIN_ROAD and
					      tiles:get(x2 + 1, my - 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(x2 + 1, my + 1) == MAP_TILE_MAIN_ROAD do
						x2 = x2 + 1
					end
					-- Expand north while still road
					while y1 > 0 and tiles:get(mx, y1 - 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(mx - 1, y1 - 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(mx + 1, y1 - 1) == MAP_TILE_MAIN_ROAD do
						y1 = y1 - 1
					end
					-- Expand south while still road
					while y2 < h - 1 and tiles:get(mx, y2 + 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(mx - 1, y2 + 1) == MAP_TILE_MAIN_ROAD and
					      tiles:get(mx + 1, y2 + 1) == MAP_TILE_MAIN_ROAD do
						y2 = y2 + 1
					end

					-- Mark all tiles in this intersection as found
					for iy = y1, y2 do
						for ix = x1, x2 do
							found[key(ix, iy)] = true
						end
					end

					-- Calculate center
					local center_mx = flr((x1 + x2) / 2)
					local center_my = flr((y1 + y2) / 2)

					-- Convert to world coordinates
					local wx, wy = map_to_world(center_mx, center_my)
					-- Adjust to center of tile
					wx = wx + tile_size / 2
					wy = wy + tile_size / 2

					-- Calculate intersection size (in tiles)
					local size_x = x2 - x1 + 1
					local size_y = y2 - y1 + 1

					add(intersections, {
						mx = center_mx,
						my = center_my,
						x = wx,
						y = wy,
						size_x = size_x,
						size_y = size_y,
					})
				end
			end
		end
	end

	printh("Found " .. #intersections .. " intersections from tilemap")
	return intersections
end

-- Initialize world from map (call this instead of manual ROADS/LEVEL_BUILDINGS)
function init_world_from_map()
	-- Parse the map sprite
	parse_world_map()

	-- Replace ROADS with generated roads
	ROADS = WORLD_DATA.roads
	COUNTRYSIDE_ROADS = WORLD_DATA.countryside_roads

	-- Generate buildings
	loading_progress = 80
	loading_message = "Generating buildings..."
	draw_loading_screen()
	LEVEL_BUILDINGS = generate_buildings_from_map()

	loading_progress = 100
	loading_message = "Done!"
	draw_loading_screen()

	printh("World initialized from map!")
end
