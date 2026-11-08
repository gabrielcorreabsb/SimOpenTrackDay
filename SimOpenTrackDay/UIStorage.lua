local UIStorage = {}

local schema = {
    uiLanguage = '',
}

local storage

function UIStorage.get()
    if storage == nil then
        storage = ac.storage(schema, 'ui')
    end
    return storage
end

return UIStorage
