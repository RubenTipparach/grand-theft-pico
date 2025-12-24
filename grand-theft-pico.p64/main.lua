--[[pod_format="raw"]]

-- Grand Theft Picotron
-- A top-down GTA1/2-style game for Picotron

-- ============================================
-- INCLUDES (load modules)
-- ============================================
include("src/constants.lua")
include("src/config.lua")
include("src/utils.lua")
include("src/profiler.lua")
include("src/perspective.lua")
include("src/culling.lua")
include("src/wall_renderer.lua")
include("src/building.lua")
include("src/collision.lua")
include("src/ground.lua")
include("src/input.lua")

-- ============================================
-- PALETTE SETUP
-- ============================================
palette_loaded = false

function setup_palette()
	if not palette_loaded then
		-- Try loading palette from project folder
		local palette_data = fetch("toybox_palette.pal")

		if not palette_data then
			-- Try alternate path
			palette_data = fetch("/ram/cart/toybox_palette.pal")
			printh("Trying /ram/cart/toybox_palette.pal...")
		end

		if palette_data then
			printh("Palette loaded! Type: " .. type(palette_data))

			local color_count = 0
			-- Load all 64 colors from palette
			for i = 0, 63 do
				local color = palette_data[i]
				if color then
					color_count = color_count + 1
					-- Apply using pal() with p=2 to set RGB display palette
					pal(i, color, 2)
				end
			end

			-- Set color 0 as transparent for sprites
			palt(0, true)
			palette_loaded = true
			printh("SUCCESS: " .. color_count .. " colors loaded and applied!")
		else
			printh("WARNING: Could not load toybox_palette.pal from any path")
		end
	end
end

-- ============================================
-- GAME STATE (globals used by modules)
-- ============================================
cam_x, cam_y = 0, 0  -- camera world position

game = {
	player = {
		x = 200,
		y = 200,
		facing_right = true,
		walk_frame = 0,
	}
}

-- Player shadow
SHADOW_RADIUS = 37
shadow_coltab_mode = 56  -- current color table sprite (cycles 56, 57, 58)

-- Night mode
night_mode = false
night_mask = nil  -- userdata for night overlay mask

-- Buildings created from level data in config
buildings = {}

-- ============================================
-- MAIN CALLBACKS
-- ============================================

-- Rendering mode: "tline3d" or "tri"
render_mode = "tline3d"

-- Apply color table for shapes (circ, rect, etc.)
function apply_color_table(color_table_sprite)
	local sprite = get_spr(color_table_sprite)
	memmap(0x8000, sprite)
	poke(0x550b, 0x3f)  -- enable color table for shapes
	local shadow_x = SCREEN_CX
	local shadow_y = SCREEN_CY + 6  -- at player's feet
	circfill(shadow_x, shadow_y, SHADOW_RADIUS)
	unmap(sprite)  -- unmap the color table
	poke(0x550b, 0x00)  -- disable color table for shapes
end

-- Apply just one row of a color table
function apply_colortable_row(color_table_sprite, color_row)
	local sprite = get_spr(color_table_sprite)
	local address = 0x8000 + color_row * 64
	for x = 0, 63 do
		local c = sprite:get(x, color_row)
		poke(address + x, c)
	end
	poke(0x550b, 0x3f)  -- enable color table for shapes
end

-- Reset color table (disable it)
function reset_colortable()
	poke(0x550b, 0x00)
end

-- Night mode settings (initialized from config in _init)

-- Generate street lights along roads
function generate_street_lights()
	local lights = {}
	local spacing = NIGHT_CONFIG.street_light_spacing

	for _, road in ipairs(ROADS) do
		if road.direction == "horizontal" then
			-- Place lights along horizontal road
			local y = road.y
			local x_start = flr(road.x1 / spacing) * spacing
			for x = x_start, road.x2, spacing do
				add(lights, { x = x, y = y })
			end
		elseif road.direction == "vertical" then
			-- Place lights along vertical road
			local x = road.x
			local y_start = flr(road.y1 / spacing) * spacing
			for y = y_start, road.y2, spacing do
				add(lights, { x = x, y = y })
			end
		end
	end

	return lights
end

-- Street light positions (generated from roads)
STREET_LIGHTS = {}

