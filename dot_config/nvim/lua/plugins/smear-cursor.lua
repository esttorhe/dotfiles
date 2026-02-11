-- ABOUTME: smear-cursor.nvim for animated cursor movement
-- ABOUTME: Provides visual flair with cursor trail effects

return {
  "sphamba/smear-cursor.nvim",
  opts = {
    smear_between_buffers = true,
    smear_between_neighbor_lines = true,
    legacy_computing_symbols_support = false,
    hide_target_hack = true,
    stiffness = 0.9,
    trailing_stiffness = 0.3,
    trailing_exponent = 0.5,
    damping = 0.7,
    distance_stop_animating = 0.3,
    max_slope = 0.5,
  },
}
