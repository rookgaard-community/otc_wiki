local api = "https://wiki.rookgaard.pl/api/"
local config = {
    api = {
        motd = function () return api .. 'bonus/monster' end,
        monster = function (name) return api .. 'monster/' .. name .. '/fixera' end,
        available = function () return api .. 'available' end
    }
}

local database = {
    items = {},
    npcs = {},
    monsters = {},
    monsterOfTheDay = nil
}

-- Zmienne globalne
local window = nil
local wikiButton = nil

local itemDataTab = nil
local npcDataTab = nil
local mobDataTab = nil
local dataPanel = nil

function init()
    window = g_ui.displayUI('wiki')
    window:setVisible(false)
    wikiButton = modules.client_topmenu.addRightGameToggleButton('wikiButton', tr('Wiki'), '/images/topbuttons/wiki', toggleWindow, false, 8)
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
end

function onGameEnd()
    if wikiButton then
        wikiButton:hide()
    end
    if window then
        window:hide()
    end
end

function onGameStart()
    if wikiButton then
        wikiButton:setOn(false)
        wikiButton:show()
    end

    setupTabs()
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if window then
        window:destroy()
        window = nil
    end

    if wikiButton then
        wikiButton:destroy()
        wikiButton = nil
    end

    database = {}
end

function toggleWindow()
    if not g_game.isOnline() or not wikiButton or not window then
        return
    end

    if wikiButton:isOn() then
        window:setVisible(false)
        wikiButton:setOn(false)
    else
        window:setVisible(true)
        wikiButton:setOn(true)
        -- motd()
        -- local item = Item.create(2148)
        local entry = g_ui.createWidget('WikiItemBox', window.dataPanel)
        entry.item:setItemId(2148)
    end
end

-- Ustawienie zakładek
function setupTabs()
    itemDataTab = window:getChildById('itemData')
    npcDataTab = window:getChildById('npcData')
    mobDataTab = window:getChildById('mobData')
    dataPanel = window:getChildById('dataPanel')

    itemDataTab.onClick = function() onWikiTabChange(itemDataTab) end
    npcDataTab.onClick = function() onWikiTabChange(npcDataTab) end
    mobDataTab.onClick = function() onWikiTabChange(mobDataTab) end
end

function clearContent()
    dataPanel:destroyChildren()
end

function onWikiTabChange(selectedTab)
    itemDataTab:setOn(selectedTab == itemDataTab)
    npcDataTab:setOn(selectedTab == npcDataTab)
    mobDataTab:setOn(selectedTab == mobDataTab)
    clearContent()

    if selectedTab == itemDataTab then
        displayItemData(itemData)
    elseif selectedTab == npcDataTab then
        displayNpcData(npcData)
    elseif selectedTab == mobDataTab then
        displayMobData(mobData)
    end
end

function motd()
    if not window then
        return
    end

    if database.monsterOfTheDay then
        return
    end

    local function parseMonsterData(response)
        if not response then
            return
        end

        database.monsterOfTheDay = json.decode(response)
        window.motdPanel.motdCreature:setOutfit(database.monsterOfTheDay.look)
    end

    local function parseMonsterName(response)
        if not response then
            return
        end
        
        database.monsterOfTheDay = {
            name = response:gsub('"', "")
        }
        window.motdPanel.motdName:setText(database.monsterOfTheDay.name)
        HTTP.get(config.api.monster(database.monsterOfTheDay.name), parseMonsterData)
    end

    HTTP.get(config.api.motd(), parseMonsterName)
end

function fetchWikiData()
    local apiData = "https://wiki.rookgaard.pl/api/available"
    
    HTTP.get(apiData, function(response, error)
        if error then
            g_logger.warning("Blad podczas pobierania danych wiki: " .. error)
            return
        end
        
        if not response or response == "" then
            g_logger.warning("Pusta odpowiedz z API")
            return
        end

        local data, pos, err = json.decode(response, 1, nil)
        if err then
            g_logger.warning("Blad w parsowaniu odpowiedzi JSON: " .. err)
            return
        end
        
        processWikiData(data)
    end)
end