-- Draw night mode overlay - efficient method
-- Draw to night_mask userdata, then render as sprite with color table
function draw_night_mode()
	if not night_mode then return end

	-- Get config values
	local player_radius = NIGHT_CONFIG.player_light_radius
	local street_radius = NIGHT_CONFIG.street_light_radius
	local darken_color = NIGHT_CONFIG.darken_color
	local ambient_color = NIGHT_CONFIG.ambient_color

	-- First pass: draw ambient tint over everything (no holes)
	local coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table
	rectfill(0, 0, SCREEN_W, SCREEN_H, ambient_color)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)

	-- Second pass: draw darker areas with light holes
	-- Set draw target to night mask
	set_draw_target(night_mask)

	-- Fill with darken color
	cls(darken_color)

	-- Punch out light circles with transparent color (0)
	-- Player light at center
	circfill(SCREEN_CX, SCREEN_CY, player_radius, 0)

	-- Street lights (convert world to screen coords)
	for _, light in ipairs(STREET_LIGHTS) do
		local sx, sy = world_to_screen(light.x, light.y)
		-- Only draw if on screen (with some margin for the radius)
		if sx > -street_radius and sx < SCREEN_W + street_radius and sy > -street_radius and sy < SCREEN_H + street_radius then
			circfill(sx, sy, street_radius, 0)
		end
	end

	-- Reset draw target to screen
	set_draw_target()

	-- Apply color table and draw the mask
	coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table

	-- Ensure color 0 is transparent when drawing sprite
	palt(0, true)

	-- Draw mask as sprite (color 0 is transparent, darken color gets darkened)
	spr(night_mask, 0, 0)

	-- Reset color table and transparency
	palt(0, true)  -- keep 0 transparent (default)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)
end

function _init()
	setup_palette()

	-- Create night mask sprite (screen-sized)
	night_mask = userdata("u8", SCREEN_W, SCREEN_H)

	-- Create buildings from level config
	buildings = create_buildings_from_level()

	-- Generate street lights along roads
	STREET_LIGHTS = generate_street_lights()
	printh("Generated " .. #STREET_LIGHTS .. " street lights")

	-- Enable profiler (detailed=true, cpu=true)
	profile.enabled(true, true)

	printh("Grand Theft Picotron initialized!")
	printh("Use arrow keys to move")
	printh("Loaded " .. #buildings .. " buildings")
	printh("Press X to toggle render mode (tline3d/tri)")
end

function _update()
	handle_input()

	-- Toggle render mode with X button
	if btnp(5) then
		if render_mode == "tline3d" then
			render_mode = "tri"
		else
			render_mode = "tline3d"
		end
		printh("Render mode: " .. render_mode)
	end

	-- Debug: cycle shadow color table with M key
	if DEBUG_CONFIG.enabled and keyp("m") then
		shadow_coltab_mode = shadow_coltab_mode + 1
		if shadow_coltab_mode > 59 then
			shadow_coltab_mode = 56
		end
		printh("Shadow color table: " .. shadow_coltab_mode)
	end

	-- Toggle night mode with N key
	if keyp("n") then
		night_mode = not night_mode
		printh("Night mode: " .. tostring(night_mode))
	end

	-- Adjust night darken color with +/- keys
	if night_mode then
		if keyp("+") or keyp("=") then
			NIGHT_DARKEN_COLOR = min(63, NIGHT_DARKEN_COLOR + 1)
			printh("Night darken color: " .. NIGHT_DARKEN_COLOR)
		end
		if keyp("-") then
			NIGHT_DARKEN_COLOR = max(0, NIGHT_DARKEN_COLOR - 1)
			printh("Night darken color: " .. NIGHT_DARKEN_COLOR)
		end
	end
end

-- Print text with drop shadow for legibility
function print_shadow(text, x, y, col, shadow_col)
	shadow_col = shadow_col or 0  -- default black shadow
	print(text, x + 1, y + 1, shadow_col)
	print(text, x, y, col)
end

function _draw()
	cls(1)  -- dark background

	-- Draw ground tiles (grass and dirt roads)
	profile("ground")
	draw_ground()
	profile("ground")

	-- Get player sprite info
	local player_spr = get_player_sprite()
	local flip_x = not game.player.facing_right

	-- Draw buildings and player with proper depth sorting
	profile("buildings")
	draw_buildings_and_player(buildings, game.player, player_spr, flip_x)
	profile("buildings")

	-- Draw player shadow overlay using color table (only when not in night mode)
	-- if not night_mode then
	-- 	apply_color_table(shadow_coltab_mode)
	-- end

	-- Draw night mode overlay (darkness with street light cutouts)
	profile("night")
	draw_night_mode()
	profile("night")

	-- UI with drop shadows
	profile("ui")
	print_shadow("GTA PICOTRON", 4, 4, 7)
	print_shadow("arrows: move  X: toggle renderer", 4, 14, 6)
	print_shadow("pos: "..flr(game.player.x)..","..flr(game.player.y), 4, SCREEN_H - 20, 6)
	print_shadow("mode: "..render_mode, 4, SCREEN_H - 10, 11)
	if DEBUG_CONFIG.enabled then
		print_shadow("coltab: "..shadow_coltab_mode.." (M to cycle)", SCREEN_W - 150, 24, 6)
	end

	-- CPU stats
	local cpu = stat(1)  -- CPU usage (0-1 range, where 1 = 100%)
	local fps = stat(7)  -- current FPS
	print_shadow("cpu: "..flr(cpu * 100).."%", SCREEN_W - 70, 4, 7)
	print_shadow("fps: "..flr(fps), SCREEN_W - 70, 14, 7)

	-- Draw profiler output
	profile.draw()
	profile("ui")
end
