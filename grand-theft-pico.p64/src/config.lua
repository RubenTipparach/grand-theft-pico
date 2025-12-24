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
	GRASS         = { id = 7, w = 8,  h = 8  },

	-- Player
	PLAYER_IDLE   = { id = 8,  w = 16, h = 16 },  -- facing left, flip_x for right
	PLAYER_WALK1  = { id = 9,  w = 16, h = 16 },
	PLAYER_WALK2  = { id = 10, w = 16, h = 16 },
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
	walk_speed = 2,
	run_speed = 4,
	animation_speed = 8,  -- frames per sprite change
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
	enabled = true,  -- set to false to disable debug features
}

-- ============================================
-- NIGHT MODE / LIGHTING CONFIG
-- ============================================
NIGHT_CONFIG = {
	player_light_radius = 25,    -- radius of light around player
	street_light_radius = 30,    -- radius of street lights
	street_light_spacing = 78,   -- distance between street lights (world units)
	darken_color = 16,           -- color index for dark areas (higher = darker)
	ambient_color = 32,          -- color index for ambient tint (even in lit areas)
}

-- ============================================
-- LEVEL DATA - ROADS
-- ============================================
-- Roads are defined as line segments with width
-- tile_type: 2=medium dirt (only using medium for consistency)
-- width = 32 (2 tiles * 16 pixels)
ROADS = {
	-- Main horizontal road through the middle
	{ direction = "horizontal", y = 200, x1 = -200, x2 = 600, width = 32, tile_type = 2 },

	-- Main vertical road
	{ direction = "vertical", x = 200, y1 = -100, y2 = 500, width = 32, tile_type = 2 },

	-- Secondary horizontal roads
	{ direction = "horizontal", y = 50, x1 = 0, x2 = 500, width = 32, tile_type = 2 },
	{ direction = "horizontal", y = 350, x1 = -100, x2 = 450, width = 32, tile_type = 2 },

	-- Secondary vertical roads
	{ direction = "vertical", x = 50, y1 = 0, y2 = 400, width = 32, tile_type = 2 },
	{ direction = "vertical", x = 400, y1 = 0, y2 = 350, width = 32, tile_type = 2 },
}

-- ============================================
-- LEVEL DATA - BUILDINGS
-- ============================================
LEVEL_BUILDINGS = {
	-- Format: { x, y, w, h, type }
	-- Buildings positioned around the roads
	{ x = 70,  y = 70,  w = 64, h = 48, type = "BRICK" },
	{ x = 250, y = 70,  w = 48, h = 64, type = "MARBLE" },
	{ x = 320, y = 60,  w = 60, h = 56, type = "OFFICE" },
	{ x = 70,  y = 220, w = 56, h = 56, type = "WAREHOUSE" },
	{ x = 250, y = 220, w = 72, h = 48, type = "BRICK" },
	{ x = 420, y = 80,  w = 48, h = 80, type = "MARBLE" },
	{ x = 250, y = 280, w = 96, h = 50, type = "WAREHOUSE" },
	{ x = 420, y = 220, w = 64, h = 64, type = "OFFICE" },
	{ x = -80, y = 220, w = 60, h = 60, type = "BRICK" },
	{ x = 70,  y = 360, w = 60, h = 48, type = "MARBLE" },
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
