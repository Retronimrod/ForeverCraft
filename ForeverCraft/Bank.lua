local _, addon = ...

-- "Bank" tab of the ForeverCraft ledger window: graphical view of the saved bank of any
-- character (or all characters combined) from addon.inventory, usable anywhere.

local ledger = {}
addon.ledger = ledger
local inventory = addon.inventory
local SLOT, GAP = 37, 4
local ALL = "*all"
local BANK_ICON = "Interface\\Icons\\INV_Box_02"
local PLAIN = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function text(key)
    local L = addon.GetText()
    return L[key] or addon.strings.enUS[key]
end

-- Same box and section heading styling as the disenchant page (Disenchant.lua).
function ledger.createBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    local background = box:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetAtlas("Professions-Recipe-Background", false)
    local border = box:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetAtlas("common-insideframe", false)
    return box
end

-- Blizzard-style dropdown (DropdownButton + WowStyle1DropdownTemplate, menu API as used by
-- other addons on this client). options() returns { {value, label}, ... }.
function ledger.dropdown(parent, width, options, isSelected, select)
    local control = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    control:SetWidth(width)
    control:SetupMenu(function(_, root)
        for _, option in ipairs(options()) do
            root:CreateRadio(option[2], function() return isSelected(option[1]) end,
                function() select(option[1]); return MenuResponse and MenuResponse.Refresh end, option[1])
        end
    end)
    function control.Sync()
        if control.GenerateMenu then control:GenerateMenu() end
    end
    return control
end

function ledger.sectionHeading(box)
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
        function heading.SetHeaderText(_, value) label:SetText(value) end
    end
    heading:SetPoint("TOPLEFT", 10, -8)
    heading:SetPoint("TOPRIGHT", -10, -8)
    heading:SetHeight(25)
    return heading
end

-- Category filters: classID/subclassID as documented for C_Item.GetItemInfoInstant
-- (Trade Goods subclasses: 5 cloth, 6 leather, 7 metal & stone, 9 herb, 12 enchanting).
local categories = {
    { "all" }, { "tradegoods", 7 }, { "cloth", 7, 5 }, { "metal", 7, 7 }, { "herb", 7, 9 },
    { "leather", 7, 6 }, { "enchanting", 7, 12 }, { "weapon", 2 }, { "armor", 4 }, { "recipe", 9 },
    { "consumable", 0 }, { "quest", 12 }, { "bound" }, { "tradeable" },
}
local qualities = { -1, 1, 2, 3, 4 }
local sorts = { "position", "name", "quality", "count", "value", "category" }


local valueCache = {}
function ledger.unitValue(link)
    if not link then return nil end
    local cached = valueCache[link]
    if cached == nil then
        local evaluation = addon.EvaluateItem(link, 1)
        local rec = evaluation and evaluation.recommendation
        cached = rec and rec.bestNet or (evaluation and evaluation.vendorGross) or false
        valueCache[link] = cached
    end
    return cached or nil
end

function ledger.resetValues()
    wipe(valueCache)
end

local function itemName(item)
    return C_Item.GetItemNameByID(item.id) or (item.link and item.link:match("%[(.-)%]")) or ""
end

local function matches(item, filter)
    if filter.query ~= "" and not itemName(item):lower():find(filter.query, 1, true) then return false end
    if filter.quality >= 0 and (item.quality or 0) < filter.quality then return false end
    local category = filter.category
    if category[1] == "all" then return true end
    if category[1] == "bound" then return item.bound == true end
    if category[1] == "tradeable" then return not item.bound end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item.id)
    return classID == category[2] and (category[3] == nil or subclassID == category[3])
end

