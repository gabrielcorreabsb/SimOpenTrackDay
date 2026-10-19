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
local textItems, itemBottom, itemCursor = {}, 0, { x = cursorX, y = cursorY }
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
  drawRectFilled = function(a, b, color, rounding) rects[#rects + 1] = { a = a, b = b, color = color, rounding = rounding or 0, filled = true } end,
  drawRect = function(a, b, color, rounding) rects[#rects + 1] = { a = a, b = b, color = color, rounding = rounding or 0 } end,
  drawLine = function(a, b, color, thickness) lines[#lines + 1] = { a = a, b = b, color = color, thickness = thickness or 1 } end,
  getCursor = function() return { x = cursorX, y = cursorY } end,
  setCursor = function(p) cursorX, cursorY = p.x, p.y; itemCursor = { x = p.x, y = p.y } end,
  itemRectMax = function() return { x = itemCursor.x + 1, y = itemBottom } end,
  textLineHeightWithSpacing = function() return 20 end,
  text = function(s) textItems[#textItems + 1] = { text = s, x = cursorX, y = cursorY }; local sz = ui.measureText(s, -1); itemBottom = math.max(itemBottom, cursorY + sz.y); cursorY = cursorY + sz.y end,
  textColored = function(s) textItems[#textItems + 1] = { text = s, x = cursorX, y = cursorY }; local sz = ui.measureText(s, -1); itemBottom = math.max(itemBottom, cursorY + sz.y); cursorY = cursorY + sz.y end,
  textWrapped = function(s) textItems[#textItems + 1] = { text = s, x = cursorX, y = cursorY }; sliderEvents[#sliderEvents + 1] = 'wrapped'; wrapped[#wrapped + 1] = s end,
  drawTextClipped = function() error('lateral widget must not use DirectWrite or clipped legacy text') end,
  dwriteDrawText = function() error('lateral widget must not use DirectWrite or clipped legacy text') end,
  measureText = function(text, wrap)
    measurements[#measurements + 1] = { text = text, native = true, wrap = wrap }
    local maxChars, lines = 0, 0
    for line in (text .. '\n'):gmatch('(.-)\n') do
      local chars = #line
      if wrap and wrap > 0 and chars * 9 > wrap then
        local n = math.ceil(chars * 9 / wrap); lines = lines + n; maxChars = math.max(maxChars, math.floor(wrap / 9))
      else lines = lines + 1; maxChars = math.max(maxChars, chars) end
    end
    return { x = maxChars * 9, y = math.max(1, lines) * 20 }
  end,
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
  local measuredLabel = #visible * 9
  width = measuredLabel + 220 + Theme.spacing.sm
  resetSlider()
  Slider.render(autoLabel, 'Tip', 0.5, -1, 1, 220, '%.2f', 0)
  check(#wrapped == 0 and itemWidths[1] == 220,
    'automatic slider stays inline at exact measured-label/slider/gap fit (' .. loc .. ')')
  local exactID = sliders[1].label:match('###(.*)$') or sliders[1].label
  check(measurements[#measurements].native and measurements[#measurements].text == visible and
    measurements[#measurements].wrap == -1,
    'automatic layout measures the visible control label using native font metrics')

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

local function drawPreview(w, yielding, overtaking, offsets, withoutWrappedHelper, sectionInset)
  width = sectionInset and (w - sectionInset) or w
  rects, lines, captions, buttons, textItems = {}, {}, {}, {}, {}
  measurements = {}
  local oldTextWrapped = ui.textWrapped
  if withoutWrappedHelper then ui.textWrapped = nil end
  cursorX, cursorY, itemBottom = sectionInset and 30 + sectionInset or 30, 50, 50
  yieldingStorage.handleYielding = yielding
  overtakingStorage.handleOvertaking = overtaking
  offsets = offsets or { -1, 1, 1 }
  local storage = { defaultLateralOffset = offsets[1], yieldingLateralOffset = offsets[2], overtakingLateralOffset = offsets[3] }
  local savedValues = { storage.defaultLateralOffset, storage.yieldingLateralOffset, storage.overtakingLateralOffset }
  local savedFlags = { yieldingStorage.handleYielding, overtakingStorage.handleOvertaking }
  Widget.draw(storage, sectionInset)
  ui.textWrapped = oldTextWrapped
  if sectionInset and w == 80 then
    check(#rects == 0 and #lines == 0 and #textItems == 0 and cursorY == 50,
      '80px Section safely skips diagram when symmetric insets leave less than minimum useful width')
    return 0
  end
  local card = rects[1]
  check(card ~= nil, 'panel remains readable at width ' .. w)
  if sectionInset then
    check(card.a.x==30+sectionInset and math.abs(card.a.x-30-sectionInset)<.01 and
      math.abs((30+w)-card.b.x-sectionInset)<.01,
      'simulated Section content inset yields equal external left/right margins')
  else
    check(card.a.x == 30 and math.abs((card.b.x-card.a.x)-w) < 0.01,
      'panel spans exactly the available section width without escaping its inset')
  end
  check(card.b.x - card.a.x <= math.max(0, w), 'card width fits available width ' .. w)
  local allText = ''
  for _, item in ipairs(textItems) do
    allText = allText .. item.text .. '\n'
    local size = ui.measureText(item.text, -1)
    check(item.x >= card.a.x and item.x + size.x <= card.b.x + 0.01, 'text horizontal bounds fit panel: ' .. item.text)
    check(item.y >= card.a.y and item.y + size.y <= card.b.y + 0.01, 'text vertical bounds fit panel: ' .. item.text)
    local found = false
    for _, measurement in ipairs(measurements) do
      if measurement.native == true and measurement.wrap == -1 and measurement.text == item.text then found = true; break end
    end
    check(found, 'rendered text was measured with the same native-font string: ' .. item.text)
  end
  check(card.b.y > card.a.y and cursorY >= card.b.y, 'background and item reservation contain all text')
  if w == 360 then
    check(card.b.y - card.a.y < 700,
      'compact 360px mock layout stays below a generous 700px text-flow ceiling (not a CSP rendering guarantee)')
  end
  local searchable = allText:gsub('%s+', '')
  local function hasText(source) return searchable:find(source:gsub('%s+', ''), 1, true) ~= nil end
  check(hasText(localization.text('Choose where AI cars try to position themselves in each situation.')), 'instruction is visible')
  check(hasText(localization.text('Configured targets, not live car positions.')), 'configured targets are distinguished from live positions')
  check(hasText(localization.text('The maneuver depends on traffic and safety conditions.')), 'safety qualification is visible')
  for _, row in ipairs({ 'Default', 'Yielding', 'Overtaking' }) do check(hasText(localization.text(row)), 'row label visible: ' .. row) end
  check(not allText:find('racing line', 1, true), 'zero is not described as racing line')
  for _, r in ipairs(rects) do
    check(r.a.x >= card.a.x and r.b.x <= card.b.x and r.a.y >= card.a.y and r.b.y <= card.b.y,
      'filled and outlined geometry remains within panel')
  end
  for _, line in ipairs(lines) do
    local half = (line.thickness or 1) * 0.5
    check(math.min(line.a.x, line.b.x) - half >= card.a.x and math.max(line.a.x, line.b.x) + half <= card.b.x and
      math.min(line.a.y, line.b.y) - half >= card.a.y and math.max(line.a.y, line.b.y) + half <= card.b.y,
      'line including stroke thickness remains within panel')
  end
  if w >= 300 then check(#lines >= 4, 'one shared rail and marker details are drawn')
  else check(#lines == 0, 'very narrow panel uses the text-only fallback') end
  check(#buttons == 0, 'diagram adds no interactive controls')
  check(#measurements > 0, 'text layout emits native measurements')
  for _, measurement in ipairs(measurements) do check(measurement.native == true, 'all active layout measurements use native metrics') end
  if w >= 300 then
    local rails, markers = {}, {}
    for _, line in ipairs(lines) do
      if line.b.x > line.a.x and math.abs(line.b.y - line.a.y) < 0.001 and line.thickness == 2 then rails[#rails + 1] = line end
    end
    for _, r in ipairs(rects) do
      if r.b.x - r.a.x == 10 and r.b.y - r.a.y == 10 then markers[#markers + 1] = r end
    end
    check(#rails == 1 and #markers == 3, 'one horizontal 2px rail and three filled/outlined square marker bounds exist')
    local expected = { storage.defaultLateralOffset, storage.yieldingLateralOffset, storage.overtakingLateralOffset }
    for i = 1, 3 do
      local expectedX = rails[1].a.x + (expected[i] + 1) * 0.5 * (rails[1].b.x - rails[1].a.x)
      check(math.abs(markers[i].a.x + 5 - expectedX) < 0.01, 'marker maps to configured target ' .. i)
      check(markers[i].color ~= nil, 'marker carries its semantic color ' .. i)
      check(markers[i].a.y >= rails[1].a.y - 17 and markers[i].b.y <= rails[1].a.y + 17,
        'marker fits within reserved 40px graph height ' .. i)
    end
    if offsets[1] == -1 and offsets[2] == 0 and offsets[3] == 1 then
      check(math.abs(markers[1].a.x + 5 - rails[1].a.x) < .01 and math.abs(markers[3].a.x + 5 - rails[1].b.x) < .01,
        'real axis endpoints represent configured -1 and +1 targets')
    end
    if offsets[1] == .020 and offsets[2] == .021 and offsets[3] == .022 then
      check(markers[1].a.x < markers[2].a.x and markers[2].a.x < markers[3].a.x and
        markers[3].a.x - markers[1].a.x < (rails[1].b.x - rails[1].a.x) * .01,
        'near-equal .020/.021/.022 targets retain their ordered, closely spaced positions')
    end
    check(math.abs(markers[1].a.y - markers[2].a.y) >= 10 and math.abs(markers[2].a.y - markers[3].a.y) >= 10,
      'vertical marker lanes have at least 10px separation')
    local legendPositions = {}
    for _, item in ipairs(textItems) do
      if item.text:find(' · ', 1, true) and item.text:match('%d%.%d%d%d') then
        legendPositions[#legendPositions + 1] = item
      end
      if w >= 300 then
        local size = ui.measureText(item.text, -1)
        for _, marker in ipairs(markers) do
          check(item.x + size.x <= marker.a.x or item.x >= marker.b.x or
            item.y + size.y <= marker.a.y or item.y >= marker.b.y,
            'native text bounds do not intersect marker geometry: ' .. item.text)
        end
        for _, line in ipairs(lines) do
          local half = (line.thickness or 1) * .5
          check(item.x + size.x <= math.min(line.a.x, line.b.x) - half or
            item.x >= math.max(line.a.x, line.b.x) + half or
            item.y + size.y <= math.min(line.a.y, line.b.y) - half or
            item.y >= math.max(line.a.y, line.b.y) + half,
            'native text bounds do not intersect stroked line geometry: ' .. item.text)
        end
      end
    end
    check(#legendPositions == 3, 'three row legends are present')
    for _, marker in ipairs(markers) do check(marker.b.y < legendPositions[1].y, 'marker bounds do not intersect legend text') end
    check(markers[1].rounding == 0, 'default square marker uses zero rounding')
    local legendSquare = false
    for _, r in ipairs(rects) do
      if r.color == markers[1].color and r.b.x - r.a.x == 6 and r.b.y - r.a.y == 6 and r.rounding == 0 then legendSquare = true end
    end
    check(legendSquare, 'default legend repeats the graphic square form')
    check(markers[2].color ~= markers[1].color and markers[3].color ~= markers[1].color and markers[2].color ~= markers[3].color,
      'marker colors distinguish semantic rows')
    local function diagonal(color)
      for _, line in ipairs(lines) do
        if line.color == color and line.a.x ~= line.b.x and line.a.y ~= line.b.y then return true end
      end
      return false
    end
    check(diagonal(markers[2].color), 'yielding diamond has diagonal strokes independently of its color')
    check(diagonal(markers[3].color), 'overtaking X has diagonal strokes independently of its color')
    for legendIndex = 2, 3 do
      local strokes = 0
      for _, line in ipairs(lines) do
        if line.color == markers[legendIndex].color and line.a.x ~= line.b.x and line.a.y ~= line.b.y and
          math.min(line.a.y, line.b.y) >= legendPositions[legendIndex].y and
          math.max(line.a.y, line.b.y) <= legendPositions[legendIndex].y + 20 then strokes = strokes + 1 end
      end
      check(strokes >= (legendIndex == 2 and 4 or 2),
        legendIndex == 2 and 'yielding legend repeats diamond form' or 'overtaking legend repeats X form')
    end
    if offsets[1] == offsets[2] and offsets[2] == offsets[3] then
      check(math.abs(markers[1].a.x - markers[2].a.x) < 0.01 and math.abs(markers[2].a.x - markers[3].a.x) < 0.01,
        'equal configured values share the same horizontal target')
    end
    check(storage.defaultLateralOffset == savedValues[1] and storage.yieldingLateralOffset == savedValues[2] and
      storage.overtakingLateralOffset == savedValues[3], 'drawing preserves all configured values')
    check(yieldingStorage.handleYielding == savedFlags[1] and overtakingStorage.handleOvertaking == savedFlags[2], 'drawing preserves both enabled flags')
    check((markers[2].filled == true) == yielding and (markers[3].filled == true) == overtaking,
      'enabled/disabled state is represented by filled versus outlined markers')
  end
  return card.b.y-card.a.y
end
for _, loc in ipairs({ 'en', 'pt-BR', 'es' }) do
  check(localization.setLocale(loc), 'preview uses real locale ' .. loc)
  local heightAt360
  for _, w in ipairs({ 80, 360, 480, 700, 900, 1200, 1760 }) do
    local height=drawPreview(w, true, true, { -1, 0, 1 })
    if w==360 then heightAt360=height end
    if w>360 then check(height<=heightAt360, 'wider full-width panel does not increase wrapped text/panel height ('..loc..', '..w..'px)') end
  end
  for _, sectionW in ipairs({80,360,480,900}) do drawPreview(sectionW,true,true,{-1,0,1},false,Theme.spacing.md) end
end
drawPreview(700, false, false, { 0.25, 0.25, 0.25 })
drawPreview(700, true, true, { .020, .021, .022 })
drawPreview(700, true, true, { 0, 0, 0 })
for _, yielding in ipairs({ false, true }) do for _, overtaking in ipairs({ false, true }) do
  drawPreview(480, yielding, overtaking, { -1, 0, 1 })
end end
drawPreview(80, false, false, { -1, 0, 1 }, true)
print('lateral runtime contract checks passed (mocked CSP geometry; no rendering validation)')
