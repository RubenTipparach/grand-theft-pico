--[[pod_format="raw"]]
-- config.lua - Game design configuration (sprites, buildings, tuning)

-- ============================================
-- SPRITE REGISTRY
-- ============================================
SPRITES = {
	-- Walls (16x16)
	BRICK_WALL       = { id = 1, w = 16, h = 16 },
	MARBLE_WALL      = { id = 2, w = 16, h = 16 },
	CRACKED_BRICK    = { id = 128, w = 16, h = 16 },
	CRACKED_CONCRETE = { id = 129, w = 16, h = 16 },
	METALLIC_PIPES   = { id = 48, w = 16, h = 16 },
	LARGE_BRICK      = { id = 49, w = 16, h = 16 },
	GREEN_BLOCK      = { id = 51, w = 16, h = 16 },
	TECHNO           = { id = 52, w = 16, h = 16 },
	ZINC             = { id = 53, w = 16, h = 16 },
	GLASS            = { id = 119, w = 16, h = 16 },
	BULKHEAD         = { id = 118, w = 16, h = 16 },

	-- Walls (16x32 tall)
	TALL_BRICK       = { id = 50, w = 16, h = 32 },

	-- Roofs/Ceilings
	ROOF             = { id = 3, w = 16, h = 16 },
	ROOF_CHIMNEY     = { id = 131, w = 16, h = 16 },
	ROOF_CIRCULAR    = { id = 40, w = 16, h = 16 },
	ROOF_POINTY      = { id = 41, w = 16, h = 16 },
	ROOF_FLAT        = { id = 42, w = 16, h = 16 },

	-- Ground textures
	DIRT_MEDIUM   = { id = 4, w = 16, h = 16 },
	DIRT_HEAVY    = { id = 5, w = 16, h = 16 },
	DIRT_LIGHT    = { id = 6, w = 16, h = 16 },
	GRASS         = { id = 7, w = 16,  h = 16  },

	-- Sidewalks (16x16)
	SIDEWALK_NS   = { id = 132, w = 16, h = 16 },  -- north-south oriented
	SIDEWALK_EW   = { id = 133, w = 16, h = 16 },  -- east-west oriented

	-- Flora (16x16)
	FLOWER_1      = { id = 139, w = 16, h = 16 },
	FLOWER_2      = { id = 140, w = 16, h = 16 },
	GRASS_BLADE   = { id = 141, w = 16, h = 16 },
	TREE_1        = { id = 142, w = 16, h = 16 },
	TREE_2        = { id = 143, w = 16, h = 16 },

	-- ============================================
	-- WATER TILES (16x16, 9-sliced, 2 animation frames)
	-- ============================================
	-- Set 1: Grass border surrounding water (water is inside)
	-- Frame 1
	WATER_SET1_F1_TL = { id = 208, w = 16, h = 16 },  -- top-left corner
	WATER_SET1_F1_T  = { id = 209, w = 16, h = 16 },  -- top edge
	WATER_SET1_F1_TR = { id = 210, w = 16, h = 16 },  -- top-right corner
	WATER_SET1_F1_L  = { id = 216, w = 16, h = 16 },  -- left edge
	WATER_SET1_F1_C  = { id = 217, w = 16, h = 16 },  -- center (pure water)
	WATER_SET1_F1_R  = { id = 218, w = 16, h = 16 },  -- right edge
	WATER_SET1_F1_BL = { id = 224, w = 16, h = 16 },  -- bottom-left corner
	WATER_SET1_F1_B  = { id = 225, w = 16, h = 16 },  -- bottom edge
	WATER_SET1_F1_BR = { id = 226, w = 16, h = 16 },  -- bottom-right corner
	-- Frame 2
	WATER_SET1_F2_TL = { id = 232, w = 16, h = 16 },
	WATER_SET1_F2_T  = { id = 233, w = 16, h = 16 },
	WATER_SET1_F2_TR = { id = 234, w = 16, h = 16 },
	WATER_SET1_F2_L  = { id = 240, w = 16, h = 16 },
	WATER_SET1_F2_C  = { id = 241, w = 16, h = 16 },
	WATER_SET1_F2_R  = { id = 242, w = 16, h = 16 },
	WATER_SET1_F2_BL = { id = 248, w = 16, h = 16 },
	WATER_SET1_F2_B  = { id = 249, w = 16, h = 16 },
	WATER_SET1_F2_BR = { id = 250, w = 16, h = 16 },

	-- Set 2: Water border surrounding grass (grass island inside water)
	-- Frame 1
	WATER_SET2_F1_TL = { id = 211, w = 16, h = 16 },  -- top-left corner (inner)
	WATER_SET2_F1_T  = { id = 212, w = 16, h = 16 },  -- top edge (inner)
	WATER_SET2_F1_TR = { id = 213, w = 16, h = 16 },  -- top-right corner (inner)
	WATER_SET2_F1_L  = { id = 219, w = 16, h = 16 },  -- left edge (inner)
	-- Center is grass (use GRASS tile)
	WATER_SET2_F1_R  = { id = 221, w = 16, h = 16 },  -- right edge (inner)
	WATER_SET2_F1_BL = { id = 227, w = 16, h = 16 },  -- bottom-left corner (inner)
	WATER_SET2_F1_B  = { id = 228, w = 16, h = 16 },  -- bottom edge (inner)
	WATER_SET2_F1_BR = { id = 229, w = 16, h = 16 },  -- bottom-right corner (inner)
	-- Frame 2
	WATER_SET2_F2_TL = { id = 235, w = 16, h = 16 },
	WATER_SET2_F2_T  = { id = 236, w = 16, h = 16 },
	WATER_SET2_F2_TR = { id = 237, w = 16, h = 16 },
	WATER_SET2_F2_L  = { id = 243, w = 16, h = 16 },
	-- Center is grass
	WATER_SET2_F2_R  = { id = 245, w = 16, h = 16 },
	WATER_SET2_F2_BL = { id = 251, w = 16, h = 16 },
	WATER_SET2_F2_B  = { id = 252, w = 16, h = 16 },
	WATER_SET2_F2_BR = { id = 253, w = 16, h = 16 },

	-- Player (facing east/west - flip_x for direction)
	PLAYER_IDLE   = { id = 8,  w = 16, h = 16 },  -- idle, facing left
	PLAYER_WALK1  = { id = 9,  w = 16, h = 16 },  -- walk frame 1
	PLAYER_WALK2  = { id = 10, w = 16, h = 16 },  -- walk frame 2
	PLAYER_DAMAGED = { id = 11, w = 16, h = 16 }, -- damaged/hurt

	-- Player (facing south - toward camera)
	PLAYER_SOUTH_IDLE  = { id = 12, w = 16, h = 16 },  -- south idle
	PLAYER_SOUTH_WALK1 = { id = 14, w = 16, h = 16 },  -- south walk frame 1
	PLAYER_SOUTH_WALK2 = { id = 17, w = 16, h = 16 },  -- south walk frame 2

	-- Player (facing north - away from camera)
	PLAYER_NORTH_IDLE  = { id = 13, w = 16, h = 16 },  -- north idle
	PLAYER_NORTH_WALK1 = { id = 15, w = 16, h = 16 },  -- north walk frame 1
	PLAYER_NORTH_WALK2 = { id = 16, w = 16, h = 16 },  -- north walk frame 2

	-- NPC1 (8x16 sprites, starts at 64)
	-- Facing south (toward camera)
	NPC1_SOUTH_IDLE  = { id = 64, w = 8, h = 16 },
	NPC1_SOUTH_WALK1 = { id = 65, w = 8, h = 16 },
	NPC1_SOUTH_WALK2 = { id = 66, w = 8, h = 16 },
	NPC1_SOUTH_WALK3 = { id = 67, w = 8, h = 16 },
	-- Facing east
	NPC1_EAST_IDLE   = { id = 68, w = 8, h = 16 },
	NPC1_EAST_WALK1  = { id = 69, w = 8, h = 16 },
	NPC1_EAST_WALK2  = { id = 70, w = 8, h = 16 },
	NPC1_EAST_WALK3  = { id = 71, w = 8, h = 16 },
	-- Facing north (away from camera)
	NPC1_NORTH_IDLE  = { id = 72, w = 8, h = 16 },
	NPC1_NORTH_WALK1 = { id = 73, w = 8, h = 16 },
	NPC1_NORTH_WALK2 = { id = 74, w = 8, h = 16 },
	NPC1_NORTH_WALK3 = { id = 75, w = 8, h = 16 },
	-- Facing west
	NPC1_WEST_IDLE   = { id = 76, w = 8, h = 16 },
	NPC1_WEST_WALK1  = { id = 77, w = 8, h = 16 },
	NPC1_WEST_WALK2  = { id = 78, w = 8, h = 16 },
	NPC1_WEST_WALK3  = { id = 79, w = 8, h = 16 },
	-- Damaged
	NPC1_DAMAGED     = { id = 81, w = 8, h = 16 },

	-- NPC2 (8x16 sprites, starts at 84)
	-- Facing south (toward camera)
	NPC2_SOUTH_IDLE  = { id = 84, w = 8, h = 16 },
	NPC2_SOUTH_WALK1 = { id = 85, w = 8, h = 16 },
	NPC2_SOUTH_WALK2 = { id = 86, w = 8, h = 16 },
	NPC2_SOUTH_WALK3 = { id = 87, w = 8, h = 16 },
	-- Facing east
	NPC2_EAST_IDLE   = { id = 88, w = 8, h = 16 },
	NPC2_EAST_WALK1  = { id = 89, w = 8, h = 16 },
	NPC2_EAST_WALK2  = { id = 90, w = 8, h = 16 },
	NPC2_EAST_WALK3  = { id = 91, w = 8, h = 16 },
	-- Facing north (away from camera)
	NPC2_NORTH_IDLE  = { id = 92, w = 8, h = 16 },
	NPC2_NORTH_WALK1 = { id = 93, w = 8, h = 16 },
	NPC2_NORTH_WALK2 = { id = 94, w = 8, h = 16 },
	NPC2_NORTH_WALK3 = { id = 95, w = 8, h = 16 },
	-- Facing west
	NPC2_WEST_IDLE   = { id = 96, w = 8, h = 16 },
	NPC2_WEST_WALK1  = { id = 97, w = 8, h = 16 },
	NPC2_WEST_WALK2  = { id = 98, w = 8, h = 16 },
	NPC2_WEST_WALK3  = { id = 99, w = 8, h = 16 },
	-- Damaged
	NPC2_DAMAGED     = { id = 101, w = 8, h = 16 },
}

