local _, addon = ...

local colors = {
    { 0.91, 0.43, 0.12 },
    { 0.89, 0.72, 0.17 },
    { 0.36, 0.65, 0.30 },
    { 0.46, 0.44, 0.40 },
}

local liveTiers
local function getLiveTiers(recipeID)
    if not liveTiers then
        local db = LibStub and LibStub("LibProfessionDB-1.0", true)
        if not db or not db.IsReady or not db:IsReady()
            or not db.GetMeta or select(2, db:GetMeta()) ~= "Forever"
            or not db.GetProfessions or not db.GetRecipes then return end
        liveTiers = {}
        for _, professionID in ipairs(db:GetProfessions()) do
            for id, recipe in pairs(db:GetRecipes(professionID) or {}) do
                local difficulty = recipe.difficulty
                if type(difficulty) == "table" then
                    local yellow, green, gray = difficulty[2], difficulty[3], difficulty[4]
                    if type(yellow) == "number" and type(green) == "number" and type(gray) == "number"
                        and yellow > 0 and green >= yellow and gray >= green then
                        liveTiers[id] = { yellow, green, gray }
                    end
                end
            end
        end
    end
    return liveTiers[recipeID]
end

function addon.GetSkillThresholds(recipe)
    local gray = recipe.maxTrivialLevel
    if type(gray) ~= "number" or gray <= 0 then gray = nil end
    local tiers = getLiveTiers(recipe.recipeID)
    if not tiers or (gray and tiers[3] ~= gray) then
        tiers = addon.skillThresholdData[recipe.recipeID]
    end
    local yellow, green, approximate
    if tiers and (not gray or tiers[3] == gray) then
        yellow, green, gray = tiers[1], tiers[2], tiers[3]
        approximate = green ~= yellow and green ~= gray
    end
    if not yellow or not green or not gray or yellow < 1 or green < yellow or gray < green then
        return nil, nil, gray
    end
    return yellow, green, gray, approximate
end

function addon.GetSkillBarBounds(yellow, green, gray)
    local padding = math.max(8, math.floor((gray - yellow) / 2))
    return { math.max(0, yellow - padding), yellow, green, gray, gray + padding }
end

function addon.GetEstimatedSkillChance(recipe, skill)
    if type(skill) ~= "number" or recipe.learned == false then return end
    local yellow, _, gray = addon.GetSkillThresholds(recipe)
    if not gray then return end
    if skill >= gray then return 0 end
    if not yellow then return end
    if skill < yellow then return 1 end
    return (gray - skill) / (gray - yellow)
end

function addon.CreateSkillScale(form, planner)
    local scale = CreateFrame("Frame", nil, form)
    scale:SetSize(282, 35)
    scale:SetPoint("BOTTOMLEFT", planner, "TOPLEFT", 0, 13)
    scale.form = form

    local track = CreateFrame("Frame", nil, scale)
    scale.track = track
    track:SetSize(278, 14)
    track:SetPoint("TOPLEFT", 1, -14)
    local base = track:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints()
    base:SetAtlas("UI-HUD-ExperienceBar-Background")
    local rim = track:CreateTexture(nil, "OVERLAY")
    rim:SetAllPoints()
    rim:SetAtlas("UI-HUD-ExperienceBar-Frame")

    scale.segments, scale.textures, scale.ticks = {}, {}, {}
    for i, color in ipairs(colors) do
        local segment = track:CreateTexture(nil, "ARTWORK")
        segment:SetColorTexture(1, 1, 1, 1)
        segment:SetGradient("VERTICAL",
            CreateColor(color[1] * 0.43, color[2] * 0.43, color[3] * 0.43, 1),
            CreateColor(color[1], color[2], color[3], 1))
        scale.segments[i] = segment
        local pattern = track:CreateTexture(nil, "ARTWORK", nil, 1)
        pattern:SetAllPoints(segment)
        pattern:SetDesaturated(true)
        pattern:SetAlpha(0.62)
        pattern:SetBlendMode("ADD")
        pattern:SetVertexColor(color[1], color[2], color[3])
        scale.textures[i] = pattern
        if i < #colors then
            local tick = track:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            tick:SetTextColor(0.86, 0.78, 0.65)
            scale.ticks[i] = tick
        end
    end

    local future = track:CreateTexture(nil, "ARTWORK", nil, 2)
    scale.future = future
    future:SetColorTexture(0.025, 0.019, 0.014, 0.35)
    scale.dividers = {}
    for i = 1, 9 do
        local divider = track:CreateTexture(nil, "ARTWORK", nil, 3)
        divider:SetSize(3, 12)
        divider:SetAtlas("ui-hud-experiencebar-divider")
        divider:SetAlpha(0.65)
        scale.dividers[i] = divider
    end

    local marker = CreateFrame("Frame", nil, track)
    scale.marker = marker
    marker:SetSize(1, 16)
    local line = marker:CreateTexture(nil, "OVERLAY")
    line:SetAllPoints()
    line:SetColorTexture(1, 0.85, 0.53, 1)
    local pip = marker:CreateTexture(nil, "OVERLAY")
    pip:SetSize(5, 5)
    pip:SetPoint("CENTER", marker, "TOP", 0, 0)
    pip:SetColorTexture(1, 0.83, 0.46, 1)
    pip:SetRotation(math.pi / 4)
    marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.text:SetPoint("BOTTOM", marker, "TOP", 0, 4)

    scale.note = scale:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scale.note:SetPoint("LEFT", 0, 2)
    scale:EnableMouseMotion(true)
    scale:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local L = addon.GetText()
        GameTooltip:AddLine(L.skillScale)
        if self.skill then GameTooltip:AddLine(L.currentSkill:format(self.skill), 1, 1, 1) end
        for _, text in ipairs(self.thresholdLabels or {}) do GameTooltip:AddLine(text, 1, 1, 1) end
        if self.approximate then GameTooltip:AddLine(L.skillApproximate, 0.85, 0.75, 0.55, true) end
        local recipe = self.recipe
        local chance = recipe and addon.GetEstimatedSkillChance(recipe, self.skill)
        if chance then
            GameTooltip:AddLine(L.skillChance:format(math.floor(chance * 100 + 0.5)))
        end
        local cost = recipe and GetMoneyString and addon.GetRecipeMaterialEstimate(recipe.recipeID)
        if cost then
            GameTooltip:AddLine(L.craftPrice:format(GetMoneyString(cost)))
            if chance and chance > 0 then
                local points = math.max(1, recipe.numSkillUps or 1)
                GameTooltip:AddLine(L.skillPrice:format(GetMoneyString(math.floor(cost / (chance * points) + 0.5))))
            end
        end
        GameTooltip:Show()
    end)
    scale:SetScript("OnLeave", function() GameTooltip:Hide() end)
    scale:Hide()
    return scale
