local StorageManager = StorageManager

local SettingsModel = {
    Profile = StorageManager.Profile,
    BehaviorMode = StorageManager.BehaviorMode,
    BehaviorProfiles = StorageManager.BehaviorProfiles,
    Options = StorageManager.Options,
    Options_Debugging = StorageManager.Options_Debugging,
    Options_Yielding = StorageManager.Options_Yielding,
    Options_Overtaking = StorageManager.Options_Overtaking,
    Options_AICarValues = StorageManager.Options_AICarValues,
    Options_PathFinding = StorageManager.Options_PathFinding,
    options_default = StorageManager.options_default,
    options_min = StorageManager.options_min,
    options_max = StorageManager.options_max,
    options_Debugging_default = StorageManager.options_Debugging_default,
    options_Debugging_min = StorageManager.options_Debugging_min,
    options_Debugging_max = StorageManager.options_Debugging_max,
    options_Yielding_default = StorageManager.options_Yielding_default,
    options_Yielding_min = StorageManager.options_Yielding_min,
    options_Yielding_max = StorageManager.options_Yielding_max,
    options_Overtaking_default = StorageManager.options_Overtaking_default,
    options_Overtaking_min = StorageManager.options_Overtaking_min,
    options_Overtaking_max = StorageManager.options_Overtaking_max,
    options_AICarValues_default = StorageManager.options_AICarValues_default,
    options_AICarValues_min = StorageManager.options_AICarValues_min,
    options_AICarValues_max = StorageManager.options_AICarValues_max,
    options_PathFinding_default = StorageManager.options_PathFinding_default,
    options_PathFinding_min = StorageManager.options_PathFinding_min,
    options_PathFinding_max = StorageManager.options_PathFinding_max,
}

function SettingsModel.getStorage()
    return StorageManager.getStorage()
end

function SettingsModel.getStorage_Yielding()
    return StorageManager.getStorage_Yielding()
end

function SettingsModel.getStorage_Overtaking()
    return StorageManager.getStorage_Overtaking()
end

function SettingsModel.getStorage_Debugging()
    return StorageManager.getStorage_Debugging()
end

function SettingsModel.getStorage_AICarValues()
    return StorageManager.getStorage_AICarValues()
end

function SettingsModel.getStorage_PathFinding()
    return StorageManager.getStorage_PathFinding()
end

function SettingsModel.getStorage_Behavior()
    return StorageManager.getStorage_Behavior()
end

function SettingsModel.getPerTrackPerModeStorageKey()
    return StorageManager.getPerTrackPerModeStorageKey()
end

function SettingsModel.inferBehaviorProfile(behavior)
    local fallback = SettingsModel.Profile.Realistic
    for index, profile in pairs(SettingsModel.BehaviorProfiles or {}) do
        if profile.mode == behavior.mode
            and profile.humanErrorEnabled == behavior.humanErrorEnabled
            and math.abs(profile.entryBlendTime_s - behavior.entryBlendTime_s) < 0.01 then
            return index
        end
    end
    return fallback
end

function SettingsModel.applyBehaviorProfile(profileIndex)
    return StorageManager.applyBehaviorProfile(profileIndex)
end

return SettingsModel
