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
            print("|cFF33FF99DLT|r: item " .. itemID .. " is already in the list!")
            return
        end
    end

    table.insert(lootList, { itemID = itemID, dungeon = dungeon })
    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end


-- Popup для добавления предмета
StaticPopupDialogs["DLT_ADD_ITEM"] = {
    text = "Enter Item ID:\n|cFFFFD700Note: Use /dlt <itemlink> for item links|r",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local text = self.EditBox:GetText()
        if text and text ~= "" then
            local linkID = text:match("item:(%d+)")
            local itemID = linkID and tonumber(linkID) or tonumber(text)
            
            if itemID then
                local mapID = LootData[itemID]
                local zoneName = "Unknown Zone"

                if mapID then
                    local mapInfo = C_Map.GetMapInfo(mapID)
                    if mapInfo and mapInfo.name then
                        zoneName = mapInfo.name
                    end
                end

                DLT.AddLootItem(itemID, zoneName)
                UpdateLootFrame()
            else
                print("|cFF33FF99DLT|r: Invalid item ID or link")
            end
        end
    end,
    OnShow = function(self)
        self.EditBox:SetFocus()
        self.EditBox:SetText("")
    end,
    OnHide = function(self)
        self.EditBox:SetText("")
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["DLT_ADD_ITEM"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Удаление предмета
function DLT.RemoveLootItem(itemID)
    local found = false
    for i, loot in ipairs(lootList) do
        if loot.itemID == itemID then
            table.remove(lootList, i)
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
        print("|cFF33FF99DLT|r: item " .. itemID .. " is not in the list.")
    end
end



-- Показ списка
function DLT.ListLoot()
    if not lootList or #lootList == 0 then
        print("|cFF33FF99DLT|r: list is empty.")
        return
    end

    print("|cFF33FF99DLT|r: items in list for |cFFFFFF00" .. UnitName("player") .. "|r:")

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
        print("|cFF33FF99DLT|r: list cleared for " .. key)
    end

    if lootFrame and lootFrame:IsShown() then
        UpdateLootFrame()
    end
end

function UpdateLootFrame()
    if not lootFrame then return end
    if not lootFrame.buttons then lootFrame.buttons = {} end

    -- Очищаем все существующие элементы
    if lootFrame.scrollChild then
        for k, v in pairs(lootFrame.scrollChild) do
            if type(v) == "table" and v.Hide then
                v:Hide()
            end
        end
    end

    -- Сортируем предметы по dungeon/zone
    local groupedLoot = {}
    for _, loot in ipairs(lootList) do
        local dungeon = loot.dungeon or "Unknown"
        if not groupedLoot[dungeon] then
            groupedLoot[dungeon] = {}
        end
        table.insert(groupedLoot[dungeon], loot)
    end

    -- Если нет предметов, выходим
    if not next(groupedLoot) then
        lootFrame.scrollChild:SetHeight(1)
        lootFrame.scrollChild:SetWidth(260)
        return
    end

    -- Начальная позиция
    local yOffset = 0
    local groupSpacing = 24 -- отступ между группами
    local itemSpacing = 42  -- отступ между предметами

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
        title:SetPoint("TOP", lootFrame.scrollChild, "TOP", 16, -yOffset)
        title:Show()
        yOffset = yOffset + 28 -- высота заголовка
        
        -- Создаем кнопки предметов в группе
        for _, loot in ipairs(items) do
            local btn = lootFrame.scrollChild[loot.itemID]
            -- Цвет фона за предметом
            local btnBackgroundColor = {0.9, 0.85, 0.7, 0.3}
            if not btn then
                btn = CreateFrame("Button", nil, lootFrame.scrollChild)
                btn:SetSize(320, 36)  -- Увеличил высоту
                btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                
                -- Фон кнопки
                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
                btn.bg:SetVertexColor(unpack(btnBackgroundColor))
                btn.bg:SetAllPoints()
                
                -- Граница кнопки
                btn.border = btn:CreateTexture(nil, "BORDER")
                btn.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
                btn.border:SetSize(32, 32)
                btn.border:SetPoint("LEFT", 4, 0)
                btn.border:SetVertexColor(0.8, 0.8, 0.8, 0.8)
                
                btn.icon = btn:CreateTexture(nil, "ARTWORK")
                btn.icon:SetSize(30, 30)
                btn.icon:SetPoint("LEFT", 5, 0)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 10, 0)  -- Увеличил отступ
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWidth(200)  -- Увеличил ширину
                btn.text:SetFontObject("GameFontNormal")  -- Явно указываем шрифт

                -- 🔹 Добавляем крестик справа (улучшенный)
                btn.remove = CreateFrame("Button", nil, btn)
                btn.remove:SetSize(24, 24)
                btn.remove:SetPoint("RIGHT", -40, 0)
                btn.remove:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
                btn.remove:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
                btn.remove:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
                btn.remove:SetScript("OnClick", function()
                    DLT.RemoveLootItem(loot.itemID)
                    print("|cFF33FF99DLT|r: removed item " .. loot.itemID)
                    UpdateLootFrame()
                end)
                
                -- Анимация при наведении на крестик
                btn.remove:SetScript("OnEnter", function(self)
                    self:SetAlpha(1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Remove Item")
                    GameTooltip:Show()
                end)
                btn.remove:SetScript("OnLeave", function(self)
                    self:SetAlpha(0.7)
                    GameTooltip:Hide()
                end)
                btn.remove:SetAlpha(0.7)

                -- Анимация при наведении на кнопку
                btn:SetScript("OnEnter", function(self)
                    self.icon:SetVertexColor(1, 1, 0)
                    self.bg:SetVertexColor(0.25, 0.25, 0.25, 0.9)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(loot.itemID)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.icon:SetVertexColor(1, 1, 1)
                    self.bg:SetVertexColor(unpack(btnBackgroundColor))
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

            btn:SetPoint("TOPLEFT", lootFrame.scrollChild, "TOPLEFT", 0, -yOffset)
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
        GameTooltip:SetText("/dlt")
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
                lootFrame:SetSize(364, 496)

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
                lootFrame.overlay = lootFrame:CreateTexture(nil, "OVERLAY")
                lootFrame.overlay:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                lootFrame.overlay:SetVertexColor(0, 0, 0, 0.75) -- черный с 40% прозрачностью
                lootFrame.overlay:SetPoint("TOPLEFT", lootFrame, "TOPLEFT", 11, -12)  -- отступы как в insets
                lootFrame.overlay:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", -12, 11)
                ---lootFrame:SetBackdropColor(0, 0, 0, 0.6)

                -- Создаем фрейм для заголовка с фоном
                lootFrame.titleFrame = CreateFrame("Frame", nil, lootFrame)
                lootFrame.titleFrame:SetSize(340, 42)
                lootFrame.titleFrame:SetPoint("TOP", lootFrame, "TOP", 0, -12)

                -- Фон заголовка
                lootFrame.titleFrame.bg = lootFrame.titleFrame:CreateTexture(nil, "BACKGROUND")
                lootFrame.titleFrame.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                lootFrame.titleFrame.bg:SetVertexColor(0, 0, 0, 0.7)
                lootFrame.titleFrame.bg:SetAllPoints()
                -- Рамка снизу (линия)
                -- Рамка снизу (линия) - без тайлинга
                lootFrame.titleFrame.bottomBorder = lootFrame.titleFrame:CreateTexture(nil, "BORDER")
                lootFrame.titleFrame.bottomBorder:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                lootFrame.titleFrame.bottomBorder:SetVertexColor(0.8, 0.8, 0.8, 0.4)
                lootFrame.titleFrame.bottomBorder:SetHeight(2)
                lootFrame.titleFrame.bottomBorder:SetPoint("BOTTOMLEFT", lootFrame.titleFrame, "BOTTOMLEFT", 0, 0)
                lootFrame.titleFrame.bottomBorder:SetPoint("BOTTOMRIGHT", lootFrame.titleFrame, "BOTTOMRIGHT", 0, 0)
                lootFrame.titleFrame.bottomBorder:SetTexCoord(0, 1, 0, 1)  -- Отключаем тайлинг

                -- Текст заголовка
                lootFrame.title = lootFrame.titleFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
                lootFrame.title:SetPoint("CENTER")
                lootFrame.title:SetText("Good luck")

                -- ScrollFrame
                lootFrame.scrollFrame = CreateFrame("ScrollFrame", nil, lootFrame, "UIPanelScrollFrameTemplate")
                lootFrame.scrollFrame:SetPoint("TOP", lootFrame, "TOP", 0, -64)
                lootFrame.scrollFrame:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", -35, 15)

                lootFrame.scrollChild = CreateFrame("Frame", nil, lootFrame.scrollFrame)
                lootFrame.scrollChild:SetSize(360, 1) -- ширина для группировки
                lootFrame.scrollFrame:SetScrollChild(lootFrame.scrollChild)

                -- Кнопка закрытия
                local closeButton = CreateFrame("Button", nil, lootFrame, "UIPanelCloseButton")
                closeButton:SetPoint("TOPRIGHT", lootFrame, "TOPRIGHT", -5, -5)
                closeButton:SetScript("OnClick", function() lootFrame:Hide() end)

                -- Кнопка добавления
                lootFrame.addButton = CreateFrame("Button", nil, lootFrame, "UIPanelButtonTemplate")
                lootFrame.addButton:SetSize(120, 25)
                lootFrame.addButton:SetPoint("BOTTOM", lootFrame, "BOTTOM", 0, 10)
                lootFrame.addButton:SetText("Add Item")
                lootFrame.addButton:SetScript("OnClick", function()

    -- Открываем диалог ввода предмета
    StaticPopup_Show("DLT_ADD_ITEM")
end)
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
