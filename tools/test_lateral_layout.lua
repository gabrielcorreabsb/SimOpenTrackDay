-- Focused runtime-contract checks for lateral controls and preview helpers.
-- Geometry uses mocked CSP drawing/text measurement; it is not a rendering test.
package.path = './?.lua;./?/init.lua;' .. package.path

local function check(ok, message)
  if not ok then error('FAIL: ' .. message, 2) end
end

local uiStorage = { uiLanguage = 'en' }
local yieldingStorage, overtakingStorage = { handleYielding = true }, { handleOvertaking = true }
_G.StorageManager = {
  getStorage_UI = function() return uiStorage end,
  getStorage_Yielding = function() return yieldingStorage end,
  getStorage_Overtaking = function() return overtakingStorage end,
}
local wrapped, sliders, itemWidths, tooltips = {}, {}, {}, {}
local sliderEvents = {}
local rects, lines, captions, buttons = {}, {}, {}, {}
local width, cursorX, cursorY, hovered, rightClicked, sliderDisabled = 700, 30, 50, false, false, false
local measurements = {}
local ui = {
  availableSpaceX = function() return width end,
  pushItemWidth = function(w) itemWidths[#itemWidths + 1] = w end,
  popItemWidth = function() end,
  pushStyleColor = function() end, popStyleColor = function() end,
  slider = function(label, value, min, max, format)
    sliderEvents[#sliderEvents + 1] = 'slider'
    sliders[#sliders + 1] = { label = label, value = value, min = min, max = max, format = format }
    return sliderDisabled and value or value + 0.125
  end,
  itemHovered = function() return hovered end,
  mouseClicked = function(button) return button == 1 and rightClicked end,
  setTooltip = function(s) tooltips[#tooltips + 1] = s end,
  textWrapped = function(s) wrapped[#wrapped + 1] = s; sliderEvents[#sliderEvents + 1] = 'wrapped' end,
  drawRectFilled = function(a, b) rects[#rects + 1] = { a = a, b = b, filled = true } end,
  drawRect = function(a, b) rects[#rects + 1] = { a = a, b = b } end,
  drawLine = function(a, b) lines[#lines + 1] = { a = a, b = b } end,
  getCursor = function() return { x = cursorX, y = cursorY } end,
  drawTextClipped = function(text, a, b) captions[#captions + 1] = { text = text, a = a, b = b } end,
  dwriteDrawText = function(text, size, p) captions[#captions + 1] = { text = text, size = size, p = p } end,
  measureDWriteText = function(text, size, wrap)
    measurements[#measurements + 1] = { text = text, size = size, wrap = wrap }
    return { x = #text * 8, y = 14 }
  end,
  invisibleButton = function(id, size) buttons[#buttons + 1] = { id = id, size = size } end,
  MouseButton = { Right = 1 }, StyleColor = { FrameBg=1, FrameBgHovered=2, FrameBgActive=3 },
}
_G.ui = ui
_G.vec2 = function(x, y) return { x = x, y = y } end
_G.rgbm = function(...) return { ... } end
local localization = require('Localization')
local Theme = require('lib/uilib/Theme')
local Slider = require('lib/uilib/Slider')
local Widget = require('UILateralOffsetsImageWidget')

local function resetSlider()
  wrapped, sliders, itemWidths, tooltips, sliderEvents = {}, {}, {}, {}, {}
  hovered, rightClicked = false, false
end

sliderDisabled = true
resetSlider()
check(Slider.renderStacked('Yielding', 'Tip', 0.5, -1, 1, 300, '%.2f', 0) == 0.5,
  'disabled slider mock leaves value unchanged, matching CSP behavior')
sliderDisabled = false
local function oldID(label)
  resetSlider()
  Slider.render(label, 'Tip', 0.5, -1, 1, 300, '%.2f', 0)
  return sliders[1].label:match('###(.*)$') or sliders[1].label:match('^##(.*)$') or sliders[1].label
end
for _, loc in ipairs({ 'en', 'pt-BR', 'es' }) do
  check(localization.setLocale(loc), 'real Localization accepts ' .. loc)
  for _, label in ipairs({
    localization.label('Yielding', 'settings.offset.yielding'), 'Default Lateral Offset [-1..1]',
    '##settings.offset.yielding', '###settings.offset.yielding',
  }) do
    local expected = oldID(label)
    resetSlider()
    Slider.renderStacked(label, 'Tip', 0.5, -1, 1, 300, '%.2f', 0)
    local actualID = sliders[1].label:match('###(.*)$') or sliders[1].label:match('^##(.*)$') or sliders[1].label
    check(actualID == expected, 'stacked slider preserves existing effective ID (' .. loc .. ')')
    local hiddenOnly = label:sub(1, 2) == '##'
    check(#wrapped == (hiddenOnly and 0 or 1) and
      (hiddenOnly or wrapped[1] == (label:match('^(.-)###') or localization.label(label):match('^(.-)###') or label)),
      'stacked slider wraps the visible label before rendering (' .. loc .. ')')
    check(hiddenOnly or (sliderEvents[1] == 'wrapped' and sliderEvents[2] == 'slider'),
      'visible label wraps before its slider (' .. loc .. ')')
    check(sliders[1].min == -1 and sliders[1].max == 1 and sliders[1].value == 0.5,
      'range and current value pass through')
    check(itemWidths[1] <= width, 'slider item width respects available space')
    resetSlider(); hovered, rightClicked = true, true
    check(Slider.renderStacked(label, 'Tip', 0.5, -1, 1, 300, '%.2f', 0) == 0,
      'right-click reset returns configured default')
    check(#tooltips == 1 and tooltips[1]:find(localization.text('Tip'), 1, true) and
      tooltips[1]:find(localization.text('Default'), 1, true), 'tooltip retains translated hint and default')
  end

  local autoLabel = localization.label('Yielding Lateral Offset', 'settings.offset.yielding')
  local visible = autoLabel:match('^(.-)###')
  local measuredLabel = #visible * 8
  width = measuredLabel + 220 + Theme.spacing.sm
  resetSlider()
  Slider.render(autoLabel, 'Tip', 0.5, -1, 1, 220, '%.2f', 0)
  check(#wrapped == 0 and itemWidths[1] == 220,
    'automatic slider stays inline at exact measured-label/slider/gap fit (' .. loc .. ')')
  local exactID = sliders[1].label:match('###(.*)$') or sliders[1].label
  check(measurements[#measurements].size == Theme.type.control and measurements[#measurements].wrap == -1,
    'automatic layout measures the control label using Theme typography')

  width = width - 1
  resetSlider()
  Slider.render(autoLabel, 'Tip', 0.5, -1, 1, 220, '%.2f', 0)
  local overflowID = sliders[1].label:match('###(.*)$') or sliders[1].label
  check(#wrapped == 1 and wrapped[1] == visible and overflowID == exactID,
    'automatic slider stacks at one pixel below fit while preserving ID (' .. loc .. ')')
  check(itemWidths[1] <= width and itemWidths[1] == math.min(width, math.max(220, Theme.slider.stackedMaxWidth)),
    'stacked automatic slider width is capped to available space and Theme maximum (' .. loc .. ')')

  for _, hidden in ipairs({ '##settings.offset.yielding', '###settings.offset.yielding' }) do
    resetSlider()
    Slider.render(hidden, 'Tip', 0.5, -1, 1, 220, '%.2f', 0)
    check(#wrapped == 0 and sliders[1].label == hidden,
      'automatic slider does not display hidden-only IDs (' .. loc .. ')')
  end
end

local function drawPreview(w, yielding, overtaking)
  width = w
  rects, lines, captions, buttons = {}, {}, {}, {}
  yieldingStorage.handleYielding = yielding
  overtakingStorage.handleOvertaking = overtaking
  Widget.draw({ defaultLateralOffset = -1, yieldingLateralOffset = 1, overtakingLateralOffset = 1 })
  local card = rects[1]
  if not card then
    local longest = math.max(#localization.text('Default'), yielding and #localization.text('Yield') or 0,
      overtaking and #localization.text('Overtake') or 0) * 8 + 8
    check(w < math.max(26, longest), 'preview omission is only permitted below measured caption minimum at width ' .. w)
    return
  end
  check(card.b.x - card.a.x <= math.max(0, w), 'card width fits available width ' .. w)
  check(#buttons == 1 and buttons[1].size.x <= math.max(0, w), 'reserved item width is clamped ' .. w)
  if card.b.x > card.a.x then
    check(card.b.y - card.a.y >= 100, 'card reserves positive height for track, markers, and captions')
    local filledCount = 0
    for _, r in ipairs(rects) do
      if r.filled then
        filledCount = filledCount + 1
        check(r.a.x >= card.a.x and r.b.x <= card.b.x and r.a.y >= card.a.y and r.b.y <= card.b.y,
          'complete filled geometry stays within card bounds')
      end
    end
    check(filledCount == 3 + (yielding and 1 or 0) + (overtaking and 1 or 0), 'default and enabled markers are present')
    check(#lines >= 5, 'track markers/ticks geometry is emitted')
    local imageCaptions = {}
    local edgeLabels = { L = true, ['0'] = true, R = true }
    local edgeCount = 0
    local captionLabels = {
      [localization.text('Default')] = true,
      [localization.text('Yield')] = true,
      [localization.text('Overtake')] = true,
    }
    for _, c in ipairs(captions) do
      if c.p and captionLabels[c.text] then imageCaptions[#imageCaptions + 1] = c end
      if c.p and edgeLabels[c.text] then
        edgeCount = edgeCount + 1
        check(c.p.x >= card.a.x and c.p.x + #c.text * 8 <= card.b.x + 1,
          'simulated edge-label text bounds stay inside card: ' .. c.text)
        check(c.p.y + 14 <= card.b.y + 1, 'simulated edge-label height fits reserved card: ' .. c.text)
      end
    end
    check(edgeCount == 3, 'L/0/R edge labels are distinguished from captions')
    check(#imageCaptions == 1 + (yielding and 1 or 0) + (overtaking and 1 or 0), 'caption conditionals match enabled controls')
    -- Simulated font metrics (8 px per byte) make containment assertions explicit,
    -- including translated/long captions; this does not model CSP text rendering.
    for _, c in ipairs(imageCaptions) do
      local estimatedWidth = #c.text * 8
      check(c.p.x >= card.a.x and c.p.x + estimatedWidth <= card.b.x + 1,
        'simulated caption text bounds stay inside card: ' .. c.text)
      check(c.p.y + 14 <= card.b.y + 1, 'simulated caption height fits reserved card: ' .. c.text)
    end
  end
end
for _, loc in ipairs({ 'en', 'pt-BR', 'es' }) do
  check(localization.setLocale(loc), 'preview uses real locale ' .. loc)
  for _, w in ipairs({ 480, 700, 900, 1024, 1200, 120, 80, 50, 24, 0 }) do drawPreview(w, true, true) end
end
drawPreview(700, false, false)
print('lateral runtime contract checks passed (mocked CSP geometry; no rendering validation)')
