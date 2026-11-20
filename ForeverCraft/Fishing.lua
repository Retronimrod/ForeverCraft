local _, addon = ...
local fishingSpell = 7620
local fishingSkill = 356
local binding = "CLICK ForeverCraftFishingCast:LeftButton"
local events = CreateFrame("Frame")
local cast = CreateFrame("Button", "ForeverCraftFishingCast", UIParent, "SecureActionButtonTemplate")
cast:RegisterForClicks("AnyDown")
cast:SetAttribute("useOnKeyDown", true)
cast:SetAttribute("type", "macro")

local fishingToggle

local catches, lootSlots = {}, nil
local manualFishingLoot = false
local refreshLog, openLog
local sessionStart, casts, successful, latest = nil, 0, 0, nil
local startingSkill
local function fishingRank()
    for _, index in pairs({ GetProfessions() }) do
        local _, _, rank, maximum, _, _, line = GetProfessionInfo(index)
        if line == fishingSkill then return rank, maximum end
    end
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(fishingSkill)
    if info then return info.skillLevel, info.maxSkillLevel end
end

local countedLoot = false
local function option(key)
    return not ForeverCraftDB or ForeverCraftDB[key] ~= false
end

local fishingRanks = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
local interactSettings = { SoftTargetInteract = 3, SoftTargetInteractRange = 30, SoftTargetInteractArc = 2 }
local previousInteract
local function restoreInteract()
    if not previousInteract then return end
    for name, saved in pairs(previousInteract) do
        if tonumber(C_CVar.GetCVar(name)) == saved.applied then C_CVar.SetCVar(name, saved.value) end
    end
    previousInteract = nil
end

local function prepareInteract()
    if previousInteract then return end
    previousInteract = {}
    for name, minimum in pairs(interactSettings) do
        local value = tonumber(C_CVar.GetCVar(name))
        if value and value < minimum then
            C_CVar.SetCVar(name, minimum)
            previousInteract[name] = { value = value, applied = minimum }
        end
    end
end

local function isFishingChannel(eventSpell)
    local name, _, _, _, _, _, _, spellID = UnitChannelInfo("player")
    return fishingRanks[eventSpell] or fishingRanks[spellID]
        or (name and name == C_Spell.GetSpellName(fishingSpell))
end

local function configureCast()
    local name = C_Spell.GetSpellName(fishingSpell)
    if name then cast:SetAttribute("macrotext", "/cast [nocombat,noflying,nostealth,noswimming,novehicleui] " .. name) end
end

local takeLoot = CreateFrame("Button", "ForeverCraftFishingLoot", UIParent)
takeLoot:RegisterForClicks("AnyDown")
takeLoot:SetScript("OnClick", function()
    if not manualFishingLoot or not IsFishingLoot or not IsFishingLoot() then return end
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end)

cast:SetScript("PreClick", function()
    if InCombatLockdown() then return end
    configureCast()
    prepareInteract()
    local prepared = previousInteract
    C_Timer.After(2, function()
        if previousInteract == prepared and not isFishingChannel() then restoreInteract() end
    end)
end)

local function updateBinding(channeling)
    if InCombatLockdown() then return end
    ClearOverrideBindings(events)
    if channeling == nil then channeling = isFishingChannel() end
    for _, key in ipairs({ GetBindingKey(binding) }) do
        if manualFishingLoot then
            SetOverrideBindingClick(events, true, key, "ForeverCraftFishingLoot", "LeftButton")
        elseif channeling then
            SetOverrideBinding(events, true, key, "INTERACTTARGET")
        else
            SetOverrideBindingClick(events, true, key, "ForeverCraftFishingCast", "LeftButton")
        end
    end
end

local function rememberLoot()
    if lootSlots or not IsFishingLoot or not IsFishingLoot() then return end
    lootSlots = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local _, _, count = GetLootSlotInfo(slot)
        local itemID = link and C_Item.GetItemInfoInstant(link)
        if itemID then lootSlots[slot] = { itemID = itemID, link = link, count = count or 1 } end
    end
end

