--[[
    Sonaran CAD Plugins

    Plugin Name: sonrad
    Creator: Sonoran Software Systems
    Description: Sonoran Radio integration plugin

    Put all server-side logic in this file.
]]

CreateThread(function() Config.LoadPlugin("sonrad", function(pluginConfig)

    if pluginConfig.enabled then

        local CallCache = {}
        local UnitCache = {}

        CreateThread(function()
            while true do
                Wait(5000)
                CallCache = GetCallCache()
                UnitCache = GetUnitCache()
                for k, v in pairs(CallCache) do
                    v.dispatch.units = {}
                    if v.dispatch.idents then
                        for ka, va in pairs(v.dispatch.idents) do
                            local unit
                            local unitId = GetUnitById(va)
                            table.insert(v.dispatch.units, UnitCache[unitId])
                        end
                    end
                end
            end
        end)

        RegisterNetEvent("SonoranCAD::sonrad:GetCurrentCall")
        AddEventHandler("SonoranCAD::sonrad:GetCurrentCall", function()
            local playerid = source
            local unit = GetUnitByPlayerId(source)
            print("unit: " .. json.encode(unit))
            for k, v in pairs(CallCache) do
                if v.dispatch.idents then
                    print(json.encode(v))
                    for ka, va in pairs(v.dispatch.idents) do
                        print("Comparing " .. unit.id .. " to " .. va)
                        if unit.id == va then
                            TriggerClientEvent("SonoranCAD::sonrad:UpdateCurrentCall", source, v)
                            print("SonoranCAD::sonrad:UpdateCurrentCall " .. source .. " " .. json.encode(v))
                        end
                    end
                end
            end
        end)

        -- Call UUID generation
        local random = math.random
        local function uuid()
            math.randomseed(os.time())
            local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
            return string.gsub(template, '[xy]', function (c)
                local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
                return string.format('%x', v)
            end)
        end

        RegisterNetEvent("SonoranCAD::sonrad:RadioPanic")
        AddEventHandler("SonoranCAD::sonrad:RadioPanic", function()
            sendRadioPanic(source)
        end)

        RegisterNetEvent("SonoranCAD::sonrad:GetUnitInfo")
        AddEventHandler("SonoranCAD::sonrad:GetUnitInfo", function()
            local unit = GetUnitByPlayerId(source)
            TriggerClientEvent("SonoranCAD::sonrad:GetUnitInfo:Return", source, unit)
        end)

        function sendRadioPanic(source)
            -- Determine identifier
            local source = tostring(source)
            local identifier = GetIdentifiers(source)[Config.primaryIdentifier]

            -- Process panic POST request
            if pluginConfig.addPanicCall then
                -- Process Unit
                local unit = GetUnitByPlayerId(source)
                if not unit then
                    debugLog("Caller is not a unit, ignoring. id: " .. source .. " unit: " .. json.encode(unit))
                    return
                end
                -- Process Postal
                local postal = ""
                if isPluginLoaded("postals") and PostalsCache[source] ~= nil then
                    postal = PostalsCache[source]
                else
                    debugLog("postal is nil?!")
                end
                local data = {
                    ['serverId'] = Config.serverId,
                    ['isEmergency'] = true,
                    ['caller'] = unit.data.name,
                    ['location'] = unit.location,
                    ['description'] = ("Unit %s has pressed their panic button"):format(unit.data.unitNum),
                    ['metaData'] = {
                        ['callerPlayerId'] = source,
                        ['callerApiId'] = GetIdentifiers(source)[Config.primaryIdentifier],
                        ['uuid'] = uuid(),
                        ['silentAlert'] = false,
                        ['useCallLocation'] = false,
                        ['callPostal'] = postal
                    }
                }
                if LocationCache[source] ~= nil then
                    data['metaData']['callLocationx'] = LocationCache[source].position.x
                    data['metaData']['callLocationy'] = LocationCache[source].position.y
                    data['metaData']['callLocationz'] = LocationCache[source].position.z
                else
                    debugLog("Warning: location cache was nil, not sending position")
                end
                debugLog(("perform panic request %s"):format(json.encode(data)))
                performApiRequest({data}, 'CALL_911', function(resp) debugLog(resp) end)
            end
            performApiRequest({{['isPanic'] = true, ['apiId'] = identifier}}, 'UNIT_PANIC', function() end)
        end
    end

end) end)