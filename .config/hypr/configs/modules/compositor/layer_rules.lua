-- ~ / .config / hypr / configs / modules / compositor / layer_rules.lua

hl.layer_rule({ name = "swayosd_blur", match = { namespace = "swayosd" }, blur = true, ignore_alpha = 0.5 })
hl.window_rule({ name = "swayosd_float", match = { class = "swayosd" }, float = true })
hl.layer_rule({ name = "swaync-control-center-blur", match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "swaync-notif-blur", match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "swaync-slide", match = { namespace = "swaync-control-center" }, animation = "slide left" })
hl.layer_rule({ name = "waybar-glass", match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "rofi-spotlight-blur", match = { namespace = "rofi" }, animation = "slide bottom", blur = true })
hl.layer_rule({ name = "rofi-spotlight-ignore-alpha", match = { namespace = "rofi" }, ignore_alpha = 0.5 })
hl.layer_rule({
  name = "shells-osd-no-anim",
  match = { namespace = "^shells-osd$" },
  no_anim = true,
})
