local _, addon = ...

-- Shared ForeverCraft UI components (Blizzard look: dark recessed panels, bronze edges,
-- gold headings). Only templates/textures confirmed on the WoW Forever client are used.
-- Sizes are always computed from explicit widths passed in (never read back from frames
-- that were just re-anchored, whose size the client only updates on the next layout).

local ui = {}
addon.ui = ui
ui.colors = {
    gold = { 1, 0.82, 0 }, lightGold = { 1, 0.93, 0.6 }, green = { 0.35, 0.85, 0.35 },
    red = { 0.92, 0.32, 0.27 }, white = { 1, 1, 1 }, grey = { 0.68, 0.68, 0.68 },
    bronze = { 0.57, 0.41, 0.24 }, blue = { 0.38, 0.62, 1 }, violet = { 0.72, 0.47, 1 }, orange = { 1, 0.6, 0.2 },
}
-- Chart series colours (muted, like Blizzard's status bars).
ui.barColors = {
    income = { 0.16, 0.6, 0.34 }, expense = { 0.62, 0.13, 0.15 }, total = { 0.86, 0.64, 0.2 },
    bags = { 0.2, 0.36, 0.72 }, bank = { 0.5, 0.33, 0.68 }, money = { 0.92, 0.76, 0.26 },
}
ui.SIDEBAR_WIDTH = 196
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local TRACK = "Interface\\AddOns\\ForeverCraft\\Art\\CraftBarTrack"
-- Nine-slice border as used by ForeverCraft's craft progress frame (corners keep their size).
local PANEL_BACKDROP = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local BACKDROP = { bgFile = WHITE, edgeFile = EDGE, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }

-- Content panel: professions background texture inside a nine-slice backdrop border
-- (bronze; gold when highlighted). The background sits inside the border insets, so
-- there are no gaps and no stretched corners at any size.
function ui.panel(parent, highlighted)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop(PANEL_BACKDROP)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetPoint("TOPLEFT", 3, -3)
    frame.background:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.background:SetAtlas("Professions-Recipe-Background", false)
    ui.highlight(frame, highlighted)
    return frame
end

function ui.highlight(frame, highlighted)
    if highlighted then frame:SetBackdropBorderColor(1, 0.82, 0.3, 1)
    else frame:SetBackdropBorderColor(0.78, 0.63, 0.41, 1) end
end

-- Section header of the professions window (ProfessionsRecipeListCategoryTemplate), as
-- part of a panel. Fallback: plain gold label.
function ui.sectionHeading(parent)
    local heading
    if _G.ProfessionsRecipeListCategoryMixin then
        heading = CreateFrame("Button", nil, parent, "ProfessionsRecipeListCategoryTemplate")
        heading:EnableMouse(false)
        heading.RankBar:Hide()
        heading:GetCollapseButton():Hide()
    else
        heading = CreateFrame("Frame", nil, parent)
        local label = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 5, 0)
        function heading.SetHeaderText(_, value) label:SetText(value) end
    end
    heading:SetPoint("TOPLEFT", 6, -6)
    heading:SetPoint("TOPRIGHT", -6, -6)
    heading:SetHeight(25)
    return heading
end

-- Status-bar style fill: Blizzard UI-StatusBar texture tinted with the series colour,
-- lighter top edge, darker bottom edge and a fine dark outline. vertical rotates the
-- texture so the shading runs across the bar.
function ui.barFill(parent, vertical)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bar:SetBackdropBorderColor(0, 0, 0, 0.55)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    bar.fill:SetTexture(STATUSBAR)
    if vertical then bar.fill:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0) end
    bar.top = bar:CreateTexture(nil, "OVERLAY")
    bar.top:SetColorTexture(1, 1, 1, 0.28)
    bar.bottom = bar:CreateTexture(nil, "OVERLAY")
    bar.bottom:SetColorTexture(0, 0, 0, 0.35)
    if vertical then
        bar.top:SetPoint("TOPLEFT", 1, -1)
        bar.top:SetPoint("BOTTOMLEFT", 1, 1)
        bar.top:SetWidth(1)
        bar.bottom:SetPoint("TOPRIGHT", -1, -1)
        bar.bottom:SetPoint("BOTTOMRIGHT", -1, 1)
        bar.bottom:SetWidth(1)
    else
        bar.top:SetPoint("TOPLEFT", 1, -1)
        bar.top:SetPoint("TOPRIGHT", -1, -1)
        bar.top:SetHeight(1)
        bar.bottom:SetPoint("BOTTOMLEFT", 1, 1)
        bar.bottom:SetPoint("BOTTOMRIGHT", -1, 1)
        bar.bottom:SetHeight(1)
    end
    function bar.Color(color, alpha)
        bar.fill:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    end
    return bar
