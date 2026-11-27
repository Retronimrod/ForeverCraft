local _, addon = ...
local events = CreateFrame("Frame")
local lastRanks = {}
local refresh

local function week()
    ForeverCraftWorkshopLog = type(ForeverCraftWorkshopLog) == "table" and ForeverCraftWorkshopLog or {}
    local today = date("*t")
    local first = date("%Y%m%d", time({
        year = today.year, month = today.month, day = today.day - 6, hour = 12,
    }))
    for day in pairs(ForeverCraftWorkshopLog) do
        if day < first then ForeverCraftWorkshopLog[day] = nil end
    end
    return ForeverCraftWorkshopLog
end

local function todayLog()
    local days, key = week(), date("%Y%m%d")
    days[key] = days[key] or { recipes = {}, skills = {} }
    return days[key]
end

local function recordRanks()
    local changed = false
    for _, index in pairs({ GetProfessions() }) do
        local name, _, rank, _, _, _, id = GetProfessionInfo(index)
        if name and id and rank then
            local before = lastRanks[id]
            lastRanks[id] = rank
            if before and rank > before then
                local skills = todayLog().skills
                local skill = skills[id] or { gain = 0 }
                skill.name, skill.rank, skill.gain = name, rank, skill.gain + rank - before
                skills[id] = skill
                changed = true
            end
        end
    end
    return changed
end

local function recordCraft(spell)
    if not spell or (issecretvalue and issecretvalue(spell)) then return end
    local info = C_TradeSkillUI.GetRecipeInfo(spell)
    if not info or not info.learned or not info.name or not C_TradeSkillUI.GetProfessionInfoByRecipeID(spell) then return false end
    local recipes = todayLog().recipes
    local entry = recipes[spell] or { count = 0 }
    entry.name, entry.count, entry.last = info.name, entry.count + 1, time()
    recipes[spell] = entry
    return true
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, _, _, spell)
    local changed
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        changed = recordCraft(spell)
    else
        changed = recordRanks()
    end
    if changed and refresh then refresh() end
end)

function addon.BuildWorkshopLog(column)
    local function line(font, y, height)
        local text = column:CreateFontString(nil, "OVERLAY", font)
        text:SetPoint("TOPLEFT", 14, y)
        text:SetPoint("TOPRIGHT", -14, y)
        text:SetHeight(height)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        return text
    end

    local heading = line("GameFontNormal", -18, 18)
    heading:SetJustifyH("CENTER")
    local period = line("GameFontHighlightSmall", -39, 16)
    period:SetJustifyH("CENTER")
    local crafted = line("GameFontNormal", -67, 17)
    local recipes = line("GameFontHighlightSmall", -90, 105)
    recipes:SetSpacing(3)
    local progress = line("GameFontNormal", -205, 17)
    local skills = line("GameFontHighlightSmall", -228, 110)
    skills:SetSpacing(3)
    -- Ends above the offer buttons at the bottom of the card.
    skills:SetPoint("BOTTOM", column, "BOTTOM", 0, 146)

    refresh = function(force)
        if not force and not column:IsVisible() then return end
        local L = addon.GetText()
        local words = L.workshopLog or addon.strings.enUS.workshopLog
        local totals, gains, count = {}, {}, 0
        for day, data in pairs(week()) do
            for id, entry in pairs(data.recipes) do
                local sum = totals[id] or { count = 0, last = 0 }
                sum.count = sum.count + entry.count
                if entry.last >= sum.last then sum.name, sum.last = entry.name, entry.last end
                totals[id] = sum
                count = count + entry.count
            end
            for id, entry in pairs(data.skills) do
                local sum = gains[id] or { gain = 0, day = "" }
                sum.gain = sum.gain + entry.gain
                if day > sum.day then sum.name, sum.rank, sum.day = entry.name, entry.rank, day end
                gains[id] = sum
            end
        end
        local sorted = {}
        for _, entry in pairs(totals) do sorted[#sorted + 1] = entry end
        table.sort(sorted, function(a, b)
            if a.last ~= b.last then return a.last > b.last end
            return a.name < b.name
        end)
        local recent = {}
        for i = 1, math.min(3, #sorted) do
            local entry = sorted[i]
            recent[i] = ("%d × %s"):format(entry.count, entry.name)
        end
        local skillLines = {}
        for _, entry in pairs(gains) do
            skillLines[#skillLines + 1] = ("%s  |cff84d76f+%d|r  (%d)"):format(entry.name, entry.gain, entry.rank)
        end
        table.sort(skillLines)
        heading:SetText(words.title)
        period:SetText(words.period)
        crafted:SetText(words.crafts:format(count))
        recipes:SetText(#recent > 0 and table.concat(recent, "\n") or words.noCrafts)
        progress:SetText(words.progress)
        skills:SetText(#skillLines > 0 and table.concat(skillLines, "\n") or words.noProgress)
    end
    column.refreshText = function() refresh(true) end
end
