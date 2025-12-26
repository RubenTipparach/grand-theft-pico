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

-- Draw all visible flora procedurally (optimized - no intermediate table)
-- Uses region-based generation: each region_size x region_size area gets items_per_region flora items
function draw_flora()
	local cfg = FLORA_CONFIG
	local region_size = cfg.region_size
	local items_per_region = cfg.items_per_region
	local tree_sprites = cfg.tree_sprites
	local flower_sprites = cfg.flower_sprites
	local grass_sprite = cfg.grass_sprite
	local tree_weight = cfg.tree_weight
	local flower_weight = cfg.flower_weight
	local shadows_enabled = cfg.shadows_enabled

	-- Cache screen constants
	local cx, cy = SCREEN_CX, SCREEN_CY
	local sw, sh = SCREEN_W, SCREEN_H

	-- Calculate visible world bounds with margin
	local margin = 16
	local left = cam_x - cx - margin
	local right = cam_x + cx + margin
	local top = cam_y - cy - margin
	local bottom = cam_y + cy + margin

	-- Get visible regions
	local rx1 = flr(left / region_size)
	local rx2 = ceil(right / region_size)
	local ry1 = flr(top / region_size)
	local ry2 = ceil(bottom / region_size)

	-- Shadow pass (if enabled) - draw all shadows first
	if shadows_enabled then
		local shadow_color = cfg.shadow_color
		local shadow_y_offset = cfg.shadow_y_offset
		local tree_sr, tree_sh = cfg.tree_shadow_radius, cfg.tree_shadow_height
		local flower_sr, flower_sh = cfg.flower_shadow_radius, cfg.flower_shadow_height
		local grass_sr, grass_sh = cfg.grass_shadow_radius, cfg.grass_shadow_height

		-- Apply shadow color table
		local coltab_sprite = get_spr(56)
		memmap(0x8000, coltab_sprite)
		poke(0x550b, 0x3f)

		for ry = ry1, ry2 do
			for rx = rx1, rx2 do
				local region_x = rx * region_size
				local region_y = ry * region_size

				for i = 1, items_per_region do
					local px = hash2d(rx * 73 + i * 17, ry * 89)
					local py = hash2d(rx * 97 + i * 31, ry * 53 + i * 7)
					local wx = region_x + px * region_size
					local wy = region_y + py * region_size

					-- Check grass tile
					local tile_type = get_tile_type(wx, wy)
					if tile_type ~= TILE_GRASS then goto shadow_continue end

					-- Screen position
					local sx = wx - cam_x + cx
					local sy = wy - cam_y + cy

					if sx < -8 or sx > sw + 8 or sy < -8 or sy > sh + 8 then
						goto shadow_continue
					end

					-- Determine flora type for shadow size
					local type_hash = hash2d(rx * 41 + i * 59, ry * 43 + i * 61)
					local can_tree = (i % 5 == 0)
					local sr, sh_height

					if can_tree and type_hash < tree_weight then
						sr, sh_height = tree_sr, tree_sh
					elseif type_hash < tree_weight + flower_weight then
						sr, sh_height = flower_sr, flower_sh
					else
						sr, sh_height = grass_sr, grass_sh
					end

					-- Draw shadow ellipse
					ovalfill(sx - sr, sy + shadow_y_offset - sh_height,
					         sx + sr, sy + shadow_y_offset + sh_height, shadow_color)

					::shadow_continue::
				end
			end
		end

		-- Disable color table
		poke(0x550b, 0x00)
		unmap(coltab_sprite)
	end

	-- Sprite pass - draw all flora sprites
	for ry = ry1, ry2 do
		for rx = rx1, rx2 do
			local region_x = rx * region_size
			local region_y = ry * region_size

			for i = 1, items_per_region do
				local px = hash2d(rx * 73 + i * 17, ry * 89)
				local py = hash2d(rx * 97 + i * 31, ry * 53 + i * 7)
				local wx = region_x + px * region_size
				local wy = region_y + py * region_size

				-- Check grass tile
				local tile_type = get_tile_type(wx, wy)
				if tile_type ~= TILE_GRASS then goto sprite_continue end

				-- Screen position (inline world_to_screen)
				local sx = wx - cam_x + cx
				local sy = wy - cam_y + cy

				if sx < -8 or sx > sw + 8 or sy < -8 or sy > sh + 8 then
					goto sprite_continue
				end

				-- Determine flora type and sprite
				local type_hash = hash2d(rx * 41 + i * 59, ry * 43 + i * 61)
				local sprite_id
				local can_tree = (i % 5 == 0)

				if can_tree and type_hash < tree_weight then
					local tree_idx = flr(hash2d(rx * 47 + i, ry * 53) * #tree_sprites) + 1
					sprite_id = tree_sprites[tree_idx]
				elseif type_hash < tree_weight + flower_weight then
					local flower_idx = flr(hash2d(rx * 59 + i, ry * 61) * #flower_sprites) + 1
					sprite_id = flower_sprites[flower_idx]
				else
					sprite_id = grass_sprite
				end

				spr(sprite_id, sx - 8, sy - 8)

				::sprite_continue::
			end
		end
	end
end