function processWikiData(data)
    local items = data.ITEMS or {}
    local npcs = data.NPCS or {}
    local monsters = data.MONSTERS or {}

    print("Liczba itemow: " .. #items[1])
    for _, item in ipairs(items[1]) do
        print(string.format("Item: %s (ID: %d)", item.name or "Unnamed", item.id or 0))
    end

    print("Liczba NPC: " .. #npcs[1])
    for _, npc in ipairs(npcs[1]) do
        local look = npc.look or {}
        print(string.format("NPC: %s (ID: %d) - Feet: %s, Body: %s, Legs: %s, Head: %s",
            npc.name or "Unnamed",
            look.type or 0,
            look.feet or "N/A",
            look.body or "N/A",
            look.legs or "N/A",
            look.head or "N/A"))
    end

    print("Liczba potworow: " .. #monsters[1])
    for _, monster in ipairs(monsters[1]) do
        local look = monster.look or {}
        print(string.format("Monster: %s (ID: %d)", monster.name or "Unnamed", look.type or 0))
    end
end

function addWikiEntry(data)
    local entry

    if data["type"] == "Item" then
        entry = g_ui.createWidget('WikiItemBox', wiki.entries)  
        entry.item:setItemId(tonumber(data["id"]))
        g_logger.info("Dodano przedmiot: " .. data["title"])
        
    elseif data["type"] == "NPC" then
        entry = g_ui.createWidget('WikiItemBox', wiki.entries)
        entry.creature:setOutfit(data["id"])
        g_logger.info("Dodano NPC: " .. data["title"])
        
    elseif data["type"] == "MONSTERS" then
        entry = g_ui.createWidget('WikiItemBox', wiki.entries)
        entry.creature:setOutfit(data["id"])
        g_logger.info("Dodano potwora: " .. data["title"])
        
    else
        g_logger.error("Nieprawidłowy typ wpisu wiki: " .. tostring(data["type"]))
        return
    end

    entry:setId("entry_" .. wiki.entries:getChildCount())
    entry.title:setText(data["title"])
    entry.description:setText(data["description"] or "")
    entry.entryId = data["id"]

    wiki.entries:addChild(entry)
end

function displayItemData(data)
    if not data or not data.id then return end
    
    local itemLabel = g_ui.createWidget('WikiItemBox', wiki.entries)
    if not itemLabel then return end
    
    pcall(function()
        if itemLabel.item then
            itemLabel.item:setItemId(tonumber(data.id))
        end
        
        if itemLabel.title then
            itemLabel.title:setText(string.format("Item: %s (ID: %d)", 
                tostring(data.title or "Unknown"), tonumber(data.id)))
        end
        
        if itemLabel.description then
            itemLabel.description:setText(tostring(data.description or ""))
        end
    end)
end

function displayNpcData(data)
    if not data or not data.id then return end
    
    local npcLabel = g_ui.createWidget('WikiItemBox', wiki.entries)
    if not npcLabel then return end
    
    pcall(function()
        if npcLabel.creature then
            npcLabel.creature:setOutfit(tonumber(data.id))
        end
        
        local outfitDetails = {}
        if data.outfit then
            for part, value in pairs(data.outfit) do
                table.insert(outfitDetails , string.format("%s: %d", tostring(part), tonumber(value)))
            end
        end
        
        local outfitString = table.concat(outfitDetails, ", ")
        
        if npcLabel.title then
            npcLabel.title:setText(string.format("%s (ID: %d) - %s", 
                tostring(data.title or "Unknown"), 
                tonumber(data.id), 
                outfitString))
        end
        
        if npcLabel.description then
            npcLabel.description:setText(tostring(data.description or ""))
        end
    end)
end

function displayMobData(data)
    if not data or not data.id then return end
    
    local mobLabel = g_ui.createWidget('WikiItemBox', wiki.entries)
    if not mobLabel then return end
    
    pcall(function()
        if mobLabel.creature then
            mobLabel.creature:setOutfit(tonumber(data.id))
        end
        
        if mobLabel.title then
            mobLabel.title:setText(string.format("%s (ID: %d)", 
                tostring(data.title or "Unknown"), 
                tonumber(data.id)))
        end
        
        if mobLabel.description then
            mobLabel.description:setText(tostring(data.description or ""))
        end
    end)
end

-- Funkcja do parsowania wpisów
local function parseLogEntry(entry)
    local itemPattern = "Item: (%w+) %((ID: (%d+))%)"
    local npcPattern = "NPC: (%w+) %((ID: (%d+))%) - Feet: (%d+), Body: (%d+), Legs: (%d+), Head: (%d+)"
    local monsterPattern = "Monster: (%w+ %w+) %((ID: (%d+))%)"

    local itemName, itemId = entry:match(itemPattern)
    if itemName and itemId then
        return {
            type = "Item",
            id = tonumber(itemId),
            title = itemName
        }
    end

    local npcName, npcId, feet, body, legs, head = entry:match(npcPattern)
    if npcName and npcId then
        return {
            type = "NPC",
            id = tonumber(npcId),
            title = npcName,
            outfit = {
                Feet = tonumber(feet),
                Body = tonumber(body),
                Legs = tonumber(legs),
                Head = tonumber(head)
            }
        }
    end

    local monsterName, monsterId = entry:match(monsterPattern)
    if monsterName and monsterId then
        return {
            type = "MONSTERS",
            id = tonumber(monsterId),
            title = monsterName
        }
    end

    return nil
end