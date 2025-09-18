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
                btn:SetSize(320, 30)
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