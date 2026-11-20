local _, addon = ...

local labels = {
    enUS = {
        open = "Profession guide", back = "Back to recipes", navigation = "Guide topics", other = "Other", training = "Training",
        overview = "Profession guides", backOverview = "Back to overview",
        professions = "Professions", allProfessions = "All professions", neutral = "Both factions", guideTitle = "%s · Training",
        skillOnly = "Requires skill %d.", book = "Buy and read %s.",
        quest = "Complete the quest %s.",
        trainers = "Trainers", requirements = "Requires skill %d and character level %d.",
        firstRank = "Learn the profession from a trainer.",
        trainerOnly = "You learn this rank from a trainer. No book or item required.",
        Horde = "Horde", Alliance = "Alliance",
        names = { "Apprentice", "Journeyman", "Expert", "Artisan" },
    },
    deDE = {
        open = "Berufs-Guide", back = "Zu den Rezepten", navigation = "Guide-Themen", other = "Sonstiges", training = "Ausbildung",
        overview = "Berufs-Guides", backOverview = "Zur Übersicht",
        professions = "Berufe", allProfessions = "Alle Berufe", neutral = "Beide Fraktionen", guideTitle = "%s · Ausbildung",
        skillOnly = "Benötigt Berufsskill %d.", book = "Kaufe und lies „%s“.",
        quest = "Schließe die Quest „%s“ ab.",
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
    local headerSpace = 76
    toggle:SetSize(70 + headerSpace, 28)
    toggle:SetPoint("RIGHT", root, "TOPRIGHT", -16, -49)
    local icon = toggle:CreateTexture(nil, "OVERLAY")
    icon:SetSize(19, 19)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    local toggleLabel = toggle:GetFontString()
    toggleLabel:ClearAllPoints()
    toggleLabel:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    toggleLabel:SetPoint("RIGHT", toggle, "RIGHT", -5, 0)
    toggleLabel:SetJustifyH("CENTER")
    toggle:SetFrameLevel(page:GetFrameLevel() + 20)
    toggle:Hide()

    local bookPage = root.BookPage
    if not bookPage then return end
    local overviewToggle = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    overviewToggle:SetSize(134, 21)
    overviewToggle:SetPoint("TOPRIGHT", root, "TOPRIGHT", -66, -3)
    local close = root.CloseButton
    if close then
        overviewToggle:SetFrameStrata(close:GetFrameStrata())
        overviewToggle:SetFrameLevel(close:GetFrameLevel() + 2)
    else
        overviewToggle:SetFrameLevel(root:GetFrameLevel() + 20)
    end
    overviewToggle:Hide()

    local panel = CreateFrame("Frame", nil, root)
    panel:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -73)
    panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -10, 8)
    panel:SetFrameStrata("DIALOG")
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
    local artwork = right:CreateTexture(nil, "BACKGROUND", nil, 1)
    artwork:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\WelcomeWorkshop")
    artwork:SetPoint("BOTTOMRIGHT", -15, 14)
    artwork:SetVertexColor(0.74, 0.58, 0.44, 0.23)
    local function sizeArtwork()
        local width = math.min(480, right:GetWidth() * 0.60, right:GetHeight() * 0.72)
        artwork:SetSize(math.max(1, width), math.max(1, width))
    end
    right:HookScript("OnSizeChanged", sizeArtwork)
    sizeArtwork()

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
    local function navigationItem(y)
        local item = CreateFrame("Button", nil, left)
        item:SetPoint("TOPLEFT", 13, y)
        item:SetPoint("TOPRIGHT", -13, y)
        item:SetHeight(28)
        item.trim = item:CreateTexture(nil, "BACKGROUND")
        item.trim:SetAllPoints()
        item.trim:SetColorTexture(0.77, 0.52, 0.22, 1)
        local fill = item:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(0.28, 0.17, 0.045, 1)
        item.label = text(item, "GameFontNormal")
        item.label:SetPoint("LEFT", 10, 0)
        return item
    end
    local function navigationHeader(y)
        local heading
        if _G.ProfessionsRecipeListCategoryMixin then
            heading = CreateFrame("Button", nil, left, "ProfessionsRecipeListCategoryTemplate")
            heading:EnableMouse(false)
            heading.RankBar:Hide()
            heading:GetCollapseButton():Hide()
        else
            heading = CreateFrame("Frame", nil, left)
            local label = text(heading, "GameFontNormal")
            label:SetPoint("LEFT", 6, 0)
            function heading:SetHeaderText(value) label:SetText(value) end
        end
        heading:SetHeight(23)
        heading:SetPoint("TOPLEFT", 13, y)
        heading:SetPoint("TOPRIGHT", -13, y)
        return heading
    end
    local professionHeader = navigationHeader(-45)
    local training = navigationItem(-71)
    local otherHeader = navigationHeader(-106)
    local allProfessions = navigationItem(-132)
    local disclosure = text(allProfessions, "GameFontNormal")
    disclosure:SetPoint("RIGHT", -10, 0)
    local guide, recipeGuide, overviewMode, overviewCard, showAll
    local expanded, sections, professions = {}, {}, {}
    local trainingGuideIDs = {171, 186, 185, 129, 356, 202, 182, 393, 165, 164, 197, 333}

    local function trainerDetails(L, rank)
        local source = rank.source or guide.trainers[rank.trainers]
        local language = L == labels.deDE and 2 or 1
        local lines = {}
        if rank.requiresSkill then
            lines[1] = rank.requiresLevel and L.requirements:format(rank.requiresSkill, rank.requiresLevel)
                or L.skillOnly:format(rank.requiresSkill)
        end
        if source.item then
            lines[#lines + 1] = L.book:format(source.item[language])
        elseif source.quest then
            lines[#lines + 1] = L.quest:format(source.quest[language])
        else
            lines[#lines + 1] = rank.requiresSkill and L.trainerOnly or L.firstRank
        end
        local faction = UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
        local other = faction == "Horde" and "Alliance" or "Horde"
        for _, side in ipairs({ faction, other, "Neutral" }) do
            if source[side] then
                lines[#lines + 1] = ""
                lines[#lines + 1] = "|cffffd100" .. (side == "Neutral" and L.neutral or L[side]) .. "|r"
                for _, trainer in ipairs(source[side]) do
                    local place = trainer[language + 1]
                    local coordinates = trainer[4] and (" · " .. trainer[4]) or ""
                    lines[#lines + 1] = trainer[1] .. " — " .. place .. coordinates
                end
            end
        end
        if source.note then
            lines[#lines + 1] = ""
            lines[#lines + 1] = source.note[language]
        end
        return table.concat(lines, "\n")
    end

    local function refreshDetails(resetScroll)
        if not guide then return end
        local L = strings()
        local language = L == labels.deDE and 2 or 1
        leftHeading:SetText(overviewMode and L.professions or L.navigation)
        professionHeader:SetShown(not overviewMode)
        otherHeader:SetShown(not overviewMode)
        if recipeGuide then professionHeader:SetHeaderText(recipeGuide.names[language]) end
        otherHeader:SetHeaderText(L.other)
        training:SetShown(not overviewMode)
        training.label:SetText(L.training)
        allProfessions:SetShown(not overviewMode)
        allProfessions.label:SetText(L.allProfessions)
        disclosure:SetText(showAll and "−" or "+")
        rightHeading:SetText((overviewMode or guide ~= recipeGuide)
            and L.guideTitle:format(guide.names[language]) or L.trainers)
        toggle:SetText(overviewMode and L.open or L.back)
        overviewToggle:SetText(overviewMode and L.backOverview or L.overview)
        for index, control in ipairs(professions) do
            control:SetShown(showAll == true)
            local y = (overviewMode and -46 or -164) - (index - 1) * (overviewMode and 26 or 23)
            control:SetPoint("TOPLEFT", overviewMode and 13 or 24, y)
            control:SetPoint("TOPRIGHT", -13, y)
            local active = guide == control.guide
            control.label:SetText(control.guide.names[language])
            control.label:SetTextColor(1, active and 0.83 or 0.77, active and 0.33 or 0.53)
            control.selection:SetShown(active)
        end

        content:SetWidth(math.max(1, scroll:GetWidth()))
        local y = 0
        for index, section in ipairs(sections) do
            local rank = guide.ranks[index]
            local heading, details = section.heading, section.details
            local open = rank ~= nil and expanded[index] == true
            heading:SetShown(rank ~= nil)
            details:SetShown(open)
            if rank then
                local title = ("%d–%d  %s"):format(rank.minimum, rank.cap, L.names[index])
                if heading.SetHeaderText then
                    heading:SetHeaderText(title)
                    heading:UpdateCollapsedState(not open)
                else
                    heading:SetText(title .. (open and "  −" or "  +"))
                end
                heading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                heading:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
                y = y + heading:GetHeight() + 5
                if open then
                    details:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
                    details:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -y)
                    details:SetText(trainerDetails(L, rank))
                    y = y + details:GetStringHeight() + 13
                end
            end
        end
        content:SetHeight(math.max(1, y))
        local scrollBar = scroll.ScrollBar
        if scrollBar then scrollBar:SetShown(y > scroll:GetHeight()) end
        if resetScroll then scroll:SetVerticalScroll(0) end
    end

    for index = 1, #labels.enUS.names do
        local template = _G.ProfessionsRecipeListCategoryMixin
            and "ProfessionsRecipeListCategoryTemplate" or "UIPanelButtonTemplate"
        local heading = CreateFrame("Button", nil, content, template)
        heading:SetHeight(25)
        if heading.RankBar then heading.RankBar:Hide() end
        local details = text(content, "GameFontHighlight")
        local function toggleRank()
            expanded[index] = not expanded[index]
            refreshDetails()
        end
        heading:SetScript("OnClick", toggleRank)
        if heading.GetCollapseButton then
            -- The native glyph can consume clicks without forwarding them to the header.
            local hitArea = CreateFrame("Button", nil, heading)
            hitArea:SetPoint("TOPRIGHT")
            hitArea:SetPoint("BOTTOMRIGHT")
            hitArea:SetWidth(28)
            hitArea:SetFrameLevel(heading:GetFrameLevel() + 5)
            hitArea:SetScript("OnClick", toggleRank)
        end
        sections[index] = { heading = heading, details = details }
    end

    for index, id in ipairs(trainingGuideIDs) do
        local control = CreateFrame("Button", nil, left)
        control.guide = addon.professionGuides[id]
        control:SetHeight(22)
        control:SetPoint("TOPLEFT", 13, -46 - (index - 1) * 26)
        control:SetPoint("TOPRIGHT", -13, -46 - (index - 1) * 26)
        control.selection = control:CreateTexture(nil, "BACKGROUND")
        control.selection:SetAllPoints()
        control.selection:SetColorTexture(0.28, 0.17, 0.045, 0.92)
        local highlight = control:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.78, 0.51, 0.20, 0.18)
        control.label = text(control, "GameFontNormal")
        control.label:SetPoint("LEFT", 10, 0)
        control:SetScript("OnClick", function()
            guide = control.guide
            expanded = { [1] = true }
            refreshDetails(true)
        end)
        professions[index] = control
    end

    allProfessions:SetScript("OnClick", function()
        showAll = not showAll
        refreshDetails()
    end)
    training:SetScript("OnClick", function()
        guide = recipeGuide
        expanded = { [1] = true }
        refreshDetails(true)
    end)
    scroll:HookScript("OnSizeChanged", function()
        if panel:IsShown() then refreshDetails() end
    end)

    local recipeAlpha, overviewAlpha
    panel:SetScript("OnShow", function()
        panel:SetPoint("TOPLEFT", root, "TOPLEFT", 10, overviewMode and -48 or -73)
        if overviewMode then
            overviewAlpha = bookPage:GetAlpha()
            bookPage:SetAlpha(0)
            addon.QueueProfessionLayout()
        else
            recipeAlpha = page.SchematicForm:GetAlpha()
            page.SchematicForm:SetAlpha(0)
        end
    end)
    panel:SetScript("OnHide", function()
        if overviewAlpha ~= nil then
            bookPage:SetAlpha(overviewAlpha)
            overviewAlpha = nil
            addon.QueueProfessionLayout()
        end
        if recipeAlpha ~= nil then
            page.SchematicForm:SetAlpha(recipeAlpha)
            recipeAlpha = nil
        end
    end)

    local activeRecipeGuide

    local function positionOverviewToggle()
        overviewToggle:ClearAllPoints()
        if overviewCard and not overviewMode then
            overviewToggle:SetPoint("BOTTOM", overviewCard, "BOTTOM", 0, 13)
        else
            overviewToggle:SetPoint("TOPRIGHT", root, "TOPRIGHT", -66, -3)
        end
    end

    function addon.SetProfessionGuideOverviewCard(card)
        overviewCard = card
        positionOverviewToggle()
    end

    function addon.GetProfessionGuideHeaderSpace()
        return activeRecipeGuide and headerSpace or 0
    end

    function addon.CloseProfessionGuide()
        panel:Hide()
        overviewMode = nil
        positionOverviewToggle()
        local L = strings()
        toggle:SetText(L.open)
        overviewToggle:SetText(L.overview)
        overviewToggle:SetShown(bookPage:IsVisible())
    end

    function addon.RefreshProfessionGuide()
        local info = page:IsVisible() and Professions.GetProfessionInfo()
        local id = info and (info.parentProfessionID or info.professionID)
        local active = id and addon.professionGuides[id]
        if activeRecipeGuide ~= active then
            if not overviewMode then addon.CloseProfessionGuide() end
            activeRecipeGuide = active
            addon.QueueProfessionLayout()
        end
        toggle:SetShown(activeRecipeGuide ~= nil)
        overviewToggle:SetShown(bookPage:IsVisible())
        if overviewMode and not bookPage:IsVisible() then addon.CloseProfessionGuide() end
        if panel:IsShown() then
            refreshDetails()
        else
            local L = strings()
            toggle:SetText(L.open)
            overviewToggle:SetText(L.overview)
        end
    end

    toggle:SetScript("OnClick", function()
        if panel:IsShown() then addon.CloseProfessionGuide(); return end
        if not activeRecipeGuide or InCombatLockdown() then return end
        closeOtherViews()
        recipeGuide = activeRecipeGuide
        guide = recipeGuide
        showAll = false
        expanded = { [1] = true }
        panel:Show()
        refreshDetails(true)
    end)
    overviewToggle:SetScript("OnClick", function()
        if panel:IsShown() then addon.CloseProfessionGuide(); return end
        if InCombatLockdown() then return end
        closeOtherViews()
        overviewMode = true
        showAll = true
        positionOverviewToggle()
        guide = addon.professionGuides[197]
        expanded = { [1] = true }
        panel:Show()
        refreshDetails(true)
    end)
    bookPage:HookScript("OnShow", addon.RefreshProfessionGuide)
    bookPage:HookScript("OnHide", function()
        if overviewMode then addon.CloseProfessionGuide() end
        overviewToggle:Hide()
    end)
    page:HookScript("OnShow", addon.RefreshProfessionGuide)
    page:HookScript("OnHide", addon.RefreshProfessionGuide)
    if page.Refresh then hooksecurefunc(page, "Refresh", addon.RefreshProfessionGuide) end
    root:HookScript("OnShow", function()
        C_Timer.After(0, addon.RefreshProfessionGuide)
    end)
    root:HookScript("OnHide", addon.CloseProfessionGuide)
    addon.RefreshProfessionGuide()
end
