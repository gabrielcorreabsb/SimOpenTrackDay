local Theme = {}

-- Shared visual language for SimOpenTrackDay's in-game interface.
Theme.colors = {
  bg = rgbm(14 / 255, 16 / 255, 20 / 255, 1),
  surface = rgbm(23 / 255, 26 / 255, 32 / 255, 1),
  divider = rgbm(38 / 255, 42 / 255, 51 / 255, 1),
  text = rgbm(232 / 255, 234 / 255, 237 / 255, 1),
  muted = rgbm(138 / 255, 143 / 255, 153 / 255, 1),
  accent = rgbm(230 / 255, 57 / 255, 70 / 255, 1),
  accentSoft = rgbm(42 / 255, 20 / 255, 24 / 255, 1)
}

Theme.spacing = { xs = 4, sm = 8, md = 14, lg = 22, xl = 32 }
Theme.type = { caption = 12, body = 14, section = 17, title = 25 }
Theme.slider = { width = 220, compactWidth = 180 }

return Theme