end

function addon.UpdateSkillScale(scale, recipe, profession)
    local yellow, green, gray, approximate = addon.GetSkillThresholds(recipe)
    scale:SetShown(gray ~= nil)
    if not gray then return false end
    scale.recipe = recipe
    scale.approximate = approximate
    scale.skill = profession and profession.skillLevel

    local L = addon.GetText()
    local full = yellow ~= nil
    scale.track:SetShown(full)
    scale.note:SetShown(not full)
    scale.thresholdLabels = nil
    local width = math.floor(math.max(120, scale.form:GetWidth() - 48))
    if not full then
        scale.note:SetText(L.noSkillFrom:format(gray))
        return true
    end

    local bounds = addon.GetSkillBarBounds(yellow, green, gray)
    local trackWidth = width - 4
    local function position(rank)
        rank = math.max(bounds[1], math.min(rank, bounds[5]))
        return 1 + (trackWidth - 2) * (rank - bounds[1]) / (bounds[5] - bounds[1])
    end

    local appearanceKey = table.concat({ width, yellow, green, gray, tostring(approximate) }, ":")
    if scale.appearanceKey ~= appearanceKey then
        scale.appearanceKey = appearanceKey
        scale:SetWidth(width)
        scale.track:SetWidth(trackWidth)
        scale.markerX = nil
        for i, divider in ipairs(scale.dividers) do
            divider:SetPoint("CENTER", scale.track, "LEFT", 1 + (trackWidth - 2) * i / 10, 0)
        end
        local previousTickX
        for i, segment in ipairs(scale.segments) do
            local left, right = position(bounds[i]), position(bounds[i + 1])
            segment:ClearAllPoints()
            segment:SetPoint("TOPLEFT", scale.track, "TOPLEFT", left, -1)
            segment:SetPoint("BOTTOMRIGHT", scale.track, "BOTTOMLEFT", right, 1)
            segment:SetShown(right > left)
            local pattern = scale.textures[i]
            pattern:SetAtlas("UI-HUD-ExperienceBar-Fill-Prediction")
            pattern:SetShown(right > left)
            local tick = scale.ticks[i]
            if tick then
                tick:ClearAllPoints()
                tick:SetPoint("TOP", scale.track, "BOTTOMLEFT", right, -3)
                tick:SetText((i == 2 and approximate and "~" or "") .. bounds[i + 1])
                local show = (not previousTickX or right - previousTickX >= 27)
                    and (i == 3 or position(gray) - right >= 27)
                tick:SetShown(show)
                if show then previousTickX = right end
            end
        end
    end
    scale.thresholdLabels = { L.yellowFrom:format(yellow), L.greenFrom:format(green), L.noSkillFrom:format(gray) }

    scale.marker:SetShown(scale.skill ~= nil)
    scale.future:SetShown(scale.skill ~= nil and scale.skill < bounds[5])
    if scale.skill then
        local x = position(scale.skill)
        if scale.markerX ~= x then
            scale.markerX = x
            scale.marker:SetPoint("CENTER", scale.track, "LEFT", x, 0)
            scale.future:ClearAllPoints()
            scale.future:SetPoint("TOPLEFT", scale.track, "TOPLEFT", x, -1)
            scale.future:SetPoint("BOTTOMRIGHT", scale.track, "BOTTOMRIGHT", -1, 1)
        end
        if scale.markerSkill ~= scale.skill then
            scale.markerSkill = scale.skill
            scale.marker.text:SetText(tostring(scale.skill))
        end
    end
    return true
end
