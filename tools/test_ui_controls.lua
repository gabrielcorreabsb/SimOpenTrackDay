-- Focused headless geometry, status drawing and payload contracts for shared UI primitives.
package.path = './?.lua;./?/init.lua;' .. package.path
_G.rgbm = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
local Theme = require('lib/uilib/Theme')
local Controls = require('lib/uilib/UIControls')
local checks = 0
local function check(ok, message)
  checks = checks + 1
  if not ok then error('FAIL: ' .. message, 2) end
end

local payload = assert(io.open('tools/payload.manifest', 'rb'), 'runtime payload manifest is readable')
local payloadSource = payload:read('*a'):gsub('\r\n', '\n')
payload:close()
check(payloadSource:find('\nlib/uilib/UIControls.lua\n', 1, true) ~= nil,
  'shared UIControls module is explicitly listed in the runtime payload manifest')

for _, available in ipairs({ 80, 480, 700, 900, 1200, 1760 }) do
  for _, measured in ipairs({ 24, 90, 280, 600, 1900 }) do
    local width = Controls.chipWidth(measured, available)
    check(width >= 0 and width <= available,
      string.format('chip width is bounded (available %d, measured %d)', available, measured))
  end
  local width, compact = Controls.comboWidth(available, 100, Theme.layout.navigationComboMaxWidth)
  check(width >= 0 and width <= available,
    string.format('responsive combo width is bounded at %d', available))
  check(compact == (available < Theme.layout.responsiveLabelThreshold),
    string.format('responsive label mode is deterministic at %d', available))
end

local calls, cursor = {}, { x = 12, y = 30 }
local statusUI = {
  getCursor = function() return cursor end,
  setCursor = function(value) cursor = value end,
  drawRectFilled = function(p1, p2, color, rounding)
    calls[#calls + 1] = { kind = 'dot', p1 = p1, p2 = p2, color = color, rounding = rounding }
  end,
  textWrapped = function(text) calls[#calls + 1] = { kind = 'wrapped', text = text } end,
  textColored = function(text, color) calls[#calls + 1] = { kind = 'colored', text = text, color = color } end,
}
local statusColor = { id = 'success' }
Controls.drawStatus('Operational', statusColor, { text = function(source) return 'localized:' .. source end }, statusUI,
  function(x, y) return { x = x, y = y } end)
check(calls[1].kind == 'dot' and calls[1].color == statusColor and calls[1].p1.x == 12 and calls[1].p1.y == 35,
  'status indicator positions and colors its dot from shared tokens')
check(cursor.x == 30 and cursor.y == 30 and calls[2].kind == 'wrapped' and calls[2].text == 'localized:Operational',
  'status indicator offsets text and localizes the status label')
statusUI.textWrapped = nil
Controls.drawStatus('Disabled', statusColor, { text = function(source) return 'localized:' .. source end }, statusUI,
  function(x, y) return { x = x, y = y } end)
check(calls[4].kind == 'colored' and calls[4].text == 'localized:Disabled' and calls[4].color == statusColor,
  'status indicator fallback preserves localized text and state color')

print(string.format('UI controls geometry tests passed: %d checks.', checks))
