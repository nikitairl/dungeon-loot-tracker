-- DungeonLootTracker.lua
-- ## SavedVariables: DLT_SavedData

DLT = DLT or {}
DLT_SavedData = DLT_SavedData or {}
local lootFrame
local iconButton
local lootList

-- Вспомогательная отладка
local function DebugPrint(...)
    if DLT.debug then
        print("|cFF33FF99DLT|r:", ...)
    end
end

-- ======================
-- SavedVariables Init
-- ======================
local function InitSavedVars()
    if not DLT_SavedData then
        DLT_SavedData = {}
    end

    -- создаём ключ для конкретного персонажа
    local playerKey = UnitName("player") .. "-" .. GetRealmName()

    -- если данных для этого персонажа нет — инициализируем
    if not DLT_SavedData[playerKey] then
        DLT_SavedData[playerKey] = {}
    end

    -- теперь lootList = данные именно этого персонажа
    lootList = DLT_SavedData[playerKey]
end


-- ======================
-- Работа со списком
-- ======================

-- Добавление предмета
function DLT.AddLootItem(itemID, dungeon)
    for _, loot in ipairs(lootList) do
        if loot.itemID == itemID then
            print("|cFF33FF99DLT|r: предмет уже есть в списке!")
            return
        end
    end

    table.insert(lootList, { itemID = itemID, dungeon = dungeon })
    print("|cFF33FF99DLT|r: добавлен предмет " .. itemID .. " (" .. dungeon .. ")")
    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end

-- Удаление предмета
function DLT.RemoveLootItem(itemID)
    local found = false
    for i, loot in ipairs(lootList) do
        if loot.itemID == itemID then
            table.remove(lootList, i)
            print("|cFF33FF99DLT|r: удалён предмет " .. itemID)
            found = true
            break
        end
    end

    -- Удаляем кнопку из UI
    if lootFrame and lootFrame.scrollChild and lootFrame.scrollChild[itemID] then
        lootFrame.scrollChild[itemID]:Hide()
        lootFrame.scrollChild[itemID] = nil
    end

    if found then
        if lootFrame and lootFrame:IsShown() then
            UpdateLootFrame()
        end
    else
        print("|cFF33FF99DLT|r: предмет не найден в списке.")
    end
end



-- Показ списка
function DLT.ListLoot()
    if not lootList or #lootList == 0 then
        print("|cFF33FF99DLT|r: список пуст.")
        return
    end

    print("|cFF33FF99DLT|r: предметы в списке для |cFFFFFF00" .. UnitName("player") .. "|r:")

    for i, loot in ipairs(lootList) do
        local name, link = GetItemInfo(loot.itemID)
        if link then
            print(i .. ". " .. link .. " — " .. loot.dungeon)
        else
            print(i .. ". " .. loot.itemID .. " — " .. loot.dungeon)
        end
    end
end

function DLT.ClearLootList()
    -- очищаем только список текущего персонажа
    local key = UnitName("player") .. "-" .. GetRealmName()
    if DLT_SavedData and DLT_SavedData[key] then
        DLT_SavedData[key] = {}
        lootList = DLT_SavedData[key]
        print("|cFF33FF99DLT|r: список очищен для персонажа " .. key)
    end

    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end

