local Localization = {}

Localization.locales = { 'en', 'pt-BR', 'es' }
Localization.localeNames = { 'English', 'Português (Brasil)', 'Español' }

local localeIndex = { en = 1, ['pt-BR'] = 2, es = 3 }
local catalogs = {}
for _, locale in ipairs(Localization.locales) do
    catalogs[locale] = require('lib/i18n/' .. locale)
end

local function getStorage()
    local manager = rawget(_G, 'StorageManager') or require('StorageManager')
    local getUIStorage = manager.getStorage_UI
    local uiStorage
    if getUIStorage == nil then
        uiStorage = require('UIStorage').get()
    elseif type(getUIStorage) ~= 'function' then
        error('StorageManager.getStorage_UI must be a function', 2)
    else
        uiStorage = getUIStorage()
    end
    if uiStorage == nil then
        error('StorageManager.getStorage_UI returned no storage handle', 2)
    end
    return uiStorage, manager
end

local function validLocale(locale)
    return localeIndex[locale] ~= nil
end

local uiStorage, storageManager = getStorage()
local persistedLocale = uiStorage.uiLanguage
if type(persistedLocale) ~= 'string' then
    error('UI storage uiLanguage must be a string', 0)
end
if persistedLocale == '' then
    local globalStorage = storageManager.getStorage_Global()
    local legacyReadOk, legacyLocale = pcall(function()
        return globalStorage.uiLanguage
    end)
    if not legacyReadOk then
        local errorText = tostring(legacyLocale)
        local unknownKey = 'Unknown key: uiLanguage'
        local unknownKeyAt = errorText:find(unknownKey, 1, true)
        local followingCharacter = unknownKeyAt and errorText:sub(unknownKeyAt + #unknownKey, unknownKeyAt + #unknownKey) or ''
        if not unknownKeyAt or followingCharacter:match('[%w_]') then
            error(legacyLocale, 0)
        end
    elseif validLocale(legacyLocale) then
        persistedLocale = legacyLocale
        uiStorage.uiLanguage = legacyLocale
    end
end

local locale = persistedLocale
if not validLocale(locale) then locale = 'en' end

function Localization.getLocale()
    return locale
end

function Localization.setLocale(newLocale)
    if not validLocale(newLocale) then return false end
    uiStorage.uiLanguage = newLocale
    locale = newLocale
    return true
end

function Localization.text(sourceEnglish, ...)
    local translated = catalogs[locale][sourceEnglish] or sourceEnglish
    if select('#', ...) > 0 then return string.format(translated, ...) end
    return translated
end

function Localization.label(sourceEnglish, stableID)
    if sourceEnglish:sub(1, 2) == '##' and sourceEnglish:sub(1, 3) ~= '###' then
        return sourceEnglish
    end
    local visibleText, existingID = sourceEnglish, nil
    local marker = sourceEnglish:find('###', 1, true)
    if marker then
        visibleText, existingID = sourceEnglish:sub(1, marker - 1), sourceEnglish:sub(marker + 3)
    else
        marker = sourceEnglish:find('##', 1, true)
        if marker then
            visibleText, existingID = sourceEnglish:sub(1, marker - 1), sourceEnglish:sub(marker + 2)
        end
    end
    if visibleText == '' then return sourceEnglish end
    return Localization.text(visibleText) .. '###' .. (stableID or existingID or visibleText)
end

return Localization
