-- Focused test of the real entry-point bootstrap against colliding module names.
local function check(value, message)
  if not value then error('FAIL: ' .. message, 2) end
end

local function write(path, contents)
  local file = assert(io.open(path, 'w'))
  file:write(contents)
  file:close()
end

local localAppData = assert(os.getenv('LOCALAPPDATA'), 'LOCALAPPDATA is required for the focused test sandbox')
local sandbox = localAppData .. '/Temp/opencode'
local root = sandbox .. '/module-path-' .. tostring(os.time()) .. '-' .. tostring(math.random(100000, 999999))
local app = root .. '/renamed app with spaces'
local external = root .. '/external'
assert(os.execute('mkdir "' .. root .. '"'))
assert(os.execute('mkdir "' .. app .. '"'))
assert(os.execute('mkdir "' .. app .. '/nested"'))
assert(os.execute('mkdir "' .. external .. '"'))
assert(os.execute('mkdir "' .. external .. '/nested"'))
write(app .. '/Constants.lua', "return { origin = 'app' }")
write(external .. '/Constants.lua', "return { origin = 'external' }")
write(app .. '/nested/init.lua', "return { origin = 'app-init' }")
write(external .. '/nested/init.lua', "return { origin = 'external-init' }")

local entry = assert(loadfile('SimOpenTrackDay.lua'))
local originalPath, originalLoaded, originalNested = package.path, package.loaded.Constants, package.loaded.nested
local originalRequire = require
local sentinel = {}

local function runBootstrap(dirname, preload)
  local suffix = 'legacy/?.lua;' .. originalPath
  package.path = external .. '/?.lua;' .. external .. '/?/init.lua;' .. suffix
  package.loaded.Constants = preload
  local env = setmetatable({
    __dirname = dirname,
    require = function(name)
      if name == 'Constants' then return originalRequire(name) end
      error(sentinel, 0)
    end,
  }, { __index = _G })
  setfenv(entry, env)
  local ok, err = pcall(entry)
  check(not ok and err == sentinel, 'entry continued past bootstrap interception')
  return env, suffix
end

local ok, err = pcall(function()
  local env, suffix = runBootstrap(app)
  check(env.Constants.origin == 'app', 'app Constants did not beat external module')
  local prefix = app .. '/?.lua;' .. app .. '/?/init.lua;'
  check(package.path:sub(1, #prefix) == prefix, 'app patterns not prefixed')
  check(package.path:sub(-#suffix) == suffix, 'original package.path suffix was not preserved exactly')
  check(originalRequire('nested').origin == 'app-init', 'app ?/init.lua pattern not used')

  env, suffix = runBootstrap(app .. '/')
  check(env.Constants.origin == 'app', 'trailing-separator dirname did not resolve app module')
  local slashPrefix = app .. '/?.lua;' .. app .. '/?/init.lua;'
  check(package.path:sub(1, #slashPrefix) == slashPrefix, 'trailing separator produced malformed app patterns')
  check(package.path:sub(-#suffix) == suffix, 'trailing-separator scenario changed original path suffix')

  local cached = { origin = 'already-cached' }
  env = runBootstrap(app, cached)
  check(env.Constants == cached and package.loaded.Constants == cached, 'bootstrap replaced a cached module')

  -- ipairs cannot represent nil, so test the absent value separately.
  local invalidDirectories = { '', false, '///' }
  local function assertInvalid(dirname, label)
    local before = external .. '/?.lua;' .. external .. '/?/init.lua;legacy/?.lua;' .. originalPath
    package.path = before
    local env = setmetatable({ __dirname = dirname, require = originalRequire }, { __index = _G })
    setfenv(entry, env)
    local failed, failure = pcall(entry)
    check(not failed and tostring(failure):find('__dirname', 1, true), label .. ' dirname was not rejected explicitly')
    check(package.path == before, label .. ' dirname changed package.path before failing')
  end
  assertInvalid(nil, 'absent')
  for _, dirname in ipairs(invalidDirectories) do
    assertInvalid(dirname, dirname == '' and 'empty' or dirname == false and 'non-string' or 'separator-only')
  end
end)

package.path = originalPath
package.loaded.Constants = originalLoaded
package.loaded.nested = originalNested
setfenv(entry, _G)
os.execute('rmdir /S /Q "' .. root .. '"')
if not ok then error(err, 0) end
print('PASS: module path bootstrap precedence, patterns, preservation, and cache boundary')