function UpdateLootFrame()
    if not lootFrame then return end
    if not lootFrame.buttons then lootFrame.buttons = {} end


    -- Сортируем предметы по dungeon/zone
    local groupedLoot = {}
    for _, loot in ipairs(lootList) do
        local dungeon = loot.dungeon or "Unknown"
        if not groupedLoot[dungeon] then
            groupedLoot[dungeon] = {}
        end
        table.insert(groupedLoot[dungeon], loot)
    end
    -- Начальная позиция
    local yOffset = 0
    local groupSpacing = 18 -- отступ между группами
    local itemSpacing = 32  -- отступ между предметами

    lootFrame.scrollChild:SetHeight(1)
    lootFrame.scrollChild:SetWidth(260)

    for dungeonName, items in pairs(groupedLoot) do
        -- Создаем заголовок группы
        local title = lootFrame.scrollChild[dungeonName .. "_title"]
        if not title then
            title = lootFrame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            lootFrame.scrollChild[dungeonName .. "_title"] = title
        end
        title:SetText(dungeonName)
        title:SetPoint("TOPLEFT", lootFrame.scrollChild, "TOPLEFT", 10, -yOffset)
        title:Show()
        yOffset = yOffset + 28 -- высота заголовка

        -- Создаем кнопки предметов в группе
        for _, loot in ipairs(items) do
            local btn = lootFrame.scrollChild[loot.itemID]
            if not btn then
                btn = CreateFrame("Button", nil, lootFrame.scrollChild)
                btn:SetSize(260, 30)
                btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

                btn.icon = btn:CreateTexture(nil, "ARTWORK")
                btn.icon:SetSize(30, 30)
                btn.icon:SetPoint("LEFT", 5, 0)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWidth(160)

                -- 🔹 Добавляем крестик справа
                btn.remove = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
                btn.remove:SetSize(20, 20)
                btn.remove:SetPoint("RIGHT", -5, 0)
                btn.remove:SetScript("OnClick", function()
                    DLT.RemoveLootItem(loot.itemID)
                    print("|cFF33FF99DLT|r: removed item " .. loot.itemID)
                    UpdateLootFrame()
                end)

                btn:SetScript("OnEnter", function(self)
                    self.icon:SetVertexColor(1, 1, 0)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(loot.itemID)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.icon:SetVertexColor(1, 1, 1)
                    GameTooltip:Hide()
                end)

                lootFrame.scrollChild[loot.itemID] = btn
            end

            -- Подгружаем инфо о предмете
            local function UpdateButton()
                local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(loot.itemID)
                if itemTexture then
                    btn.icon:SetTexture(itemTexture)
                    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    btn.text:SetText(itemName)
                else
                    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    btn.icon:SetTexCoord(0, 1, 0, 1)
                    btn.text:SetText("Loading... — " .. dungeonName)
                end
            end
            UpdateButton()

            -- Событие подгрузки предмета
            local f = CreateFrame("Frame")
            f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            f:SetScript("OnEvent", function(self, event, id)
                if id == loot.itemID then
                    UpdateButton()
                    self:UnregisterAllEvents()
                    self:SetScript("OnEvent", nil)
                end
            end)

            btn:SetPoint("TOPLEFT", lootFrame.scrollChild, "TOPLEFT", 10, -yOffset)
            btn:Show()
            yOffset = yOffset + itemSpacing
        end

        -- Добавляем отступ между группами
        yOffset = yOffset + groupSpacing
    end

    lootFrame.scrollChild:SetHeight(yOffset)
end

local function CreateEJIcon()
    if iconButton or not EncounterJournal then return end

    -- уменьшаем searchBox, чтобы освободить место
    if EncounterJournal.searchBox then
        EncounterJournal.searchBox:SetWidth(140)
        EncounterJournal.searchBox:ClearAllPoints()
        EncounterJournal.searchBox:SetPoint("RIGHT", EncounterJournal, "TOPRIGHT", -64, -42)
    end

    -- кнопка-иконка
    iconButton = CreateFrame("Button", "DLT_EJButton", EncounterJournal)
    iconButton:SetSize(24, 24)
    iconButton:SetPoint("LEFT", EncounterJournal.searchBox, "RIGHT", 8, 0)
    iconButton:SetNormalTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    iconButton:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)

    iconButton:SetScript("OnEnter", function(self)
        self:GetNormalTexture():SetVertexColor(1, 1, 0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Desired Loot Tracker")
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function(self)
        self:GetNormalTexture():SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)

    iconButton:SetScript("OnClick", function()
        if lootFrame and lootFrame:IsShown() then
            lootFrame:Hide()
        else
            if not lootFrame then
                -- Создаем окно списка
                lootFrame = CreateFrame("Frame", "DLT_LootFrame", UIParent, "BackdropTemplate")
                lootFrame:SetSize(400, 496)

                -- Расположение справа от EJ
                if EncounterJournal:IsShown() then
                    lootFrame:SetPoint("TOPLEFT", EncounterJournal, "TOPRIGHT", 48, 0)
                else
                    lootFrame:SetPoint("CENTER") -- Если EJ закрыт, центр
                end

                lootFrame:SetBackdrop({
                    bgFile = "Interface\\AddOns\\DungeonLootTracker\\textures\\bg3",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true,    -- включаем плитку
                    tileSize = 640, -- увеличиваем размер плитки, чтобы фон был больше
                    edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 }
                })
                lootFrame:SetBackdropColor(0, 0, 0, 0.6)


                -- Заголовок
                lootFrame.title = lootFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                lootFrame.title:SetPoint("TOP", lootFrame, "TOP", 0, -18)
                lootFrame.title:SetText("Good luck, Champion")

                -- ScrollFrame
                lootFrame.scrollFrame = CreateFrame("ScrollFrame", nil, lootFrame, "UIPanelScrollFrameTemplate")
                lootFrame.scrollFrame:SetPoint("TOPLEFT", lootFrame, "TOPLEFT", 15, -48)
                lootFrame.scrollFrame:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", -35, 15)

                lootFrame.scrollChild = CreateFrame("Frame", nil, lootFrame.scrollFrame)
                lootFrame.scrollChild:SetSize(360, 1) -- ширина для группировки
                lootFrame.scrollFrame:SetScrollChild(lootFrame.scrollChild)

                -- Кнопка закрытия
                local closeButton = CreateFrame("Button", nil, lootFrame, "UIPanelCloseButton")
                closeButton:SetPoint("TOPRIGHT", lootFrame, "TOPRIGHT", -5, -5)
                closeButton:SetScript("OnClick", function() lootFrame:Hide() end)
            end

            UpdateLootFrame()
            lootFrame:Show()
        end
    end)
