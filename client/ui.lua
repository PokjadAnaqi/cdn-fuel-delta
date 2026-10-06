-- CDN-Fuel UI provider bridge.
-- Config.useDTfuel = false -> normal ox_lib UI.
-- Config.useDTfuel = true  -> DT_fuelsystem NUI, with automatic ox_lib fallback.

CDNUI = CDNUI or {}

local contexts = {}

local function dtReady()
    return Config.useDTfuel == true and GetResourceState('DT_fuelsystem') == 'started'
end

function CDNUI.menuEnabled()
    return Config.useDTfuel == true or Config.Ox.Menu == true
end

function CDNUI.inputEnabled()
    return Config.useDTfuel == true or Config.Ox.Input == true
end

local function cleanText(value)
    if value == nil then return '' end
    value = tostring(value)
    value = value:gsub('<br%s*/?>', '\n')
    value = value:gsub('<.->', '')
    return value
end

local function sanitizeMetadata(metadata)
    if type(metadata) ~= 'table' then return nil end

    local output = {}
    for key, value in pairs(metadata) do
        if type(value) == 'table' then
            local label = value.label or value[1] or tostring(key)
            local data = value.value or value[2] or ''
            output[#output + 1] = { label = cleanText(label), value = cleanText(data) }
        else
            output[#output + 1] = { label = cleanText(key), value = cleanText(value) }
        end
    end

    return output
end

local function normalizeRows(rows)
    local output = {}

    for i = 1, #(rows or {}) do
        local row = rows[i]
        if type(row) == 'string' then
            output[#output + 1] = {
                index = i,
                type = 'number',
                label = cleanText(row),
                placeholder = '',
                default = '',
                required = true,
                disabled = false,
            }
        elseif type(row) == 'table' then
            local rowType = row.type or 'input'
            if rowType == 'text' then rowType = 'input' end
            output[#output + 1] = {
                index = i,
                type = rowType,
                label = cleanText(row.label or ('Field ' .. i)),
                description = cleanText(row.description or ''),
                placeholder = cleanText(row.placeholder or ''),
                default = row.default,
                min = row.min,
                max = row.max,
                step = row.step or (rowType == 'slider' and 1 or nil),
                required = row.required ~= false,
                disabled = row.disabled == true,
            }
        end
    end

    return output
end

function CDNUI.registerContext(context)
    if type(context) ~= 'table' or not context.id then return end
    contexts[context.id] = context

    -- Always register the original context too. This makes ox_lib an immediate
    -- fallback if DT_fuelsystem is stopped/restarted while players are online.
    if Config.Ox.Menu then
        lib.registerContext(context)
    end
end

local function runOption(option)
    if not option or option.disabled then return end
    if type(option.onSelect) == 'function' then
        option.onSelect(option.args)
    elseif option.event then
        TriggerEvent(option.event, option.args)
    elseif option.serverEvent then
        TriggerServerEvent(option.serverEvent, option.args)
    end
end

function CDNUI.showContext(id)
    local context = contexts[id]

    if not dtReady() then
        if Config.Ox.Menu then
            lib.showContext(id)
        end
        return
    end

    if not context then
        print(('[cdn-fuel] DT UI context not found: %s'):format(tostring(id)))
        return
    end

    local payload = {
        id = id,
        title = cleanText(context.title or 'Fuel Terminal'),
        options = {}
    }

    for i = 1, #(context.options or {}) do
        local option = context.options[i]
        payload.options[#payload.options + 1] = {
            index = i,
            title = cleanText(option.title or option.label or ('Option ' .. i)),
            description = cleanText(option.description or option.txt or ''),
            icon = option.icon or 'fa-solid fa-chevron-right',
            disabled = option.disabled == true,
            arrow = option.arrow == true,
            metadata = sanitizeMetadata(option.metadata),
        }
    end

    CreateThread(function()
        local ok, selected = pcall(function()
            return exports['DT_fuelsystem']:ShowFuelMenu(payload)
        end)

        if not ok then
            print(('[cdn-fuel] DT_fuelsystem menu bridge failed: %s'):format(tostring(selected)))
            if Config.Ox.Menu then lib.showContext(id) end
            return
        end

        local index = tonumber(selected)
        if not index then return end
        runOption(context.options and context.options[index])
    end)
end

function CDNUI.hideContext()
    if dtReady() then
        pcall(function() exports['DT_fuelsystem']:HideFuelUI() end)
    elseif Config.Ox.Menu then
        lib.hideContext()
    end
end

function CDNUI.inputDialog(title, rows, options)
    if dtReady() then
        local ok, result = pcall(function()
            return exports['DT_fuelsystem']:ShowFuelInput({
                title = cleanText(title or 'Fuel Terminal'),
                fields = normalizeRows(rows),
                allowCancel = not (options and options.allowCancel == false),
            })
        end)

        if ok then return result end
        print(('[cdn-fuel] DT_fuelsystem input bridge failed: %s'):format(tostring(result)))
    end

    if Config.Ox.Input then
        return lib.inputDialog(title, rows, options)
    end

    return nil
end