-- ============================================
-- BUILDING TYPES
-- ============================================
-- wall_height: multiplier for PERSPECTIVE_CONFIG.max_wall_height (1 = normal, 2 = double, etc.)
BUILDING_TYPES = {
	-- === PRIMITIVE / LOW-RISE (outer city) ===
	BRICK = {
		wall_sprite = SPRITES.BRICK_WALL.id,
		roof_sprite = SPRITES.ROOF_CHIMNEY.id,
		wall_height = 1,
	},
	CRACKED_BRICK = {
		wall_sprite = SPRITES.CRACKED_BRICK.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	LARGE_BRICK = {
		wall_sprite = SPRITES.LARGE_BRICK.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 1,
	},
	CONCRETE = {
		wall_sprite = SPRITES.CRACKED_CONCRETE.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	WAREHOUSE = {
		wall_sprite = SPRITES.ZINC.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},

	-- === MID-RISE (transition zone) ===
	MARBLE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 1,
	},
	OFFICE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 2,
	},
	INDUSTRIAL = {
		wall_sprite = SPRITES.METALLIC_PIPES.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 1,
	},
	GREEN = {
		wall_sprite = SPRITES.GREEN_BLOCK.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 1,
	},

	-- === HIGH-RISE / SKYSCRAPERS (city center) ===
	TECHNO_TOWER = {
		wall_sprite = SPRITES.TECHNO.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 3,
	},
	GLASS_TOWER = {
		wall_sprite = SPRITES.GLASS.id,
		roof_sprite = SPRITES.ROOF_FLAT.id,
		wall_height = 3,
	},
	BULKHEAD_TOWER = {
		wall_sprite = SPRITES.BULKHEAD.id,
		roof_sprite = SPRITES.ROOF_POINTY.id,
		wall_height = 3,
	},
	CORPORATE_HQ = {
		wall_sprite = SPRITES.GLASS.id,
		roof_sprite = SPRITES.ROOF_CIRCULAR.id,
		wall_height = 4,
	},
}

