local Localization = {}

Localization.locales = { 'en', 'pt-BR', 'es' }
Localization.localeNames = { 'English', 'Português (Brasil)', 'Español' }

local localeIndex = { en = 1, ['pt-BR'] = 2, es = 3 }
local catalogs = {}
for _, locale in ipairs(Localization.locales) do
    catalogs[locale] = require('lib/i18n/' .. locale)
end

local function getGlobalStorage()
    local manager = rawget(_G, 'StorageManager') or require('StorageManager')
    return manager.getStorage_Global()
end

local function validLocale(locale)
    return localeIndex[locale] ~= nil
end

local storage = getGlobalStorage()
local locale = storage.uiLanguage
if not validLocale(locale) then locale = 'en' end

function Localization.getLocale()
    return locale
end

function Localization.setLocale(newLocale)
    if not validLocale(newLocale) then return false end
    locale = newLocale
    storage.uiLanguage = newLocale
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
