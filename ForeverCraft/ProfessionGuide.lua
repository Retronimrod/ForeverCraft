local _, addon = ...

local labels = {
    enUS = {
        open = "Guide", back = "Recipes", ranks = "Training ranks",
        trainers = "Trainers", requirements = "Requires skill %d and character level %d.",
        firstRank = "Learn the profession from a trainer.",
        trainerOnly = "You learn this rank from a trainer. No book or item required.",
        Horde = "Horde", Alliance = "Alliance",
        names = { "Apprentice", "Journeyman", "Expert", "Artisan" },
    },
    deDE = {
        open = "Guide", back = "Rezepte", ranks = "Ausbildungsränge",
        trainers = "Berufslehrer", requirements = "Benötigt Berufsskill %d und Charakterstufe %d.",
        firstRank = "Lerne den Beruf bei einem Berufslehrer.",
        trainerOnly = "Diesen Rang lernst du beim Lehrer. Du brauchst kein Buch oder Item.",
        Horde = "Horde", Alliance = "Allianz",
        names = { "Lehrling", "Geselle", "Experte", "Fachmann" },
    },
}

local function strings()
    local locale = ForeverCraftDB and ForeverCraftDB.language
    return labels[(not locale or locale == "auto") and GetLocale() or locale] or labels.enUS
end

local function box(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("Professions-Recipe-Background")
    background:SetAllPoints()
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAtlas("common-insideframe")
    border:SetAllPoints()
    return frame
end

local function text(parent, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    return label
end

function addon.AttachProfessionGuide(root, page, closeOtherViews)
    local toggle = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    toggle:SetSize(70, 21)
    toggle:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -36)
    toggle:SetFrameLevel(page:GetFrameLevel() + 20)
    toggle:Hide()

    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -73)
    panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -10, 8)
    panel:SetFrameLevel(page:GetFrameLevel() + 30)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:Hide()
    local base = panel:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints()
    base:SetColorTexture(0.09, 0.065, 0.046, 1)

    local left, right = box(panel), box(panel)
    left:SetPoint("TOPLEFT", 3, -3)
    left:SetPoint("BOTTOMLEFT", 3, 3)
    left:SetWidth(213)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 7, 0)
    right:SetPoint("BOTTOMRIGHT", -3, 3)

    local leftHeading = text(left, "GameFontNormalLarge")
    leftHeading:SetPoint("TOPLEFT", 17, -15)
    local rightHeading = text(right, "GameFontNormalLarge")
    rightHeading:SetPoint("TOPLEFT", 17, -15)

    local scroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 17, -45)
    scroll:SetPoint("BOTTOMRIGHT", -30, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local details = text(content, "GameFontHighlight")
    details:SetPoint("TOPLEFT")
    details:SetPoint("TOPRIGHT")

    local guide, selected
    local rankButtons = {}
    local function refreshDetails(resetScroll)
        if not guide or not selected then return end
        local L = strings()
        local rank = guide.ranks[selected]
        leftHeading:SetText(L.ranks)
        rightHeading:SetText(L.trainers)
        toggle:SetText(L.back)
        for index, control in ipairs(rankButtons) do
            local entry = guide.ranks[index]
            control:SetShown(entry ~= nil)
            if entry then
                control:SetText(("%d–%d  %s"):format(entry.minimum, entry.cap, L.names[index]))
                control:SetEnabled(index ~= selected)
            end
        end

        local lines = { ("|cffffd100%s · %d–%d|r"):format(L.names[selected], rank.minimum, rank.cap), "" }
        lines[#lines + 1] = rank.requiresSkill
            and L.requirements:format(rank.requiresSkill, rank.requiresLevel) or L.firstRank
        lines[#lines + 1] = L.trainerOnly
        local faction = UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
        local other = faction == "Horde" and "Alliance" or "Horde"
        for _, side in ipairs({ faction, other }) do
            lines[#lines + 1] = ""
            lines[#lines + 1] = "|cffffd100" .. L[side] .. "|r"
            for _, trainer in ipairs(guide.trainers[rank.trainers][side]) do
                local place = trainer[L == labels.deDE and 3 or 2]
                local coordinates = trainer[4] and (" · " .. trainer[4]) or ""
                lines[#lines + 1] = trainer[1] .. " — " .. place .. coordinates
            end
        end
        content:SetWidth(math.max(1, scroll:GetWidth()))
        details:SetText(table.concat(lines, "\n"))
        content:SetHeight(math.max(1, details:GetStringHeight() + 12))
        if resetScroll then scroll:SetVerticalScroll(0) end
    end

    scroll:HookScript("OnSizeChanged", function()
        if panel:IsShown() then refreshDetails() end
    end)

    for index = 1, #labels.enUS.names do
        local control = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        control:SetHeight(28)
        control:SetPoint("TOPLEFT", 13, -48 - (index - 1) * 36)
        control:SetPoint("TOPRIGHT", -13, -48 - (index - 1) * 36)
        control:SetScript("OnClick", function()
            selected = index
            refreshDetails(true)
        end)
        rankButtons[index] = control
    end

    function addon.CloseProfessionGuide()
        panel:Hide()
        toggle:SetText(strings().open)
    end

    function addon.RefreshProfessionGuide()
        local info = page:IsVisible() and Professions.GetProfessionInfo()
        local id = info and (info.parentProfessionID or info.professionID)
        local active = id and addon.professionGuides[id]
        if guide ~= active then addon.CloseProfessionGuide() end
        guide = active
        toggle:SetShown(guide ~= nil)
        if panel:IsShown() then refreshDetails() else toggle:SetText(strings().open) end
    end

    toggle:SetScript("OnClick", function()
        if panel:IsShown() then addon.CloseProfessionGuide(); return end
        if not guide or InCombatLockdown() then return end
        closeOtherViews()
        local info = Professions.GetProfessionInfo()
        local skill = info and info.skillLevel or 0
        selected = 1
        for index, rank in ipairs(guide.ranks) do
            if rank.requiresSkill and skill >= rank.requiresSkill then selected = index end
        end
        panel:Show()
        refreshDetails(true)
    end)
    page:HookScript("OnShow", addon.RefreshProfessionGuide)
    page:HookScript("OnHide", addon.RefreshProfessionGuide)
    if page.Refresh then hooksecurefunc(page, "Refresh", addon.RefreshProfessionGuide) end
    root:HookScript("OnHide", addon.CloseProfessionGuide)
    addon.RefreshProfessionGuide()
end
