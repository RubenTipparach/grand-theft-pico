--[[pod_format="raw"]]
-- config.lua - Game design configuration (sprites, buildings, tuning)

-- ============================================
-- SPRITE REGISTRY
-- ============================================
SPRITES = {
	-- Walls
	BRICK_WALL    = { id = 1, w = 16, h = 16 },
	MARBLE_WALL   = { id = 2, w = 16, h = 16 },

	-- Roofs
	ROOF          = { id = 3, w = 16, h = 16 },

	-- Ground textures
	DIRT_MEDIUM   = { id = 4, w = 16, h = 16 },
	DIRT_HEAVY    = { id = 5, w = 16, h = 16 },
	DIRT_LIGHT    = { id = 6, w = 16, h = 16 },
	GRASS         = { id = 7, w = 16,  h = 16  },

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
BUILDING_TYPES = {
	BRICK = {
		wall_sprite = SPRITES.BRICK_WALL.id,
		roof_color = 5,  -- dark gray
	},
	MARBLE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_color = 6,  -- light gray
	},
	WAREHOUSE = {
		wall_sprite = SPRITES.BRICK_WALL.id,
		roof_color = 4,  -- brown
	},
	OFFICE = {
		wall_sprite = SPRITES.MARBLE_WALL.id,
		roof_color = 13, -- blue-gray
	},
}

-- ============================================
-- PLAYER CONFIG
-- ============================================
PLAYER_CONFIG = {
	walk_speed = 1,
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
	follow_smoothing = 0.1,  -- 0 = instant, 1 = no movement
	deadzone_x = 20,
	deadzone_y = 20,
}

-- ============================================
-- NPC CONFIG
-- ============================================
NPC_CONFIG = {
	walk_speed = 0.25,           -- slower than player
	animation_speed = 10,     -- frames per sprite change
	direction_change_time = { min = 60, max = 180 },  -- frames before changing direction
	idle_time = { min = 30, max = 90 },               -- frames to stand still
	collision_radius = 4,     -- hitbox radius for building collision
	spawn_count = 20,          -- number of NPCs to spawn
	shadow_color = 25,
	shadow_radius = 4,
	shadow_height = 2,
	shadow_x_offset = 0,
	shadow_y_offset = 6,
}

