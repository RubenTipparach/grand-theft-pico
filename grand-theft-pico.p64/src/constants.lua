--[[pod_format="raw"]]
-- constants.lua - System constants (non-configurable)

-- Screen dimensions (Picotron native)
SCREEN_W = 480
SCREEN_H = 270
SCREEN_CX = 240         -- screen center X
SCREEN_CY = 135         -- screen center Y

-- Culling margin (derived from max wall height + buffer)
-- Increased to account for perspective offset at screen edges
CULL_MARGIN = 96
