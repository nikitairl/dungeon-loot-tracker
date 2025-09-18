-- ======================
-- Slash-команды
-- ======================

SLASH_DLT1 = "/dlt"

SlashCmdList["DLT"] = function(msg)
    -- Функция для парсинга itemID
    local function ParseItemID(input)
        if not input or input == "" then return nil end
        local linkID = input:match("item:(%d+)")
        return linkID and tonumber(linkID) or tonumber(input)
    end

    -- Функция для проверки, есть ли предмет в списке
    local function IsItemInList(itemID)
        if not lootList then return false end
        for _, loot in ipairs(lootList) do
            if loot.itemID == itemID then
                return true
            end
        end
        return false
    end

    -- Функция для получения названия подземелья
    local function GetZoneName(itemID)
        local mapID = LootData[itemID]
        local zoneName = "Unknown Zone"

        if mapID then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo and mapInfo.name then
                zoneName = mapInfo.name
            end
        end
        return zoneName
    end

    -- Разбираем ввод
    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end

    local cmd = words[1] and words[1]:lower() or ""
    local rest = ""
    if #words > 1 then
        rest = table.concat(words, " ", 2)
    end

    if cmd == "add" then
        if rest == "" then
            print("|cFF33FF99DLT|r: usage: /dlt add <itemLink or itemID>")
            return
        end

        local itemID = ParseItemID(rest)
        if not itemID then
            print("|cFF33FF99DLT|r: please provide a valid itemLink or numeric itemID")
            return
        end

        local zoneName = GetZoneName(itemID)
        DLT.AddLootItem(itemID, zoneName)

    elseif cmd == "remove" or cmd == "rm" then
        if rest == "" then
            print("|cFF33FF99DLT|r: usage: /dlt remove <itemLink or itemID>")
            return
        end

        local itemID = ParseItemID(rest)
        if itemID then
            DLT.RemoveLootItem(itemID)
        else
            print("|cFF33FF99DLT|r: please provide itemLink or numeric itemID")
        end

    elseif cmd == "list" then
        local playerKey = UnitName("player") .. "-" .. GetRealmName()
        local list = DLT_SavedData[playerKey]
        
        if not list or #list == 0 then
            print("|cFF33FF99DLT|r: list is empty for character " .. playerKey)
        else
            print("|cFF33FF99DLT|r: items in list for |cFFFFFF00" .. playerKey .. "|r:")
            for i, loot in ipairs(list) do
                local name, link = GetItemInfo(loot.itemID)
                if link then
                    print(i .. ". " .. link .. " — " .. loot.dungeon)
                else
                    print(i .. ". " .. loot.itemID .. " — " .. loot.dungeon)
                end
            end
        end

    elseif cmd == "clear" then
        DLT.ClearLootList()
        print("|cFF33FF99DLT|r: list cleared")

    elseif cmd == "info" or cmd == "help" then
        print("|cFF33FF99Dungeon Loot Tracker|r - Help")
        print(" ")
        print("|cFFFFD700Available Commands:|r")
        print("  |cFF33FF99/dlt <item>|r          - Toggle command (add/remove)")
        print("  |cFF33FF99/dlt add <item>|r      - Also adds item to list")
        print("  |cFF33FF99/dlt remove <item>|r   - Removes item from list too")
        print("  |cFF33FF99/dlt list|r            - Show your loot list")
        print("  |cFF33FF99/dlt clear|r           - Clear entire list")
        print("  |cFF33FF99/dlt info|r            - Show this help")
        print(" ")
        print("|cFFFFD700Usage Examples:|r")
        print("  |cFF33FF99/dlt 12345|r           - Toggle item by ID")
        print("  |cFF33FF99/dlt item:12345|r      - Toggle item by link")
        print("  |cFF33FF99/dlt add 12345|r       - Add item")
        print(" ")
        print("|cFFFFD700How to Use:|r")
        print("• Use the 'Add Item' button in UI to add items by id")
        print("• Items are saved per character")
        print("• /dlt <item> command automatically adds or removes items")
        print("• made by |cFF33FF99Чиловар-Howling Fjord|r")

    else
        -- Toggle режим - либо команда не распознана, либо это предмет
        local itemInput = msg
        if itemInput == "" then
            print("|cFF33FF99DLT|r: usage: /dlt <itemLink or itemID> - toggle item")
            print("|cFF33FF99DLT|r: use /dlt info for help")
            return
        end

        local itemID = ParseItemID(itemInput)
        if not itemID then
            print("|cFF33FF99DLT|r: please provide a valid itemLink or numeric itemID")
            print("|cFF33FF99DLT|r: use /dlt info for help")
            return
        end

        if IsItemInList(itemID) then
            -- Удаляем, если уже есть
            DLT.RemoveLootItem(itemID)
            print("|cFF33FF99DLT|r: removed item " .. itemID)
        else
            -- Добавляем, если нет
            local zoneName = GetZoneName(itemID)
            DLT.AddLootItem(itemID, zoneName)
            print("|cFF33FF99DLT|r: added item " .. itemID .. " (" .. zoneName .. ")")
        end
    end
end