events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_SLOT_CLEARED")
events:RegisterEvent("LOOT_CLOSED")
events:SetScript("OnEvent", function(_, event, slot, _, eventSpell)
    if event == "PLAYER_LOGOUT" then
        restoreInteract()
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        rememberLoot()
        if event == "LOOT_OPENED" and slot ~= true and lootSlots then
            manualFishingLoot = true
            updateBinding()
        end
    elseif event == "LOOT_CLOSED" then
        manualFishingLoot = false
        updateBinding()
        lootSlots = nil
        countedLoot = false
    elseif event == "LOOT_SLOT_CLEARED" then
        local item = lootSlots and lootSlots[slot]
        if not item then return end
        lootSlots[slot] = nil
        if not countedLoot then
            countedLoot = true
            successful = successful + 1
        end
        latest = item
        local previous = catches[item.itemID]
        if previous then
            previous.count = previous.count + item.count
        else
            catches[item.itemID] = item
        end
        if refreshLog then refreshLog() end
    else
        if event == "UNIT_SPELLCAST_CHANNEL_START" and isFishingChannel(eventSpell) then
            if GetBindingKey(binding) then prepareInteract() end
            local newSession = not sessionStart
            sessionStart = sessionStart or GetTime()
            if newSession then startingSkill = fishingRank() end
            casts = casts + 1
            updateBinding(true)
            if newSession and option("fishingAutoOpen") then openLog() end
            if refreshLog then refreshLog() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            restoreInteract()
            updateBinding(false)
        else
            if not InCombatLockdown() then configureCast() end
            updateBinding()
        end
    end
end)

function addon.BuildFishingBindingSettings(card)
    local assign = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    assign:SetSize(244, 24)
    assign:SetPoint("TOPLEFT", 13, -34)
    local clear = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    clear:SetSize(100, 24)
    clear:SetPoint("LEFT", assign, "RIGHT", 8, 0)
    local status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", assign, "BOTTOMLEFT", 0, -10)
    status:SetPoint("RIGHT", card, "RIGHT", -13, 0)
    status:SetJustifyH("LEFT")
    local recording = false

    local function text(key)
        return addon.GetText()[key] or addon.strings.enUS[key]
    end
    local function refresh()
        local keys = { GetBindingKey(binding) }
        local names = {}
        for index, key in ipairs(keys) do names[index] = GetBindingText(key, "KEY_") end
        assign:SetText(recording and text("fishingPressKey")
            or (#names > 0 and table.concat(names, " / ") or text("fishingBindKey")))
        clear:SetText(text("fishingClearKey"))
        clear:SetEnabled(#keys > 0 and not recording and not InCombatLockdown())
        assign:SetEnabled(not InCombatLockdown())
    end
    local function stop()
        recording = false
        card:EnableKeyboard(false)
        refresh()
    end
    assign:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        status:SetText("")
        if recording then stop(); return end
        recording = true
        card:SetPropagateKeyboardInput(false)
        card:EnableKeyboard(true)
        refresh()
    end)
    clear:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        for _, key in ipairs({ GetBindingKey(binding) }) do SetBinding(key) end
        SaveBindings(GetCurrentBindingSet())
        status:SetText("")
        refresh()
    end)
    card:SetScript("OnKeyDown", function(_, key)
        if not recording or InCombatLockdown() then return end
        if key == "ESCAPE" then stop(); return end
        if key == "UNKNOWN" or key:find("^[LR]SHIFT$") or key:find("^[LR]CTRL$") or key:find("^[LR]ALT$") then return end
        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if IsAltKeyDown() then key = "ALT-" .. key end
        local action = GetBindingAction(key)
        stop()
        if action and action ~= "" and action ~= binding then
            status:SetText(text("fishingKeyInUse"):format(GetBindingText(key, "KEY_")))
            return
        end
        local previous = { GetBindingKey(binding) }
        if not SetBinding(key, binding) then
            status:SetText(text("fishingBindFailed"))
            return
        end
        for _, old in ipairs(previous) do
            if old ~= key then SetBinding(old) end
        end
        SaveBindings(GetCurrentBindingSet())
        refresh()
    end)
    card:HookScript("OnShow", function()
        status:SetText("")
        refresh()
    end)
    card:HookScript("OnHide", stop)
    card:RegisterEvent("UPDATE_BINDINGS")
    card:RegisterEvent("PLAYER_REGEN_DISABLED")
    card:RegisterEvent("PLAYER_REGEN_ENABLED")
    card:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then stop() else refresh() end
    end)
    refresh()
end

