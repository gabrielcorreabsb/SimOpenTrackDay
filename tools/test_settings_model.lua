-- Narrow headless contract checks for SettingsModel and transient UIState.
-- This does not establish CSP runtime behavior.

local scriptPath = debug.getinfo(1, 'S').source:sub(2)
local toolsDir = scriptPath:match('^(.*)[/\\]') or 'tools'
local root = toolsDir:match('^(.*)[/\\]tools$') or '.'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

local Profile = { Casual = 1, Realistic = 2, Competitive = 3 }
local BehaviorMode = { TrackDay = 1, Race = 2 }
local profileDefinitions = {
  [Profile.Casual] = { mode = BehaviorMode.TrackDay, humanErrorEnabled = false, entryBlendTime_s = 0.5 },
  [Profile.Realistic] = { mode = BehaviorMode.TrackDay, humanErrorEnabled = false, entryBlendTime_s = 1.5 },
  [Profile.Competitive] = { mode = BehaviorMode.Race, humanErrorEnabled = true, entryBlendTime_s = 0.8 },
}
local handles = {
  {}, {}, {}, {}, {}, {}, {},
}
local getters = {
  getStorage = handles[1], getStorage_Yielding = handles[2],
  getStorage_Overtaking = handles[3], getStorage_Debugging = handles[4],
  getStorage_AICarValues = handles[5], getStorage_PathFinding = handles[6],
  getStorage_Behavior = handles[7],
}
local getterCalls, applyCalls = {}, {}
local defaults, minimums, maximums = {}, {}, {}
local enums = { Options = {}, Options_Debugging = {}, Options_Yielding = {}, Options_Overtaking = {}, Options_AICarValues = {}, Options_PathFinding = {} }
local StorageManager = {
  Profile = Profile, BehaviorMode = BehaviorMode, BehaviorProfiles = profileDefinitions,
  options_default = defaults, options_min = minimums, options_max = maximums,
  options_Debugging_default = defaults, options_Debugging_min = minimums, options_Debugging_max = maximums,
  options_Yielding_default = defaults, options_Yielding_min = minimums, options_Yielding_max = maximums,
  options_Overtaking_default = defaults, options_Overtaking_min = minimums, options_Overtaking_max = maximums,
  options_AICarValues_default = defaults, options_AICarValues_min = minimums, options_AICarValues_max = maximums,
  options_PathFinding_default = defaults, options_PathFinding_min = minimums, options_PathFinding_max = maximums,
  Options = enums.Options, Options_Debugging = enums.Options_Debugging, Options_Yielding = enums.Options_Yielding,
  Options_Overtaking = enums.Options_Overtaking, Options_AICarValues = enums.Options_AICarValues,
  Options_PathFinding = enums.Options_PathFinding,
  getPerTrackPerModeStorageKey = function() return 'track_mode' end,
  applyBehaviorProfile = function(index)
    applyCalls[#applyCalls + 1] = index
    return index == Profile.Casual
  end,
}
for name, handle in pairs(getters) do
  StorageManager[name] = function()
    getterCalls[name] = (getterCalls[name] or 0) + 1
    return handle
  end
end
_G.StorageManager = StorageManager

local checks = 0
local function check(condition, message)
  checks = checks + 1
  if not condition then error('FAIL: ' .. message, 2) end
end

local SettingsModel = require('SettingsModel')
for name, handle in pairs(getters) do
  check(SettingsModel[name]() == handle, name .. ' preserves original storage handle identity')
  check(getterCalls[name] == 1, name .. ' delegates once')
end
check(SettingsModel.Profile == Profile and SettingsModel.BehaviorMode == BehaviorMode and
  SettingsModel.BehaviorProfiles == profileDefinitions, 'enum/profile tables are original references')
check(SettingsModel.options_default == defaults and SettingsModel.options_min == minimums and
  SettingsModel.options_max == maximums, 'option tables are original references')
check(SettingsModel.getPerTrackPerModeStorageKey() == 'track_mode', 'storage key query delegates')

local writes = 0
local strictBehavior = setmetatable({}, {
  __index = function(_, key)
    if key == 'profile' then error('undeclared behavior.profile read') end
    if key == 'mode' then return BehaviorMode.TrackDay end
    if key == 'humanErrorEnabled' then return false end
    if key == 'entryBlendTime_s' then return 0.5 end
    error('unexpected behavior field read: ' .. tostring(key))
  end,
  __newindex = function(_, key) writes = writes + 1; error('query wrote behavior field: ' .. tostring(key)) end,
})
check(SettingsModel.inferBehaviorProfile(strictBehavior) == Profile.Casual,
  'profile inference matches the existing partial comparison')
check(writes == 0, 'profile inference is read-only')
check(SettingsModel.inferBehaviorProfile({ mode = 999, humanErrorEnabled = false, entryBlendTime_s = 4 }) == Profile.Realistic,
  'unmatched values fall back to Realistic')
check(SettingsModel.inferBehaviorProfile({ mode = 1, humanErrorEnabled = false, entryBlendTime_s = 0.5,
  pointBySpeedDeltaKmh = 123 }) == Profile.Casual,
  'uncompared custom slider can still coincide; inference is not universal')
check(#applyCalls == 0, 'profile query never applies or writes a profile')
check(SettingsModel.applyBehaviorProfile(Profile.Casual) == true and #applyCalls == 1 and
  applyCalls[1] == Profile.Casual, 'apply action delegates exactly once with the selected current profile index')

local storageCalls, acStorageCalls = 0, 0
_G.StorageManager = setmetatable({}, { __index = function() storageCalls = storageCalls + 1; error('unexpected StorageManager access') end })
_G.ac = { storage = function() acStorageCalls = acStorageCalls + 1; error('unexpected ac.storage access') end }
package.loaded['UIState'] = nil
local UIState = require('UIState')
check(UIState.advancedBehaviorOpen == false, 'advanced section starts collapsed')
UIState.advancedBehaviorOpen = true
check(UIState.advancedBehaviorOpen == true, 'advanced section state is mutable in-memory state')
check(storageCalls == 0 and acStorageCalls == 0, 'UIState does not access StorageManager or ac.storage')
check(UIState.advancedBehaviorOpen == true, 'expansion state is not persisted or reset by storage')

print(string.format('SettingsModel/UIState tests passed: %d checks.', checks))
