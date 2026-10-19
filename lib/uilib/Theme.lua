local Theme = {}

-- Shared visual language for SimOpenTrackDay's in-game interface.
Theme.colors = {
  bg = rgbm(16 / 255, 24 / 255, 32 / 255, 1),
  surface = rgbm(25 / 255, 38 / 255, 49 / 255, 1),
  divider = rgbm(52 / 255, 69 / 255, 84 / 255, 1),
  text = rgbm(1, 1, 1, 1),
  muted = rgbm(168 / 255, 182 / 255, 197 / 255, 1),
  disabled = rgbm(130 / 255, 144 / 255, 157 / 255, 1),
  accent = rgbm(36 / 255, 99 / 255, 235 / 255, 1),
  accentSoft = rgbm(19 / 255, 47 / 255, 94 / 255, 1),
  warning = rgbm(244 / 255, 201 / 255, 93 / 255, 1),
  success = rgbm(73 / 255, 184 / 255, 121 / 255, 1),
  white = rgbm(1, 1, 1, 1),
  transparent = rgbm(0, 0, 0, 0),
  danger = rgbm(232 / 255, 90 / 255, 90 / 255, 1),
  headerGradientTopLeft = rgbm(30 / 255, 57 / 255, 100 / 255, 1),
  headerGradientTopRight = rgbm(25 / 255, 38 / 255, 49 / 255, 1),
  headerGradientBottomRight = rgbm(16 / 255, 24 / 255, 32 / 255, 1),
  headerGradientBottomLeft = rgbm(22 / 255, 43 / 255, 73 / 255, 1),
  sectionGradientLeft = rgbm(31 / 255, 54 / 255, 82 / 255, 1),
  sectionGradientRight = rgbm(25 / 255, 38 / 255, 49 / 255, 1)
}

Theme.spacing = { xs = 4, sm = 8, md = 14, lg = 22, xl = 32 }
Theme.type = { caption = 13, body = 15, control = 18, tab = 19, section = 18, title = 26, carDetail = 16 }
Theme.slider = { width = 220, compactWidth = 180, stackedMaxWidth = 460 }
Theme.layout = {
  windowInset = 8,
  tabHeight = 34,
  tabUnderlineHeight = 3,
  chipHeight = 28,
  chipGap = Theme.spacing.sm,
  statusDotSize = 10,
  statusDotGap = Theme.spacing.sm,
  responsiveLabelThreshold = 300,
  responsiveComboMaxWidth = 420,
  languageComboMaxWidth = 270,
  navigationComboMaxWidth = 350,
}

return Theme