end

-- Recessed track behind horizontal bars: ForeverCraft's CraftBarTrack in three slices
-- (caps keep their width, only the middle stretches).
function ui.barTrack(parent, height)
    local track = CreateFrame("Frame", nil, parent)
    track:SetHeight(height)
    local function slice(left, right)
        local texture = track:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(TRACK)
        texture:SetTexCoord(left / 32, right / 32, 0, 24 / 32)
        texture:SetPoint("TOP")
        texture:SetPoint("BOTTOM")
        return texture
    end
    local leftCap, middle, rightCap = slice(0, 6), slice(6, 26), slice(26, 32)
    leftCap:SetWidth(4)
    leftCap:SetPoint("LEFT")
    rightCap:SetWidth(4)
    rightCap:SetPoint("RIGHT")
    middle:SetPoint("LEFT", leftCap, "RIGHT")
    middle:SetPoint("RIGHT", rightCap, "LEFT")
    track.bar = ui.barFill(track)
    track.bar:SetPoint("TOPLEFT", 2, -2)
    track.bar:SetPoint("BOTTOMLEFT", 2, 2)
    -- fraction 0..1 of the inner width; 100 % fills the whole track.
    function track.Set(fraction, color, width)
        local inner = width - 4
        track.bar:SetWidth(math.max(2, inner * math.min(1, fraction)))
        track.bar.Color(color)
        track.bar:SetShown(fraction > 0)
    end
    return track
end

-- Subtle thematic illustration bottom right (like the disenchant watermark): behind all
-- controls, no mouse handling, low opacity. file is a texture in ForeverCraft\Art or nil.
function ui.watermark(parent, file)
    if not file then return nil end
    local texture = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    texture:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\" .. file)
    texture:SetPoint("BOTTOMRIGHT", -6, 26)
    texture:SetVertexColor(0.74, 0.58, 0.44, 0.12)
    function texture.Fit(width, height)
        local w = math.max(1, math.min(width * 0.55, height - 40, 420))
        texture:SetSize(w, w * 0.5)
    end
    return texture
end

function ui.heading(parent, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    font:SetJustifyH("LEFT")
    font:SetWordWrap(false)
    font:SetTextColor(1, 0.82, 0)
    return font
end

function ui.text(parent, template, justify, color)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    font:SetJustifyH(justify or "LEFT")
    font:SetWordWrap(false)
    if color then font:SetTextColor(color[1], color[2], color[3]) end
    return font
end

function ui.divider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.57, 0.41, 0.24, 0.55)
    return line
end

function ui.color(font, value)
    local c = value > 0 and ui.colors.green or value < 0 and ui.colors.red or ui.colors.white
    font:SetTextColor(c[1], c[2], c[3])
end

-- Sets text with the largest font that fits maxWidth (never truncates with "...").
local fitFonts = { "GameFontHighlightHuge", "GameFontHighlightLarge", "GameFontHighlight", "GameFontHighlightSmall" }
function ui.fit(font, value, maxWidth, fonts)
    font:SetText(value)
    for _, object in ipairs(fonts or fitFonts) do
        font:SetFontObject(object)
        if font:GetStringWidth() <= maxWidth then return true end
    end
    return false
end