local log
local settingsOpen, restoreLog = false, false
local function buildLog()
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(312, 287)
    panel:SetPoint("CENTER", UIParent, "CENTER", 330, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    local body = CreateFrame("Frame", nil, panel)
    body:SetAllPoints()
    local close = CreateFrame("Button", nil, body, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -8, -5)
    close:SetScript("OnClick", function() panel:Hide() end)
    addon.AddSettingsGear(panel)
    local gear = panel.ForeverCraftSettingsGear
    gear:ClearAllPoints()
    gear:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 11, 8)
    gear:SetSize(22, 22)
    local base = body:CreateTexture(nil, "BACKGROUND", nil, -1)
    base:SetAllPoints()
    base:SetColorTexture(0.09, 0.07, 0.05, 1)
    local background = body:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetAtlas("Professions-Recipe-Background", false)
    local border = body:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetAtlas("common-insideframe", false)
    local edgeMask = body:CreateMaskTexture()
    edgeMask:SetAllPoints()
    edgeMask:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\FishingLogMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    base:AddMaskTexture(edgeMask)
    background:AddMaskTexture(edgeMask)
    border:AddMaskTexture(edgeMask)
    local function statBox(offset, caption)
        local card = CreateFrame("Frame", nil, body)
        card:SetSize(93, 38)
        card:SetPoint("TOPLEFT", 12 + offset, -27)
        local fill = card:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.18, 0.135, 0.09, 0.9)
        local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", 7, -5)
        name:SetText(caption)
        local number = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        number:SetPoint("BOTTOMLEFT", 7, 5)
        return number, name
    end
    local catchStat, catchLabel = statBox(0, "")
    local rateStat, rateLabel = statBox(97, "")
    local valueStat, valueLabel = statBox(194, "")
    local rankText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankText:SetPoint("TOPLEFT", 13, -72)
    local rankGain = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankGain:SetPoint("TOPRIGHT", -13, -72)
    rankGain:SetTextColor(0.41, 0.85, 0.35)
    local rankBar = CreateFrame("StatusBar", nil, body)
    rankBar:SetPoint("TOPLEFT", 13, -87)
    rankBar:SetPoint("TOPRIGHT", -13, -87)
    rankBar:SetHeight(5)
    rankBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rankBar:SetStatusBarColor(0.28, 0.58, 0.82)
    local track = rankBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.20, 0.16, 0.12)

    local recent = CreateFrame("Frame", nil, body)
    recent:SetPoint("TOPLEFT", 12, -99)
    recent:SetPoint("TOPRIGHT", -12, -99)
    recent:SetHeight(36)
    local recentFill = recent:CreateTexture(nil, "BACKGROUND")
    recentFill:SetAllPoints()
    recentFill:SetColorTexture(0.29, 0.21, 0.14, 0.95)
    local recentAccent = recent:CreateTexture(nil, "BORDER")
    recentAccent:SetPoint("TOPLEFT")
    recentAccent:SetPoint("BOTTOMLEFT")
    recentAccent:SetWidth(2)
    recentAccent:SetColorTexture(0.65, 0.47, 0.24, 0.9)
    local recentIcon = recent:CreateTexture(nil, "ARTWORK")
    recentIcon:SetSize(23, 23)
    recentIcon:SetPoint("LEFT", 6, 0)
    local recentLabel = recent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recentLabel:SetPoint("TOPLEFT", 35, -4)
    local lastCatch = recent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lastCatch:SetPoint("TOPLEFT", recentLabel, "BOTTOMLEFT", 0, -2)
    lastCatch:SetPoint("RIGHT", -5, 0)
    lastCatch:SetJustifyH("LEFT")
    lastCatch:SetWordWrap(false)
    local details = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("BOTTOM", body, "BOTTOM", 0, 38)
    details:SetJustifyH("CENTER")

    local reset = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    reset:SetSize(126, 22)
    reset:SetPoint("BOTTOMRIGHT", -12, 10)
    reset:SetScript("OnClick", function()
        catches, latest, sessionStart = {}, nil, nil
        casts, successful = 0, 0
        startingSkill = fishingRank()
        if isFishingChannel() then
            sessionStart, casts = GetTime(), 1
        end
        refreshLog()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 13, -141)
    scroll:SetPoint("BOTTOMRIGHT", -29, 57)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(self) content:SetWidth(math.max(1, self:GetWidth())) end)
    addon.HideUnusedScrollbar(scroll)
    local rows = {}
    local value
    local function refreshStats()
        local elapsed = sessionStart and math.max(0, math.floor(GetTime() - sessionStart)) or 0
        local rate = elapsed >= 1 and math.floor(successful * 3600 / elapsed + 0.5) or 0
        catchStat:SetText(successful)
        rateStat:SetText(rate)
        valueStat:SetText(option("fishingShowValue") and value and
            (GetMoneyString and GetMoneyString(math.floor(value + 0.5)) or tostring(math.floor(value + 0.5))) or "–")
        details:SetText(addon.GetText().fishingSession
            :format(math.floor(elapsed / 60), elapsed % 60, casts))
    end
    refreshLog = function()
        if not panel:IsVisible() then return end
        local L = addon.GetText()
        catchLabel:SetText(L.fishingCatches)
        rateLabel:SetText(L.fishingRate)
        valueLabel:SetText(L.fishingValue)
        recentLabel:SetText(L.fishingLatest)
        reset:SetText(L.fishingReset)
        local items = {}
        value = nil
        for _, item in pairs(catches) do
            items[#items + 1] = item
            if option("fishingShowValue") then
                local estimate = addon.GetMarketEstimate(item.itemID, item.count)
                if estimate then value = (value or 0) + estimate end
            end
        end
        refreshStats()
        local rank, maximum = fishingRank()
        rankText:SetText(L.settingsFishing .. (rank and maximum and (" %d / %d"):format(rank, maximum) or " –"))
        rankBar:SetMinMaxValues(0, math.max(1, maximum or 0))
        rankBar:SetValue(rank or 0)
        rankGain:SetText(rank and startingSkill and rank > startingSkill
            and L.fishingGain:format(rank - startingSkill) or "")
        lastCatch:SetText(latest and latest.link or "–")
        recentIcon:SetTexture(latest and C_Item.GetItemIconByID(latest.itemID) or nil)
        table.sort(items, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.link < b.link
        end)
        for i = 1, math.max(1, #items) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
                row:SetPoint("TOPRIGHT", 0, -(i - 1) * 20)
                row:SetHeight(20)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16)
                row.icon:SetPoint("LEFT")
                row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.count:SetPoint("RIGHT", -3, 0)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.name:SetPoint("LEFT", 22, 0)
                row.name:SetPoint("RIGHT", -39, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWordWrap(false)
                rows[i] = row
            end
            local item = items[i]
            row.icon:SetTexture(item and C_Item.GetItemIconByID(item.itemID) or nil)
            row.name:SetText(item and item.link or L.fishingEmpty)
            row.count:SetText(item and ("×%d"):format(item.count) or "")
            row:Show()
        end
        for i = math.max(1, #items) + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #items) * 20)
    end
    panel:SetScript("OnShow", refreshLog)
    panel:RegisterEvent("SKILL_LINES_CHANGED")
    panel:SetScript("OnEvent", refreshLog)
    local tick = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        tick = tick + elapsed
        if tick < 1 then return end
        tick = tick % 1
        refreshStats()
    end)
    return panel
end

openLog = function()
    if settingsOpen then
        restoreLog = true
        return
    end
    log = log or buildLog()
    log:Show()
    refreshLog()
end

function addon.SetFishingSettingsOpen(open)
    if settingsOpen == open then return end
    settingsOpen = open
    if open then
        restoreLog = log and log:IsShown() or false
        if restoreLog then log:Hide() end
    elseif restoreLog then
        restoreLog = false
        openLog()
    end
end

function addon.RefreshFishingLog()
    local L = addon.GetText()
    _G["BINDING_NAME_" .. binding] = L.settingsFishingBinding
    if fishingToggle then fishingToggle:SetText(L.settingsFishingLog) end
    if refreshLog then refreshLog() end
end

function addon.AttachFishing(root, page)
    local toggle = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    toggle:SetSize(105, 22)
    toggle:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 5)
    fishingToggle = toggle
    toggle:SetText(addon.GetText().settingsFishingLog)
    toggle:SetScript("OnClick", function()
        if log and log:IsShown() then log:Hide() else openLog() end
    end)
    local function selectProfession()
        toggle:SetShown(root.selectedSkillLine == fishingSkill)
    end
    hooksecurefunc(root, "RightTabSelected", selectProfession)
    selectProfession()
end

addon.RefreshFishingLog()