-- ============================================
-- PLAYER CONFIG
-- ============================================
PLAYER_CONFIG = {
	walk_speed = 1.2,
	run_speed = 2,
	animation_speed = 8,  -- frames per sprite change
	shadow_color = 25,    -- shadow color during daytime
	shadow_radius = 8,    -- shadow ellipse radius (width)
	shadow_height = 4,    -- shadow ellipse height
	shadow_x_offset = -1,  -- horizontal offset for shadow
	shadow_y_offset = 6,  -- how far below player center to draw shadow
}

-- ============================================
-- CAMERA CONFIG
-- ============================================
CAMERA_CONFIG = {
	follow_smoothing = 0.08,  -- smoothing factor (lower = smoother/slower, higher = snappier)
	deadzone_half_w = 16,     -- half-width of center deadzone (player can move this far before camera follows)
	deadzone_half_h = 16,     -- half-height of center deadzone
}

-- ============================================
-- NPC CONFIG
-- ============================================
NPC_CONFIG = {
	-- Movement speeds (pixels per second)
	walk_speed = 15,
	run_speed = 60,
	-- Animation timing (seconds per sprite change)
	run_animation_speed = 0.05,
	animation_speed = 0.1,
	-- AI behavior timing (seconds)
	direction_change_time = { min = 1.0, max = 3.0 },
	idle_time = { min = 0.5, max = 1.5 },
	-- Collision
	collision_radius = 4,
	-- Spawning
	spawn_count = 200,
	-- NPC update mode:
	-- 1 = persistent: NPCs exist everywhere, throttled updates for distant ones
	-- 2 = streaming: NPCs despawn when far, respawn nearby to maintain target count
	update_mode = 1,
	-- Shadows
	shadow_color = 25,
	shadow_radius = 4,
	shadow_height = 2,
	shadow_x_offset = 0,
	shadow_y_offset = 6,

	-- Performance tuning (mode 1: persistent)
	offscreen_update_interval = 2,  -- seconds between AI updates for offscreen NPCs
	offscreen_update_distance = 400,  -- pixels from player; NPCs beyond this are frozen

	-- Performance tuning (mode 2: streaming)
	despawn_distance = 400,    -- pixels from player; NPCs beyond this despawn (also max spawn distance)
	spawn_distance_min = 10,   -- min pixels from player for new spawns
	target_npc_count = 50,     -- target number of NPCs to maintain in streaming mode

	-- Freaked out behavior
	flee_recheck_interval = 0.75,
	scare_radius = 32,
	surprise_duration = 1.0,     -- seconds
	flee_duration = 15.0,        -- seconds
	surprise_sprite = 135,
}

