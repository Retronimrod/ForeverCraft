local _, addon = ...

-- "Finances" tab of the ForeverCraft ledger. Layout only – all numbers come from
-- addon.finance (Finance.lua). Character, period and valuation stay selected while
-- switching sections.

local ledger, finance, inventory, ui = addon.ledger, addon.finance, addon.inventory, addon.ui
local C = ui.colors
local ALL = "*all"
local FINANCE_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local periods = { "24h", "7d", "30d", "month", "lastMonth", "year", "all", "custom" }
local sections = { "overview", "wealth", "income", "expense", "transactions" }
local wealthViews = { "money", "bags", "bank", "total" }
local viewColors = { money = ui.barColors.money, bags = ui.barColors.bags, bank = ui.barColors.bank,
    total = ui.barColors.total }
local retentions = { 30, 90, 365, 0 }
local categoryIcons = {
    quest = "Interface\\GossipFrame\\ActiveQuestIcon", loot = "Interface\\Icons\\INV_Misc_Bag_10",
    vendor = "Interface\\GossipFrame\\VendorGossipIcon", auction = "Interface\\Icons\\INV_Misc_Coin_03",
    auctionFee = "Interface\\Icons\\INV_Misc_Coin_06", trade = "Interface\\Icons\\INV_Misc_Bag_07",
    mail = "Interface\\Icons\\INV_Letter_15", refund = "Interface\\Icons\\INV_Misc_Coin_02",
    guildbank = "Interface\\Icons\\INV_Box_04", classTrainer = "Interface\\GossipFrame\\TrainerGossipIcon",
    professionTrainer = "Interface\\GossipFrame\\TrainerGossipIcon", repair = "Interface\\Icons\\Trade_BlackSmithing",
    flight = "Interface\\GossipFrame\\TaxiGossipIcon", bank = "Interface\\GossipFrame\\BankerGossipIcon",
    talent = "Interface\\Icons\\INV_Misc_Book_09", transfer = "Interface\\Icons\\INV_Letter_15",
    otherIncome = "Interface\\Icons\\INV_Misc_Coin_04", otherExpense = "Interface\\Icons\\INV_Misc_Coin_04",
    untracked = "Interface\\Icons\\INV_Misc_Coin_04",
}
-- Neutral coin instead of a red question mark for anything without its own icon.
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_Coin_04"
-- Thematic illustration (Art\FinanceWatermark.tga) - set once the artwork is part of the
-- addon; nil shows none.
local WATERMARK = nil

local function text(key)
    local L = addon.GetText()
    return L[key] or addon.strings.enUS[key] or key
end

-- Label part of an existing "Label: %s" string (keeps the figures in the catalogs).
local function label(key)
    return (text(key):gsub("%%s", ""):gsub("%s+$", ""):gsub(":$", ""):gsub("：$", ""))
end

local function money(copper, signed)
    copper = math.floor((copper or 0) + 0.5)
    local value = GetMoneyString(math.abs(copper))
    if signed and copper > 0 then return "+" .. value end
    if signed and copper < 0 then return "-" .. value end
    return value
end

