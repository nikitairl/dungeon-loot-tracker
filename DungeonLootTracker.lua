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

if not LootData then
    LootData = {} -- на случай, если файл не подключился
end
-- ======================
-- SavedVariables Init
-- ======================
local function InitSavedVars()
    if not DLT_SavedData then
        DLT_SavedData = {}
    end
    lootList = DLT_SavedData
end

-- ======================
-- Работа со списком
-- ======================

function DLT.AddLootItem(itemID, dungeon)
    if not itemID then return end
    for _, loot in ipairs(lootList) do
        if loot.itemID == itemID then
            DebugPrint("Item already in list:", itemID)
            return
        end
    end
    table.insert(lootList, { itemID = itemID, dungeon = dungeon or "Unknown" })
    DebugPrint("Added loot item:", itemID, dungeon)
    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end

function DLT.RemoveLootItem(itemID)
    for i, loot in ipairs(lootList) do
        if loot.itemID == itemID then
            table.remove(lootList, i)
            DebugPrint("Removed loot item:", itemID)
            if lootFrame and lootFrame:IsShown() then
                UpdateLootFrame()
            end
            return
        end
    end
end

function DLT.ClearLootList()
    lootList = {}
    DLT_SavedData = {}
    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end

-- ======================
-- UI: Обновление списка
-- ======================


function UpdateLootFrame()
    if not lootFrame then return end
    if not lootFrame.buttons then lootFrame.buttons = {} end

    lootFrame.scrollChild:SetHeight(math.max(1, #lootList * 35))
    lootFrame.scrollChild:SetWidth(260)

    for i, loot in ipairs(lootList) do
        local btn = lootFrame.buttons[i]
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
            btn.text:SetWidth(200)

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

            lootFrame.buttons[i] = btn
        end

        -- Подгрузка инфо о предмете
        local function UpdateButton()
            local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
            itemEquipLoc, itemTexture, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID,
            itemSetID, isCraftingReagent, maxCount, isAuctionable = GetItemInfo(loot.itemID)

            if itemTexture then
                btn.icon:SetTexture(itemTexture)
                btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                btn.text:SetText(itemName .. " — " .. loot.dungeon)
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                btn.icon:SetTexCoord(0, 1, 0, 1)
                btn.text:SetText("Loading... — " .. loot.dungeon)
                print("|cFF33FF99DLT|r: Item info not loaded yet for item ID: " .. loot.itemID)
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

        btn:SetPoint("TOPLEFT", lootFrame.scrollChild, "TOPLEFT", 10, -((i - 1) * 35))
        btn:Show()
    end

    -- Скрываем лишние кнопки
    for i = #lootList + 1, #lootFrame.buttons do
        if lootFrame.buttons[i] then
            lootFrame.buttons[i]:Hide()
        end
    end
end

-- ======================
-- UI: Кнопка в EJ
-- ======================
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
                lootFrame = CreateFrame("Frame", "DLT_LootFrame", UIParent, "BackdropTemplate")
                lootFrame:SetSize(512, 256)
                lootFrame:SetPoint("CENTER")
                lootFrame:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true,
                    tileSize = 32,
                    edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 }
                })

                lootFrame.title = lootFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                lootFrame.title:SetPoint("TOP", lootFrame, "TOP", 0, -10)
                lootFrame.title:SetText("Desired Loot")

                lootFrame.scrollFrame = CreateFrame("ScrollFrame", nil, lootFrame, "UIPanelScrollFrameTemplate")
                lootFrame.scrollFrame:SetPoint("TOPLEFT", lootFrame, "TOPLEFT", 15, -40)
                lootFrame.scrollFrame:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", -35, 15)

                lootFrame.scrollChild = CreateFrame("Frame", nil, lootFrame.scrollFrame)
                lootFrame.scrollChild:SetSize(260, 1)
                lootFrame.scrollFrame:SetScrollChild(lootFrame.scrollChild)

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
        if not DLT_SavedData or not next(DLT_SavedData) then
            print("|cFF33FF99DLT|r: list is empty")
        else
            print("|cFF33FF99DLT|r: items in list:")
            for i, loot in ipairs(DLT_SavedData) do
                local name, link = GetItemInfo(loot.itemID)
                if link then
                    print(i .. ":", link, "-", loot.dungeon)
                else
                    print(i .. ":", loot.itemID, "-", loot.dungeon)
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
