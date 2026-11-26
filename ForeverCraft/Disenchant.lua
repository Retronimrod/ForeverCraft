local _, addon = ...
local spellID = 13262
local queue, rows = {}, {}
local panel, tab, action, scroll, content, nextText, help
local pending, displayed, closeAfterCombat
local function spellIcon()
    return C_Spell.GetSpellTexture(spellID) or "Interface\\Icons\\INV_Enchant_Disenchant"
end
local eventFrame = CreateFrame("Frame")

local function hasSpell()
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(spellID) end
    return IsPlayerSpell and IsPlayerSpell(spellID)
end

local function readItem(bag, slot)
    local data = C_Container.GetContainerItemInfo(bag, slot)
    if not data or not data.hyperlink or not data.quality or data.quality < 2 or data.quality > 4 then return end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(data.itemID)
    if class ~= Enum.ItemClass.Weapon and class ~= Enum.ItemClass.Armor then return end
    if class == Enum.ItemClass.Weapon and subclass == 20 then return end
    if data.stackCount ~= 1 then return end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    local guid = C_Item.GetItemGUID(location)
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    return {
        guid = guid, bag = bag, slot = slot, link = data.hyperlink, texture = data.iconFileID,
        locked = data.isLocked, itemID = data.itemID,
    }
end

local function clearAction()
    if InCombatLockdown() then return end
    action:SetAttribute("type", nil)
    action:SetAttribute("target-bag", nil)
    action:SetAttribute("target-slot", nil)
end