local function cycle(list, current)
    for i, value in ipairs(list) do
        if value == current then return list[i % #list + 1] end
    end
    return list[1]
end

local function setting(key, fallback)
    local value = ForeverCraftDB and ForeverCraftDB[key]
    if value == nil then return fallback end
    return value
end

local function classIcon(texture, character)
    local coords = character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
    if coords then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(unpack(coords))
    else
        texture:SetTexture(FINANCE_ICON)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

-- Time range for a period key; "custom" reads "DD.MM.YYYY - DD.MM.YYYY".
local function range(period, custom)
    local now = time()
    local today = date("*t", now)
    local function at(y, m, d) return time({ year = y, month = m, day = d, hour = 0 }) end
    if period == "24h" then return { from = now - 86400, to = now } end
    if period == "7d" then return { from = now - 7 * 86400, to = now } end
    if period == "30d" then return { from = now - 30 * 86400, to = now } end
    if period == "month" then return { from = at(today.year, today.month, 1), to = now } end
    if period == "lastMonth" then
        local y, m = today.year, today.month - 1
        if m == 0 then y, m = y - 1, 12 end
        return { from = at(y, m, 1), to = at(today.year, today.month, 1) - 1 }
    end
    if period == "year" then return { from = at(today.year, 1, 1), to = now } end
    if period == "custom" and custom then
        local d1, m1, y1, d2, m2, y2 = custom:match("(%d+)%.(%d+)%.(%d+)%s*%-%s*(%d+)%.(%d+)%.(%d+)")
        if d1 then
            return { from = at(tonumber(y1), tonumber(m1), tonumber(d1)),
                to = at(tonumber(y2), tonumber(m2), tonumber(d2)) + 86399 }
        end
    end
    local first = now
    for _, entry in pairs(finance.db().characters) do
        for day in pairs(entry.daily) do
            local y, m, d = day:match("^(%d+)-(%d+)-(%d+)$")
            first = math.min(first, at(tonumber(y), tonumber(m), tonumber(d)))
        end
    end
    return { from = first, to = now }
end

local function allKeys()
    local keys, seen = {}, {}
    for _, key in ipairs(inventory.characterKeys()) do keys[#keys + 1] = key; seen[key] = true end
    for key in pairs(finance.db().characters) do if not seen[key] then keys[#keys + 1] = key end end
    return keys
end

local function keysFor(selected)
    if selected ~= ALL then return { selected } end
    return allKeys()
end

-- History points: several characters are summed with each one's latest snapshot so far.
local function historyPoints(keys, view, period)
    local points, perCharacter, times = {}, {}, {}
    for _, key in ipairs(keys) do
        local entry = finance.db().characters[key]
        perCharacter[key] = entry and entry.snapshots or {}
        for _, s in ipairs(perCharacter[key]) do
            if s.t >= period.from and s.t <= period.to then times[#times + 1] = s.t end
        end
    end
    table.sort(times)
    local function value(s)
        if view == "money" then return s.money end
        if view == "bags" then return s.bags end
        if view == "bank" then return s.bank end
        return s.money + s.bags + s.bank
    end
    for _, t in ipairs(times) do
        local total = 0
        for _, list in pairs(perCharacter) do
            local latest
            for _, s in ipairs(list) do if s.t <= t then latest = s end end
            if latest then total = total + value(latest) end
        end
        points[#points + 1] = { t = t, v = total }
    end
    return points
end

local function transactionsFor(keys, period, filter, query)
    local result = {}
    for _, key in ipairs(keys) do
        local entry = finance.db().characters[key]
        local character = inventory.db().characters[key]
        for _, tx in ipairs(entry and entry.transactions or {}) do
            local category = finance.category(tx)
            local include = tx.t >= period.from and tx.t <= period.to
            if filter == "income" then include = include and tx.a > 0 and not finance.neutral[category]
            elseif filter == "expense" then include = include and tx.a < 0 and not finance.neutral[category]
            elseif filter == "other" then include = include and (category == "otherIncome"
                or category == "otherExpense" or finance.neutral[category] ~= nil) end
            local name = character and character.name or key
            if include and query and query ~= "" then
                include = (name .. " " .. text("financeCategory_" .. category) .. " " .. (tx.d or "")):lower()
                    :find(query, 1, true) ~= nil
            end
            if include then result[#result + 1] = { tx = tx, entry = entry, name = name, character = character } end
        end
    end
    table.sort(result, function(a, b) return a.tx.t > b.tx.t end)
    return result
end

-- Category breakdown (shared ui.categoryBars): tooltip with exact amount, share and count.
local function categoryBars(box, color)
    local draw = ui.categoryBars(box, color, categoryIcons,
        function(category) return text("financeCategory_" .. category) end, UNKNOWN_ICON)
    local function tooltip(row)
        local entry = row.entry
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(text("financeCategory_" .. entry.category))
        GameTooltip:AddDoubleLine(text("financeAmount"), money(entry.amount), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(text("financeShare"), ("%.1f %%"):format(entry.share), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(text("financeCount"), tostring(entry.count), 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end
    return function(values, counts, sign, total, emptyMessage)
        local list = {}
        for category, amount in pairs(values) do
            list[#list + 1] = { category = category, amount = amount, text = money(amount), tooltip = tooltip,
                share = total > 0 and amount / total * 100 or 0, count = counts[sign .. category] or 0 }
        end
        table.sort(list, function(a, b) return a.amount > b.amount end)
        return draw(list, total, emptyMessage)
    end
end

-- Number of categories with a value (for the box height before drawing).
local function countOf(values)
    local n = 0
    for _ in pairs(values) do n = n + 1 end
    return n
end

-- Column chart of one money flow (income or expenses) over time buckets.
local function flowChart(box, color, field)
    local bars = {}
    return function(series, step)
        local maxValue, any = 1, false
        for _, bucket in ipairs(series) do
            maxValue = math.max(maxValue, bucket[field])
            if bucket[field] > 0 then any = true end
        end
        box.scale:SetText("")
        -- Value axis first: its measured width decides where the plot starts.
        box.YAxis(any and { "0", money(maxValue / 3), money(maxValue * 2 / 3), money(maxValue) } or nil)
        box.Layout(true)
        local width, height = box.plotWidth or 1, box.plotHeight or 1
        local slot = width / math.max(1, #series)
        local column = math.floor(math.max(2, math.min(18, slot * 0.62)))
        for i, bucket in ipairs(series) do
            local entry = bars[i]
            if not entry then
                entry = CreateFrame("Frame", nil, box.plot)
                entry.hover = entry:CreateTexture(nil, "BACKGROUND")
                entry.hover:SetAllPoints()
                entry.hover:SetColorTexture(1, 0.82, 0.4, 0.08)
                entry.hover:Hide()
                entry.bar = ui.barFill(entry, true)
                entry:EnableMouse(true)
                entry:SetScript("OnEnter", function(self)
                    self.hover:Show()
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.label)
                    GameTooltip:AddLine(money(self.value), 1, 1, 1)
                    GameTooltip:Show()
                end)
                entry:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
                bars[i] = entry
            end
            entry.value = bucket[field]
            entry.label = step == "hour" and date("%d.%m. %H:00", bucket.t) or step == "day" and date("%d.%m.%Y", bucket.t)
                or date("%m/%Y", bucket.t)
            entry:ClearAllPoints()
            entry:SetPoint("BOTTOMLEFT", (i - 1) * slot, 0)
            entry:SetSize(slot, height)
            entry.bar:ClearAllPoints()
            entry.bar:SetPoint("BOTTOM", entry, "BOTTOM", 0, 0)
            entry.bar:SetSize(column, math.max(3, entry.value / maxValue * (height - 4)))
            entry.bar.Color(color)
            entry.bar:SetShown(entry.value > 0)
            entry:Show()
        end
        for i = #series + 1, #bars do bars[i]:Hide() end
        -- Up to five evenly spread time labels under the bars.
        local times, labels = {}, math.min(5, #series)
        for n = 1, labels do
            local i = labels == 1 and 1 or math.floor(1 + (n - 1) * (#series - 1) / (labels - 1) + 0.5)
            local t = series[i].t
            times[n] = { (i - 0.5) * slot, step == "hour" and date("%H:00", t) or step == "day" and date("%d.%m.", t)
                or date("%m/%Y", t) }
        end
        box.XAxis(times)
        return any
    end
end

-- Line chart from stored snapshots (values as they were at that time).
local function lineChart(box)
    local lines, dots = {}, {}
    return function(points, color, emptyMessage)
        for _, line in ipairs(lines) do line:Hide() end
        for _, dot in ipairs(dots) do dot:Hide() end
        local enough = #points >= 2
        box.empty.Set(not enough and emptyMessage or nil)
        box.scale:SetText("")
        local maxV = 1
        for _, p in ipairs(points) do maxV = math.max(maxV, p.v) end
        box.YAxis(enough and { "0", money(maxV / 3), money(maxV * 2 / 3), money(maxV) } or nil)
        box.Layout(true)
        box.XAxis(nil)
        if not enough then return end
        local width, height = box.plotWidth or 1, box.plotHeight or 1
        local minT, maxT = points[1].t, points[#points].t
        box.XAxis({ { 4, date("%d.%m.", minT) }, { (width - 8) / 2 + 4, date("%d.%m.", (minT + maxT) / 2) },
            { width - 4, date("%d.%m.", maxT) } })
        local function xy(p)
            return (p.t - minT) / math.max(1, maxT - minT) * (width - 8) + 4, p.v / maxV * (height - 8) + 4
        end
        for i = 1, #points do
            local x, y = xy(points[i])
            local dot = dots[i]
            if not dot then
                dot = CreateFrame("Frame", nil, box.plot)
                dot:SetSize(8, 8)
                dot.texture = dot:CreateTexture(nil, "OVERLAY")
                dot.texture:SetAllPoints()
                dot:EnableMouse(true)
                dot:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(date("%d.%m.%Y %H:%M", self.point.t))
                    GameTooltip:AddLine(money(self.point.v), 1, 1, 1)
                    GameTooltip:Show()
                end)
                dot:SetScript("OnLeave", function() GameTooltip:Hide() end)
                dots[i] = dot
            end
            dot.point = points[i]
            dot.texture:SetColorTexture(color[1], color[2], color[3], 1)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", box.plot, "BOTTOMLEFT", x, y)
            dot:Show()
            if i > 1 then
                local line = lines[i - 1]
                if not line then
                    line = box.plot:CreateLine(nil, "ARTWORK")
                    line:SetThickness(2)
                    lines[i - 1] = line
                end
                local px, py = xy(points[i - 1])
                line:SetColorTexture(color[1], color[2], color[3], 0.9)
                line:SetStartPoint("BOTTOMLEFT", box.plot, px, py)
                line:SetEndPoint("BOTTOMLEFT", box.plot, x, y)
                line:Show()
            end
        end
    end
end

local function priceSource()
    local auctionator = Auctionator and Auctionator.API and Auctionator.API.v1
    local auctioneer = AucAdvanced and AucAdvanced.API
    if auctionator and auctioneer then
        return (ForeverCraftDB and ForeverCraftDB.preferAuctionator) and "Auctionator" or "Auctioneer"
    end
    return auctionator and "Auctionator" or auctioneer and "Auctioneer" or nil
end
addon.PriceSourceName = priceSource

function ledger.buildFinance(page)
    local state = { selected = ALL, section = "overview", view = "total", filter = "all",
        period = setting("financeDefaultPeriod", "30d"), method = setting("financeDefaultMethod", "best") }
    local refresh, dirty

    -- Character list ------------------------------------------------------------------
    local sidebar = ledger.createBox(page)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(ui.SIDEBAR_WIDTH)
    local sidebarTitle = ledger.sectionHeading(sidebar)
    local wealthCache, totalMoney = {}, 0
    local characterList = ui.characterList(sidebar, {
        entries = function()
            local entries = { ALL }
            for _, key in ipairs(allKeys()) do entries[#entries + 1] = key end
            return entries
        end,
        info = function(key)
            if key == ALL then return text("bankAllCharacters"), nil, GetMoneyString(totalMoney) end
            local character = inventory.db().characters[key]
            local w = wealthCache[key]
            return character and character.name or key, character and character.level,
                w and GetMoneyString(w.money) or "", character
        end,
        selected = function() return state.selected end,
        select = function(key) state.selected, state.transaction = key, nil; refresh() end,
        menu = function(key)
            if key == ALL then return nil end
            return { { text("financeMenuDelete"), function() ledger.confirmFinanceReset(key) end } }
        end,
        menuHint = function() return text("characterMenuHint") end,
        allIcon = FINANCE_ICON,
    })
    characterList:SetPoint("TOPLEFT", 8, -38)
    characterList:SetPoint("BOTTOMRIGHT", -6, 10)

    -- Main area: tabs on top, filter bar, content, status bar ------------------------
    local main = ledger.createBox(page)
    main:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, -30)
    main:SetPoint("BOTTOMRIGHT", 0, 0)
    local tabs = ui.tabs(main, sections, function(key) return text("financeSection_" .. key) end,
        function(key) state.section = key; state.transaction = nil; refresh() end)

    local function options(list, prefix)
        return function()
            local result = {}
            for _, value in ipairs(list) do result[#result + 1] = { value, text(prefix .. value) } end
            return result
        end
    end
    local periodMenu = ledger.dropdown(main, 210, options(periods, "financePeriod_"),
        function(value) return state.period == value end, function(value) state.period = value; refresh() end)
    periodMenu:SetPoint("TOPLEFT", 14, -12)
    local methodMenu = ledger.dropdown(main, 250, options(finance.methods, "financeMethod_"),
        function(value) return state.method == value end,
        function(value) state.method = value; finance.resetValues(); refresh() end)
    methodMenu:SetPoint("LEFT", periodMenu, "RIGHT", 10, 0)
    local customRange = CreateFrame("EditBox", nil, main, "InputBoxTemplate")
    customRange:SetSize(180, 20)
    customRange:SetPoint("LEFT", methodMenu, "RIGHT", 14, 0)
    customRange:SetAutoFocus(false)
    customRange:SetText(date("%d.%m.%Y", time() - 30 * 86400) .. " - " .. date("%d.%m.%Y"))
    customRange:SetScript("OnEnterPressed", function(self) self:ClearFocus(); refresh() end)
    local filterLine = ui.divider(main)
    filterLine:SetPoint("TOPLEFT", 12, -42)
    filterLine:SetPoint("TOPRIGHT", -12, -42)

    local watermark = ui.watermark(main, WATERMARK)
    local status = ui.statusBar(main)
    status:SetPoint("BOTTOMLEFT", 12, 8)
    status:SetPoint("BOTTOMRIGHT", -12, 8)

    local bodyScroll = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 14, -50)
    bodyScroll:SetPoint("BOTTOMRIGHT", -32, 30)
    local body = CreateFrame("Frame", nil, bodyScroll)
    body:SetSize(1, 1)
    bodyScroll:SetScrollChild(body)
    addon.HideUnusedScrollbar(bodyScroll)
    local panes = {}
    for _, key in ipairs({ "overview", "wealth", "income", "expense" }) do
        panes[key] = CreateFrame("Frame", nil, body)
        panes[key]:SetPoint("TOPLEFT")
        panes[key]:SetPoint("TOPRIGHT")
    end

    -- Overview ------------------------------------------------------------------------
    local overview = panes.overview
    local wealthHeading = ui.heading(overview)
    wealthHeading:SetPoint("TOPLEFT", 2, 0)
    local wealthTiles = {
        ui.tile(overview, "Interface\\Icons\\INV_Misc_Coin_02"), ui.tile(overview, "Interface\\Icons\\INV_Misc_Bag_08"),
        ui.tile(overview, "Interface\\Icons\\INV_Box_02"), ui.tile(overview, "Interface\\Icons\\INV_Box_01", true),
    }
    local flowHeading = ui.heading(overview)
    local flowTiles = {
        ui.tile(overview, "Interface\\Icons\\INV_Misc_Coin_01"), ui.tile(overview, "Interface\\Icons\\INV_Misc_Coin_05"),
        ui.tile(overview, "Interface\\Icons\\INV_Misc_Coin_04"),
    }
    local historyBox = ui.chart(overview, nil, true)
    local drawHistory = lineChart(historyBox)
    local figuresBox = ui.panel(overview)
    local figuresHeading = ui.sectionHeading(figuresBox)
    local figureRows, dividers = {}, {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, figuresBox)
        row:SetHeight(16)
        row.label = ui.text(row, "GameFontHighlightSmall", "LEFT", C.grey)
        row.label:SetPoint("LEFT")
        row.value = ui.text(row, "GameFontHighlightSmall", "RIGHT")
        row.value:SetPoint("RIGHT")
        row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
        figureRows[i] = row
    end
    for i = 1, 3 do dividers[i] = ui.divider(figuresBox) end
    -- "Most valuable items": own subsection header inside the key figures panel.
    local itemsTitle = ui.sectionHeading(figuresBox)
    local itemRows = {}
    for i = 1, 2 do
        local row = CreateFrame("Button", nil, figuresBox)
        row:SetHeight(30)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(26, 26)
        row.icon:SetPoint("TOPLEFT")
        -- Quality-coloured name (from the item link) wraps instead of leaving the frame.
        row.name = ui.text(row, "GameFontHighlightSmall")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
        row.name:SetWordWrap(true)
        row.value = ui.text(row, "GameFontHighlightSmall", "LEFT", C.grey)
        row.value:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        itemRows[i] = row
    end
    local incomeBox, expenseBox = ui.chart(overview), ui.chart(overview)
    local drawIncomeSources = categoryBars(incomeBox, ui.barColors.income)
    local drawExpenseCategories = categoryBars(expenseBox, ui.barColors.expense)

    -- Wealth ---------------------------------------------------------------------------
    local wealthPane = panes.wealth
    local tableBox = ui.panel(wealthPane)
    local tableRows = {}
    local wealthChart = ui.chart(wealthPane, nil, true)
    local drawWealth = lineChart(wealthChart)
    local viewMenu = ledger.dropdown(wealthChart, 190, options(wealthViews, "financeView_"),
        function(value) return state.view == value end, function(value) state.view = value; refresh() end)
    viewMenu:SetPoint("TOPRIGHT", -12, -6)
    viewMenu:SetFrameLevel(wealthChart.heading:GetFrameLevel() + 2)
    wealthChart.scale:ClearAllPoints()
    wealthChart.scale:SetPoint("RIGHT", viewMenu, "LEFT", -10, 0)

    -- Income / expenses: tiles, chart over time, categories --------------------------
    local function flowPane(pane, color, icon, field)
        local view = { tiles = { ui.tile(pane, icon, true), ui.tile(pane, "Interface\\Icons\\INV_Misc_Note_01"),
            ui.tile(pane, "Interface\\Icons\\INV_Misc_PocketWatch_01") } }
        view.chart = ui.chart(pane, nil, true)
        view.draw = flowChart(view.chart, color, field)
        view.categories = ui.chart(pane)
        view.drawCategories = categoryBars(view.categories, color)
        return view
    end
    local incomeView = flowPane(panes.income, ui.barColors.income, "Interface\\Icons\\INV_Misc_Coin_01", "income")
    local expenseView = flowPane(panes.expense, ui.barColors.expense, "Interface\\Icons\\INV_Misc_Coin_05", "expense")

    -- Transactions ------------------------------------------------------------------
    local txPane = CreateFrame("Frame", nil, main)
    txPane:SetPoint("TOPLEFT", 14, -50)
    txPane:SetPoint("BOTTOMRIGHT", -14, 30)
    local search = CreateFrame("EditBox", nil, txPane, "SearchBoxTemplate")
    search:SetSize(190, 22)
    search:SetPoint("TOPLEFT", 6, 0)
    local filterMenu = ledger.dropdown(txPane, 210, options({ "all", "income", "expense", "other" }, "financeFilter_"),
        function(value) return state.filter == value end, function(value) state.filter = value; refresh() end)
    filterMenu:SetPoint("LEFT", search, "RIGHT", 10, 0)
    local recategorize = CreateFrame("Button", nil, txPane, "UIPanelButtonTemplate")
    recategorize:SetSize(200, 22)
    recategorize:SetPoint("TOPRIGHT", 0, 0)
    local header = CreateFrame("Frame", nil, txPane)
    header:SetPoint("TOPLEFT", 0, -30)
    header:SetPoint("TOPRIGHT", -24, -30)
    header:SetHeight(18)
    header.cells = {}
    for c = 1, 5 do header.cells[c] = ui.heading(header, "GameFontNormalSmall") end
    local headerLine = ui.divider(txPane)
    headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    local txScroll = CreateFrame("ScrollFrame", nil, txPane, "UIPanelScrollFrameTemplate")
    txScroll:SetPoint("TOPLEFT", 0, -54)
    txScroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local txContent = CreateFrame("Frame", nil, txScroll)
    txContent:SetSize(1, 1)
    txScroll:SetScrollChild(txContent)
    addon.HideUnusedScrollbar(txScroll)
    local txEmpty = ui.empty(txScroll)
    local txRows = {}
    local columns = { 0, 0.15, 0.31, 0.53, 0.78 }
    search:HookScript("OnTextChanged", function() if refresh then refresh() end end)
    recategorize:SetScript("OnClick", function()
        local selected = state.transaction
        if not selected then return end
        local list = selected.tx.a > 0 and finance.income or finance.expense
        local choices = {}
        for _, category in ipairs(list) do choices[#choices + 1] = category end
        choices[#choices + 1] = "transfer"
        finance.recategorize(selected.entry, selected.tx, cycle(choices, finance.category(selected.tx)))
    end)

    local function placeColumns(parent, cells, width)
        for c = 1, 5 do
            local cell = cells[c]
            cell:ClearAllPoints()
            local left, right = width * columns[c], width * (columns[c + 1] or 1)
            if c == 5 then
                cell:SetPoint("RIGHT", parent, "LEFT", right - 4, 0)
                cell:SetJustifyH("RIGHT")
            else
                cell:SetPoint("LEFT", parent, "LEFT", left + (c == 3 and 20 or 4), 0)
            end
            cell:SetWidth(right - left - (c == 3 and 26 or 8))
        end
    end

    -- One draw function per section keeps each closure under Lua 5.1's upvalue limit.
    local sectionViews = {}
    sectionViews.overview = function(ctx)
        local keys, period, summary, w, width, days = ctx.keys, ctx.period, ctx.summary, ctx.w, ctx.width, ctx.days
        local characters, figureLabels, richest = ctx.characters, ctx.figureLabels, ctx.richest
        local bestBag, bestBagValue, bestBank, bestBankValue = ctx.bestBag, ctx.bestBagValue, ctx.bestBank, ctx.bestBankValue
        -- Everything is stacked from the top with explicit heights (no overlaps).
        local y = 0
        wealthHeading:SetText(text("financeSection_wealth"))
        y = y + 20
        local tileKeys = { "money", "bags", "bank", "total" }
        y = y + ui.tileGrid(wealthTiles, overview, y, width, 70, 150) + 12
        for i, tile in ipairs(wealthTiles) do
            tile.Set(text("financeTile_" .. tileKeys[i]), money(w[tileKeys[i]]), (i == 1 or i == 4) and C.gold or C.white,
                i == 4 and text("financeTileTotalHint"):format(text("financeMethod_" .. state.method)) or nil)
        end
        flowHeading:ClearAllPoints()
        flowHeading:SetPoint("TOPLEFT", 2, -y)
        flowHeading:SetText(text("financeHeadingFlow"))
        y = y + 20
        y = y + ui.tileGrid(flowTiles, overview, y, width, 64, 150) + 12
        local flowKeys, flowValues = { "income", "expense", "net" },
            { summary.totalIncome, -summary.totalExpense, summary.net }
        for i, tile in ipairs(flowTiles) do
            tile.Set(text("financeTile_" .. flowKeys[i]), money(i == 2 and summary.totalExpense or flowValues[i], i ~= 2),
                flowValues[i] > 0 and C.green or flowValues[i] < 0 and C.red or C.white)
        end

        -- History chart and key figures side by side (stacked when narrow).
        local stacked = width < 620
        local chartWidth = stacked and width or math.floor(width * 0.6)
        local figuresWidth = stacked and width or width - chartWidth - 8
        local historyHeight = 190
        historyBox:ClearAllPoints()
        historyBox:SetPoint("TOPLEFT", 0, -y)

        figuresHeading:SetHeaderText(text("financeHeadingFigures"))
        local inner = figuresWidth - 24
        local largestIn, largestOut
        for _, row in ipairs(transactionsFor(keys, period, "all")) do
            local category = finance.category(row.tx)
            if not finance.neutral[category] then
                if row.tx.a > 0 and (not largestIn or row.tx.a > largestIn.tx.a) then largestIn = row end
                if row.tx.a < 0 and (not largestOut or row.tx.a < largestOut.tx.a) then largestOut = row end
            end
        end
        local function top(values)
            local best, bestValue
            for category, amount in pairs(values) do
                if not bestValue or amount > bestValue then best, bestValue = category, amount end
            end
            return best and text("financeCategory_" .. best) or "–"
        end
        local richestName = richest and characters[richest] and characters[richest].name or "–"
        local values = { money(summary.net / days, true), money(summary.totalExpense / days),
            largestIn and money(largestIn.tx.a) or "–", largestOut and money(-largestOut.tx.a) or "–",
            top(summary.income), top(summary.expense), richestName }
        if summary.transfers ~= 0 then
            figureLabels[#figureLabels + 1] = "financeFigureTransfers"
            values[#values + 1] = money(summary.transfers, true)
        end
        local fy = 40
        for i, row in ipairs(figureRows) do
            row:ClearAllPoints()
            if figureLabels[i] then
                if i == 3 or i == 5 then
                    local line = dividers[i == 3 and 1 or 2]
                    line:ClearAllPoints()
                    line:SetPoint("TOPLEFT", 12, -(fy + 1))
                    line:SetPoint("TOPRIGHT", -12, -(fy + 1))
                    fy = fy + 5
                end
                row:SetPoint("TOPLEFT", 12, -fy)
                row:SetWidth(inner)
                row.label:SetText(label(figureLabels[i]))
                row.value:SetText(values[i])
                row:Show()
                fy = fy + 17
            else
                row:Hide()
            end
        end
        -- "Most valuable items" as its own subsection (header replaces the divider line).
        dividers[3]:Hide()
        fy = fy + 8
        itemsTitle:ClearAllPoints()
        itemsTitle:SetPoint("TOPLEFT", 6, -fy)
        itemsTitle:SetPoint("TOPRIGHT", -6, -fy)
        itemsTitle:SetHeaderText(text("financeHeadingItems"))
        fy = fy + 32
        local items = { { bestBag, bestBagValue, "financeItemBag" }, { bestBank, bestBankValue, "financeItemBank" } }
        for i, row in ipairs(itemRows) do
            local item, value = items[i][1], items[i][2]
            row.link = item and item.link
            row.icon:SetTexture(item and C_Item.GetItemIconByID(item.id) or UNKNOWN_ICON)
            row.icon:SetDesaturated(item == nil)
            row.name:SetWidth(inner - 32)
            row.name:SetText(item and item.link or (text(items[i][3]) .. ": –"))
            row.value:SetText(item and (text(items[i][3]) .. " · " .. money(value)) or "")
            local rowHeight = math.max(28, row.name:GetStringHeight() + 4 + (item and row.value:GetStringHeight() + 2 or 0))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 12, -fy)
            row:SetSize(inner, rowHeight)
            fy = fy + rowHeight + 6
        end
        local figuresHeight = fy + 6
        figuresBox:ClearAllPoints()
        if stacked then
            historyBox.Size(chartWidth, historyHeight)
            figuresBox:SetPoint("TOPLEFT", 0, -(y + historyHeight + 8))
            y = y + historyHeight + 8 + figuresHeight + 10
        else
            -- Both boxes share the taller height so the row ends evenly.
            local rowHeight = math.max(historyHeight, figuresHeight)
            historyBox.Size(chartWidth, rowHeight)
            figuresBox:SetPoint("TOPLEFT", chartWidth + 8, -y)
            figuresHeight = rowHeight
            y = y + rowHeight + 10
        end
        figuresBox:SetSize(figuresWidth, figuresHeight)
        historyBox.title:SetText(text("financeHeadingHistory"))
        drawHistory(historyPoints(keys, "total", period), ui.barColors.total, text("financeEmptyHistory"))

        -- Income sources / expense categories; height from the number of rows.
        local half = (width - 8) / 2
        local categoryHeight = math.max(140, math.max(countOf(summary.income), countOf(summary.expense)) * ui.CATEGORY_ROW + 58)
        incomeBox:ClearAllPoints()
        incomeBox:SetPoint("TOPLEFT", 0, -y)
        incomeBox.Size(half, categoryHeight)
        incomeBox.title:SetText(text("financeHeadingIncomeSources"))
        expenseBox:ClearAllPoints()
        expenseBox:SetPoint("TOPLEFT", half + 8, -y)
        expenseBox.Size(half, categoryHeight)
        expenseBox.title:SetText(text("financeHeadingExpenseCategories"))
        drawIncomeSources(summary.income, summary.counts, "+", summary.totalIncome, text("financeEmptyIncome"))
        drawExpenseCategories(summary.expense, summary.counts, "-", summary.totalExpense, text("financeEmptyExpense"))
        y = y + categoryHeight + 4
        overview:SetHeight(y)
        body:SetHeight(y)
    end
    sectionViews.wealth = function(ctx)
        local keys, period, width, characters, wealthCache = ctx.keys, ctx.period, ctx.width, ctx.characters, ctx.wealthCache
            local rowKeys = keysFor(ALL)
            local rowsData = { { header = true, cells = { text("financeColCharacter"), text("financeTile_money"),
                text("financeTile_bags"), text("financeTile_bank"), text("financeTile_total") } } }
            local totals = { 0, 0, 0, 0 }
            for _, key in ipairs(rowKeys) do
                local v = wealthCache[key] or finance.wealth(key, state.method)
                local character = characters[key]
                rowsData[#rowsData + 1] = { key = key, character = character, cells = {
                    character and ("%s  |cffaaaaaa%s|r"):format(character.name, character.level or "") or key,
                    money(v.money), money(v.bags), money(v.bank), money(v.total) } }
                totals[1], totals[2] = totals[1] + v.money, totals[2] + v.bags
                totals[3], totals[4] = totals[3] + v.bank, totals[4] + v.total
            end
            rowsData[#rowsData + 1] = { total = true, cells = { text("financeColTotal"), money(totals[1]),
                money(totals[2]), money(totals[3]), money(totals[4]) } }
            local tableHeight = #rowsData * 26 + 20
            tableBox:ClearAllPoints()
            tableBox:SetPoint("TOPLEFT")
            tableBox:SetSize(width, tableHeight)
            local inner = width - 24
            local cols = { 0, 0.36, 0.52, 0.68, 0.84 }
            for i, data in ipairs(rowsData) do
                local row = tableRows[i]
                if not row then
                    row = CreateFrame("Button", nil, tableBox)
                    row:SetHeight(24)
                    row.stripe = row:CreateTexture(nil, "BACKGROUND")
                    row.stripe:SetAllPoints()
                    row.cells = {}
                    for c = 1, 5 do row.cells[c] = ui.text(row, "GameFontHighlightSmall", c == 1 and "LEFT" or "RIGHT") end
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(18, 18)
                    row.icon:SetPoint("LEFT", 4, 0)
                    row.line = ui.divider(row)
                    row.line:SetPoint("TOPLEFT")
                    row.line:SetPoint("TOPRIGHT")
                    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                    row:SetScript("OnClick", function(self)
                        if self.key then state.selected = self.key; state.section = "overview"; refresh() end
                    end)
                    tableRows[i] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 12, -10 - (i - 1) * 26)
                row:SetWidth(inner)
                row.key = data.key
                row.stripe:SetColorTexture(1, 1, 1, (not data.header and i % 2 == 0) and 0.04 or 0)
                row.line:SetShown(data.total == true)
                row.icon:SetShown(data.character ~= nil)
                if data.character then classIcon(row.icon, data.character) end
                for c = 1, 5 do
                    local cell = row.cells[c]
                    cell:ClearAllPoints()
                    if c == 1 then
                        cell:SetPoint("LEFT", 28, 0)
                        cell:SetWidth(inner * cols[2] - 32)
                    else
                        cell:SetPoint("RIGHT", row, "LEFT", inner * (cols[c + 1] or 1) - 6, 0)
                        cell:SetWidth(inner * 0.16 - 8)
                    end
                    cell:SetText(data.cells[c])
                    cell:SetFontObject((data.total and c > 1) and "GameFontNormal" or "GameFontHighlightSmall")
                    if data.header or data.total then cell:SetTextColor(1, 0.82, 0)
                    elseif c == 1 then cell:SetTextColor(inventory.classColor(data.character))
                    else cell:SetTextColor(1, 1, 1) end
                end
                row:EnableMouse(data.key ~= nil)
                row:Show()
            end
            for i = #rowsData + 1, #tableRows do tableRows[i]:Hide() end
            wealthChart:ClearAllPoints()
            wealthChart:SetPoint("TOPLEFT", tableBox, "BOTTOMLEFT", 0, -10)
            wealthChart.Size(width, 200)
            wealthChart.title:SetText(text("financeHeadingHistory"))
            viewMenu.Sync()
            drawWealth(historyPoints(keys, state.view, period), viewColors[state.view], text("financeEmptyHistory"))
            wealthPane:SetHeight(tableHeight + 210)
            body:SetHeight(wealthPane:GetHeight())
    end
    sectionViews.flow = function(ctx)
        local keys, period, summary, width, days = ctx.keys, ctx.period, ctx.summary, ctx.width, ctx.days
            local isIncome = state.section == "income"
            local view = isIncome and incomeView or expenseView
            local pane = panes[state.section]
            local total = isIncome and summary.totalIncome or summary.totalExpense
            local count = 0
            for key2, n in pairs(summary.counts) do
                if key2:sub(1, 1) == (isIncome and "+" or "-") then count = count + n end
            end
            local top = ui.tileGrid(view.tiles, pane, 0, width, 64, 150) + 10
            local tileLabels = { isIncome and "financeTile_income" or "financeTile_expense", "financeCount", "financeTilePerDay" }
            local tileValues = { money(total), tostring(count), money(total / days) }
            local flowColor = total > 0 and (isIncome and C.green or C.red) or C.white
            for i, tile in ipairs(view.tiles) do
                tile.Set(label(tileLabels[i]), tileValues[i], i == 2 and C.white or flowColor)
            end
            view.chart:ClearAllPoints()
            view.chart:SetPoint("TOPLEFT", 0, -top)
            local series, step = finance.series(keys, period)
            local filled = 0
            for _, bucket in ipairs(series) do
                if (bucket[isIncome and "income" or "expense"] or 0) > 0 then filled = filled + 1 end
            end
            -- Few data points: a lower chart (the full period is still shown on the time axis).
            local chartHeight = filled <= 2 and 160 or 200
            view.chart.Size(width, chartHeight)
            view.chart.title:SetText(text(isIncome and "financeHeadingIncomeChart" or "financeHeadingExpenseChart"))
            local any = view.draw(series, step)
            view.chart.empty.Set(not any and text(isIncome and "financeEmptyIncome" or "financeEmptyExpense") or nil)
            local values = isIncome and summary.income or summary.expense
            local height = math.max(140, countOf(values) * ui.CATEGORY_ROW + 58)
            view.categories:ClearAllPoints()
            view.categories:SetPoint("TOPLEFT", 0, -(top + chartHeight + 10))
            view.categories.Size(width, height)
            view.categories.title:SetText(text(isIncome and "financeHeadingIncomeSources" or "financeHeadingExpenseCategories"))
            view.drawCategories(values, summary.counts, isIncome and "+" or "-", total,
                text(isIncome and "financeEmptyIncome" or "financeEmptyExpense"))
            pane:SetHeight(top + chartHeight + 10 + height)
            body:SetHeight(pane:GetHeight())
    end
    sectionViews.transactions = function(ctx)
        local keys, period = ctx.keys, ctx.period
            filterMenu.Sync()
            local labels = { "financeColDate", "financeColCharacter", "financeColCategory", "financeColDescription", "financeColAmount" }
            local headerWidth = header:GetWidth()
            placeColumns(header, header.cells, headerWidth)
            for c = 1, 5 do header.cells[c]:SetText(text(labels[c])) end
            local rows = transactionsFor(keys, period, state.filter, (search:GetText() or ""):lower())
            local shown = math.min(#rows, 500)
            local rowWidth = math.max(1, txScroll:GetWidth())
            txContent:SetSize(rowWidth, math.max(1, shown * 22))
            txEmpty.Set(shown == 0 and text("financeEmptyTransactions") or nil)
            for i = 1, shown do
                local data = rows[i]
                local row = txRows[i]
                if not row then
                    row = CreateFrame("Button", nil, txContent)
                    row:SetHeight(22)
                    row.stripe = row:CreateTexture(nil, "BACKGROUND")
                    row.stripe:SetAllPoints()
                    row.active = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                    row.active:SetAllPoints()
                    row.active:SetColorTexture(0.55, 0.4, 0.08, 0.4)
                    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(14, 14)
                    row.cells = {}
                    for c = 1, 5 do row.cells[c] = ui.text(row, "GameFontHighlightSmall") end
                    row:SetScript("OnClick", function(self) state.transaction = self.data; refresh() end)
                    txRows[i] = row
                end
                row.data = data
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                row:SetWidth(rowWidth)
                row.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
                row.active:SetShown(state.transaction ~= nil and state.transaction.tx == data.tx)
                local category = finance.category(data.tx)
                placeColumns(row, row.cells, rowWidth)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", row, "LEFT", rowWidth * columns[3] + 2, 0)
                row.icon:SetTexture(categoryIcons[category] or UNKNOWN_ICON)
                local cells = { date("%d.%m.%Y %H:%M", data.tx.t), data.name,
                    text("financeCategory_" .. category) .. (data.tx.o and " *" or ""), data.tx.d or "", money(data.tx.a, true) }
                for c = 1, 5 do row.cells[c]:SetText(cells[c]) end
                row.cells[1]:SetTextColor(C.grey[1], C.grey[2], C.grey[3])
                row.cells[2]:SetTextColor(inventory.classColor(data.character))
                row.cells[3]:SetTextColor(0.9, 0.85, 0.7)
                row.cells[4]:SetTextColor(1, 1, 1)
                ui.color(row.cells[5], finance.neutral[category] and 0 or data.tx.a)
                row:Show()
            end
            for i = shown + 1, #txRows do txRows[i]:Hide() end
            recategorize:SetText(text("financeRecategorize"))
            recategorize:SetEnabled(state.transaction ~= nil)
    end

    -- Refresh ------------------------------------------------------------------------
    refresh = function()
        if not page:IsVisible() then dirty = true; return end
        dirty = false
        local keys = keysFor(state.selected)
        local period = range(state.period, customRange:GetText())
        sidebarTitle:SetHeaderText(text("bankCharacters"))
        tabs.Update(state.section)
        periodMenu.Sync()
        methodMenu.Sync()
        customRange:SetShown(state.period == "custom")
        local isTransactions = state.section == "transactions"
        bodyScroll:SetShown(not isTransactions)
        txPane:SetShown(isTransactions)
        for key, pane in pairs(panes) do pane:SetShown(key == state.section) end

        -- Character entries: name (class colour) + level, known gold below.
        local characters = inventory.db().characters
        wipe(wealthCache)
        totalMoney = 0
        for _, key in ipairs(allKeys()) do
            wealthCache[key] = finance.wealth(key, state.method)
            totalMoney = totalMoney + wealthCache[key].money
        end
        characterList.Refresh(ui.SIDEBAR_WIDTH - 14 - 24)

        local summary = finance.summary(keys, period)
        local w = { money = 0, bags = 0, bank = 0, total = 0, unvalued = 0 }
        local bestBag, bestBagValue, bestBank, bestBankValue, richest, richestValue
        for _, key in ipairs(keys) do
            local v = wealthCache[key] or finance.wealth(key, state.method)
            for field in pairs(w) do w[field] = w[field] + (v[field] or 0) end
            if v.bestBag and v.bestBagValue > (bestBagValue or 0) then bestBag, bestBagValue = v.bestBag, v.bestBagValue end
            if v.bestBank and v.bestBankValue > (bestBankValue or 0) then bestBank, bestBankValue = v.bestBank, v.bestBankValue end
            if v.total > (richestValue or -1) then richest, richestValue = key, v.total end
        end

        -- Status bar: price source, missing prices, data age, reconciliation.
        local parts, newest = {}, 0
        local source = priceSource()
        parts[#parts + 1] = source and text("financeStatusSource"):format(source) or text("financeStatusVendorOnly")
        parts[#parts + 1] = w.unvalued > 0 and ("|cffff9933" .. text("financeStatusUnvalued"):format(w.unvalued) .. "|r")
            or text("financeStatusComplete")
        for _, key in ipairs(keys) do
            local character = characters[key]
            newest = math.max(newest, character and character.bagsAt or 0, character and character.bank and character.bank.at or 0)
        end
        if newest > 0 then parts[#parts + 1] = text("financeStatusUpdated"):format(date("%d.%m. %H:%M", newest)) end
        if state.selected == inventory.currentKey() then
            local difference = finance.reconcile(finance.db().characters[state.selected], GetMoney())
            if difference then
                parts[#parts + 1] = difference == 0 and text("financeReconcileOk")
                    or ("|cffff9933" .. text("financeReconcileDiff"):format(money(difference, true)) .. "|r")
            end
        end
        status.Set(parts, text("financeMethod_" .. state.method))
        table.insert(status.tooltip, 2, text("financeMethodNote"):format(text("financeMethod_" .. state.method), w.unvalued))

        -- Explicit width from the page (a just re-anchored scroll frame reports a stale size).
        local width = math.max(300, page:GetWidth() - ui.SIDEBAR_WIDTH - 8 - 46 - 4)
        if watermark then watermark.Fit(width, page:GetHeight() - 30) end
        body:SetWidth(width)
        local figureLabels = { "financeFigureAvgProfit", "financeFigureAvgExpense", "financeFigureLargestIn",
            "financeFigureLargestOut", "financeFigureTopIncome", "financeFigureTopExpense", "financeFigureRichest" }
        local days = math.max(1, (period.to - period.from) / 86400)

        local ctx = { keys = keys, period = period, summary = summary, w = w, width = width, days = days,
            characters = characters, wealthCache = wealthCache, figureLabels = figureLabels, bestBag = bestBag,
            bestBagValue = bestBagValue, bestBank = bestBank, bestBankValue = bestBankValue, richest = richest }
        if state.section == "income" or state.section == "expense" then sectionViews.flow(ctx)
        else sectionViews[state.section](ctx) end
    end

    local previous = finance.onChange
    finance.onChange = function()
        if previous then previous() end
        if page:IsVisible() then refresh() else dirty = true end
    end
    inventory.onChange(function() if page:IsVisible() then refresh() else dirty = true end end)
    page:SetScript("OnShow", function() finance.resetValues(); refresh() end)
    -- Rebuild the layout only once the size has settled (no work per resize frame).
    local pending
    page:SetScript("OnSizeChanged", function()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function() pending = false; if page:IsVisible() then refresh() end end)
    end)
    page.refresh = refresh
    page.isDirty = function() return dirty end
end

StaticPopupDialogs["FOREVERCRAFT_CONFIRM_FINANCE_DELETE"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
    showAlert = true,
    OnAccept = function(_, key)
        local characters = finance.db().characters
        if key == ALL then wipe(characters) else characters[key] = nil end
        if finance.onChange then finance.onChange() end
    end,
}

function ledger.confirmFinanceReset(key)
    local character = key ~= ALL and inventory.db().characters[key]
    local message = key == ALL and text("financeResetConfirm")
        or text("financeResetCharacterConfirm"):format(character and character.name or key)
    StaticPopup_Show("FOREVERCRAFT_CONFIRM_FINANCE_DELETE", message, nil, key)
end
ledger.ALL = ALL
ledger.financeRetentions = retentions
ledger.financePeriods = periods

function addon.AttachFinance(root, closeOthers, nativeHeader)
    return ledger.attach(root, closeOthers, nativeHeader, "finance")
end

ledger.addPage("finance", "ledgerFinance", ledger.buildFinance, FINANCE_ICON)
ledger.pages[#ledger.pages].description = "navFinanceDesc"

SLASH_FOREVERCRAFTFINANCE1 = "/fcfinance"
SlashCmdList.FOREVERCRAFTFINANCE = function()
    if ledger.frame and ledger.frame:IsShown() then ledger.frame:Hide() else ledger.show("finance") end
end