end



-- ======================
-- События
-- ======================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_EncounterJournal" then
        CreateEJIcon()
    elseif event == "PLAYER_LOGIN" then
        InitSavedVars()
        C_Timer.After(2, function()
            if not iconButton and EncounterJournal then
                CreateEJIcon()
            end
        end)
    end
end)

if EncounterJournal then
    EncounterJournal:HookScript("OnHide", function()
        if lootFrame and lootFrame:IsShown() then
            lootFrame:Hide()
        end
    end)
end

-- ======================
-- Slash-команды
-- ======================

SLASH_DLT1 = "/dlt"

SlashCmdList["DLT"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "add" then
        if rest == "" then
            print("|cFF33FF99DLT|r: usage: /dlt add <itemLink or itemID>")
            return
        end

        -- Парсим линк или ID
        local linkID = rest:match("item:(%d+)")
        local itemID = linkID and tonumber(linkID) or tonumber(rest)

        if not itemID then
            print("|cFF33FF99DLT|r: please provide a valid itemLink or numeric itemID")
            return
        end

        -- Получаем MapID из LootData
        local mapID = LootData[itemID]
        local zoneName = "Unknown Zone"

        if mapID then
            -- Пробуем получить информацию о карте
            local mapInfo = C_Map.GetMapInfo(mapID)
            --- print("|cFF33FF99DLT DEBUG|r: mapInfo for itemID " .. itemID .. " = " .. tostring(mapInfo))
            if mapInfo and mapInfo.name then
                zoneName = mapInfo.name
            else
                print("|cFF33FF99DLT DEBUG|r: mapInfo not found, using Unknown Zone")
            end
        else
            print("|cFF33FF99DLT DEBUG|r: MapID for itemID " .. itemID .. " not found in LootData.lua")
        end

        -- Добавляем предмет в список
        DLT.AddLootItem(itemID, zoneName)
        --- print("|cFF33FF99DLT|r: added item " .. itemID .. " (" .. zoneName .. ")")
    elseif cmd == "remove" or cmd == "rm" then
        if rest == "" then
            print("|cFF33FF99DLT|r: usage: /dlt remove <itemLink or itemID>")
            return
        end

        local linkID = rest:match("item:(%d+)")
        local itemID = linkID and tonumber(linkID) or tonumber(rest)
        if itemID then
            DLT.RemoveLootItem(itemID)
            print("|cFF33FF99DLT|r: removed item " .. itemID)
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
    else
        print("|cFF33FF99DLT|r commands:")
        print("  /dlt add <itemLink or itemID>    - добавить предмет")
        print("  /dlt remove <itemLink or itemID> - удалить предмет")
        print("  /dlt list                        - показать список")
        print("  /dlt clear                       - очистить список")
    end
end
