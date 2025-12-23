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

-- Buildings created from level data in config
buildings = {}

-- ============================================
-- MAIN CALLBACKS
-- ============================================

-- Rendering mode: "tline3d" or "tri"
render_mode = "tline3d"

function _init()
	setup_palette()

	-- Create buildings from level config
	buildings = create_buildings_from_level()

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

	-- UI with drop shadows
	profile("ui")
	print_shadow("GTA PICOTRON", 4, 4, 7)
	print_shadow("arrows: move  X: toggle renderer", 4, 14, 6)
	print_shadow("pos: "..flr(game.player.x)..","..flr(game.player.y), 4, SCREEN_H - 20, 6)
	print_shadow("mode: "..render_mode, 4, SCREEN_H - 10, 11)

	-- CPU stats
	local cpu = stat(1)  -- CPU usage (0-1 range, where 1 = 100%)
	local fps = stat(7)  -- current FPS
	print_shadow("cpu: "..flr(cpu * 100).."%", SCREEN_W - 70, 4, 7)
	print_shadow("fps: "..flr(fps), SCREEN_W - 70, 14, 7)

	-- Draw profiler output
	profile.draw()
	profile("ui")
end
