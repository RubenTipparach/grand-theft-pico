--[[pod_format="raw"]]
-- flora.lua - Procedural flora rendering
-- Generates flora on-the-fly based on grass tiles, no pre-generation needed

-- Deterministic hash for consistent random values at each position
-- Uses simple multiplicative hash (no bitwise XOR needed)
local function hash2d(x, y)
	local n = x * 374761393 + y * 668265263
	n = (n * 1274126177) % 4294967296
	return (n % 65536) / 65536
end

-- No initialization needed - flora is generated procedurally
function generate_flora()
	printh("Flora system: procedural generation enabled")
	printh("Flora config: " .. FLORA_CONFIG.items_per_region .. " items per " .. FLORA_CONFIG.region_size .. "x" .. FLORA_CONFIG.region_size .. " region")
end

-- Check if a world position is on a grass tile
local function is_grass_tile(wx, wy)
	-- Get tile type at this world position (TILE_GRASS = 0)
	local tile_type = get_tile_type(wx, wy)
	return tile_type == TILE_GRASS
end

-- Collect visible flora for a given screen area
-- Returns a list of {sx, sy, sprite_id, flora_type} for drawing
local function collect_visible_flora()
	local cfg = FLORA_CONFIG
	local region_size = cfg.region_size
	local items_per_region = cfg.items_per_region
	local tree_sprites = cfg.tree_sprites
	local flower_sprites = cfg.flower_sprites
	local grass_sprite = cfg.grass_sprite

	local visible = {}

	-- Calculate visible world bounds with margin
	local margin = 16
	local left = cam_x - SCREEN_CX - margin
	local right = cam_x + SCREEN_CX + margin
	local top = cam_y - SCREEN_CY - margin
	local bottom = cam_y + SCREEN_CY + margin

	-- Get visible regions
	local rx1 = flr(left / region_size)
	local rx2 = ceil(right / region_size)
	local ry1 = flr(top / region_size)
	local ry2 = ceil(bottom / region_size)

	-- Iterate over each visible region
	for ry = ry1, ry2 do
		for rx = rx1, rx2 do
			-- Region origin in world coords
			local region_x = rx * region_size
			local region_y = ry * region_size

			-- Generate fixed number of flora items per region
			for i = 1, items_per_region do
				-- Deterministic position within region based on region coords and item index
				local px = hash2d(rx * 73 + i * 17, ry * 89)
				local py = hash2d(rx * 97 + i * 31, ry * 53 + i * 7)

				local wx = region_x + px * region_size
				local wy = region_y + py * region_size

				-- Only place flora on grass tiles
				if not is_grass_tile(wx, wy) then
					goto continue
				end

				-- Convert to screen position
				local sx, sy = world_to_screen(wx, wy)

				-- Screen bounds check
				if sx < -8 or sx > SCREEN_W + 8 or sy < -8 or sy > SCREEN_H + 8 then
					goto continue
				end

				-- Determine flora type based on hash
				local type_hash = hash2d(rx * 41 + i * 59, ry * 43 + i * 61)
				local sprite_id
				local flora_type

				-- Trees are sparser (only some items can be trees)
				local can_tree = (i % 5 == 0)  -- Every 5th item can be a tree

				if can_tree and type_hash < cfg.tree_weight then
					-- Tree
					local tree_idx = flr(hash2d(rx * 47 + i, ry * 53) * #tree_sprites) + 1
					sprite_id = tree_sprites[tree_idx]
					flora_type = "tree"
				elseif type_hash < cfg.tree_weight + cfg.flower_weight then
					-- Flower
					local flower_idx = flr(hash2d(rx * 59 + i, ry * 61) * #flower_sprites) + 1
					sprite_id = flower_sprites[flower_idx]
					flora_type = "flower"
				else
					-- Grass blade
					sprite_id = grass_sprite
					flora_type = "grass"
				end

				add(visible, {
					sx = sx,
					sy = sy,
					sprite = sprite_id,
					flora_type = flora_type,
				})

				::continue::
			end
		end
	end

	return visible
end

-- Draw all visible flora procedurally with shadows
-- Uses region-based generation: each region_size x region_size area gets items_per_region flora items
function draw_flora()
	local cfg = FLORA_CONFIG
	local visible = collect_visible_flora()

	-- Draw shadows first (with color table for transparency)
	local coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table

	for _, item in ipairs(visible) do
		-- Shadow size varies by flora type
		local sr, sh  -- shadow radius, shadow height
		if item.flora_type == "tree" then
			sr, sh = cfg.tree_shadow_radius, cfg.tree_shadow_height
		elseif item.flora_type == "flower" then
			sr, sh = cfg.flower_shadow_radius, cfg.flower_shadow_height
		else
			sr, sh = cfg.grass_shadow_radius, cfg.grass_shadow_height
		end

		-- Draw shadow oval
		local shadow_y = item.sy + cfg.shadow_y_offset
		ovalfill(item.sx - sr, shadow_y, item.sx + sr, shadow_y + sh, cfg.shadow_color)
	end

	unmap(coltab_sprite)
	poke(0x550b, 0x00)  -- disable color table

	-- Draw flora sprites
	for _, item in ipairs(visible) do
		spr(item.sprite, item.sx - 8, item.sy - 8)
	end
end
