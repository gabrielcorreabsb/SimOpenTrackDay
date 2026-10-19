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
  danger = rgbm(232 / 255, 90 / 255, 90 / 255, 1)
}

Theme.spacing = { xs = 4, sm = 8, md = 14, lg = 22, xl = 32 }
-- DirectWrite sizing references; these are not pixel sizes for native ui.Font roles.
Theme.type = { caption = 13, body = 15, control = 18, tab = 19, section = 18, title = 26, carDetail = 16 }
Theme.slider = { width = 220, compactWidth = 180, stackedMaxWidth = 460 }
Theme.button = {
  selected = {
    normal = Theme.colors.accentSoft,
    hovered = Theme.colors.accentSoft,
    pressed = Theme.colors.accent,
    text = Theme.colors.white,
  },
  quiet = {
    normal = Theme.colors.transparent,
    hovered = Theme.colors.divider,
    pressed = Theme.colors.accent,
    text = Theme.colors.text,
  },
  windowChrome = {
    normal = Theme.colors.surface,
    hovered = Theme.colors.divider,
    pressed = Theme.colors.accent,
    text = Theme.colors.text,
  },
  disabled = {
    normal = Theme.colors.surface,
    hovered = Theme.colors.surface,
    pressed = Theme.colors.surface,
    text = Theme.colors.disabled,
  },
}
Theme.layout = {
  windowInset = 8,
  headerTitleRowHeight = 34,
  headerContextGap = Theme.spacing.xs,
  headerBottomPadding = Theme.spacing.sm,
  headerControlRowHeight = 34,
  headerControlGap = Theme.spacing.sm,
  headerWideControlThreshold = 760,
  headerLanguageStartRatio = 0.31,
  headerStatusStartRatio = 0.76,
  tabHeight = 34,
  closeButtonSize = 28,
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
