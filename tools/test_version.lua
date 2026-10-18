-- Checks current package metadata against the runtime constants and manifest.
-- Run from the repository root: luajit tools/test_version.lua
package.path = './?.lua;./?/init.lua;' .. package.path

local checks = 0
local function check(ok, message)
  checks = checks + 1
  if not ok then error('FAIL: ' .. message, 2) end
end

_G.ac = { getSim = function() return { isOnlineRace = false } end }
_G.vec2 = function(x, y) return { x = x, y = y } end
package.loaded.Constants = nil
local constants = require('Constants')

local manifestFile = assert(io.open('manifest.ini', 'rb'))
local manifestSource = manifestFile:read('*a')
manifestFile:close()
local about = manifestSource:match('%[ABOUT%](.-)%[') or manifestSource:match('%[ABOUT%](.*)')
check(about ~= nil, 'manifest contains an ABOUT section')
local aboutValues = {}
if about then
  for key, value in about:gmatch('([%w_]+)%s*=%s*([^\r\n]+)') do
    aboutValues[key] = value:gsub('%s+$', '')
  end
end

check(constants.APP_NAME == 'SimOpenTrackDay' and constants.APP_VERSION == '0.1' and
  constants.APP_AUTHOR == 'dreasgrech',
  'runtime Constants expose current app name, 0.1 version, and author')
check(aboutValues.NAME == constants.APP_NAME and aboutValues.VERSION == constants.APP_VERSION and
  aboutValues.AUTHOR == constants.APP_AUTHOR,
  'manifest ABOUT metadata matches runtime Constants exactly')

local licenseFile = assert(io.open('LICENSE', 'rb'))
local licenseSource = licenseFile:read('*a')
licenseFile:close()
check(licenseSource:find('MIT License', 1, true) ~= nil and
  licenseSource:find('Copyright (c) 2025 Andreas Grech', 1, true) ~= nil,
  'existing MIT license and copyright notice remain present')

print(string.format('Version metadata checks passed: %d checks.', checks))