-- Summary tile: icon + label on top, amount below (left aligned, fitted, never cut).
-- Optional progress bar (e.g. used bank slots).
function ui.tile(parent, icon, highlighted, small)
    local tile = ui.panel(parent, highlighted)
    tile.small = small
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetSize(small and 18 or 22, small and 18 or 22)
    tile.icon:SetPoint("TOPLEFT", 10, -9)
    tile.icon:SetTexture(icon)
    tile.label = ui.text(tile, "GameFontNormalSmall")
    tile.label:SetPoint("LEFT", tile.icon, "RIGHT", 7, 0)
    tile.label:SetPoint("RIGHT", tile, "RIGHT", -8, 0)
    tile.value = ui.text(tile, "GameFontHighlightHuge")
    tile.value:SetPoint("BOTTOMLEFT", 12, small and 8 or 11)
    tile:EnableMouse(true)
    tile:SetScript("OnEnter", function(self)
        if not self.hint then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.label:GetText() or "")
        GameTooltip:AddLine(self.hint, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function tile.Set(label, value, color, hint)
        tile.label:SetText(label)
        tile.hint = hint
        local width = (tile.width or tile:GetWidth()) - 24
        ui.fit(tile.value, value, width, small and { "GameFontHighlightLarge", "GameFontHighlight", "GameFontHighlightSmall" } or nil)
        local c = color or ui.colors.white
        tile.value:SetTextColor(c[1], c[2], c[3])
    end
    function tile.Progress(fraction)
        if not tile.track then
            tile.track = tile:CreateTexture(nil, "ARTWORK")
            tile.track:SetHeight(4)
            tile.track:SetPoint("BOTTOMLEFT", 12, 5)
            tile.track:SetPoint("BOTTOMRIGHT", -12, 5)
            tile.track:SetColorTexture(1, 1, 1, 0.08)
            tile.bar = tile:CreateTexture(nil, "OVERLAY")
            tile.bar:SetHeight(4)
            tile.bar:SetPoint("BOTTOMLEFT", tile.track, "BOTTOMLEFT")
            tile.bar:SetColorTexture(1, 0.82, 0, 0.8)
        end
        tile.track:SetShown(fraction ~= nil)
        tile.bar:SetShown(fraction ~= nil and fraction > 0)
        if fraction then tile.bar:SetWidth(math.max(1, ((tile.width or tile:GetWidth()) - 24) * math.min(1, fraction))) end
    end
    return tile
end

-- Places tiles in one row, or a 2-column grid when tiles would get narrower than
-- minWidth. Returns the used height.
function ui.tileGrid(tiles, parent, top, width, height, minWidth)
    local gap = 8
    local perRow = #tiles
    while perRow > 1 and (width - gap * (perRow - 1)) / perRow < (minWidth or 150) do
        perRow = perRow == 4 and 2 or perRow - 1
    end
    local tileWidth = (width - gap * (perRow - 1)) / perRow
    for i, tile in ipairs(tiles) do
        local column, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        tile:ClearAllPoints()
        tile.width = tileWidth
        tile:SetSize(tileWidth, height)
        tile:SetPoint("TOPLEFT", parent, "TOPLEFT", column * (tileWidth + gap), -(top + row * (height + gap)))
    end
    local rows = math.ceil(#tiles / perRow)
    return rows * height + (rows - 1) * gap
end

function ui.empty(parent, icon)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(24, 24)
    frame.icon:SetPoint("CENTER", 0, 10)
    frame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Note_01")
    frame.icon:SetDesaturated(true)
    frame.icon:SetAlpha(0.45)
    frame.message = ui.text(frame, "GameFontDisable", "CENTER")
    frame.message:SetPoint("TOP", frame.icon, "BOTTOM", 0, -6)
    frame.message:SetPoint("LEFT", 10, 0)
    frame.message:SetPoint("RIGHT", -10, 0)
    frame.message:SetWordWrap(true)
    frame:Hide()
    function frame.Set(message)
        frame.message:SetText(message or "")
        frame:SetShown(message ~= nil)
    end
    return frame
end

-- Chart box: framed area, gold title, plot area with guide lines, value scale and an
-- empty state. box.Size(w, h) sets the box and records the plot size explicitly.
function ui.chart(parent, title, axes)
    local box = ui.panel(parent)
    box.axes = axes
    local heading = ui.sectionHeading(box)
    box.heading = heading
    box.title = { SetText = function(_, value) heading:SetHeaderText(value or "") end }
    box.title:SetText(title)
    box.plot = CreateFrame("Frame", nil, box)
    box.plotBackground = box.plot:CreateTexture(nil, "BACKGROUND", nil, -1)
    box.plotBackground:SetAllPoints()
    box.plotBackground:SetColorTexture(0.05, 0.035, 0.02, 0.35)
    box.yLabels, box.xLabels = {}, {}
    box.guides = {}
    for i = 1, 4 do
        local guide = box.plot:CreateTexture(nil, "BACKGROUND")
        guide:SetHeight(1)
        guide:SetColorTexture(0.85, 0.7, 0.45, i == 1 and 0.3 or 0.1)
        box.guides[i] = guide
    end
    box.scale = ui.text(box, "GameFontDisableSmall", "RIGHT")
    box.scale:SetPoint("TOPRIGHT", -14, -12)
    box.empty = ui.empty(box.plot)
    local TOP, BOTTOM = 40, axes and 28 or 14
    -- Plot area right of the value labels; left = measured width of the longest label.
    local function place(left)
        box.plotLeft = left
        box.plot:ClearAllPoints()
        box.plot:SetPoint("TOPLEFT", left, -TOP)
        box.plot:SetPoint("BOTTOMRIGHT", -14, BOTTOM)
        box.plotWidth = (box.width or 0) - left - 14
        box.plotHeight = (box.height or 0) - TOP - BOTTOM
    end
    function box.Size(width, height)
        box:SetSize(width, height)
        box.width, box.height = width, height
        place(14)
    end
    function box.Layout(showGuides)
        for i, guide in ipairs(box.guides) do
            guide:ClearAllPoints()
            local y = (box.plotHeight or 0) * (i - 1) / 3
            guide:SetPoint("BOTTOMLEFT", box.plot, "BOTTOMLEFT", 0, y)
            guide:SetPoint("BOTTOMRIGHT", box.plot, "BOTTOMRIGHT", 0, y)
            guide:SetShown(showGuides ~= false)
        end
    end
    -- Value labels at the guide lines (never truncated: the plot moves right instead).
    -- Call before drawing, because it changes plotWidth.
    function box.YAxis(values)
        local widest = 0
        for i = 1, 4 do
            local font = box.yLabels[i]
            if not font then
                font = ui.text(box, "GameFontDisableSmall", "RIGHT")
                box.yLabels[i] = font
            end
            font:SetText(values and values[i] or "")
            font:SetShown(values ~= nil)
            if values then widest = math.max(widest, font:GetStringWidth()) end
        end
        place(values and math.ceil(widest) + 22 or 14)
        for i = 1, 4 do
            local font = box.yLabels[i]
            font:ClearAllPoints()
            font:SetPoint("RIGHT", box, "BOTTOMLEFT", box.plotLeft - 6, BOTTOM + (box.plotHeight or 0) * (i - 1) / 3)
        end
    end
    function box.XAxis(times)
        for i, entry in ipairs(times or {}) do
            local font = box.xLabels[i]
            if not font then
                font = ui.text(box, "GameFontDisableSmall", "CENTER")
                box.xLabels[i] = font
            end
            font:ClearAllPoints()
            font:SetPoint("TOP", box.plot, "BOTTOMLEFT", entry[1], -6)
            font:SetText(entry[2])
            font:Show()
        end
        for i = #(times or {}) + 1, #box.xLabels do box.xLabels[i]:Hide() end
    end
    return box
end

-- Category rows (income sources / expense categories), shared by all finance views:
--   [icon] name ......................... amount
--          [track ===================]   96 %
-- 100 % fills the whole track. Returns the used height.
ui.CATEGORY_ROW = 42
function ui.categoryBars(box, color, icons, label, fallbackIcon)
    local rows = {}
    return function(list, total, emptyMessage)
        local width = box.plotWidth or 200
        for i, entry in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, box.plot)
                row:SetHeight(ui.CATEGORY_ROW - 6)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(18, 18)
                row.icon:SetPoint("TOPLEFT", 0, 0)
                row.amount = ui.text(row, "GameFontHighlightSmall", "RIGHT")
                row.amount:SetPoint("TOPRIGHT", 0, -3)
                row.name = ui.text(row, "GameFontHighlightSmall")
                row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -3)
                row.track = ui.barTrack(row, 14)
                row.track:SetPoint("TOPLEFT", 24, -21)
                row.percent = ui.text(row, "GameFontNormalSmall", "RIGHT")
                row.percent:SetPoint("TOPRIGHT", 0, -22)
                row:EnableMouse(true)
                row:SetScript("OnEnter", function(self)
                    if self.onEnter then self.onEnter(self) end
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[i] = row
            end
            local share = total > 0 and entry.amount / total or 0
            row.entry = entry
            row.onEnter = entry.tooltip
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ui.CATEGORY_ROW - 2)
            row:SetWidth(width)
            row.icon:SetTexture(icons[entry.category] or fallbackIcon)
            row.amount:SetText(entry.text)
            row.name:SetWidth(math.max(40, width - 24 - row.amount:GetStringWidth() - 10))
            row.name:SetText(label(entry.category))
            local trackWidth = math.max(40, width - 24 - 46)
            row.track:SetWidth(trackWidth)
            row.track.Set(share, color, trackWidth)
            row.percent:SetText(("%.0f %%"):format(share * 100))
            row:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        box.empty.Set(#list == 0 and emptyMessage or nil)
        return #list * ui.CATEGORY_ROW
    end
end

-- Bar fill with a subtle vertical gradient (SetGradient/CreateColor as in SkillScale.lua).
function ui.gradient(texture, color)
    texture:SetColorTexture(1, 1, 1, 1)
    if texture.SetGradient and CreateColor then
        texture:SetGradient("VERTICAL", CreateColor(color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, 0.95),
            CreateColor(color[1], color[2], color[3], 0.95))
    else
        texture:SetColorTexture(color[1], color[2], color[3], 0.9)
    end
end

-- Blizzard top tabs (PanelTopTabButtonTemplate as used by other addons on this client).
function ui.tabs(parent, keys, label, onSelect)
    local tabs = {}
    for i, key in ipairs(keys) do
        local tab = CreateFrame("Button", nil, parent, "PanelTopTabButtonTemplate")
        tab.key = key
        tab:SetScript("OnClick", function() onSelect(key) end)
        if i == 1 then tab:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 6, -2)
        else tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 2, 0) end
        tabs[i] = tab
    end
    function tabs.Update(selected)
        for _, tab in ipairs(tabs) do
            tab:SetText(label(tab.key))
            PanelTemplates_TabResize(tab, 15, nil, 70)
            if tab.key == selected then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    return tabs