local function update()
    if not panel or not panel:IsVisible() or InCombatLockdown() then return end
    local L = addon.GetText()
    local candidates, byGUID = {}, {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = readItem(bag, slot)
            if item then
                candidates[#candidates + 1] = item
                byGUID[item.guid] = item
            end
        end
    end
    if pending and pending.succeeded and not byGUID[pending.guid] then
        if queue[1] and queue[1].guid == pending.guid then table.remove(queue, 1) end
        pending = nil
    end

    local queued = {}
    for index, item in ipairs(queue) do queued[item.guid] = index end
    -- Queued items always keep their place and order (that is the actual disenchant
    -- order); only the remaining bag candidates are sorted/filtered by economic value,
    -- so picking what to queue next is easier without disturbing an already-built queue.
    local displayRows = {}
    for _, item in ipairs(queue) do
        local resolved = byGUID[item.guid] or item
        resolved.evaluation = addon.EvaluateItem(resolved.link)
        displayRows[#displayRows + 1] = resolved
    end
    local sortMode = ForeverCraftDB and ForeverCraftDB.disenchantSortMode or "default"
    local candidateRows = {}
    for _, item in ipairs(candidates) do
        if not queued[item.guid] then candidateRows[#candidateRows + 1] = item end
    end
    for _, item in ipairs(candidateRows) do item.evaluation = addon.EvaluateItem(item.link) end
    candidateRows = addon.SortDisenchantRows(candidateRows, sortMode)
    for _, item in ipairs(candidateRows) do displayRows[#displayRows + 1] = item end

    for index, item in ipairs(displayRows) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Button", nil, content)
            row:SetHeight(27)
            row:SetPoint("TOPLEFT", 2, -(index - 1) * 28)
            row:SetPoint("TOPRIGHT", -2, -(index - 1) * 28)
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.63, 0.44, 0.19, 0.18)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(19, 19)
            row.icon:SetPoint("LEFT", 28, 0)
            row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.checkbox:SetSize(21, 21)
            row.checkbox:SetPoint("LEFT", 0, 0)
            row.checkbox:EnableMouse(false)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.text:SetPoint("RIGHT", -5, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self)
                if InCombatLockdown() or pending then return end
                local selected = self.item
                for position, queuedItem in ipairs(queue) do
                    if selected.guid == queuedItem.guid then
                        table.remove(queue, position)
                        update()
                        return
                    end
                end
                local current = readItem(selected.bag, selected.slot)
                if current and current.guid == selected.guid and not current.locked then
                    queue[#queue + 1] = current
                end
                update()
            end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.item.link)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            rows[index] = row
        end
        row.item, row.queued = item, queued[item.guid]
        row.checkbox:SetChecked(row.queued ~= nil)
        row.icon:SetTexture(item.texture)
        row.text:SetText(item.link .. addon.FormatDisenchantRowValue(item.evaluation))
        row:SetAlpha(byGUID[item.guid] and 1 or 0.45)
        row:Show()
    end
    for index = #displayRows + 1, #rows do rows[index]:Hide() end
    content:SetHeight(math.max(1, #displayRows * 28))

    local first = queue[1]
    displayed = first and byGUID[first.guid]
    nextText:SetText(first and L.disenchantNext:format(first.link, #queue) or L.disenchantEmpty)
    help:SetText(first and not displayed and L.disenchantMoved or L.disenchantHint)
    action:SetEnabled(displayed ~= nil and not displayed.locked and not pending and hasSpell())
    action:SetText(C_Spell.GetSpellName(spellID) or L.disenchantTitle)
end

local function makePanel(root, nativeHeader)
    panel = CreateFrame("Frame", nil, root)
    panel:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -72)
    panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, 6)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(root:GetFrameLevel() + 30)
    panel:EnableMouse(true)
    panel:Hide()

    local headerArt = CreateFrame("Frame", nil, root)
    headerArt:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -21)
    headerArt:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, 6)
    headerArt:SetFrameLevel(root:GetFrameLevel() + 2)
    headerArt:SetClipsChildren(true)
    headerArt:Hide()
    local headerCanvas = CreateFrame("Frame", nil, headerArt)
    headerCanvas:SetPoint("TOPLEFT")
    headerCanvas:SetPoint("TOPRIGHT")
    headerCanvas:SetHeight(nativeHeader and nativeHeader:GetHeight() or root:GetHeight())
    local headerTexture = headerCanvas:CreateTexture(nil, "BACKGROUND")
    headerTexture:SetAtlas(nativeHeader and nativeHeader:GetAtlas() or "Profession-Background-Template2")
    headerTexture:SetAllPoints()

    local professionRank = CreateFrame("Frame", nil, headerArt, "ProfessionsRankBarTemplate")
    professionRank:SetPoint("TOPLEFT", root, "TOPLEFT", 110, -40)
    professionRank:EnableMouse(false)
    local function updateProfessionRank()
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(333)
        local show = info and info.maxSkillLevel and info.maxSkillLevel > 0
        professionRank:SetShown(show and true or false)
        if show then professionRank:Update(info) end
    end
    headerArt:RegisterEvent("SKILL_LINES_CHANGED")
    headerArt:SetScript("OnEvent", function()
        if headerArt:IsVisible() then updateProfessionRank() end
    end)

    local function createBox()
        local box = CreateFrame("Frame", nil, panel)
        local background = box:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetAtlas("Professions-Recipe-Background", false)

        local border = box:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetAtlas("common-insideframe", false)
        return box
    end
    local left = createBox()
    left:SetPoint("TOPLEFT", 7, -3)
    left:SetPoint("BOTTOMLEFT", 7, 5)
    local right = createBox()
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", -4, 5)
    local watermark = right:CreateTexture(nil, "BACKGROUND", nil, 1)
    watermark:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\DisenchantWatermark")
    watermark:SetPoint("BOTTOMRIGHT", -6, 8)
    watermark:SetVertexColor(0.74, 0.58, 0.44, 0.14)
    local function layout()
        local innerWidth = panel:GetWidth() - 22
        local leftWidth = math.max(120, math.floor(innerWidth * 0.49))
        left:SetWidth(leftWidth)
        local watermarkWidth = math.max(1, math.min(innerWidth - leftWidth - 12, panel:GetHeight() - 32))
        watermark:SetSize(watermarkWidth, watermarkWidth * 0.5)
    end
    panel:SetScript("OnSizeChanged", layout)
    layout()

    local function createSectionHeading(box)
        local heading
        if _G.ProfessionsRecipeListCategoryMixin then
            heading = CreateFrame("Button", nil, box, "ProfessionsRecipeListCategoryTemplate")
            heading:EnableMouse(false)
            heading.RankBar:Hide()
            heading:GetCollapseButton():Hide()
        else
            heading = CreateFrame("Frame", nil, box)
            local label = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", 5, 0)
            function heading:SetHeaderText(value)
                label:SetText(value)
            end
        end
        heading:SetPoint("TOPLEFT", 10, -8)
        heading:SetPoint("TOPRIGHT", -10, -8)
        heading:SetHeight(25)
        return heading
    end
    local bagTitle = createSectionHeading(left)
    local queueTitle = createSectionHeading(right)

    nextText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nextText:SetPoint("TOPLEFT", queueTitle, "BOTTOMLEFT", 5, -10)
    nextText:SetPoint("RIGHT", right, "RIGHT", -15, 0)
    nextText:SetJustifyH("LEFT")
    nextText:SetWordWrap(true)
    help = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", nextText, "BOTTOMLEFT", 0, -10)
    help:SetPoint("RIGHT", right, "RIGHT", -15, 0)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)

    local sortButton = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    sortButton:SetSize(216, 20)
    sortButton:SetPoint("TOPLEFT", bagTitle, "BOTTOMLEFT", 2, -3)
    sortButton:SetScript("OnClick", function()
        local order = addon.disenchantSortOrder
        local index = 1
        for current, mode in ipairs(order) do
            if mode == (ForeverCraftDB.disenchantSortMode or order[1]) then index = current end
        end
        ForeverCraftDB.disenchantSortMode = order[index % #order + 1]
        panel.refreshText()
    end)
    sortButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hint = addon.GetText().settingsEconomySortHint or addon.strings.enUS.settingsEconomySortHint
        GameTooltip:AddLine(hint, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sortButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.sortButton = sortButton

    scroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 13, -67)
    scroll:SetPoint("BOTTOMRIGHT", -25, 12)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    addon.HideUnusedScrollbar(scroll)
    scroll:HookScript("OnSizeChanged", function(self) content:SetWidth(math.max(1, self:GetWidth())) end)

    action = CreateFrame("Button", "ForeverCraftDisenchantAction", panel,
        "UIPanelButtonTemplate,SecureActionButtonTemplate,SecureHandlerStateTemplate")
    action:SetSize(155, 24)
    action:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -14, 14)
    action:RegisterForClicks("LeftButtonUp")
    action:SetAttribute("useOnKeyDown", false)
    action:SetAttribute("spell", spellID)
    action:SetAttribute("_onstate-combat", 'self:SetAttribute("type", nil)')
    RegisterStateDriver(action, "combat", "[combat] blocked; ready")
    action:SetScript("PreClick", function(_, mouseButton, down)
        if InCombatLockdown() then return end
        clearAction()
        if down or mouseButton ~= "LeftButton"
            or not panel:IsVisible() or not displayed or pending or not hasSpell()
            or UnitCastingInfo("player") or SpellIsTargeting() or (LootFrame and LootFrame:IsShown()) then return end
        local current = readItem(displayed.bag, displayed.slot)
        if not current or current.guid ~= displayed.guid or current.locked then
            update()
            return
        end
        pending = { guid = current.guid, itemID = current.itemID }
        action:SetAttribute("target-bag", current.bag)
        action:SetAttribute("target-slot", current.slot)
        action:SetAttribute("type", "spell")

        local attempt = pending
        C_Timer.After(10, function()
            if pending ~= attempt then return end
            update()
            if pending == attempt then
                pending = nil
                update()
            end
        end)
    end)
    action:SetScript("PostClick", clearAction)
    local title = root.TitleContainer and root.TitleContainer.TitleText
    local pageTitle
    if title then
        pageTitle = root.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pageTitle:SetAllPoints(title)
        pageTitle:SetJustifyH("CENTER")
        pageTitle:SetWordWrap(false)
        pageTitle:Hide()
    end
    panel.refreshText = function()
        local L = addon.GetText()
        bagTitle:SetHeaderText(L.disenchantBag)
        queueTitle:SetHeaderText(L.disenchantQueue)
        if pageTitle then pageTitle:SetText(addon.HeaderTitle(L.disenchantTitle)) end
        local sortMode = ForeverCraftDB and ForeverCraftDB.disenchantSortMode or "default"
        local labelKey = addon.disenchantSortLabelKeys[sortMode] or addon.disenchantSortLabelKeys.default
        sortButton:SetText(L[labelKey] or addon.strings.enUS[labelKey])
        update()
    end
    local titleAlpha, nativePortrait, activePortrait, previousTab
    local pageAlphas = {}
    panel:SetScript("OnShow", function()
        headerArt:Show()
        updateProfessionRank()
        for _, page in ipairs(root.Pages or {}) do
            pageAlphas[page] = page:GetAlpha()
            page:SetAlpha(0)
        end
        addon.QueueProfessionLayout()
        if pageTitle then
            titleAlpha = title:GetAlpha()
            title:SetAlpha(0)
            pageTitle:Show()
        end
        local portrait = root.PortraitContainer and root.PortraitContainer.portrait
        if portrait then
            nativePortrait = portrait:GetTexture()
            root:SetPortraitToAsset(spellIcon())
            activePortrait = portrait:GetTexture()
        end
        for _, nativeTab in ipairs({ root.ProfessionsOverviewTab, unpack(root.rightProfessionTabs) }) do
            if nativeTab:GetID() == root.selectedGamepadTabID then
                previousTab = nativeTab
                nativeTab:SetChecked(false)
                break
            end
        end
        tab.SelectedTexture:Show()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        panel.refreshText()
    end)
    panel:HookScript("OnHide", function()
        headerArt:Hide()
        for page, alpha in pairs(pageAlphas) do
            page:SetAlpha(alpha)
        end
        wipe(pageAlphas)
        addon.QueueProfessionLayout()
        clearAction()
        tab.SelectedTexture:Hide()
        if pageTitle then
            pageTitle:Hide()
            if titleAlpha ~= nil then title:SetAlpha(titleAlpha) end
            titleAlpha = nil
        end
        local portrait = root.PortraitContainer and root.PortraitContainer.portrait
        if portrait and nativePortrait and portrait:GetTexture() == activePortrait then
            root:SetPortraitToAsset(nativePortrait)
        end
        nativePortrait, activePortrait = nil, nil
        if previousTab and previousTab:GetID() == root.selectedGamepadTabID then previousTab:SetChecked(true) end
        previousTab = nil
    end)
end

function addon.RefreshDisenchantText()
    _G["BINDING_NAME_CLICK ForeverCraftDisenchantAction:LeftButton"] = addon.GetText().disenchantTitle
    if panel and panel:IsVisible() then panel.refreshText() end
end

function addon.CloseDisenchant()
    if not panel or not panel:IsShown() then return end
    if InCombatLockdown() then closeAfterCombat = true; return end
    panel:Hide()
end

function addon.AnchorProfessionSideTab(sideTab, previous)
    local point, relative, relativePoint, x, y = sideTab:GetPoint(1)
    if point == "TOPLEFT" and relative == previous and relativePoint == "BOTTOMLEFT" and x == 0 and y == -2 then return end
    sideTab:ClearAllPoints()
    sideTab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
end

function addon.PositionDisenchantTab(root)
    local last = root.ProfessionsOverviewTab
    local showTab = tab and (not ForeverCraftDB or ForeverCraftDB.showDisenchant ~= false) and hasSpell()
    if tab then tab:SetShown(showTab and true or false) end
    local inserted
    for _, professionTab in ipairs(root.rightProfessionTabs) do
        if professionTab:IsShown() then
            addon.AnchorProfessionSideTab(professionTab, last)
            last = professionTab
            if showTab and professionTab.skillLine == 333 then
                addon.AnchorProfessionSideTab(tab, last)
                last = tab
                inserted = true
            end
        end
    end
    if showTab and not inserted then
        addon.AnchorProfessionSideTab(tab, last)
        last = tab
    end
    return last
end

function addon.AttachDisenchant(root, closeShopping, nativeHeader)
    if tab then return end
    tab = CreateFrame("Frame", nil, root, "LargeSideTabButtonTemplate")
    tab.fillToInterior = true
    tab:SetFrameStrata("DIALOG")
    tab.Icon:SetTexture(spellIcon())
    tab.SelectedTexture:Hide()
    local click = CreateFrame("Button", nil, tab)
    click:SetAllPoints()
    click:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(addon.GetText().disenchantTitle)
        GameTooltip:Show()
    end)
    click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    click:SetScript("OnClick", function()
        if InCombatLockdown() or not hasSpell() then return end
        if panel and panel:IsShown() then panel:Hide(); return end
        closeShopping()
        if addon.CloseProfessionGuide then addon.CloseProfessionGuide() end
        if not panel then makePanel(root, nativeHeader) end
        panel:Show()
    end)
    root:HookScript("OnShow", function()
        addon.CloseDisenchant()
    end)
end

BINDING_HEADER_FOREVERCRAFT = "ForeverCraft"
_G["BINDING_NAME_CLICK ForeverCraftDisenchantAction:LeftButton"] = addon.GetText().disenchantTitle

-- Records the actual materials gained from a successful disenchant into the local
-- statistics log (Economy.lua), so the tooltip's disenchant estimate can fall back to
-- real observed results when no other data source (e.g. Auctionator) is installed.
local function recordLootResult()
    if not pending or not pending.succeeded or pending.recorded or not pending.itemID then return end
    if ForeverCraftDB and ForeverCraftDB.economyLogDisenchant == false then return end
    pending.recorded = true
    local lootItems = {}
    for slot = 1, GetNumLootItems() do
        local _, _, quantity = GetLootSlotInfo(slot)
        local link = GetLootSlotLink(slot)
        local lootItemID = link and C_Item.GetItemInfoInstant(link)
        if lootItemID and quantity and quantity > 0 then
            lootItems[lootItemID] = (lootItems[lootItemID] or 0) + quantity
        end
    end
    addon.RecordDisenchantResult(pending.itemID, lootItems)
end

eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:SetScript("OnEvent", function(_, event, _, _, castSpell)
    if closeAfterCombat and event == "PLAYER_REGEN_ENABLED" then
        closeAfterCombat = nil
        addon.CloseDisenchant()
    end
    _G["BINDING_NAME_CLICK ForeverCraftDisenchantAction:LeftButton"] = addon.GetText().disenchantTitle
    if pending and castSpell and not (issecretvalue and issecretvalue(castSpell)) and castSpell == spellID then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then pending.succeeded = true
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then pending = nil end
    end
    if event == "LOOT_OPENED" then recordLootResult() end
    update()
end)