-- NPC type definitions (sprite sets)
NPC_TYPES = {
	{
		name = "MALE_NPC",
		south = { idle = SPRITES.NPC1_SOUTH_IDLE.id, walk = { SPRITES.NPC1_SOUTH_WALK1.id, SPRITES.NPC1_SOUTH_WALK2.id, SPRITES.NPC1_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC1_EAST_IDLE.id,  walk = { SPRITES.NPC1_EAST_WALK1.id,  SPRITES.NPC1_EAST_WALK2.id,  SPRITES.NPC1_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC1_NORTH_IDLE.id, walk = { SPRITES.NPC1_NORTH_WALK1.id, SPRITES.NPC1_NORTH_WALK2.id, SPRITES.NPC1_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC1_WEST_IDLE.id,  walk = { SPRITES.NPC1_WEST_WALK1.id,  SPRITES.NPC1_WEST_WALK2.id,  SPRITES.NPC1_WEST_WALK3.id } },
		-- Expressions
		mouth_open = 80,
		surprised = 81,
		look_up = 82,
		look_down = 83,
		w = 8, h = 16,
	},
	{
		name = "FEMALE_NPC",
		south = { idle = SPRITES.NPC2_SOUTH_IDLE.id, walk = { SPRITES.NPC2_SOUTH_WALK1.id, SPRITES.NPC2_SOUTH_WALK2.id, SPRITES.NPC2_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC2_EAST_IDLE.id,  walk = { SPRITES.NPC2_EAST_WALK1.id,  SPRITES.NPC2_EAST_WALK2.id,  SPRITES.NPC2_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC2_NORTH_IDLE.id, walk = { SPRITES.NPC2_NORTH_WALK1.id, SPRITES.NPC2_NORTH_WALK2.id, SPRITES.NPC2_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC2_WEST_IDLE.id,  walk = { SPRITES.NPC2_WEST_WALK1.id,  SPRITES.NPC2_WEST_WALK2.id,  SPRITES.NPC2_WEST_WALK3.id } },
		-- Expressions
		mouth_open = 100,
		surprised = 101,
		look_up = 102,
		look_down = 103,
		w = 8, h = 16,
	},
}

-- ============================================
-- PERSPECTIVE CONFIG (GTA1/2 style)
-- ============================================
PERSPECTIVE_CONFIG = {
	max_wall_height = 24,           -- fixed height of all building walls
	perspective_scale = 0.12,       -- how much roofs offset from center (higher = more 3D, was 0.15)
	wall_visibility_threshold = 0,  -- pixels from center before walls show (0 = always show walls)
}

-- ============================================
-- GROUND CONFIG
-- ============================================
GROUND_CONFIG = {
	tile_size = 16,  -- base tile size for ground grid
}

-- ============================================
-- DEBUG CONFIG
-- ============================================
DEBUG_CONFIG = {
	enabled = false,  -- set to false to disable debug features
}

-- ============================================
-- TRAFFIC LIGHT CONFIG
-- ============================================
TRAFFIC_CONFIG = {
	cycle_time = 15,        -- seconds per green phase
	yellow_time = 2,        -- seconds for yellow before switching
	-- N-S traffic signals (controls north-south traffic flow)
	signal_sprites_ns = {
		yellow = 195,
		green = 196,
		red = 197,
	},
	-- E-W traffic signals (controls east-west traffic flow)
	signal_sprites_ew = {
		yellow = 214,
		green = 215,
		red = 222,
	},
	-- Base signal position on lamp sprite
	signal_base_x = 12,     -- from left edge of lamp (center of 24px lamp)
	signal_base_y = 21,     -- from bottom of lamp (near top)
	-- Offset for first signal (N-S) from base position
	signal_1_offset_x = -6,
	signal_1_offset_y = 0,
	-- Offset for second signal (E-W) from base position
	signal_2_offset_x = 6,
	signal_2_offset_y = 0,
	-- Only show traffic lights at intersections (disable regular street lights)
	intersection_lights_only = true,
}

-- ============================================
-- MINIMAP CONFIG
-- ============================================
MINIMAP_CONFIG = {
	enabled = true,          -- show minimap
	x = 8,                   -- screen X position (top-left corner)
	y = 8,                   -- screen Y position (top-left corner)
	width = 80,              -- minimap width in pixels
	height = 60,             -- minimap height in pixels
	scale = 0.03,            -- world-to-minimap scale (smaller = more zoomed out)
	bg_color = 20,           -- background color (grass green)
	border_color = 6,        -- border color
	road_color = 5,          -- road color (gray)
	building_color = 4,      -- building color (brown)
	player_color = 11,       -- player blip color (green)
	npc_color = 8,           -- NPC blip color (red)
	player_size = 2,         -- player blip radius
	npc_size = 1,            -- NPC blip size
	alpha = 0.7,             -- transparency (not used directly, for reference)
	water_color = 24,        -- water color on minimap (blue)
}

-- ============================================
-- MAP GENERATION CONFIG
-- ============================================
-- Sprite 255 contains a 256x256 map that defines the world layout
-- Each pixel color represents a terrain type
MAP_CONFIG = {
	-- Map sprite ID
	sprite_id = 247,
	map_width = 256,
	map_height = 256,

	-- World scale: each map pixel = this many world units
	-- 256px * 16 = 4096 world units
	tile_size = 16,

	-- Color legend (map pixel colors)
	colors = {
		grass = 20,         -- grass/land
		water = 24,         -- water
		main_road = 31,     -- main paved streets (no sidewalk in map, generate sidewalks)
		dirt_road = 16,     -- dirt/country roads
		building_zone = 4,  -- brown rectangles where buildings can spawn
	},

	-- Building generation settings
	building = {
		-- Min/max building dimensions (in world units)
		min_size = 48,
		max_size = 96,
		-- Padding from roads/water (in world units)
		road_padding = 32,
		-- Target building count
		target_count = 80,
		-- Building type distribution by distance from center
		-- World (0,0) is map center, so downtown is near origin
		center_x = 0,     -- world center X (map center)
		center_y = 0,     -- world center Y (map center)
		inner_radius = 400,   -- within this = downtown
		outer_radius = 1000,  -- beyond this = countryside
	},
}

-- ============================================
-- WATER CONFIG
-- ============================================
-- Water surrounds the city with animated tiles
-- Set 1: Grass border around water (outer coastline)
-- Set 2: Water border around grass (island coastlines)
WATER_CONFIG = {
	animation_speed = 0.5,   -- seconds per frame (2 FPS animation)
	-- World bounds for land (beyond this = water)
	-- Roads span -700 to 1900 x, -400 to 1600 y
	-- Adding extra grass buffer around the city
	land_min_x = -850,       -- west edge of land (extra 100px grass beyond roads)
	land_max_x = 2050,       -- east edge of land (extra 150px grass beyond roads)
	land_min_y = -550,       -- north edge of land (extra 150px grass beyond roads)
	land_max_y = 1750,       -- south edge of land (extra 150px grass beyond roads)
	-- Water extends to world bounds (defined in ground.lua)

	-- 9-slice tile IDs for Set 1 (grass surrounding water - outer coastline)
	-- [frame][position] where position: tl, t, tr, l, c, r, bl, b, br
	set1 = {
		-- Frame 1
		{ tl = 208, t = 209, tr = 210,
		  l  = 216, c = 217, r  = 218,
		  bl = 224, b = 225, br = 226 },
		-- Frame 2
		{ tl = 232, t = 233, tr = 234,
		  l  = 240, c = 241, r  = 242,
		  bl = 248, b = 249, br = 250 },
	},

	-- 9-slice tile IDs for Set 2 (water surrounding grass - island coastlines)
	-- Center tile not used (use grass instead)
	set2 = {
		-- Frame 1
		{ tl = 211, t = 212, tr = 213,
		  l  = 219, c = nil, r  = 221,
		  bl = 227, b = 228, br = 229 },
		-- Frame 2
		{ tl = 235, t = 236, tr = 237,
		  l  = 243, c = nil, r  = 245,
		  bl = 251, b = 252, br = 253 },
	},

	-- Islands configuration (position in water, outside land bounds)
	-- x,y = world position of island top-left, w,h = size in tiles (16px each)
	islands = {
		{ x = -1000, y = -600, w = 4, h = 3 },   -- island far NW
		{ x = -1100, y = 400, w = 3, h = 2 },    -- island W
		{ x = -950, y = 1200, w = 5, h = 4 },    -- larger island SW
		{ x = 2050, y = -500, w = 4, h = 3 },    -- island far NE
		{ x = 2100, y = 600, w = 3, h = 3 },     -- island E
		{ x = 2000, y = 1400, w = 4, h = 2 },    -- island SE
		{ x = 400, y = 1750, w = 3, h = 2 },     -- island S
		{ x = 800, y = -650, w = 3, h = 2 },     -- island N
	},
}

-- ============================================
-- NIGHT MODE / LIGHTING CONFIG
-- ============================================
NIGHT_CONFIG = {
	player_light_radius = 25,    -- radius of light around player
	street_light_radius = 20,    -- radius of street lights
	street_light_spacing = 64,   -- distance between street lights (world units)
	street_light_offset = 0,     -- offset along sidewalk path (slide lights forward/back)
	darken_color = 16,           -- color index for dark areas (higher = darker)
	ambient_color = 31,          -- color index for ambient tint (even in lit areas)
	transition_speed = 16,        -- frames per transition step
	-- Transition sequences (darken_color values)
	day_to_night = { 33, 30, 20, 25, 11 },  -- day gets darker
	night_to_day = { 11, 25, 20, 30, 33 },  -- night gets lighter
	-- Lamp sprite (visual representation of street lights)
	lamp_sprite = 192,           -- sprite ID for lamp
	lamp_width = 24,             -- lamp sprite width
	lamp_height = 24,            -- lamp sprite height
}

-- ============================================
-- ROAD/SIDEWALK CONFIG
-- ============================================
ROAD_CONFIG = {
	road_width = 64,       -- width of road surface (doubled from 32)
	sidewalk_width = 16,   -- width of sidewalk on each side (1 tile)
	-- Total street width = road_width + 2*sidewalk_width = 96
}

-- ============================================
-- LEVEL DATA - ROADS
-- ============================================
-- Roads are defined as line segments with width
-- tile_type: 2=medium dirt (only using medium for consistency)
-- Coordinates are doubled for larger scale
-- Each road has sidewalks on both sides (16px each)
-- Street lights placed on sidewalks (both sides)
ROADS = {
	-- === MAJOR ARTERIAL ROADS (form the main grid) ===
	-- Main horizontal roads (y positions doubled, street width 64)
	{ direction = "horizontal", y = 0,    x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 384,  x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 768,  x1 = -640, x2 = 1600, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 1152, x1 = -640, x2 = 1600, width = 64, tile_type = 2 },

	-- Main vertical roads (x positions doubled, street width 64)
	{ direction = "vertical", x = -256, y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 256,  y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 768,  y1 = -256, y2 = 1408, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 1216, y1 = -256, y2 = 1408, width = 64, tile_type = 2 },

	-- === SECONDARY STREETS (subdivide blocks) ===
	-- Inner city horizontal streets
	{ direction = "horizontal", y = 192,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 576,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },
	{ direction = "horizontal", y = 960,  x1 = -256, x2 = 1216, width = 64, tile_type = 2 },

	-- Inner city vertical streets
	{ direction = "vertical", x = 0,    y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 512,  y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
	{ direction = "vertical", x = 960,  y1 = 0, y2 = 1152, width = 64, tile_type = 2 },
}

-- ============================================
-- COUNTRYSIDE ROADS (no sidewalks, no street lights)
-- ============================================
-- Organic road segments outside the city grid
-- tile_type: 3 = dense dirt (DIRT_HEAVY)
-- countryside = true marks these as rural roads
COUNTRYSIDE_ROADS = {
	-- === WEST COUNTRYSIDE ===
	-- Main road heading west from city
	{ direction = "horizontal", y = 576, x1 = -640, x2 = -256, width = 32, tile_type = 3, countryside = true },
	-- Branch north
	{ direction = "vertical", x = -512, y1 = 200, y2 = 576, width = 32, tile_type = 3, countryside = true },
	-- Branch south
	{ direction = "vertical", x = -480, y1 = 576, y2 = 900, width = 32, tile_type = 3, countryside = true },
	-- Curved path northwest
	{ direction = "horizontal", y = 200, x1 = -700, x2 = -512, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = -700, y1 = -100, y2 = 200, width = 32, tile_type = 3, countryside = true },

	-- === EAST COUNTRYSIDE ===
	-- Main road heading east from city
	{ direction = "horizontal", y = 576, x1 = 1296, x2 = 1800, width = 32, tile_type = 3, countryside = true },
	-- Branch northeast
	{ direction = "vertical", x = 1600, y1 = 300, y2 = 576, width = 32, tile_type = 3, countryside = true },
	{ direction = "horizontal", y = 300, x1 = 1600, x2 = 1900, width = 32, tile_type = 3, countryside = true },
	-- Branch southeast
	{ direction = "vertical", x = 1700, y1 = 576, y2 = 1000, width = 32, tile_type = 3, countryside = true },

	-- === NORTH COUNTRYSIDE ===
	-- Road heading north from city
	{ direction = "vertical", x = 480, y1 = -256, y2 = -100, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = 480, y1 = -400, y2 = -256, width = 32, tile_type = 3, countryside = true },
	-- Branch west
	{ direction = "horizontal", y = -300, x1 = 100, x2 = 480, width = 32, tile_type = 3, countryside = true },
	-- Branch east
	{ direction = "horizontal", y = -350, x1 = 480, x2 = 900, width = 32, tile_type = 3, countryside = true },

	-- === SOUTH COUNTRYSIDE ===
	-- Road heading south from city
	{ direction = "vertical", x = 600, y1 = 1216, y2 = 1500, width = 32, tile_type = 3, countryside = true },
	-- Branch southwest
	{ direction = "horizontal", y = 1400, x1 = 200, x2 = 600, width = 32, tile_type = 3, countryside = true },
	{ direction = "vertical", x = 200, y1 = 1400, y2 = 1600, width = 32, tile_type = 3, countryside = true },
	-- Branch southeast
	{ direction = "horizontal", y = 1350, x1 = 600, x2 = 1100, width = 32, tile_type = 3, countryside = true },
}

-- ============================================
-- FLORA CONFIG
-- ============================================
FLORA_CONFIG = {
	-- Region-based procedural generation
	-- Each region_size x region_size area gets items_per_region flora items
	region_size = 160,       -- 10 tiles x 16 pixels = 160 pixel regions
	items_per_region = 8,   -- 20 flora items per 160x160 region

	-- Probability weights for flora types (relative chances)
	tree_weight = 0.15,      -- 15% chance for trees (only on eligible spots)
	flower_weight = 0.40,    -- 40% chance for flowers
	-- Remaining chance = grass blades

	-- Flora sprite IDs
	tree_sprites = { SPRITES.TREE_1.id, SPRITES.TREE_2.id },
	flower_sprites = { SPRITES.FLOWER_1.id, SPRITES.FLOWER_2.id },
	grass_sprite = SPRITES.GRASS_BLADE.id,

	-- Shadow toggle and settings
	shadows_enabled = false,  -- set to true to enable flora shadows
	shadow_color = 25,
	shadow_y_offset = 6,
	tree_shadow_radius = 5,
	tree_shadow_height = 3,
	flower_shadow_radius = 3,
	flower_shadow_height = 2,
	grass_shadow_radius = 2,
	grass_shadow_height = 1,
}

-- ============================================
-- LEVEL DATA - BUILDINGS
-- ============================================
-- Layout calculation:
-- Road corridor = 96 (64 road + 16 sidewalk each side)
-- Road spacing = 192 (between horizontal roads)
-- Block interior = 192 - 96 = 96px available
-- Building zone with 16px padding = starts at road_center + 48, height ~64px max
--
-- Horizontal roads: y=0, 192, 384, 576, 768, 960, 1152
-- Vertical roads: x=-256, 0, 256, 512, 768, 960, 1216

LEVEL_BUILDINGS = {
	-- Format: { x, y, w, h, type }

	-- =============================================
	-- OUTER RING: PRIMITIVE BUILDINGS (brick, concrete, cracked)
	-- =============================================

	-- === FAR WEST COLUMN - Left of x=-256 road ===
	{ x = -480, y = 64,  w = 80, h = 64, type = "CRACKED_BRICK" },
	{ x = -384, y = 64,  w = 64, h = 64, type = "BRICK" },
	{ x = -480, y = 256, w = 96, h = 64, type = "CRACKED_CONCRETE" },
	{ x = -368, y = 256, w = 64, h = 64, type = "LARGE_BRICK" },
	{ x = -480, y = 448, w = 80, h = 64, type = "BRICK" },
	{ x = -384, y = 448, w = 72, h = 64, type = "ZINC" },
	{ x = -480, y = 640, w = 88, h = 64, type = "CRACKED_BRICK" },
	{ x = -376, y = 640, w = 64, h = 64, type = "CONCRETE" },
	{ x = -480, y = 832, w = 160, h = 64, type = "WAREHOUSE" },
	{ x = -480, y = 1024, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = -384, y = 1024, w = 72, h = 64, type = "BRICK" },

	-- === FAR EAST COLUMN - Right of x=1216 road ===
	{ x = 1296, y = 64,  w = 80, h = 64, type = "BRICK" },
	{ x = 1392, y = 64,  w = 64, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1296, y = 256, w = 64, h = 64, type = "ZINC" },
	{ x = 1376, y = 256, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 1296, y = 448, w = 96, h = 64, type = "CRACKED_BRICK" },
	{ x = 1408, y = 448, w = 56, h = 64, type = "CONCRETE" },
	{ x = 1296, y = 640, w = 72, h = 64, type = "BRICK" },
	{ x = 1384, y = 640, w = 72, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1296, y = 832, w = 160, h = 64, type = "WAREHOUSE" },
	{ x = 1296, y = 1024, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 1392, y = 1024, w = 64, h = 64, type = "CRACKED_BRICK" },

	-- === TOP ROW - Above y=0 road ===
	{ x = -160, y = -112, w = 96, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 80,   y = -112, w = 80, h = 64, type = "BRICK" },
	{ x = 336,  y = -112, w = 80, h = 64, type = "ZINC" },
	{ x = 592,  y = -112, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 848,  y = -112, w = 64, h = 64, type = "CRACKED_BRICK" },
	{ x = 1040, y = -112, w = 80, h = 64, type = "CONCRETE" },

	-- === BOTTOM ROW - Below y=1152 road ===
	{ x = -160, y = 1216, w = 96, h = 64, type = "BRICK" },
	{ x = 80,   y = 1216, w = 80, h = 64, type = "CRACKED_BRICK" },
	{ x = 336,  y = 1216, w = 80, h = 64, type = "ZINC" },
	{ x = 592,  y = 1216, w = 80, h = 64, type = "LARGE_BRICK" },
	{ x = 848,  y = 1216, w = 64, h = 64, type = "CRACKED_CONCRETE" },
	{ x = 1040, y = 1216, w = 80, h = 64, type = "CONCRETE" },

	-- =============================================
	-- MIDDLE RING: MIXED DEVELOPMENT (office, marble, warehouse)
	-- =============================================

	-- === WEST COLUMN - Between x=-256 and x=0 roads ===
	{ x = -160, y = 64,  w = 96, h = 64, type = "CONCRETE" },
	{ x = -160, y = 256, w = 96, h = 64, type = "OFFICE" },
	{ x = -160, y = 448, w = 96, h = 64, type = "MARBLE" },
	{ x = -160, y = 640, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = -160, y = 832, w = 96, h = 64, type = "GREEN" },
	{ x = -160, y = 1024, w = 96, h = 64, type = "OFFICE" },

	-- === EAST COLUMN - Between x=960 and x=1216 roads ===
	{ x = 1040, y = 64,  w = 96, h = 64, type = "CONCRETE" },
	{ x = 1040, y = 256, w = 96, h = 64, type = "OFFICE" },
	{ x = 1040, y = 448, w = 96, h = 64, type = "BULKHEAD_TOWER" },
	{ x = 1040, y = 640, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = 1040, y = 832, w = 96, h = 64, type = "MARBLE" },
	{ x = 1040, y = 1024, w = 96, h = 64, type = "GREEN" },

	-- === ROW ABOVE CENTER - Inner blocks ===
	{ x = 80,  y = 64,  w = 96, h = 64, type = "MARBLE" },
	{ x = 336, y = 64,  w = 96, h = 64, type = "OFFICE" },
	{ x = 592, y = 64,  w = 96, h = 64, type = "BULKHEAD_TOWER" },
	{ x = 848, y = 64,  w = 64, h = 64, type = "CONCRETE" },

	-- === ROW BELOW CENTER ===
	{ x = 80,  y = 832, w = 96, h = 64, type = "OFFICE" },
	{ x = 336, y = 832, w = 96, h = 64, type = "MARBLE" },
	{ x = 592, y = 832, w = 96, h = 64, type = "GREEN" },
	{ x = 848, y = 832, w = 64, h = 64, type = "BULKHEAD_TOWER" },

	-- === BOTTOM INNER ROW ===
	{ x = 80,  y = 1024, w = 96, h = 64, type = "WAREHOUSE" },
	{ x = 336, y = 1024, w = 96, h = 64, type = "OFFICE" },
	{ x = 592, y = 1024, w = 96, h = 64, type = "MARBLE" },
	{ x = 848, y = 1024, w = 64, h = 64, type = "CONCRETE" },

	-- =============================================
	-- CITY CENTER: TALL TECHNO SKYSCRAPERS
	-- =============================================

	-- === DOWNTOWN CORE ROW 1 (between y=192 and y=384) ===
	{ x = 80,  y = 256, w = 96, h = 64, type = "METALLIC_PIPES" },
	{ x = 336, y = 256, w = 96, h = 64, type = "TECHNO_TOWER" },
	{ x = 592, y = 256, w = 96, h = 64, type = "GLASS_TOWER" },
	{ x = 848, y = 256, w = 64, h = 64, type = "BULKHEAD_TOWER" },

	-- === DOWNTOWN CORE ROW 2 (between y=384 and y=576) - THE HEART ===
	{ x = 80,  y = 448, w = 96, h = 64, type = "GLASS_SKYSCRAPER" },
	{ x = 336, y = 448, w = 96, h = 64, type = "CORPORATE_HQ" },
	{ x = 592, y = 448, w = 96, h = 64, type = "TECHNO_TOWER" },
	{ x = 848, y = 448, w = 64, h = 64, type = "METALLIC_PIPES" },

	-- === DOWNTOWN CORE ROW 3 (between y=576 and y=768) ===
	{ x = 80,  y = 640, w = 96, h = 64, type = "TECHNO" },
	{ x = 336, y = 640, w = 96, h = 64, type = "GLASS_TOWER" },
	{ x = 592, y = 640, w = 96, h = 64, type = "GLASS_SKYSCRAPER" },
	{ x = 848, y = 640, w = 64, h = 64, type = "BULKHEAD_TOWER" },
}

-- ============================================
-- HELPER: Create building from level data
-- ============================================
function create_buildings_from_level()
	local buildings = {}
	for _, b in ipairs(LEVEL_BUILDINGS) do
		local btype = BUILDING_TYPES[b.type] or BUILDING_TYPES.BRICK
		add(buildings, {
			x = b.x,
			y = b.y,
			w = b.w,
			h = b.h,
			wall_sprite = btype.wall_sprite,
			roof_sprite = btype.roof_sprite or SPRITES.ROOF.id,
			wall_height = btype.wall_height or 1,
		})
	end
	return buildings
end