-- NPC type definitions (sprite sets)
NPC_TYPES = {
	{
		name = "NPC1",
		south = { idle = SPRITES.NPC1_SOUTH_IDLE.id, walk = { SPRITES.NPC1_SOUTH_WALK1.id, SPRITES.NPC1_SOUTH_WALK2.id, SPRITES.NPC1_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC1_EAST_IDLE.id,  walk = { SPRITES.NPC1_EAST_WALK1.id,  SPRITES.NPC1_EAST_WALK2.id,  SPRITES.NPC1_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC1_NORTH_IDLE.id, walk = { SPRITES.NPC1_NORTH_WALK1.id, SPRITES.NPC1_NORTH_WALK2.id, SPRITES.NPC1_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC1_WEST_IDLE.id,  walk = { SPRITES.NPC1_WEST_WALK1.id,  SPRITES.NPC1_WEST_WALK2.id,  SPRITES.NPC1_WEST_WALK3.id } },
		damaged = SPRITES.NPC1_DAMAGED.id,
		w = 8, h = 16,
	},
	{
		name = "NPC2",
		south = { idle = SPRITES.NPC2_SOUTH_IDLE.id, walk = { SPRITES.NPC2_SOUTH_WALK1.id, SPRITES.NPC2_SOUTH_WALK2.id, SPRITES.NPC2_SOUTH_WALK3.id } },
		east  = { idle = SPRITES.NPC2_EAST_IDLE.id,  walk = { SPRITES.NPC2_EAST_WALK1.id,  SPRITES.NPC2_EAST_WALK2.id,  SPRITES.NPC2_EAST_WALK3.id } },
		north = { idle = SPRITES.NPC2_NORTH_IDLE.id, walk = { SPRITES.NPC2_NORTH_WALK1.id, SPRITES.NPC2_NORTH_WALK2.id, SPRITES.NPC2_NORTH_WALK3.id } },
		west  = { idle = SPRITES.NPC2_WEST_IDLE.id,  walk = { SPRITES.NPC2_WEST_WALK1.id,  SPRITES.NPC2_WEST_WALK2.id,  SPRITES.NPC2_WEST_WALK3.id } },
		damaged = SPRITES.NPC2_DAMAGED.id,
		w = 8, h = 16,
	},
}

-- ============================================
-- PERSPECTIVE CONFIG (GTA1/2 style)
-- ============================================
PERSPECTIVE_CONFIG = {
	max_wall_height = 24,           -- fixed height of all building walls
	perspective_scale = 0.15,       -- how much roofs offset from center (higher = more 3D)
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
-- NIGHT MODE / LIGHTING CONFIG
-- ============================================
NIGHT_CONFIG = {
	player_light_radius = 25,    -- radius of light around player
	street_light_radius = 30,    -- radius of street lights
	street_light_spacing = 128,  -- distance between street lights (world units)
	darken_color = 16,           -- color index for dark areas (higher = darker)
	ambient_color = 31,          -- color index for ambient tint (even in lit areas)
	transition_speed = 16,        -- frames per transition step
	-- Transition sequences (darken_color values)
	day_to_night = { 33, 30, 20, 25, 11 },  -- day gets darker
	night_to_day = { 11, 25, 20, 30, 33 },  -- night gets lighter
}

-- ============================================
-- LEVEL DATA - ROADS
-- ============================================
-- Roads are defined as line segments with width
-- tile_type: 2=medium dirt (only using medium for consistency)
-- width = 32 (2 tiles * 16 pixels)
-- NOTE: All coordinates should be multiples of 32 for even street light spacing
ROADS = {
	-- Main horizontal road through the middle
	{ direction = "horizontal", y = 192, x1 = -192, x2 = 576, width = 32, tile_type = 2 },

	-- Main vertical road
	{ direction = "vertical", x = 192, y1 = -96, y2 = 480, width = 32, tile_type = 2 },

	-- Secondary horizontal roads
	{ direction = "horizontal", y = 64, x1 = 0, x2 = 512, width = 32, tile_type = 2 },
	{ direction = "horizontal", y = 352, x1 = -96, x2 = 448, width = 32, tile_type = 2 },

	-- Secondary vertical roads
	{ direction = "vertical", x = 64, y1 = 0, y2 = 384, width = 32, tile_type = 2 },
	{ direction = "vertical", x = 384, y1 = 0, y2 = 352, width = 32, tile_type = 2 },
}

-- ============================================
-- LEVEL DATA - BUILDINGS
-- ============================================
-- City blocks are defined by road intersections:
-- Horizontal roads: y=64, y=192, y=352
-- Vertical roads: x=64, x=192, x=384
-- Road width is 32, so block edges are at road_pos +/- 16
-- Block margin = 8 pixels from road edge

LEVEL_BUILDINGS = {
	-- Format: { x, y, w, h, type }

	-- === BLOCK A: Top-left (x=80 to x=176, y=80 to y=176) ===
	-- Between roads x=64 and x=192, y=64 and y=192
	{ x = 88,  y = 88,  w = 80, h = 80, type = "BRICK" },

	-- === BLOCK B: Top-middle (x=208 to x=368, y=80 to y=176) ===
	-- Between roads x=192 and x=384, y=64 and y=192
	{ x = 216, y = 88,  w = 64, h = 72, type = "MARBLE" },
	{ x = 296, y = 88,  w = 64, h = 72, type = "OFFICE" },

	-- === BLOCK C: Top-right (x=400 to x=496, y=80 to y=176) ===
	-- Right of road x=384, above road y=192
	{ x = 400, y = 88,  w = 88, h = 80, type = "WAREHOUSE" },

	-- === BLOCK D: Middle-left (x=80 to x=176, y=208 to y=336) ===
	-- Between roads x=64 and x=192, y=192 and y=352
	{ x = 88,  y = 216, w = 80, h = 56, type = "WAREHOUSE" },
	{ x = 88,  y = 280, w = 80, h = 56, type = "BRICK" },

	-- === BLOCK E: Middle-center (x=208 to x=368, y=208 to y=336) ===
	-- Between roads x=192 and x=384, y=192 and y=352
	{ x = 216, y = 216, w = 72, h = 56, type = "OFFICE" },
	{ x = 296, y = 216, w = 64, h = 56, type = "MARBLE" },
	{ x = 216, y = 280, w = 140, h = 56, type = "WAREHOUSE" },

	-- === BLOCK F: Middle-right (x=400 to x=496, y=208 to y=336) ===
	-- Right of road x=384, between y=192 and y=352
	{ x = 400, y = 216, w = 80, h = 112, type = "OFFICE" },

	-- === BLOCK G: Bottom-left (x=80 to x=176, y=368 to y=464) ===
	-- Between roads x=64 and x=192, below y=352
	{ x = 88,  y = 368, w = 80, h = 64, type = "MARBLE" },

	-- === BLOCK H: Left of leftmost road (x=-176 to x=48) ===
	-- Left of road x=64
	{ x = -160, y = 216, w = 72, h = 80, type = "BRICK" },
	{ x = -80,  y = 216, w = 64, h = 80, type = "WAREHOUSE" },
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
			roof_color = btype.roof_color,
		})
	end
	return buildings
end