local function sortItems(items, mode)
    local function key(item)
        if mode == "name" then return itemName(item) end
        if mode == "quality" then return -(item.quality or 0) end
        if mode == "count" then return -(item.count or 0) end
        if mode == "value" then return -((ledger.unitValue(item.link) or 0) * (item.count or 1)) end
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item.id)
        return (classID or 99) * 100 + (subclassID or 0)
    end
    table.sort(items, function(a, b)
        local ka, kb = key(a), key(b)
        if ka == kb then return itemName(a) < itemName(b) end
        return ka < kb
    end)
end

local function createSlot(parent)
    local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
    slot:SetSize(SLOT, SLOT)
    slot:SetBackdrop(PLAIN)
    -- Classic Blizzard empty bag slot behind every item.
    slot.empty = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
    slot.empty:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
    slot.empty:SetPoint("CENTER")
    slot.empty:SetSize(SLOT * 64 / 37, SLOT * 64 / 37)
    slot.empty:SetAlpha(0.85)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.count:SetPoint("BOTTOMRIGHT", -3, 3)
    slot:SetScript("OnEnter", function(self)
        if not self.item or not self.item.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.item.link)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return slot
end

local function paintSlot(slot, item, dimmed)
    slot.item = item
    slot:SetBackdropColor(0, 0, 0, 0)
    if item then
        slot.icon:SetTexture(C_Item.GetItemIconByID(item.id))
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality or 1]
        slot:SetBackdropBorderColor(color and color.r or 0.4, color and color.g or 0.4, color and color.b or 0.4, 1)
        slot.count:SetText((item.count or 1) > 1 and item.count or "")
    else
        slot.icon:SetTexture(nil)
        slot:SetBackdropBorderColor(0.25, 0.2, 0.15, 1)
        slot.count:SetText("")
    end
    slot.icon:SetDesaturated(dimmed and true or false)
    slot:SetAlpha(dimmed and 0.3 or 1)
    slot:Show()
end