end

-- Status bar: grey secondary text; full details in a tooltip when it does not fit.
function ui.statusBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(18)
    local line = ui.divider(bar)
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    bar.text = ui.text(bar, "GameFontDisableSmall")
    bar.text:SetPoint("LEFT", 4, -2)
    bar.text:SetPoint("RIGHT", -4, -2)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if not self.tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        for i, entry in ipairs(self.tooltip) do
            if i == 1 then GameTooltip:SetText(entry) else GameTooltip:AddLine(entry, 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function bar.Set(parts, title)
        bar.text:SetText(table.concat(parts, "  ·  "))
        bar.tooltip = { title or "" }
        for _, part in ipairs(parts) do bar.tooltip[#bar.tooltip + 1] = part end
    end
    return bar
end

-- Right-click context menu (MenuUtil as used by other addons on this client).
function ui.contextMenu(owner, entries)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, entry in ipairs(entries) do root:CreateButton(entry[1], entry[2]) end
    end)
end

-- Character list shared by bank and finances: class icon, name (class colour, wraps to a
-- second line instead of being cut), level right aligned, module-specific line below.
-- opts: entries() -> list of keys incl. "*all"; info(key) -> name, level, detail, character;
-- selected() -> key; select(key); menu(key) -> context menu entries or nil.
function ui.characterList(parent, opts)
    local list = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    addon.HideUnusedScrollbar(scroll)
    local rows = {}
    function list.Refresh(width)
        local keys, y = opts.entries(), 0
        width = width or (ui.SIDEBAR_WIDTH - 40)
        for i, key in ipairs(keys) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", nil, content)
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row.active = row:CreateTexture(nil, "BACKGROUND")
                row.active:SetAllPoints()
                row.active:SetColorTexture(0.55, 0.4, 0.08, 0.35)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(24, 24)
                row.icon:SetPoint("TOPLEFT", 4, -6)
                row.level = ui.text(row, "GameFontHighlightSmall", "RIGHT", ui.colors.grey)
                row.level:SetPoint("TOPRIGHT", -4, -6)
                row.name = ui.text(row, "GameFontNormal")
                row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
                row.name:SetWordWrap(true)
                row.detail = ui.text(row, "GameFontHighlightSmall")
                row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
                row:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then
                        local entries = opts.menu and opts.menu(self.key)
                        if entries then ui.contextMenu(self, entries) end
                        return
                    end
                    opts.select(self.key)
                end)
                row:SetScript("OnEnter", function(self)
                    if not self.realm then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.name:GetText() or "")
                    GameTooltip:AddLine(self.realm, 0.68, 0.68, 0.68)
                    if opts.menuHint then GameTooltip:AddLine(opts.menuHint(), 0.68, 0.68, 0.68, true) end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[i] = row
            end
            local name, level, detail, character = opts.info(key)
            row.key, row.realm = key, character and character.realm
            row.active:SetShown(opts.selected() == key)
            local coords = character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
            if coords then
                row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                row.icon:SetTexCoord(unpack(coords))
            else
                row.icon:SetTexture(opts.allIcon)
                row.icon:SetTexCoord(0, 1, 0, 1)
            end
            row.level:SetText(level or "")
            local nameWidth = width - 38 - (level and 26 or 4)
            row.name:SetWidth(nameWidth)
            row.name:SetText(name)
            local color = character and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 0.82, color and color.b or 0)
            row.detail:SetWidth(width - 38)
            row.detail:SetText(detail or "")
            local height = math.max(44, 12 + row.name:GetStringHeight() + 2 + row.detail:GetStringHeight() + 8)
            row:SetSize(width, height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + height + 2
            row:Show()
        end
        for i = #keys + 1, #rows do rows[i]:Hide() end
        content:SetSize(width, math.max(1, y))
    end
    return list
end

-- Navigation tooltip: module name, short description, key binding, unavailable reason.
function ui.navTooltip(owner, title, description, binding, unavailable)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if description then GameTooltip:AddLine(description, 1, 1, 1, true) end
    if binding then GameTooltip:AddLine(binding, 0.68, 0.68, 0.68) end
    if unavailable then GameTooltip:AddLine(unavailable, 1, 0.3, 0.25, true) end
    GameTooltip:Show()
end

-- Professions side navigation as one rail attached flush to the window's right edge:
-- one continuous bronze-edged background exactly as tall as its tabs (no empty area),
-- starting below the close button. All side tabs (Blizzard's and ForeverCraft's) share
-- one size and spacing; the scale shrinks when they would not fit the window height.
-- The window's clamp rect includes the rail so it always stays on screen.
function ui.layoutRail(root, tabs)
    local first = tabs[1]
    if not first then return end
    local rail = root.ForeverCraftRail
    if not rail then
        rail = CreateFrame("Frame", nil, root, "BackdropTemplate")
        rail:SetBackdrop(BACKDROP)
        rail:SetBackdropColor(0.16, 0.11, 0.07, 0.96)
        rail:SetBackdropBorderColor(0.57, 0.41, 0.24, 1)
        root.ForeverCraftRail = rail
    end
    local top, gap = 30, 2
    local tabHeight, tabWidth = first:GetHeight() or 50, first:GetWidth() or 50
    local available = (root:GetHeight() or 600) - top - 16
    local scale = math.max(0.55, math.min(0.78, available / math.max(1, (tabHeight + gap) * #tabs + 12)))
    local railWidth = tabWidth * scale + 10
    rail:ClearAllPoints()
    rail:SetPoint("TOPLEFT", root, "TOPRIGHT", -2, -top)
    rail:SetSize(railWidth, (tabHeight + gap) * scale * #tabs - gap * scale + 12)
    rail:SetFrameLevel(math.max(0, first:GetFrameLevel() - 1))
    for i, tab in ipairs(tabs) do
        tab:SetScale(scale)
        tab:ClearAllPoints()
        if i == 1 then tab:SetPoint("TOPLEFT", rail, "TOPLEFT", 5 / scale, -6 / scale)
        else tab:SetPoint("TOPLEFT", tabs[i - 1], "BOTTOMLEFT", 0, -gap) end
    end
    if root.SetClampRectInsets then root:SetClampRectInsets(0, railWidth, 0, 0) end
end
