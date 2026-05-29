-- ~ / .config / hypr / configs / modules / visuals / decorations.lua

local wal = require("configs.modules.visuals.colors")

hl.config({
  general = {
    gaps_in = 10,
    gaps_out = 20,
    border_size = 0,
    col = {
      active_border = { colors = { wal.color1, wal.color2 }, angle = 45 },
      inactive_border = wal.background,
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 12,
    dim_inactive = false,
    active_opacity = 1.00,
    inactive_opacity = 0.92,

    shadow = {
      enabled = false,
      range = 10,
      render_power = 4,
      color = wal.background,
    },

    blur = {
      enabled = true,
      size = 10,
      passes = 3,
      new_optimizations = true,
      xray = false,
      contrast = 1.50,
      noise = 0.08,
      ignore_opacity = true,
    },
  },

  misc = {
    disable_hyprland_logo = true,
  },
})