local function aggregateBanks()
    local byID, list = {}, {}
    for _, character in pairs(inventory.db().characters) do
        for _, tab in pairs(character.bank and character.bank.tabs or {}) do
            for _, item in ipairs(tab.items) do
                local entry = byID[item.id]
                if not entry then
                    entry = { id = item.id, link = item.link, quality = item.quality, count = 0, bound = item.bound }
                    byID[item.id] = entry
                    list[#list + 1] = entry
                end
                entry.count = entry.count + item.count
            end
        end
    end
    return list
end

-- Bank tab icon: the stored icon, or a neutral bank box instead of a question mark.
local function tabIcon(icon)
    if icon == nil or icon == 134400 or icon == 0 or (type(icon) == "string" and icon:find("QuestionMark")) then
        return BANK_ICON
    end
    return icon
end

local function bankValueOf(key)
    local finance = addon.finance
    return finance and finance.wealth(key, ForeverCraftDB and ForeverCraftDB.financeDefaultMethod or "best").bank or 0
end

-- Same layout as the finance page: character list left, title, summary tiles, filter bar,
-- scrolling content and status bar on the right.
function ledger.buildBank(page)
    local ui = addon.ui
    local state = { selected = inventory.currentKey(), category = "all", quality = -1, sort = "position" }
    local refresh
    local sidebar = ledger.createBox(page)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(ui.SIDEBAR_WIDTH)
    local sidebarTitle = ledger.sectionHeading(sidebar)
    local characterList = ui.characterList(sidebar, {
        entries = function()
            local entries = { ALL }
            for _, key in ipairs(inventory.characterKeys()) do entries[#entries + 1] = key end
            return entries
        end,
        info = function(key)
            if key == ALL then return text("bankAllCharacters") end
            local character = inventory.db().characters[key]
            local bank = character and character.bank
            local detail = bank and ("%s  |cffaaaaaa%d/%d|r"):format(GetMoneyString(math.floor(bankValueOf(key) + 0.5)),
                bank.slots - bank.free, bank.slots) or "|cff888888–|r"
            return character and character.name or key, character and character.level, detail, character
        end,
        selected = function() return state.selected end,
        select = function(key) state.selected = key; refresh() end,
        menu = function(key)
            if key == ALL then return nil end
            return { { text("bankDeleteCharacter"), function() ledger.confirmDeleteCharacter(key) end } }
        end,
        menuHint = function() return text("characterMenuHint") end,
        allIcon = BANK_ICON,
    })
    characterList:SetPoint("TOPLEFT", 8, -38)
    characterList:SetPoint("BOTTOMRIGHT", -6, 10)

    local main = ledger.createBox(page)
    main:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    main:SetPoint("BOTTOMRIGHT", 0, 0)
    local mainTitle = ui.heading(main, "GameFontNormalLarge")
    mainTitle:SetPoint("TOPLEFT", 16, -12)
    mainTitle:SetPoint("RIGHT", main, "RIGHT", -16, 0)
    local tiles = {
        ui.tile(main, BANK_ICON, true, true), ui.tile(main, "Interface\\Icons\\INV_Misc_Bag_08", false, true),
        ui.tile(main, "Interface\\Icons\\INV_Misc_Bag_10", false, true), ui.tile(main, "Interface\\Icons\\INV_Misc_Note_01", false, true),
    }
    local tileFrame = CreateFrame("Frame", nil, main)
    tileFrame:SetPoint("TOPLEFT", 14, 0)
    tileFrame:SetSize(1, 1)
    for _, tile in ipairs(tiles) do tile:SetParent(tileFrame) end

    local search = CreateFrame("EditBox", nil, main, "SearchBoxTemplate")
    search:SetSize(170, 22)
    local function qualityLabel(quality)
        return quality < 0 and text("bankQualityAll")
            or text("bankQualityMin"):format(_G["ITEM_QUALITY" .. quality .. "_DESC"] or quality)
    end
    local categoryButton = ledger.dropdown(main, 190, function()
        local list = {}
        for _, entry in ipairs(categories) do list[#list + 1] = { entry[1], text("bankCategory_" .. entry[1]) } end
        return list
    end, function(value) return state.category == value end, function(value) state.category = value; refresh() end)
    local qualityButton = ledger.dropdown(main, 190, function()
        local list = {}
        for _, quality in ipairs(qualities) do list[#list + 1] = { quality, qualityLabel(quality) } end
        return list
    end, function(value) return state.quality == value end, function(value) state.quality = value; refresh() end)
    local sortButton = ledger.dropdown(main, 200, function()
        local list = {}
        for _, sort in ipairs(sorts) do list[#list + 1] = { sort, text("bankSort_" .. sort) } end
        return list
    end, function(value) return state.sort == value end, function(value) state.sort = value; refresh() end)
    local filterLine = ui.divider(main)

    local status = ui.statusBar(main)
    status:SetPoint("BOTTOMLEFT", 12, 8)
    status:SetPoint("BOTTOMRIGHT", -12, 8)
    local scroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("BOTTOMRIGHT", -32, 30)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    addon.HideUnusedScrollbar(scroll)
    local empty = ui.empty(scroll, BANK_ICON)
    -- Thematic illustration (Art\BankWatermark.tga) once the artwork is part of the addon.
    local watermark = ui.watermark(main, nil)
    local slots, sections = {}, {}

    local function section(index)
        local entry = sections[index]
        if not entry then
            entry = ui.panel(content)
            entry.icon = entry:CreateTexture(nil, "ARTWORK")
            entry.icon:SetSize(20, 20)
            entry.icon:SetPoint("TOPLEFT", 10, -8)
            entry.label = ui.heading(entry)
            entry.label:SetPoint("LEFT", entry.icon, "RIGHT", 6, 0)
            entry.count = ui.text(entry, "GameFontHighlightSmall", "RIGHT", ui.colors.grey)
            entry.count:SetPoint("TOPRIGHT", -12, -12)
            entry.label:SetPoint("RIGHT", entry.count, "LEFT", -8, 0)
            sections[index] = entry
        end
        entry:Show()
        return entry
    end

    -- Filter controls in one row, or two rows when the area is too narrow.
    local function layoutFilters(width, top)
        local controls = { search, categoryButton, qualityButton, sortButton }
        local x, y, rowHeight = 0, top, 28
        for i, control in ipairs(controls) do
            local w = control:GetWidth() + (i == 1 and 6 or 0)
            if x > 0 and x + w > width then x, y = 0, y + rowHeight end
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", main, "TOPLEFT", 14 + x + (i == 1 and 6 or 0), -(y + (i == 1 and 3 or 0)))
            x = x + w + 8
        end
        return y + rowHeight - top
    end

    refresh = function()
        if not page:IsVisible() then return end
        state.query = (search:GetText() or ""):lower()
        local filter = { query = state.query, quality = state.quality, category = categories[1] }
        for _, entry in ipairs(categories) do if entry[1] == state.category then filter.category = entry end end
        sidebarTitle:SetHeaderText(text("bankCharacters"))
        categoryButton.Sync()
        qualityButton.Sync()
        sortButton.Sync()
        local characters = inventory.db().characters
        if state.selected ~= ALL and not characters[state.selected] then state.selected = ALL end
        characterList.Refresh(ui.SIDEBAR_WIDTH - 14 - 24)

        -- Explicit widths from the page (re-anchored frames report stale sizes).
        local mainWidth = page:GetWidth() - ui.SIDEBAR_WIDTH - 8
        local innerWidth = mainWidth - 28
        if watermark then watermark.Fit(innerWidth, page:GetHeight()) end
        local character = state.selected ~= ALL and characters[state.selected]
        local bank = character and character.bank
        mainTitle:SetText(character and text("bankHeadingOf"):format(character.name or state.selected)
            or text("bankAllCharacters"))

        local y = 38
        local shown = state.selected == ALL and 4 or 3
        for i, tile in ipairs(tiles) do tile:SetShown(i <= shown) end
        local visibleTiles = {}
        for i = 1, shown do visibleTiles[i] = tiles[i] end
        tileFrame:SetPoint("TOPLEFT", 14, 0)
        y = y + ui.tileGrid(visibleTiles, tileFrame, y, innerWidth, 58, 140) + 10
        y = y + layoutFilters(innerWidth, y) + 4
        filterLine:ClearAllPoints()
        filterLine:SetPoint("TOPLEFT", 12, -y)
        filterLine:SetPoint("TOPRIGHT", -12, -y)
        scroll:SetPoint("TOPLEFT", 14, -(y + 6))

        for _, slot in ipairs(slots) do slot:Hide() end
        for _, entry in ipairs(sections) do entry:Hide() end
        local width = innerWidth - 18
        local used, cy, total, unvalued, itemCount = 0, 0, 0, 0, 0
        local function place(parent, item, dimmed, x, top)
            used = used + 1
            local slot = slots[used] or createSlot(content)
            slots[used] = slot
            slot:SetParent(parent)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", x, -top)
            paintSlot(slot, item, dimmed)
            if item and not dimmed then
                itemCount = itemCount + (item.count or 1)
                local value = ledger.unitValue(item.link)
                if value then total = total + value * (item.count or 1) else unvalued = unvalued + 1 end
            end
        end
        -- Grid inside a framed section; columns follow the available width.
        local function grid(parent, list, keepEmpty, gridWidth, top, left)
            local columns = math.max(1, math.floor((gridWidth + GAP) / (SLOT + GAP)))
            local count = 0
            for _, item in ipairs(list) do
                local hit = item and matches(item, filter)
                if keepEmpty or hit then
                    place(parent, item or nil, item and not hit, left + (count % columns) * (SLOT + GAP),
                        top + math.floor(count / columns) * (SLOT + GAP))
                    count = count + 1
                end
            end
            return math.ceil(count / columns) * (SLOT + GAP), count
        end

        if state.selected == ALL or state.sort ~= "position" then
            local list = {}
            if state.selected == ALL then
                list = aggregateBanks()
            elseif bank then
                for _, tab in pairs(bank.tabs) do for _, item in ipairs(tab.items) do list[#list + 1] = item end end
            end
            sortItems(list, state.sort == "position" and "name" or state.sort)
            local height = grid(content, list, false, width, 0, 0)
            cy = height
        elseif bank then
            for index, tab in ipairs(bank.tabs) do
                local box = section(index)
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", 0, -cy)
                box.icon:SetTexture(tabIcon(tab.icon))
                local name = tab.name and tab.name ~= "" and tab.name or text("bankTabFallback"):format(index)
                box.label:SetText(name)
                box.count:SetText(("%d/%d"):format(#tab.items, tab.size or 0))
                local layout = {}
                for i = 1, tab.size or 0 do layout[i] = false end
                for _, item in ipairs(tab.items) do layout[item.slot or (#layout + 1)] = item end
                local height = grid(box, layout, true, width - 24, 34, 12)
                box:SetSize(width, 34 + height + 8)
                cy = cy + 34 + height + 8 + 8
            end
        end
        content:SetSize(width, math.max(1, cy))
        empty.Set((state.selected ~= ALL and not bank) and text("bankNoData") or nil)

        -- Summary tiles.
        local C = ui.colors
        if state.selected == ALL then
            local count = #inventory.characterKeys()
            tiles[1].Set(text("bankTileTotal"), GetMoneyString(math.floor(total + 0.5)), C.gold)
            tiles[2].Set(text("bankTileCharacters"), tostring(count), C.white)
            tiles[3].Set(text("bankTileItems"), tostring(itemCount), C.white)
            tiles[4].Set(text("bankTileUnvalued"), tostring(unvalued), unvalued > 0 and C.orange or C.white)
            tiles[2].Progress(nil)
        else
            local usedSlots, capacity = bank and bank.slots - bank.free or 0, bank and bank.slots or 0
            tiles[1].Set(text("financeTile_bank"), bank and GetMoneyString(math.floor(total + 0.5)) or "–", C.gold)
            tiles[2].Set(text("bankTileUsed"), bank and ("%d / %d"):format(usedSlots, capacity) or "–", C.white)
            tiles[2].Progress(bank and capacity > 0 and usedSlots / capacity or nil)
            tiles[3].Set(text("bankTileFree"), bank and tostring(bank.free) or "–", C.white)
        end

        -- Status bar: last update · items without price · price source.
        local parts = {}
        local newest = 0
        if state.selected == ALL then
            for _, entry in pairs(characters) do newest = math.max(newest, entry.bank and entry.bank.at or 0) end
        else
            newest = bank and bank.at or 0
        end
        if newest > 0 then parts[#parts + 1] = text("bankStatusUpdated"):format(date("%d.%m.%Y %H:%M", newest)) end
        if unvalued > 0 then parts[#parts + 1] = "|cffff9933" .. text("bankUnvalued"):format(unvalued) .. "|r" end
        local source = addon.PriceSourceName and addon.PriceSourceName()
        parts[#parts + 1] = source and text("financeStatusSource"):format(source) or text("financeStatusVendorOnly")
        status.Set(parts, text("ledgerBank"))
    end

    search:HookScript("OnTextChanged", refresh)
    local pending
    page:SetScript("OnSizeChanged", function()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function() pending = false; refresh() end)
    end)
    page:SetScript("OnShow", function() ledger.resetValues(); refresh() end)
    inventory.onChange(refresh)
    page.refresh = refresh
end

-- Ledger window: a standalone ForeverCraft frame with page tabs (Bank; Finances follows).
local pages = {}
ledger.pages = pages
function ledger.addPage(key, label, build, icon)
    pages[#pages + 1] = { key = key, label = label, build = build, icon = icon }
end

function ledger.show(key)
    local frame = ledger.frame
    if not frame then
        frame = CreateFrame("Frame", "ForeverCraftLedgerFrame", UIParent, "PortraitFrameTemplate")
        ledger.frame = frame
        frame:SetSize(960, 580)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("HIGH")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
        addon.AddSettingsGear(frame)
        tinsert(UISpecialFrames, "ForeverCraftLedgerFrame")
        frame.tabs, frame.pages = {}, {}
        for i, entry in ipairs(pages) do
            local page = CreateFrame("Frame", nil, frame)
            page:SetPoint("TOPLEFT", 8, -60)
            page:SetPoint("BOTTOMRIGHT", -6, 6)
            page:Hide()
            entry.build(page)
            frame.pages[i] = page
            local tab = CreateFrame("Button", "ForeverCraftLedgerFrameTab" .. i, frame, "PanelTabButtonTemplate")
            tab:SetID(i)
            tab:SetText(text(entry.label))
            if i == 1 then tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
            else tab:SetPoint("LEFT", frame.tabs[i - 1], "RIGHT", -16, 0) end
            tab:SetScript("OnClick", function(self) ledger.show(pages[self:GetID()].key) end)
            frame.tabs[i] = tab
        end
        PanelTemplates_SetNumTabs(frame, #pages)
    end
    local selected = 1
    for i, entry in ipairs(pages) do if entry.key == key then selected = i end end
    PanelTemplates_SetTab(frame, selected)
    for i, page in ipairs(frame.pages) do page:SetShown(i == selected) end
    frame:SetTitle(addon.HeaderTitle(text(pages[selected].label)))
    frame:Show()
end

-- Bank as a side tab of the professions window, docked over its content like the
-- shopping list and disenchant pages.
-- Each ledger page (bank, finance) can also be docked as a side tab; key -> {tab, panel}.
local dockedPages = {}
function addon.CloseBank()
    for _, entry in pairs(dockedPages) do
        if entry.panel and entry.panel:IsShown() then entry.panel:Hide() end
    end
end


-- Docked like the disenchant page: profession header art on top, native pages faded out,
-- own title and portrait while open; everything is restored when the page closes.
local function buildDocked(root, nativeHeader, page, tab)
    local panel = CreateFrame("Frame", nil, root)
    panel:SetPoint("TOPLEFT", root, "TOPLEFT", 6, page.compact and -26 or -72)
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
    local canvas = CreateFrame("Frame", nil, headerArt)
    canvas:SetPoint("TOPLEFT")
    canvas:SetPoint("TOPRIGHT")
    canvas:SetHeight(nativeHeader and nativeHeader:GetHeight() or root:GetHeight())
    local art = canvas:CreateTexture(nil, "BACKGROUND")
    art:SetAtlas(nativeHeader and nativeHeader:GetAtlas() or "Profession-Background-Template2")
    art:SetAllPoints()

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 7, -3)
    content:SetPoint("BOTTOMRIGHT", -4, 5)
    page.build(content)

    local title = root.TitleContainer and root.TitleContainer.TitleText
    local pageTitle
    if title then
        pageTitle = root.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pageTitle:SetAllPoints(title)
        pageTitle:SetJustifyH("CENTER")
        pageTitle:SetWordWrap(false)
        pageTitle:Hide()
    end
    local pageAlphas, titleAlpha, nativePortrait, activePortrait, previousTab = {}, nil, nil, nil, nil
    panel:SetScript("OnShow", function()
        headerArt:SetShown(not page.compact)
        for _, nativePage in ipairs(root.Pages or {}) do
            pageAlphas[nativePage] = nativePage:GetAlpha()
            nativePage:SetAlpha(0)
        end
        if addon.QueueProfessionLayout then addon.QueueProfessionLayout() end
        if pageTitle then
            titleAlpha = title:GetAlpha()
            title:SetAlpha(0)
            pageTitle:SetText(addon.HeaderTitle(text(page.label)))
            pageTitle:Show()
        end
        local portrait = root.PortraitContainer and root.PortraitContainer.portrait
        if portrait then
            nativePortrait = portrait:GetTexture()
            root:SetPortraitToAsset(page.icon)
            activePortrait = portrait:GetTexture()
        end
        for _, nativeTab in ipairs({ root.ProfessionsOverviewTab, unpack(root.rightProfessionTabs or {}) }) do
            if nativeTab:GetID() == root.selectedGamepadTabID then
                previousTab = nativeTab
                nativeTab:SetChecked(false)
                break
            end
        end
        tab.SelectedTexture:Show()
    end)
    panel:SetScript("OnHide", function()
        headerArt:Hide()
        for nativePage, alpha in pairs(pageAlphas) do nativePage:SetAlpha(alpha) end
        wipe(pageAlphas)
        if addon.QueueProfessionLayout then addon.QueueProfessionLayout() end
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
    return panel
end

function ledger.attach(root, closeOthers, nativeHeader, key)
    if dockedPages[key] then return dockedPages[key].tab end
    local page
    for _, entry in ipairs(ledger.pages) do if entry.key == key then page = entry end end
    local tab = CreateFrame("Frame", nil, root, "LargeSideTabButtonTemplate")
    local entry = { tab = tab }
    dockedPages[key] = entry
    tab.fillToInterior = true
    tab:SetFrameStrata("DIALOG")
    tab.Icon:SetTexture(page.icon)
    tab.SelectedTexture:Hide()
    local click = CreateFrame("Button", nil, tab)
    click:SetAllPoints()
    click:SetScript("OnEnter", function(self)
        addon.ui.navTooltip(self, text(page.label), page.description and text(page.description))
    end)
    click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    click:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if entry.panel and entry.panel:IsShown() then entry.panel:Hide(); return end
        addon.CloseBank()
        closeOthers()
        entry.panel = entry.panel or buildDocked(root, nativeHeader, page, tab)
        entry.panel:Show()
    end)
    root:HookScript("OnHide", addon.CloseBank)
    return tab
end

function addon.AttachBank(root, closeOthers, nativeHeader)
    return ledger.attach(root, closeOthers, nativeHeader, "bank")
end

-- Deleting saved data always goes through an explicit confirmation naming what is lost.
StaticPopupDialogs["FOREVERCRAFT_CONFIRM_INVENTORY_DELETE"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
    showAlert = true,
    OnAccept = function(_, key)
        local characters = inventory.db().characters
        if key == ALL then wipe(characters) else characters[key] = nil end
        inventory.changed()
    end,
}

function ledger.confirmReset()
    StaticPopup_Show("FOREVERCRAFT_CONFIRM_INVENTORY_DELETE", text("bankResetConfirm"), nil, ALL)
end

function ledger.confirmDeleteCharacter(key)
    local character = inventory.db().characters[key]
    if not character then return end
    StaticPopup_Show("FOREVERCRAFT_CONFIRM_INVENTORY_DELETE",
        text("bankDeleteConfirm"):format(character.name or key, character.realm or ""), nil, key)
end

ledger.addPage("bank", "ledgerBank", ledger.buildBank, BANK_ICON)
pages[#pages].description = "navBankDesc"

SLASH_FOREVERCRAFTBANK1 = "/fcbank"
SlashCmdList.FOREVERCRAFTBANK = function(message)
    if message == "status" then
        for _, line in ipairs(inventory.status()) do print(line) end
        local entry = addon.finance and addon.finance.character()
        print(("finance: entry=%s · transactions=%d"):format(tostring(entry ~= nil), entry and #entry.transactions or 0))
        return
    end
    if ledger.frame and ledger.frame:IsShown() then ledger.frame:Hide() else ledger.show("bank") end
end
