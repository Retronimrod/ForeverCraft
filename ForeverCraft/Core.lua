local addonName, addon = ...
-- Fallback only; the real version always comes from the TOC so the two never drift apart.
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata
local version = (getMetadata and getMetadata(addonName, "Version")) or "0.1.134"
local curseForgeProfile = "https://www.curseforge.com/members/nimri82/projects"
local events = CreateFrame("Frame")
local root, page, list, form, planner, settings
local showSettings, positionTab
local queueLayout
local originalWidth, originalListWidth, originalFormWidth, recipeBaseWidth
local welcomeColumn
local appliedWidth, appliedFormWidth, queued, layoutQueued
local lastRecipeID, nativeQuantity
local header, headerWidth, rankBar, rankWidth, rankRegions
local reagentLabels = {}
local copper = { 0.84, 0.58, 0.35 }

local function box(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.055, 0.066, 0.08, 0.98)
    frame:SetBackdropBorderColor(0.36, 0.27, 0.19, 1)
    frame:EnableMouse(true)
    return frame
end

local function button(parent, width, text)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 21)
    control:SetText(text)
    return control
end

local titlePrefix = "ForeverCraft  ·  "

function addon.HeaderTitle(title)
    if title:sub(1, #titlePrefix) == titlePrefix then return title end
    return titlePrefix .. title
end

function addon.AddSettingsGear(frame)
    if frame.ForeverCraftSettingsGear then return end
    local gear = button(frame, 27, "")
    frame.ForeverCraftSettingsGear = gear
    gear:SetHeight(18)
    if frame.TitleContainer then
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, -1)
    end
    local close = frame.CloseButton
    if close then
        gear:SetPoint("RIGHT", close, "LEFT", -4, 0)
        gear:SetFrameStrata(close:GetFrameStrata())
        gear:SetFrameLevel(close:GetFrameLevel() + 2)
    else
        gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -5)
        gear:SetFrameLevel(frame:GetFrameLevel() + 20)
    end
    local icon = gear:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\SettingsGear")
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(addon.GetText().settingsTitle)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gear:SetScript("OnClick", function()
        GameTooltip:Hide()
        if settings and settings:IsShown() then settings:Hide() else showSettings() end
    end)
end

local function label(parent, template, text)
    local font = parent:CreateFontString(nil, "OVERLAY", template)
    font:SetJustifyH("LEFT")
    font:SetText(text)
    return font
end

local shoppingWindow, shoppingTab, shoppingShell
local shoppingHeaderArt, shoppingLines, shoppingSections
local shoppingTitleText, savedTitleAlpha, savedPortrait, shoppingPortrait
local shoppingDocked, hiddenPages, previousTab
local queue
local shoppingIcon = "Interface\\Icons\\INV_Misc_Bag_10"

local function setShoppingSelected(selected)
    if not shoppingTab then return end
    if shoppingTab.SetChecked then shoppingTab:SetChecked(selected) end
    if shoppingTab.SelectedTexture then shoppingTab.SelectedTexture:SetShown(selected) end
end

local function restoreProfessionPage()
    if shoppingHeaderArt then shoppingHeaderArt:Hide() end
    local portrait = root and root.PortraitContainer and root.PortraitContainer.portrait
    if portrait and savedPortrait and portrait:GetTexture() == shoppingPortrait then
        root:SetPortraitToAsset(savedPortrait)
    end
    savedPortrait, shoppingPortrait = nil, nil
    local title = root and root.TitleContainer and root.TitleContainer.TitleText
    if shoppingTitleText then shoppingTitleText:Hide() end
    if title and savedTitleAlpha ~= nil then title:SetAlpha(savedTitleAlpha) end
    savedTitleAlpha = nil
    for professionPage, alpha in pairs(hiddenPages or {}) do professionPage:SetAlpha(alpha) end
    hiddenPages = nil
    if previousTab then previousTab:SetChecked(true) end
    previousTab = nil
end

local pendingPlanRecipe, preparedBatch

local function professionForRecipe(id)
    local info = C_TradeSkillUI.GetProfessionInfoByRecipeID(id)
    return info and (info.parentProfessionID or info.professionID), info and (info.parentProfessionName or info.professionName)
end

local function professionIsOpen(id)
    if not id or not page or not page:IsVisible() then return false end
    local active = Professions.GetProfessionInfo()
    return active and (active.parentProfessionID or active.professionID) == id
end

local function professionSpell(professionID)
    if not professionID or not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then return end
    for _, index in pairs({ GetProfessions() }) do
        local _, _, _, _, _, offset, skillLine = GetProfessionInfo(index)
        if skillLine == professionID and offset then
            local entry = C_SpellBook.GetSpellBookItemInfo(offset + 1, Enum.SpellBookSpellBank.Player)
            return entry and entry.spellID
        end
    end
end

local function requestCraftPreparation(id, quantity, stillNeeded)
    local timeout = 8
    local request = {
        id = id, quantity = quantity, stillNeeded = stillNeeded,
        profession = professionForRecipe(id), expiresAt = GetTime() + timeout,
    }
    pendingPlanRecipe = request
    queue()
    C_Timer.After(timeout, function()
        if pendingPlanRecipe == request then
            pendingPlanRecipe = nil
            queue()
        end
    end)
end

local function preparePendingCraft()
    local request = pendingPlanRecipe
    if not request or InCombatLockdown() or not page or not page:IsVisible()
        or not form or form.isRecraft or form.isInspection then return end
    local recipe = form:GetRecipeInfo()
    if not request.stillNeeded() then pendingPlanRecipe = nil; return end
    if not recipe or recipe.recipeID ~= request.id then
        if not request.requested and professionIsOpen(request.profession) and C_TradeSkillUI.OpenRecipe then
            request.requested = true
            C_TradeSkillUI.OpenRecipe(request.id)
        end
        return
    end
    local amount, create = page.CreateMultipleInputBox, page.CreateButton
    if not amount or not create or not create:IsEnabled() or not page.GetCraftableCount
        or page:GetCraftableCount() < request.quantity then return end
    amount:SetValue(request.quantity)
    if amount:GetValue() == request.quantity then
        pendingPlanRecipe = nil
        preparedBatch = { id = request.id, quantity = request.quantity, done = 0 }
        local batch = preparedBatch
        C_Timer.After(60, function() if preparedBatch == batch then preparedBatch = nil end end)
    end
end

local craftBatch
local progressFrame

local function castDuration(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    return info and info.castTime and info.castTime > 0 and info.castTime / 1000 or nil
end

local function dismissCraftProgress()
    craftBatch = nil
    progressFrame:Hide()
end

local function showInterruptedCraft()
    if not craftBatch or not progressFrame then return end
    craftBatch = nil
    progressFrame.interruptedAt = GetTime()
    progressFrame.fillAtlas = nil
    progressFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressFrame.bar:SetStatusBarColor(0.82, 0.12, 0.08)
    progressFrame.bar:SetMinMaxValues(0, 1)
    progressFrame.bar:SetValue(1)
    progressFrame.count:SetText(INTERRUPTED or SPELL_FAILED_INTERRUPTED or "Interrupted")
end

local function visibleCraftCastBar()
    local overlay = _G.OverlayPlayerCastingBarFrame
    if overlay and overlay:IsVisible() then return overlay end
    local native = _G.PlayerCastingBarFrame or _G.CastingBarFrame
    if native and native:IsVisible() then return native end
end

local function updateCraftCountdown(self)
    local batch = craftBatch
    if not batch then
        if self.interruptedAt then
            local elapsed = GetTime() - self.interruptedAt
            if elapsed >= 2.8 or (elapsed >= 1.2 and not visibleCraftCastBar()) then
                self.interruptedAt = nil
                self:Hide()
            end
        end
        return
    end

    local nativeBar = visibleCraftCastBar()
    if nativeBar then
        if self.castBarAnchor ~= nativeBar then
            self:ClearAllPoints()
            self:SetPoint("CENTER", nativeBar, "CENTER", 0, -5)
            self.castBarAnchor = nativeBar
        end
        local scale = nativeBar:GetEffectiveScale() / self:GetEffectiveScale()
        local width = math.max(328, nativeBar:GetWidth() * scale + 16)
        local height = math.max(74, nativeBar:GetHeight() * scale + 40)
        if math.abs(self:GetWidth() - width) > 0.5 or math.abs(self:GetHeight() - height) > 0.5 then
            self:SetSize(width, height)
        end
    end
    local now = GetTime()
    local _, _, _, startMS, endMS, tradeSkill, _, _, spellID = UnitCastingInfo("player")
    local readableID = spellID and (not issecretvalue or not issecretvalue(spellID))
    local isCrafting = readableID and spellID == batch.id
    if not readableID and (not issecretvalue or not issecretvalue(tradeSkill)) then
        isCrafting = tradeSkill == true
    end
    local duration = batch.castDuration
    local fraction = 0
    local left = batch.quantity - batch.done
    local remaining = duration and left * duration
    if left > 0 and isCrafting then
        batch.lastActivity = now
    elseif now - batch.lastActivity >= (left == 0 and 2 or batch.castDuration and 2.5 or 8) then
        dismissCraftProgress()
        return
    end
    if left > 0 and isCrafting and type(startMS) == "number" and type(endMS) == "number"
        and (not issecretvalue or (not issecretvalue(startMS) and not issecretvalue(endMS))) and endMS > startMS then
        duration = (endMS - startMS) / 1000
        batch.castDuration = duration
        local nativeTexture = nativeBar and nativeBar.GetStatusBarTexture and nativeBar:GetStatusBarTexture()
        local atlas = nativeTexture and nativeTexture:GetAtlas()
        if atlas and atlas ~= self.fillAtlas then
            self.bar:GetStatusBarTexture():SetAtlas(atlas, false)
            self.bar:SetStatusBarColor(1, 1, 1)
            self.fillAtlas = atlas
        end
        local current = math.min(duration, math.max(0, endMS / 1000 - now))
        fraction = math.min(0.99, 1 - current / duration)
        remaining = current + (left - 1) * duration
    end

    self.bar:SetValue(batch.done + fraction)
    local text = ("%d / %d"):format(batch.done, batch.quantity)
    if remaining then
        local seconds = math.ceil(remaining)
        text = text .. ("  ·  ~%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
    end
    if self.count:GetText() ~= text then self.count:SetText(text) end
end

local function updateCraftProgress()
    if not craftBatch then return end
    if not progressFrame then
        progressFrame = box(UIParent, 328, 74)
        progressFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        progressFrame:SetBackdropColor(0.12, 0.085, 0.055, 0.98)
        progressFrame:SetBackdropBorderColor(0.78, 0.63, 0.41)
        progressFrame:EnableMouse(false)
        progressFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -165)
        progressFrame:SetFrameStrata("TOOLTIP")
        progressFrame.title = label(progressFrame, "GameFontNormal", "")
        progressFrame.title:SetPoint("TOP", 0, -10)
        local track = CreateFrame("Frame", nil, progressFrame)
        track:SetPoint("BOTTOMLEFT", 12, 11)
        track:SetPoint("BOTTOMRIGHT", -12, 11)
        track:SetHeight(24)
        local function trackSlice(left, right)
            local texture = track:CreateTexture(nil, "BACKGROUND")
            texture:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\CraftBarTrack")
            texture:SetTexCoord(left / 32, right / 32, 0, 24 / 32)
            texture:SetHeight(24)
            return texture
        end
        local leftCap, middle, rightCap = trackSlice(0, 6), trackSlice(6, 26), trackSlice(26, 32)
        leftCap:SetWidth(6)
        leftCap:SetPoint("LEFT")
        rightCap:SetWidth(6)
        rightCap:SetPoint("RIGHT")
        middle:SetPoint("LEFT", leftCap, "RIGHT")
        middle:SetPoint("RIGHT", rightCap, "LEFT")

        local fillClip = CreateFrame("Frame", nil, track)
        fillClip:SetPoint("TOPLEFT", 4, -3)
        fillClip:SetPoint("BOTTOMRIGHT", -4, 3)
        fillClip:SetClipsChildren(true)
        progressFrame.bar = CreateFrame("StatusBar", nil, fillClip)
        progressFrame.bar:SetAllPoints()
        progressFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        progressFrame.bar:SetStatusBarColor(0.18, 0.56, 1)
        local foreground = CreateFrame("Frame", nil, track)
        foreground:SetAllPoints()
        foreground:SetFrameLevel(progressFrame.bar:GetFrameLevel() + 1)
        local text = label(foreground, "GameFontHighlight", "")
        text:SetPoint("CENTER")
        text:SetDrawLayer("OVERLAY", 2)
        progressFrame.count = text
        progressFrame:SetScript("OnUpdate", updateCraftCountdown)
        progressFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        progressFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        progressFrame:RegisterEvent("PLAYER_STARTED_MOVING")
        progressFrame:SetScript("OnEvent", function(_, event, _, _, spellID)
            local batch = craftBatch
            if not batch or batch.done >= batch.quantity then return end
            if event == "PLAYER_STARTED_MOVING" then
                C_Timer.After(0.15, function()
                    if craftBatch == batch and batch.done < batch.quantity and not UnitCastingInfo("player") then
                        showInterruptedCraft()
                    end
                end)
            elseif spellID and (not issecretvalue or not issecretvalue(spellID)) and spellID == batch.id then
                showInterruptedCraft()
            end
        end)
    end
    local batch = craftBatch
    batch.lastActivity = GetTime()
    if progressFrame.interruptedAt then progressFrame.interruptedAt = nil end
    if not progressFrame.fillAtlas then progressFrame.bar:SetStatusBarColor(0.18, 0.56, 1) end
    progressFrame.title:SetText((C_Spell and C_Spell.GetSpellName(batch.id)) or ("#" .. batch.id))
    progressFrame.bar:SetMinMaxValues(0, batch.quantity)
    progressFrame.bar:SetValue(batch.done)
    updateCraftCountdown(progressFrame)
    progressFrame:Show()

end

local function nativeCraftTarget(id, quantity)
    if not id or InCombatLockdown() or UnitCastingInfo("player") or not page or not page:IsVisible()
        or not form or form.isRecraft or form.isInspection then return end
    local info = form:GetRecipeInfo()
    if not info or info.recipeID ~= id or not page.GetCraftableCount then return end
    local craftable = page:GetCraftableCount()
    if type(craftable) ~= "number" or (issecretvalue and issecretvalue(craftable)) or craftable < quantity then return end
    local all = page.CreateAllButton
    if craftable == quantity and all and all:IsVisible() and all:IsEnabled() then return all end
    local create = page.CreateButton
    local amount = page.CreateMultipleInputBox
    if create and create:IsVisible() and create:IsEnabled() and amount and amount:GetValue() == quantity then
        return create
    end
end

local function updatePreparationText(button)
    local request = button.preparation
    if not request or request ~= pendingPlanRecipe then return end
    local seconds = math.max(0, math.ceil(request.expiresAt - GetTime()))
    if seconds ~= button.preparationSeconds then
        button.preparationSeconds = seconds
        button:SetText(addon.GetText().craftPreparing:format(seconds))
    end
end

local function updateCraftAction(row, id, quantity, output)
    row.actionID, row.actionQuantity = id, quantity
    if not row.secureCraft and id then
        local action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate,SecureActionButtonTemplate,SecureHandlerStateTemplate")
        row.secureCraft = action
        action:SetAllPoints(row.craft)
        action:RegisterForClicks("LeftButtonUp")
        action:SetAttribute("useOnKeyDown", false)
        action:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then
                self:SetAttribute("type", nil)
                self:SetAttribute("clickbutton", nil)
            end
        ]])
        RegisterStateDriver(action, "combat", "[combat] combat; ready")
        action:SetScript("PreClick", function(self, mouseButton, down)
            self.craftAccepted = false
            if InCombatLockdown() or down or mouseButton ~= "LeftButton" then return end
            if self:GetAttribute("type") == "spell" then
                local id, quantity = row.actionID, row.actionQuantity
                local profession = professionForRecipe(id)
                if (pendingPlanRecipe and pendingPlanRecipe.id == id) or professionIsOpen(profession)
                    or self:GetAttribute("spell") ~= professionSpell(profession)
                    or not row.validateCraft(id, quantity) then
                    self:SetAttribute("type", nil)
                    return
                end
                requestCraftPreparation(id, quantity, function() return row.validateCraft(id, quantity) end)
                return
            end
            local target = self:GetAttribute("clickbutton")
            if not target or target ~= nativeCraftTarget(row.actionID, row.actionQuantity)
                or not row.validateCraft(row.actionID, row.actionQuantity) then
                self:SetAttribute("type", nil)
                return
            end
            self.craftAccepted = { id = row.actionID, quantity = row.actionQuantity, done = 0 }
        end)
        action:SetScript("PostClick", function(self)
            if not self.craftAccepted then return end
            craftBatch = self.craftAccepted
            self.craftAccepted = false
            preparedBatch = nil
            updateCraftProgress()
        end)
        local function showDuration(self)
            local duration = castDuration(row.actionID)
            local opensProfession = self == action and action:GetAttribute("type") == "spell"
            if not opensProfession and (not duration or not row.actionQuantity) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local L = addon.GetText()
            if opensProfession then
                GameTooltip:AddLine(L.craftTwoClicks, 1, 1, 1, true)
            end
            if duration and row.actionQuantity then
                local seconds = math.ceil(duration * row.actionQuantity)
                GameTooltip:AddLine(L.craftDuration:format(SecondsToTime(seconds)), 1, 0.85, 0.64, true)
            end
            GameTooltip:Show()
        end
        for _, control in ipairs({ row.craft, action }) do
            control:SetScript("OnEnter", showDuration)
            control:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
    local target = nativeCraftTarget(id, quantity)
    local profession, name
    if id and not target then profession, name = professionForRecipe(id) end
    local spell = profession and not professionIsOpen(profession) and professionSpell(profession) or nil
    local preparing = id and not target and pendingPlanRecipe and pendingPlanRecipe.id == id
    local action = row.secureCraft
    if action then
        action:SetAttribute("type", target and "click" or (not preparing and spell) and "spell" or nil)
        action:SetAttribute("clickbutton", target)
        action:SetAttribute("spell", spell)
        action:SetShown(target ~= nil or spell ~= nil or not not preparing)
        action:SetEnabled(not preparing)
        action.preparation = preparing and pendingPlanRecipe or nil
        action.preparationSeconds = nil
        action:SetScript("OnUpdate", preparing and updatePreparationText or nil)
        local L = addon.GetText()
        if target then
            action:SetText(L.craftDirect:format(output))
        elseif preparing then
            updatePreparationText(action)
        elseif spell then
            action:SetText("1/2  ·  " .. L.craftOpenProfession:format(name or L.unknownProfession))
        end
    end
    row.craft:SetShown(id ~= nil and not target and not spell and not preparing)
end

local function openCraft(id, quantity, stillNeeded)
    if InCombatLockdown() or UnitCastingInfo("player") or not stillNeeded() then return end
    requestCraftPreparation(id, quantity, stillNeeded)
    if professionIsOpen(professionForRecipe(id)) then return end
    shoppingWindow:Hide()
    local recipe = C_TradeSkillUI.GetRecipeInfo(id)
    local name = recipe and recipe.name or (C_Spell and C_Spell.GetSpellName(id)) or ("#" .. id)
    print("ForeverCraft: " .. addon.GetText().planCraftHint:format(name))
end

local function openPlannedCraft(id, quantity)
    local entry = ForeverCraftShopping[id]
    openCraft(id, quantity, function()
        local current = ForeverCraftShopping[id]
        if not current or current ~= entry then return false end
        local remaining = current.target and current.target - current.done or addon.GetLegacyPlanQuantity(id, current)
        return remaining == quantity
    end)
end

local function getIntermediateOffer(professionID, itemID)
    local _, sections = addon.GetShoppingLines(ForeverCraftShopping)
    for _, section in ipairs(sections) do
        if section.id == professionID then
            for index, missingID in ipairs(section.itemIDs) do
                if missingID == itemID then return section.intermediateCrafts[index] end
            end
        end
    end
end

local function createPlannedJobRow(card, refresh)
    local row = CreateFrame("Frame", nil, card)
    row:SetHeight(45)
    row.name = label(row, "GameFontHighlight", "")
    row.name:SetPoint("TOPLEFT", 0, -2)
    row.name:SetPoint("TOPRIGHT", -186, -2)
    row.name:SetWordWrap(false)
    row.status = label(row, "GameFontNormalSmall", "")
    row.status:SetPoint("BOTTOMLEFT", 0, 7)

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(20, 20)
    row.remove:SetPoint("TOPRIGHT")
    row.remove:SetScript("OnClick", function()
        ForeverCraftShopping[row.id] = nil
        refresh()
    end)
    row.save = button(row, 76, "")
    row.save:SetPoint("RIGHT", row.remove, "LEFT", -4, 0)
    row.target = CreateFrame("EditBox", nil, row, "NumericInputSpinnerTemplate")
    row.target:SetWidth(42)
    row.target:SetPoint("RIGHT", row.save, "LEFT", -25, 0)
    row.target:SetAutoFocus(false)
    row.target:SetMaxLetters(4)
    row.target.clampIfInputExceedsRange = true
    row.target:SetMinMaxValues(1, 9999)
    row.target:SetOnValueChangedCallback(function()
        if not row.updatingTarget then row.targetDirty = true end
    end)
    local function save()
        local entry, amount = ForeverCraftShopping[row.id], tonumber(row.target:GetText())
        if entry and amount and amount >= 1 then
            if entry.target then
                addon.SetPlanTarget(entry, entry.done + amount)
            else
                addon.AddShoppingRecipe(ForeverCraftShopping, row.id, amount)
            end
        end
        row.targetDirty = nil
        row.target:ClearFocus()
        refresh()
    end
    row.save:SetScript("OnClick", save)
    row.target:SetScript("OnEnterPressed", save)
    row.target:SetScript("OnEscapePressed", function(self)
        row.targetDirty = nil
        self:ClearFocus()
        refresh()
    end)
    row.craft = button(row, 174, "")
    row.craft:SetPoint("BOTTOMRIGHT", -2, 2)
    row.validateCraft = function(id, quantity)
        for _, job in ipairs(addon.GetPlanRows(ForeverCraftShopping)) do
            if job.id == id and not job.finished and #job.missing == 0 then
                local entry = job.entry
                local remaining = entry.target and entry.target - entry.done or addon.GetLegacyPlanQuantity(id, entry)
                return remaining == quantity
            end
        end
        return false
    end
    row.craft:SetScript("OnClick", function()
        for _, job in ipairs(addon.GetPlanRows(ForeverCraftShopping)) do
            if job.id == row.id and not job.finished and #job.missing == 0 then
                local entry = job.entry
                local quantity = entry.target and entry.target - entry.done or addon.GetLegacyPlanQuantity(job.id, entry)
                if quantity and quantity > 0 then openPlannedCraft(job.id, quantity) end
                return
            end
        end
    end)
    return row
end

local function refreshShopping()
    if not ForeverCraftShopping then return end
    if next(ForeverCraftShopping) then
        shoppingLines, shoppingSections = addon.GetShoppingLines(ForeverCraftShopping)
    else
        shoppingLines, shoppingSections = {}, {}
    end
    addon.RefreshSideShopping(shoppingSections)
    if not shoppingWindow or not shoppingWindow:IsShown() or InCombatLockdown() then return end
    local L = addon.GetText()
    local lines, sections = shoppingLines, shoppingSections
    local content = shoppingWindow.content
    local byProfession, combined = {}, {}
    for _, section in ipairs(sections) do
        local view = { id = section.id, name = section.name, rows = section.rows,
            itemIDs = section.itemIDs, quantities = section.quantities, alternatives = section.alternatives,
            alternativeItems = section.alternativeItems, intermediateCrafts = section.intermediateCrafts, jobs = {} }
        combined[#combined + 1], byProfession[view.id] = view, view
    end
    for _, job in ipairs(addon.GetPlanRows(ForeverCraftShopping)) do
        if not job.finished then
            local entry = job.entry
            local id = entry.professionID or 0
            local section = byProfession[id]
            if not section then
                section = { id = id, name = addon.GetPlanProfessionName(entry) or L.unknownProfession, rows = {}, jobs = {} }
                combined[#combined + 1], byProfession[id] = section, section
            end
            local quantity = entry.target and entry.target - entry.done or addon.GetLegacyPlanQuantity(job.id, entry)
            job.quantity = quantity
            section.jobs[#section.jobs + 1] = job
        end
    end
    table.sort(combined, function(a, b) return a.id < b.id end)
    sections = combined
    local y = 0
    for index, section in ipairs(sections) do
        local card = shoppingWindow.cards[index]
        local collapsed = shoppingWindow.collapsed[section.id] == true
        if not card then
            card = CreateFrame("Frame", nil, content)
            card.icon = card:CreateTexture(nil, "ARTWORK")
            card.icon:SetSize(17, 17)
            card.icon:SetPoint("TOPLEFT", 1, -4)
            local native = _G.ProfessionsRecipeListCategoryMixin
            local heading = native and CreateFrame("Button", nil, card, "ProfessionsRecipeListCategoryTemplate")
                or button(card, 150, "")
            if not native then
                heading.SetHeaderText = heading.SetText
                heading.UpdateCollapsedState = function() end
            end
            heading:SetPoint("TOPLEFT", 23, 0)
            heading:SetPoint("TOPRIGHT", -2, 0)
            if heading.RankBar then heading.RankBar:Hide() end
            card.heading = heading
            local function toggleSection()
                local id = card.professionID
                shoppingWindow.collapsed[id] = not shoppingWindow.collapsed[id]
                refreshShopping()
            end
            heading:SetScript("OnClick", toggleSection)
            local collapseButton = heading.GetCollapseButton and heading:GetCollapseButton()
            if collapseButton and collapseButton:IsObjectType("Button") then
                collapseButton:SetScript("OnClick", toggleSection)
            end
            card.plannedTitle = label(card, "GameFontNormalSmall", "")
            card.plannedTitle:SetPoint("TOPLEFT", 26, -30)
            card.jobRows = {}
            card.materialTitle = label(card, "GameFontNormalSmall", "")
            card.rows = {}
            shoppingWindow.cards[index] = card
        end
        local icon = section.id > 0 and C_TradeSkillUI.GetTradeSkillTexture(section.id)
        card.icon:SetTexture(icon or shoppingIcon)
        card.professionID = section.id
        card.heading:SetHeaderText(section.name)
        card.heading:UpdateCollapsedState(collapsed)
        local shownRows = collapsed and 0 or #section.rows
        local rowOffset = 28
        local hasJobs = not collapsed and #section.jobs > 0
        card.plannedTitle:SetText(L.planned)
        card.plannedTitle:SetShown(hasJobs)
        local jobs = hasJobs and #section.jobs or 0
        if hasJobs then rowOffset = 42 end
        for jobIndex = 1, jobs do
            local job = section.jobs[jobIndex]
            local row = card.jobRows[jobIndex]
            if not row then
                row = createPlannedJobRow(card, refreshShopping)
                card.jobRows[jobIndex] = row
            end
            if row.id ~= job.id then
                row.targetDirty = nil
                row.target:ClearFocus()
            end
            row.id = job.id
            local ready = job.quantity and #job.missing == 0
            row.name:SetText(job.quantity and ("%d × %s"):format(job.quantity, job.name) or job.name)
            row.status:SetText(ready and L.planReady or (job.quantity and L.planNeedsMaterials or L.planLegacy))
            if ready then row.status:SetTextColor(0.48, 0.93, 0.46) else row.status:SetTextColor(1, 0.75, 0.38) end
            row.save:SetText(L.planSave)
            if not row.targetDirty and not row.target:HasFocus() then
                row.updatingTarget = true
                row.target:SetValue(job.quantity or 1)
                row.updatingTarget = nil
            end
            row.craft:SetText((L.planCraft or addon.strings.enUS.planCraft):format(job.quantity or 0))
            updateCraftAction(row, ready and job.id or nil, job.quantity, job.quantity)
            row:SetPoint("TOPLEFT", 26, -rowOffset)
            row:SetPoint("TOPRIGHT", -4, -rowOffset)
            row:Show()
            rowOffset = rowOffset + 47
        end
        for jobIndex = jobs + 1, #card.jobRows do card.jobRows[jobIndex]:Hide() end
        card.materialTitle:SetShown(shownRows > 0)
        card.materialTitle:SetText(L.planMissing)
        card.materialTitle:SetPoint("TOPLEFT", 26, -rowOffset)
        if shownRows > 0 then rowOffset = rowOffset + 18 end
        for rowIndex = 1, shownRows do
            local text = section.rows[rowIndex]
            local row = card.rows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, card)
                row:SetHeight(20)
                local remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
                remove:SetSize(17, 17)
                remove:SetPoint("RIGHT")
                remove:SetScript("OnClick", function()
                    addon.RemoveShoppingItem(ForeverCraftShopping, row.professionID, row.itemID)
                    refreshShopping()
                end)
                remove:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(addon.GetText().removeShoppingItem)
                    GameTooltip:Show()
                end)
                remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.text = label(row, "GameFontHighlight", "")
                row.text:SetPoint("LEFT")
                row.text:SetPoint("RIGHT", remove, "LEFT", -26, 0)
                row.text:SetWordWrap(false)
                local info = CreateFrame("Button", nil, row)
                row.alternative = info
                info:SetSize(15, 15)
                info:SetPoint("RIGHT", remove, "LEFT", -5, 0)
                info:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
                info:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(addon.GetText().craftAlternative)
                    GameTooltip:AddLine(row.alternativeText, 1, 1, 1, true)
                    if row.craftEstimate then
                        GameTooltip:AddLine(addon.GetText().marketEstimate:format(GetMoneyString(row.craftEstimate)))
                    end
                    GameTooltip:Show()
                end)
                info:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.craft = button(row, 136, "")
                row.craft:SetPoint("RIGHT", info, "LEFT", -5, 0)
                row.validateCraft = function(id, quantity)
                    local offer = getIntermediateOffer(row.professionID, row.itemID)
                    return offer and offer.recipeID == id and offer.crafts >= quantity
                end
                row.craft:SetScript("OnClick", function()
                    local professionID, itemID = row.professionID, row.itemID
                    local offer = getIntermediateOffer(professionID, itemID)
                    if not offer then refreshShopping(); return end
                    openCraft(offer.recipeID, offer.crafts, function()
                        local current = getIntermediateOffer(professionID, itemID)
                        return current and current.recipeID == offer.recipeID and current.crafts >= offer.crafts
                    end)
                end)
                card.rows[rowIndex] = row
            end
            row.professionID, row.itemID = section.id, section.itemIDs[rowIndex]
            local estimate, source
            if GetMoneyString then
                estimate, source = addon.GetMarketEstimate(row.itemID, section.quantities[rowIndex])
            end
            row.text:SetText(estimate and (text .. "   ·   " .. source .. " " .. L.marketEstimate:format(GetMoneyString(estimate))) or text)
            row.craftEstimate = nil
            local alternatives = section.alternativeItems[rowIndex]
            if GetMoneyString and alternatives and #alternatives > 0 then
                local total = 0
                for _, material in ipairs(alternatives) do
                    local cost = addon.GetMarketEstimate(material.id, material.quantity)
                    if not cost then total = nil; break end
                    total = total + cost
                end
                row.craftEstimate = total
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", card, "TOPLEFT", 26, -rowOffset)
            row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -7, -rowOffset)
            row.alternativeText = section.alternatives[rowIndex]
            row.alternative:SetShown(row.alternativeText ~= nil)
            local offer = section.intermediateCrafts[rowIndex]
            updateCraftAction(row, offer and offer.recipeID, offer and offer.crafts, offer and offer.output)
            if offer then row.craft:SetText(L.planCraft:format(offer.output)) end
            row.text:SetPoint("RIGHT", offer and row.craft or row.alternative, "LEFT", -5, 0)
            row:Show()
            rowOffset = rowOffset + 20
        end
        for rowIndex = shownRows + 1, #card.rows do card.rows[rowIndex]:Hide() end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        card:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        local height = rowOffset + 1
        card:SetHeight(height)
        card:Show()
        y = y + height + 8
    end
    for index = #sections + 1, #shoppingWindow.cards do shoppingWindow.cards[index]:Hide() end
    content:SetHeight(math.max(1, y))
    local headerTitle = addon.HeaderTitle(L.shopping)
    if shoppingDocked then
        if shoppingTitleText and shoppingTitleText:GetText() ~= headerTitle then
            shoppingTitleText:SetText(headerTitle)
        end
    else
        local shellTitle = shoppingShell.TitleContainer and shoppingShell.TitleContainer.TitleText
        if not shellTitle or shellTitle:GetText() ~= headerTitle then shoppingShell:SetTitle(headerTitle) end
    end
    shoppingWindow.empty:SetText(L.emptyShopping)
    shoppingWindow.empty:SetShown(#sections == 0)
    shoppingWindow.clear:SetText(L.clearShopping)
    shoppingWindow.clear:SetEnabled(next(ForeverCraftShopping) ~= nil)
    shoppingWindow.close:SetText(L.done)
end

local function showShopping(dock)
    if addon.CloseProfessionGuide then addon.CloseProfessionGuide() end
    if InCombatLockdown() then return end
    addon.CloseDisenchant()
    addon.CloseBank()
    if not shoppingWindow then
        local shell = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
        shoppingShell = shell
        addon.AddSettingsGear(shell)
        shell:Hide()
        shell:SetPortraitToAsset(shoppingIcon)
        shell:SetPoint("CENTER")
        shell:SetFrameStrata("DIALOG")
        shell:SetMovable(true)
        shell:SetClampedToScreen(true)
        shell:EnableMouse(true)
        shell:RegisterForDrag("LeftButton")
        shell:SetScript("OnDragStart", shell.StartMoving)
        shell:SetScript("OnDragStop", shell.StopMovingOrSizing)
        shell:HookScript("OnHide", function()
            if shoppingWindow:GetParent() == shell then shoppingWindow:Hide() end
        end)

        local frame = CreateFrame("Frame", nil, shell)
        shoppingWindow = frame
        frame:Hide()
        frame:EnableMouse(true)
        local backdrop = frame:CreateTexture(nil, "BACKGROUND")
        backdrop:SetAllPoints()
        backdrop:SetColorTexture(33 / 255, 25 / 255, 19 / 255, 1)
        local inset = CreateFrame("Frame", nil, frame)
        inset:SetPoint("TOPLEFT", 4, -4)
        inset:SetPoint("BOTTOMRIGHT", -4, 40)
        local bottomLine = inset:CreateTexture(nil, "ARTWORK")
        bottomLine:SetPoint("BOTTOMLEFT", 4, 0)
        bottomLine:SetPoint("BOTTOMRIGHT", -4, 0)
        bottomLine:SetHeight(1)
        bottomLine:SetColorTexture(0.37, 0.27, 0.15, 0.55)
        local artwork = inset:CreateTexture(nil, "BACKGROUND", nil, 1)
        artwork:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\TradingLedger")
        artwork:SetPoint("BOTTOMRIGHT", -8, 8)
        local function resizeArtwork()
            local width = math.min(520, math.max(1, inset:GetWidth() - 16))
            artwork:SetSize(width, width * 309 / 1024)
        end
        inset:HookScript("OnSizeChanged", resizeArtwork)
        resizeArtwork()
        frame:HookScript("OnHide", function()
            shoppingDocked = false
            restoreProfessionPage()
            queueLayout()
            setShoppingSelected(false)
            if shell:IsShown() then shell:Hide() end
        end)

        frame.empty = label(frame, "GameFontHighlightSmall", "")
        frame.empty:SetPoint("TOPLEFT", inset, "TOPLEFT", 14, -14)
        frame.empty:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

        local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
        frame.inset, frame.scroll = inset, scroll
        scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 14, -14)
        scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -25, 8)
        local content = CreateFrame("Frame", nil, scroll)
        frame.content, frame.cards, frame.collapsed = content, {}, {}
        content:SetSize(330, 1)
        scroll:SetScrollChild(content)
        addon.HideUnusedScrollbar(scroll)
        scroll:HookScript("OnSizeChanged", function(self) content:SetWidth(self:GetWidth()) end)

        frame.clear = button(frame, 110, "")
        frame.clear:SetPoint("BOTTOMLEFT", 12, 12)
        frame.clear:SetScript("OnClick", function()
            wipe(ForeverCraftShopping)
            refreshShopping()
        end)
        frame.close = button(frame, 85, "")
        frame.close:SetPoint("BOTTOMRIGHT", -12, 12)
        frame.close:SetScript("OnClick", function() frame:Hide() end)
    end
    if page and page:IsVisible() and form:GetRecipeInfo() then addon.RememberIntermediateRecipes() end
    local docked = dock == true and shoppingTab and root:IsShown()
    restoreProfessionPage()
    shoppingDocked = docked and true or false
    shoppingWindow:SetParent(shoppingDocked and root or shoppingShell)
    shoppingWindow:ClearAllPoints()
    shoppingWindow:SetFrameStrata(shoppingDocked and "FULLSCREEN_DIALOG" or "DIALOG")
    shoppingWindow:SetFrameLevel((shoppingDocked and root or shoppingShell):GetFrameLevel() + 1)
    if shoppingDocked then
        shoppingShell:Hide()
        shoppingWindow:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -72)
        shoppingWindow:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, 6)
        if not shoppingHeaderArt then
            local clip = CreateFrame("Frame", nil, root)
            shoppingHeaderArt = clip
            clip:SetPoint("TOPLEFT", root, "TOPLEFT", 3, -21)
            clip:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", -3, -72)
            clip:SetFrameLevel(root:GetFrameLevel() + 2)
            clip:SetClipsChildren(true)
            local artFrame = CreateFrame("Frame", nil, clip)
            artFrame:SetPoint("TOPLEFT")
            artFrame:SetPoint("TOPRIGHT")
            artFrame:SetHeight(header and header:GetHeight() or root:GetHeight())
            local art = artFrame:CreateTexture(nil, "BACKGROUND")
            art:SetAtlas(header and header:GetAtlas() or "Profession-Background-Template2")
            art:SetAllPoints()
        end
        shoppingHeaderArt:Show()
        local title = root.TitleContainer and root.TitleContainer.TitleText
        if title then
            if not shoppingTitleText then
                shoppingTitleText = root.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                shoppingTitleText:SetAllPoints(title)
                shoppingTitleText:SetJustifyH("CENTER")
                shoppingTitleText:SetWordWrap(false)
            end
            savedTitleAlpha = title:GetAlpha()
            title:SetAlpha(0)
            local L = addon.GetText()
            shoppingTitleText:SetText(addon.HeaderTitle(L.shopping))
            shoppingTitleText:Show()
        end
        local portrait = root.PortraitContainer and root.PortraitContainer.portrait
        if portrait then
            savedPortrait = portrait:GetTexture()
            root:SetPortraitToAsset(shoppingIcon)
            shoppingPortrait = portrait:GetTexture()
        end
        hiddenPages = {}
        for _, professionPage in ipairs(root.Pages or { page, root.BookPage }) do
            hiddenPages[professionPage] = professionPage:GetAlpha()
            professionPage:SetAlpha(0)
        end
        for _, tab in ipairs({ root.ProfessionsOverviewTab, unpack(root.rightProfessionTabs) }) do
            if tab:GetID() == root.selectedGamepadTabID then previousTab = tab end
            tab:SetChecked(false)
        end
    else
        local width = root and math.min(root:GetWidth(), UIParent:GetWidth() - 40) or 390
        local height = root and math.min(root:GetHeight(), UIParent:GetHeight() - 40) or 440
        shoppingShell:SetSize(math.max(340, width), math.max(310, height))
        shoppingWindow:SetPoint("TOPLEFT", shoppingShell, "TOPLEFT", 6, -30)
        shoppingWindow:SetPoint("BOTTOMRIGHT", shoppingShell, "BOTTOMRIGHT", -6, 6)
        shoppingShell:Show()
    end
    GameTooltip:Hide()
    shoppingWindow:Show()
    setShoppingSelected(shoppingDocked)
    refreshShopping()
    queueLayout()
end

local function reservePlannerSpace(reagents, clearance)
    local point, relative, relativePoint, x, y = reagents:GetPoint(1)
    if not point then return end
    local prior = planner.reagentAnchor
    local alreadyOffset = prior and point == prior.point and relative == prior.relative
        and relativePoint == prior.relativePoint and x == prior.x and y == prior.y
    if alreadyOffset and clearance == prior.clearance then return end

    local nativeY = alreadyOffset and y + prior.clearance or y
    local targetY = nativeY - clearance
    planner.reagentAnchor = {
        point = point, relative = relative, relativePoint = relativePoint,
        x = x, y = targetY, clearance = clearance,
    }
    if y ~= targetY then
        reagents:ClearAllPoints()
        reagents:SetPoint(point, relative, relativePoint, x, targetY)
    end
end

local function refresh()
    if not page or not page:IsVisible() or InCombatLockdown() then return end
    local favorite, title = form.FavoriteButton, form.OutputText
    if favorite and favorite:IsShown() and title and title:IsShown() and list:IsShown() then
        local _, titleY = title:GetCenter()
        local top = form:GetTop()
        if top and titleY then
            local y = titleY - top + 1
            local point, relative, target, x, oldY = favorite:GetPoint()
            if point ~= "RIGHT" or relative ~= form or target ~= "TOPRIGHT" or x ~= -18
                or not oldY or math.abs(oldY - y) > 0.5 then
                favorite:ClearAllPoints()
                favorite:SetPoint("RIGHT", form, "TOPRIGHT", -18, y)
            end
        end
    end
    local recipe = form:GetRecipeInfo()
    local id = recipe and recipe.recipeID
    if id then addon.RememberIntermediateRecipes() end
    local spinner = page.CreateMultipleInputBox
    local count = spinner and spinner:GetValue()
    count = tonumber(count)
    if id ~= lastRecipeID then
        lastRecipeID = id
        planner.amount:SetValue(math.max(1, count or 0))
    elseif count and count >= 1 and count ~= nativeQuantity then
        planner.amount:SetValue(count)
    end
    nativeQuantity = count
    local reagents = form.Reagents
    local visible = id and reagents:IsShown() and not form.isInspection
    planner:SetShown(visible and true or false)
    if not visible then planner.skillScale:Hide() end
    for slot, labels in pairs(reagentLabels) do
        labels.active = false
        if not visible and labels.name:IsShown() then
            slot.Name:SetAlpha(labels.originalAlpha)
            labels.name:Hide()
            labels.count:Hide()
        end
    end
    if not visible then
        reservePlannerSpace(reagents, 0)
        return
    end
    local showScale = ForeverCraftDB.showSkillScale ~= false and not form.isRecraft
        and addon.UpdateSkillScale(planner.skillScale, recipe, Professions.GetProfessionInfo())
    planner.skillScale:SetShown(showScale and true or false)

    reservePlannerSpace(reagents, showScale and 60 or 26)

    local right, left = form:GetRight(), planner:GetLeft()
    if right and left then
        local width = math.max(230, right - left - 18)
        if math.abs(planner:GetWidth() - width) > 0.5 then planner:SetWidth(width) end
    end

    local amount = planner.amount:GetValue()
    local basic = Enum.CraftingReagentType.Basic
    local slots = form:GetSlotsByReagentType(basic)
    for _, slot in ipairs(slots or {}) do
        local data = slot:GetReagentSlotSchematic()
        local reagents = data and data.reagents
        local item = reagents and #reagents == 1 and reagents[1]
        if slot:IsShown() and slot.Name and item and item.itemID and item.itemID > 0 then
            local name = addon.GetLoadedItemName(item.itemID)
            if name and name ~= "" then
                local owned = C_Item.GetItemCount(item.itemID, false)
                local perCraft = data.GetQuantityRequired and data:GetQuantityRequired(item) or data.quantityRequired
                local needed = perCraft * amount
                local color = owned < needed and RED_FONT_COLOR or GREEN_FONT_COLOR
                local labels = reagentLabels[slot]
                if not labels then
                    local font = slot.Name:GetFontObject()
                    labels = {
                        name = label(slot, "GameFontHighlightSmall", ""),
                        count = label(slot, "GameFontHighlightSmall", ""),
                        originalAlpha = slot.Name:GetAlpha(),
                    }
                    if font then
                        labels.name:SetFontObject(font)
                        labels.count:SetFontObject(font)
                    end
                    labels.name:SetPoint("LEFT", slot.Name, "LEFT")
                    labels.count:SetPoint("LEFT", labels.name, "RIGHT", 7, 0)
                    labels.count:SetWordWrap(false)
                    reagentLabels[slot] = labels
                end
                labels.name:SetText(slot:GetNameColor():WrapTextInColorCode(name))
                labels.count:SetText(color:WrapTextInColorCode(("%d/%d"):format(owned, needed)))
                local singleColumn = #slots <= 3 or (#slots == 4 and not form.isRecraft)
                local rowWidth = singleColumn and math.min(form:GetWidth() - 80, 300) or slot:GetWidth() - 45
                local nameWidth = math.max(28, rowWidth - labels.count:GetUnboundedStringWidth() - 7)
                labels.name:SetWidth(math.min(nameWidth, labels.name:GetUnboundedStringWidth()))
                labels.active = true
                labels.name:Show()
                labels.count:Show()
                slot.Name:SetAlpha(0)
            end
        end
    end
    for slot, labels in pairs(reagentLabels) do
        if not labels.active and labels.name:IsShown() then
            slot.Name:SetAlpha(labels.originalAlpha)
            labels.name:Hide()
            labels.count:Hide()
        end
    end
    planner.hint:SetShown(amount > 1 or slots and #slots > 0)
end

local function createWelcomeColumn(book)
    local column = CreateFrame("Frame", nil, book)
    local background = column:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\WelcomeCard")
    local art = column:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetPoint("BOTTOM", 0, 8)
    column.art = art
    art:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\WelcomeWorkshop")
    art:SetVertexColor(0.79, 0.66, 0.53, 0.17)

    addon.BuildWorkshopLog(column)
    column:Hide()
    return column
end

local applyingLayout
local function updateLayout(fromSizeChange)
    if applyingLayout or not root or InCombatLockdown() then return end
    local width = root:GetWidth()
    local nativeWidthChanged = width > 0 and (not appliedWidth or math.abs(width - appliedWidth) > 0.5)
    if nativeWidthChanged then originalWidth = width end
    local formWidth = form:GetWidth()
    if formWidth > 0 and (not appliedFormWidth or math.abs(formWidth - appliedFormWidth) > 0.5) then
        originalFormWidth = formWidth
    end
    if not originalWidth or not originalFormWidth then return end
    applyingLayout = true
    local book = root.BookPage
    local overview = book and book:IsVisible()
    local showWelcome = overview and book:GetAlpha() > 0
    local recipes = not overview and page:IsVisible() and list:IsShown()
    -- The native desired width can be wider than the recipe panes on Forever.
    if recipes then
        local left, right = root:GetLeft(), form:GetRight()
        if left and right and right > left then
            local contentWidth = right - left + 8
            local listExtra = list:GetWidth() - originalListWidth
            local formExtra = formWidth - originalFormWidth
            recipeBaseWidth = contentWidth - listExtra - formExtra
        end
    end
    local baseWidth = recipes and (recipeBaseWidth
        or (page.GetDesiredPageWidth and page:GetDesiredPageWidth())
        or originalWidth) or originalWidth
    local sharedWidth, logVisible
    if book then
        local cards = book.ProfessionsContentFrame
        local primary = cards and cards.PrimaryProfession1
        local third = cards and cards.SecondaryProfession3
        local second = cards and cards.SecondaryProfession2
        local topCard = primary and (primary.Background or primary)
        local bottomCard = third and (third.Background or third)
        local adjacentCard = second and (second.Background or second)
        local rootLeft, rootTop = root:GetLeft(), root:GetTop()
        local left, top, right
        if topCard then
            left, top, right = topCard:GetLeft(), topCard:GetTop(), topCard:GetRight()
        end
        local bottom = bottomCard and bottomCard:GetBottom()
        local neighborLeft = bottomCard and bottomCard:GetLeft()
        local neighborRight = adjacentCard and adjacentCard:GetRight()
        if rootLeft and rootTop and left and top and right and bottom and neighborLeft and neighborRight then
            local gap = math.max(0, neighborLeft - neighborRight)
            -- Blizzard's atlas has transparent padding around the visible card trim.
            local minimumCardWidth = bottomCard:GetWidth() - 8
            local cardHeight = top - bottom - 10
            local start = right - rootLeft + gap
            local rightInset = left - rootLeft + 6
            local minimumWidth = start + minimumCardWidth + rightInset
            local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local room = UIParent:GetWidth() / scale - rootLeft - 66
            local preferredCardWidth = math.floor(bottomCard:GetWidth() * 1.3 + 0.5)
            local desiredWidth = math.min(room, start + preferredCardWidth + rightInset)
            local cardWidth = desiredWidth - start - rightInset
            if cardWidth > 0 and cardHeight > 0 and room >= minimumWidth then
                sharedWidth = desiredWidth
            end
            if showWelcome and cardWidth >= minimumCardWidth and cardHeight > 0 then
                logVisible = true
                welcomeColumn = welcomeColumn or createWelcomeColumn(book)
                welcomeColumn:SetPoint("TOPLEFT", root, "TOPLEFT", start, top - rootTop - 6)
                welcomeColumn:SetSize(cardWidth, cardHeight)
                local artSize = math.max(1, cardWidth - 12)
                welcomeColumn.art:SetSize(artSize, artSize)
                welcomeColumn.refreshText()
            end
        end
    end
    if welcomeColumn then welcomeColumn:SetShown(logVisible == true) end
    if addon.SetProfessionGuideOverviewCard then
        addon.SetProfessionGuideOverviewCard(logVisible and welcomeColumn or nil)
    end
    local forList, forForm = 0, 0
    if recipes and (not ForeverCraftDB or ForeverCraftDB.wide ~= false) then
        local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local room = UIParent:GetWidth() / scale - (root:GetLeft() or 20) - 66
        local previousListExtra = math.floor(baseWidth * 0.57)
        local previousFormExtra = baseWidth - previousListExtra
        local listExtra = math.max(0, (originalListWidth + previousListExtra) * 2 / 3 - originalListWidth)
        local formExtra = math.max(0, (originalFormWidth + previousFormExtra) * 0.75 - originalFormWidth)
        local desiredExtra = listExtra + formExtra
        local target = sharedWidth or math.min(room, baseWidth + desiredExtra)
        local extraWidth = math.max(0, target - baseWidth)
        local listShare = desiredExtra > 0 and listExtra / desiredExtra or 0.5
        forList = math.floor(extraWidth * listShare)
        forForm = extraWidth - forList
    end
    local extra = forList + forForm
    appliedWidth = overview and (sharedWidth or originalWidth) or (baseWidth + extra)
    appliedFormWidth = originalFormWidth + forForm
    if math.abs(list:GetWidth() - originalListWidth - forList) > 0.5 then
        list:SetWidth(originalListWidth + forList)
    end
    if math.abs(formWidth - appliedFormWidth) > 0.5 then
        form:SetWidth(appliedFormWidth)
    end
    if math.abs(width - appliedWidth) > 0.5 then
        root:SetWidth(appliedWidth)
        if not fromSizeChange and UpdateUIPanelPositions and root:IsShown() then UpdateUIPanelPositions(root) end
    end
    if header and math.abs(header:GetWidth() - headerWidth - extra) > 0.5 then header:SetWidth(headerWidth + extra) end
    local guideSpace = recipes and addon.GetProfessionGuideHeaderSpace and addon.GetProfessionGuideHeaderSpace() or 0
    local rankExtra = extra - guideSpace
    if rankBar and math.abs(rankBar:GetWidth() - rankWidth - rankExtra) > 0.5 then
        local oldRankWidth = rankBar:GetWidth()
        local maskOffset = rankBar.overrideMaskRightOffset or 0
        local progress = (rankBar.Mask:GetWidth() - maskOffset) / oldRankWidth
        rankBar:SetWidth(rankWidth + rankExtra)
        for region, baseWidth in pairs(rankRegions) do region:SetWidth(baseWidth + rankExtra) end
        rankBar.Mask:SetWidth(math.max(0.01, rankBar:GetMaskWidth(progress)))
    end
    applyingLayout = false
end

queue = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if layoutQueued then
            layoutQueued = false
            updateLayout()
        end
        preparePendingCraft()
        refresh()
        if shoppingWindow and shoppingWindow:IsShown() then refreshShopping() end
    end)
end

queueLayout = function()
    layoutQueued = true
    queue()
end

addon.QueueProfessionLayout = queueLayout

local function nativeLayoutChanged()
    updateLayout()
    queue()
end

local function recipeLayoutChanged()
    if appliedFormWidth and math.abs(form:GetWidth() - appliedFormWidth) > 0.5 then
        updateLayout()
    end
    queue()
end

local function localize()
    addon.RefreshFishingLog()
    addon.RefreshDisenchantText()
    if addon.RefreshProfessionGuide then addon.RefreshProfessionGuide() end
    if welcomeColumn and welcomeColumn:IsVisible() then welcomeColumn.refreshText() end
    if not planner then return end
    local L = addon.GetText()
    planner.quantity:SetText(L.quantity)
    planner.shopping:SetText(L.addShopping)
    refreshShopping()
    refresh()
end

local function attach()
    if root then return end
    local frame = _G.ProfessionsFrame
    local crafting = frame and frame.CraftingPage
    if not crafting or not crafting.RecipeList or not crafting.SchematicForm or not crafting.SchematicForm.Reagents
        or not crafting.SchematicForm.GetSlotsByReagentType then return end
    root, page, list, form = frame, crafting, crafting.RecipeList, crafting.SchematicForm
    originalListWidth = list:GetWidth()
    for _, region in ipairs({ page:GetRegions() }) do
        local atlas = region.GetAtlas and region:GetAtlas()
        if atlas and atlas:lower() == "profession-background-template2" then
            header, headerWidth = region, region:GetWidth()
            break
        end
    end
    local bar = page.RankBar
    if bar and bar.Background and bar.Border and bar.Fill and bar.Mask and bar.GetMaskWidth then
        rankBar, rankWidth = bar, bar:GetWidth()
        rankRegions = {
            [bar.Background] = bar.Background:GetWidth(),
            [bar.Border] = bar.Border:GetWidth(),
            [bar.Fill] = bar.Fill:GetWidth(),
        }
    end

    planner = CreateFrame("Frame", nil, form)
    planner:SetSize(230, 18)
    planner:SetPoint("BOTTOMLEFT", form.Reagents, "TOPLEFT", 0, 9)
    planner:SetFrameLevel(form:GetFrameLevel() + 12)
    planner.skillScale = addon.CreateSkillScale(form, planner)
    planner:Hide()
    planner.quantity = label(planner, "GameFontNormalSmall", "")
    planner.quantity:SetPoint("LEFT")
    local amount = CreateFrame("EditBox", nil, planner, "NumericInputSpinnerTemplate")
    planner.amount = amount
    amount:SetWidth(38)
    amount:SetPoint("LEFT", planner.quantity, "RIGHT", 34, 0)
    amount:SetMaxLetters(4)
    amount.clampIfInputExceedsRange = true
    amount.highlightIfInputExceedsRange = true
    amount:SetMinMaxValues(1, 9999)
    amount:SetScript("OnEnterPressed", amount.ClearFocus)
    amount:SetOnValueChangedCallback(queue)

    planner.hint = CreateFrame("Button", nil, planner)
    planner.hint:SetSize(16, 16)
    planner.hint:SetPoint("LEFT", amount.IncrementButton, "RIGHT", 5, 0)
    planner.hint:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
    planner.hint:SetScript("OnEnter", function(self)
        local recipe = form:GetRecipeInfo()
        local count = amount:GetValue()
        local _, details = addon.GetMaterialLines(recipe and recipe.recipeID, count)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(addon.GetText().scopes, 1, 0.85, 0.64, true)
        for _, line in ipairs(details or {}) do
            GameTooltip:AddLine(line, 1, 0.85, 0.64, true)
        end
        GameTooltip:Show()
    end)
    planner.hint:SetScript("OnLeave", function() GameTooltip:Hide() end)

    planner.shopping = button(planner, 80, "")
    planner.shopping:SetPoint("RIGHT", planner, "RIGHT", 0, 0)
    planner.shopping:SetScript("OnClick", function()
        local recipe = form:GetRecipeInfo()
        if not addon.AddShoppingRecipe(ForeverCraftShopping, recipe and recipe.recipeID, amount:GetValue(), page.professionInfo) then
            print("ForeverCraft: " .. addon.GetText().nothingToAdd)
        end
        showShopping(true)
    end)
    planner.shopping:SetScript("OnEnter", function(self)
        local L = addon.GetText()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.shoppingTip, 1, 0.85, 0.64, true)
        GameTooltip:AddLine(L.shoppingChoice, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    planner.shopping:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if root.ProfessionsOverviewTab and root.rightProfessionTabs then
        shoppingTab = CreateFrame("Frame", nil, root, "LargeSideTabButtonTemplate")
        shoppingTab.fillToInterior = true
        shoppingTab:SetFrameStrata("DIALOG")
        shoppingTab.Icon:SetTexture(shoppingIcon)
        setShoppingSelected(false)
        local click = CreateFrame("Button", nil, shoppingTab)
        click:SetAllPoints()
        click:SetScript("OnClick", function()
            addon.CloseDisenchant()
            addon.CloseBank()
            if shoppingWindow and shoppingWindow:IsShown() and shoppingDocked then
                shoppingWindow:Hide()
                queue()
            else
                showShopping(true)
                queue()
            end
        end)
        click:SetScript("OnEnter", function(self)
            local L = addon.GetText()
            addon.ui.navTooltip(self, L.shopping, L.navShoppingDesc or addon.strings.enUS.navShoppingDesc)
        end)
        click:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local function leaveShopping()
            if shoppingWindow and shoppingWindow:GetParent() == root then shoppingWindow:Hide() end
        end
        local bankTab = addon.AttachBank(root, function()
            leaveShopping()
            addon.CloseDisenchant()
            if addon.CloseProfessionGuide then addon.CloseProfessionGuide() end
        end, header)
        local financeTab = addon.AttachFinance(root, function()
            leaveShopping()
            addon.CloseDisenchant()
            if addon.CloseProfessionGuide then addon.CloseProfessionGuide() end
        end, header)
        positionTab = function()
            local last = addon.PositionDisenchantTab(root)
            addon.AnchorProfessionSideTab(shoppingTab, last)
            addon.AnchorProfessionSideTab(bankTab, shoppingTab)
            addon.AnchorProfessionSideTab(financeTab, bankTab)
            -- One compact, coherent navigation rail for Blizzard's and ForeverCraft's tabs.
            local tabs = { root.ProfessionsOverviewTab }
            for _, professionTab in ipairs(root.rightProfessionTabs) do
                if professionTab:IsShown() then tabs[#tabs + 1] = professionTab end
            end
            if addon.disenchantTab and addon.disenchantTab:IsShown() then tabs[#tabs + 1] = addon.disenchantTab end
            tabs[#tabs + 1], tabs[#tabs + 2], tabs[#tabs + 3] = shoppingTab, bankTab, financeTab
            addon.ui.layoutRail(root, tabs)
        end
        if root.RefreshRightTabs then hooksecurefunc(root, "RefreshRightTabs", positionTab) end
        local function onNativeTabMouseUp(nativeTab, mouseButton)
            if mouseButton ~= "LeftButton" then return end
            addon.CloseDisenchant()
            addon.CloseBank()
            -- The active profession can be reused without a native tab change.
            if shoppingDocked and nativeTab:GetID() == root.selectedGamepadTabID
                and not pendingPlanRecipe and not craftBatch then
                leaveShopping()
            end
        end
        root.ProfessionsOverviewTab:HookScript("OnMouseUp", onNativeTabMouseUp)
        for _, professionTab in ipairs(root.rightProfessionTabs) do
            professionTab:HookScript("OnMouseUp", onNativeTabMouseUp)
        end
        if root.RightTabSelected then
            local previousNativeTab = root.selectedGamepadTabID
            hooksecurefunc(root, "RightTabSelected", function(_, selectedTab)
                local selectedID = selectedTab:GetID()
                local changed = selectedID ~= previousNativeTab
                previousNativeTab = selectedID
                if changed then addon.CloseDisenchant(); addon.CloseBank() end
                if shoppingDocked and changed then
                    previousTab = nil
                    local switching = pendingPlanRecipe and selectedTab.skillLine == pendingPlanRecipe.profession
                    if not switching and not craftBatch then leaveShopping() end
                end
            end)
        end
        root:HookScript("OnHide", leaveShopping)
        addon.AttachDisenchant(root, function() leaveShopping(); addon.CloseBank() end, header)
        addon.AttachProfessionGuide(root, page, function()
            leaveShopping()
            addon.CloseDisenchant()
            addon.CloseBank()
        end)
        addon.AttachFishing(root, page)
        root:HookScript("OnShow", positionTab)
        positionTab()
        root:HookScript("OnHide", addon.CloseDisenchant)
    end

    root:HookScript("OnShow", queueLayout)
    if root.BookPage then
        root.BookPage:HookScript("OnShow", queueLayout)
        root.BookPage:HookScript("OnHide", queueLayout)
    end
    addon.AddSettingsGear(root)
    local function updateProfessionTitle()
        local text = root.TitleContainer and root.TitleContainer.TitleText
        if text and text:GetText() then text:SetText(addon.HeaderTitle(text:GetText())) end
    end
    if root.SetTitleFormatted then hooksecurefunc(root, "SetTitleFormatted", updateProfessionTitle) end
    if root.SetTitle then hooksecurefunc(root, "SetTitle", updateProfessionTitle) end
    root:HookScript("OnShow", updateProfessionTitle)
    updateProfessionTitle()
    root:HookScript("OnHide", function() if settings then settings:Hide() end end)
    page:HookScript("OnShow", queueLayout)
    page:HookScript("OnHide", function()
        lastRecipeID = nil
        addon.InvalidateRecipes()
        queueLayout()
    end)
    list:HookScript("OnShow", queueLayout)
    list:HookScript("OnHide", queueLayout)
    root:HookScript("OnSizeChanged", function(self, width)
        if not applyingLayout and width > 0 and (not appliedWidth or math.abs(width - appliedWidth) > 0.5) then
            updateLayout(true)
            queue()
        end
    end)
    -- Init restores the native reagent anchor. Reserve our space in the same
    -- call so the recipe pane never renders a frame at the native position.
    if form.Init then hooksecurefunc(form, "Init", refresh) end
    if form.UpdateAllSlots then hooksecurefunc(form, "UpdateAllSlots", queue) end
    -- Native layout can briefly restore its original widths during a profession switch.
    -- Reapply ours before the next render rather than waiting for the queued refresh.
    if root.ApplyDesiredWidth then hooksecurefunc(root, "ApplyDesiredWidth", nativeLayoutChanged) end
    if root.SetTab then hooksecurefunc(root, "SetTab", nativeLayoutChanged) end
    if page.Refresh then hooksecurefunc(page, "Refresh", recipeLayoutChanged) end
    if page.SelectRecipe then hooksecurefunc(page, "SelectRecipe", recipeLayoutChanged) end
    if page.CreateMultipleInputBox then page.CreateMultipleInputBox:HookScript("OnTextChanged", queue) end
    localize()
    queueLayout()
end

local function pickupShoppingMacro()
    local L = addon.GetText()
    if InCombatLockdown() or GetCursorInfo() then
        print("ForeverCraft: " .. L.settingsMacroBusy)
        return
    end

    local body = "/fclist"
    local freeName
    local index, macroName
    for suffix = 1, 99 do
        local name = suffix == 1 and "ForeverCraft" or ("ForeverCraft %d"):format(suffix)
        local slot = GetMacroIndexByName(name)
        if slot == 0 then
            freeName = freeName or name
        elseif GetMacroBody(slot) == body then
            index, macroName = slot, name
            break
        end
    end
    if not index and freeName then
        local ok, slot = pcall(CreateMacro, freeName, shoppingIcon, body)
        if ok and type(slot) == "number" and slot > 0 then index, macroName = slot, freeName end
    end
    if not index then
        print("ForeverCraft: " .. L.settingsMacroFailed)
        return
    end
    if PickupMacro then pcall(PickupMacro, index) end
    if GetCursorInfo() == "macro" then
        settings:Hide()
    else
        print("ForeverCraft: " .. L.settingsMacroManual:format(macroName))
    end
end

local settingPages = {
    { title = "general", groups = {
        { title = "window", options = {
            { key = "wide", label = "widescreen" },
            { key = "showSkillScale", label = "settingsSkillScale" },
            { key = "showDisenchant", label = "settingsDisenchant" },
        }},
        { title = "language", language = true },
    }},
    { title = "sideShopping", groups = {
        { title = "settingsAutoOpen", detail = "scopes", options = {
            { key = "merchantList", label = "settingsMerchant" },
            { key = "auctionList", label = "settingsAuction" },
        }},
        { title = "settingsActionBar", macro = true },
    }},
    { title = "settingsFishing", height = 522, groups = {
        { title = "settingsFishingBinding", fishingBinding = true },
        { title = "settingsFishingLog", options = {
            { key = "fishingAutoOpen", label = "settingsFishingAutoOpen" },
            { key = "fishingShowValue", label = "settingsFishingShowValue" },
        }},
        { title = "settingsFishingAudio", detail = "settingsFishingAudioDetail", audioLevel = true, options = {
            { key = "fishingSoundBackground", label = "settingsFishingSoundBackground", defaultOff = true },
        }},
    }},
    { title = "settingsMarket", groups = {
        { title = "settingsPriceSources", options = {
            { key = "showMarketPrices", label = "settingsPrices" },
            { key = "preferAuctionator", label = "settingsAuctionator", defaultOff = true },
        }, detail = "settingsPriceFallback" },
    }},
    { title = "settingsEconomy", height = 720, groups = {
        { title = "settingsEconomyGeneral", options = {
            { key = "economyTooltip", label = "settingsEconomyEnable" },
            { key = "economyShowVendor", label = "settingsEconomyVendor" },
            { key = "economyShowAuction", label = "settingsEconomyAuction" },
            { key = "economyShowNet", label = "settingsEconomyNet" },
            { key = "economyShowDisenchant", label = "settingsEconomyDisenchant" },
            { key = "economyShowRecommendation", label = "settingsEconomyRecommendation" },
            { key = "economyShowUpside", label = "settingsEconomyUpside" },
            { key = "economyLogDisenchant", label = "settingsEconomyLogToggle" },
        }},
        { title = "settingsEconomyDetail", detail = "settingsEconomyDetailHint", economyModifier = true, options = {
            { key = "economyShowBreakdown", label = "settingsEconomyBreakdown" },
            { key = "economyShowIcons", label = "settingsEconomyIcons" },
            { key = "economyShowSource", label = "settingsEconomySource" },
            { key = "economyShowAge", label = "settingsEconomyAge" },
            { key = "economyDetailAlways", label = "settingsEconomyAlways", defaultOff = true },
        }},
    }},
    { title = "settingsBank", groups = {
        { title = "settingsBankTracking", detail = "settingsBankDetail", bankActions = true, options = {
            { key = "bankTracking", label = "settingsBankCapture" },
            { key = "inventoryTracking", label = "settingsInventoryCapture" },
            { key = "inventoryTooltip", label = "settingsInventoryTooltip" },
            { key = "shoppingCrossCharacter", label = "settingsShoppingStock" },
        }},
    }},
    { title = "settingsFinance", height = 560, groups = {
        { title = "settingsFinanceTracking", detail = "settingsFinanceDetail", financeActions = true, options = {
            { key = "financeTracking", label = "settingsFinanceEnable" },
            { key = "financeSeparateTransfers", label = "settingsFinanceTransfers" },
            { key = "financeSnapshots", label = "settingsFinanceSnapshots" },
            { key = "financeIncludeEquipment", label = "settingsFinanceEquipment", defaultOff = true },
        }},
    }},
    { title = "about", groups = {
        { title = "welcomeTitle", about = true },
        { title = "changelogTitle", changelog = true },
    }},
}

local function applySetting(key)
    if key == "fishingAutoOpen" or key == "fishingShowValue" then
        addon.RefreshFishingLog()
    elseif key == "fishingSoundBackground" then
        addon.RefreshFishingAudio()
    elseif key == "wide" then
        queueLayout()
    elseif key == "showSkillScale" then
        queue()
    elseif key == "showDisenchant" then
        if ForeverCraftDB.showDisenchant == false then addon.CloseDisenchant() end
        if positionTab then positionTab() end
    elseif key == "merchantList" or key == "auctionList" then
        local kind = key == "merchantList" and "merchant" or "auction"
        if ForeverCraftDB[key] == false then
            addon.CloseSideShopping(kind)
        elseif addon.OpenSideShopping(kind) then
            refreshShopping()
        end
    else
        refreshShopping()
    end
end

local function selectSettingsPage(index)
    settings.selected = index
    settings:SetHeight(settingPages[index].height or 388)
    for pageIndex, view in ipairs(settings.pages) do
        local selected = pageIndex == index
        view.panel:SetShown(selected)
        view.active:SetShown(selected)
        view.nav:SetNormalFontObject(selected and GameFontNormal or GameFontHighlight)
    end
end

local function buildSettings()
    settings = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
    settings:Hide()
    addon.AddSettingsGear(settings)
    settings:SetSize(686, 388)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")
    settings:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
    settings:SetClampedToScreen(true)
    settings:SetMovable(true)
    settings:EnableMouse(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings:HookScript("OnShow", function()
        GameTooltip:Hide()
        addon.SetFishingSettingsOpen(true)
    end)
    settings:HookScript("OnHide", function()
        ForeverCraftDB.setup = true
        addon.SetFishingSettingsOpen(false)
    end)

    local sidebar = box(settings, 164, 311)
    sidebar:SetPoint("TOPLEFT", 10, -56)
    sidebar:SetBackdropColor(0.11, 0.08, 0.05, 1)
    local build = label(sidebar, "GameFontDisableSmall", "v" .. version)
    build:SetPoint("BOTTOMLEFT", 12, 13)
    settings.pages = {}
    settings.options = {}
    for index, pageData in ipairs(settingPages) do
        local view = {}
        settings.pages[index] = view
        view.nav = CreateFrame("Button", nil, sidebar)
        view.nav:SetSize(146, 30)
        view.nav:SetPoint("TOPLEFT", 9, -12 - (index - 1) * 36)
        view.nav:SetNormalFontObject(GameFontHighlight)
        local navText = label(view.nav, "GameFontHighlight", "")
        navText:SetPoint("LEFT", 10, 0)
        view.nav:SetFontString(navText)
        view.nav:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        view.active = view.nav:CreateTexture(nil, "BACKGROUND")
        view.active:SetAllPoints()
        view.active:SetColorTexture(0.36, 0.24, 0.10, 0.8)
        view.nav:SetScript("OnClick", function() selectSettingsPage(index) end)

        local panel = CreateFrame("Frame", nil, settings)
        view.panel = panel
        panel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 18, 0)
        panel:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -15, 59)
        view.title = label(panel, "GameFontNormalLarge", "")
        view.title:SetPoint("TOPLEFT", 0, -3)
        view.groups = {}
        local y = -35
        for _, group in ipairs(pageData.groups) do
            local hasCycleButton = group.language or group.macro or group.economyModifier or group.bankActions
            if group.financeActions then hasCycleButton = true end
            local height = 43 + 29 * #(group.options or {}) + (hasCycleButton and 30 or 0)
                + (group.detail and 33 or 0) + (group.fishingBinding and 62 or 0)
            if group.audioLevel then height = height + 29 end
            if group.financeActions then height = height + 30 end
            if group.about or group.changelog then height = 112 end
            local card = box(panel, 460, height)
            card:SetPoint("TOPLEFT", 0, y)
            card:SetPoint("TOPRIGHT", 0, y)
            card:SetBackdropColor(0.16, 0.115, 0.075, 0.96)
            y = y - height - 12
            local title = label(card, "GameFontNormal", "")
            title:SetPoint("TOPLEFT", 13, -12)
            local detail
            if group.detail then
                detail = label(card, "GameFontHighlightSmall", "")
                detail:SetPoint("BOTTOMLEFT", 14, 13)
                detail:SetWidth(440)
                detail:SetTextColor(0.80, 0.72, 0.59)
            end
            local widgets = { title = title, detail = detail }
            view.groups[#view.groups + 1] = widgets
            if group.about then
                widgets.description = label(card, "GameFontHighlightSmall", "")
                widgets.description:SetPoint("TOPLEFT", 13, -33)
                widgets.description:SetPoint("TOPRIGHT", -13, -33)
                widgets.description:SetWordWrap(true)
                widgets.author = label(card, "GameFontHighlightSmall", "")
                widgets.author:SetPoint("BOTTOMLEFT", 13, 40)
                local url = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
                url:SetSize(333, 20)
                url:SetPoint("BOTTOMLEFT", 18, 11)
                url:SetAutoFocus(false)
                url:SetText(curseForgeProfile)
                url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                url:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                url:SetScript("OnEditFocusLost", function(self) self:SetText(curseForgeProfile) end)
                url:EnableMouse(true)
                local link = button(card, 94, "CurseForge")
                link:SetPoint("LEFT", url, "RIGHT", 8, 0)
                link:SetScript("OnClick", function()
                    if C_Browser and C_Browser.OpenURL then
                        local ok, result = pcall(C_Browser.OpenURL, curseForgeProfile)
                        if ok and result ~= false then return end
                    end
                    url:SetFocus()
                    url:HighlightText()
                end)
            elseif group.changelog then
                widgets.changes = label(card, "GameFontHighlightSmall", "")
                widgets.changes:SetPoint("TOPLEFT", 13, -34)
                widgets.changes:SetPoint("TOPRIGHT", -13, -34)
                widgets.changes:SetWordWrap(true)
                widgets.changes:SetSpacing(4)
            end

            for row, option in ipairs(group.options or {}) do
                local check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
                check:SetSize(24, 24)
                check:SetPoint("TOPLEFT", 11, -34 - (row - 1) * 29)
                check.text = label(check, "GameFontHighlight", "")
                check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
                check.text:SetWidth(395)
                check:SetHitRectInsets(0, -395, 0, 0)
                check:SetScript("OnClick", function(self)
                    ForeverCraftDB[option.key] = self:GetChecked() and true or false
                    applySetting(option.key)
                end)
                settings.options[#settings.options + 1] = { control = check, option = option }
            end
            if group.macro then
                settings.macro = button(card, 242, "")
                settings.macro:SetPoint("TOPLEFT", 13, -36)
                settings.macro:SetScript("OnClick", pickupShoppingMacro)
            end
            if group.audioLevel then
                local level = button(card, 300, "")
                level:SetPoint("TOPLEFT", 13, -64)
                settings.fishingAudioLevel = level
                level:SetScript("OnClick", function()
                    ForeverCraftDB.fishingAudioLevel = addon.GetFishingAudioLevel() % 5 + 1
                    addon.RefreshFishingAudio()
                    local L = addon.GetText()
                    level:SetText((L.settingsFishingAudioLevel or addon.strings.enUS.settingsFishingAudioLevel)
                        :format(addon.GetFishingAudioLevel(), addon.GetFishingAudioReduction()))
                end)
            end
            if group.fishingBinding then addon.BuildFishingBindingSettings(card) end
            if group.financeActions then
                local top = -34 - 29 * #(group.options or {})
                local function cycleSetting(key, values, fallback)
                    local current = ForeverCraftDB[key] or fallback
                    for i, value in ipairs(values) do
                        if value == current then ForeverCraftDB[key] = values[i % #values + 1]; return end
                    end
                    ForeverCraftDB[key] = values[1]
                end
                settings.financePeriod = button(card, 210, "")
                settings.financePeriod:SetPoint("TOPLEFT", 13, top)
                settings.financePeriod:SetScript("OnClick", function()
                    cycleSetting("financeDefaultPeriod", addon.ledger.financePeriods, "30d"); showSettings(settings.first)
                end)
                settings.financeMethod = button(card, 230, "")
                settings.financeMethod:SetPoint("LEFT", settings.financePeriod, "RIGHT", 8, 0)
                settings.financeMethod:SetScript("OnClick", function()
                    cycleSetting("financeDefaultMethod", addon.finance.methods, "best"); showSettings(settings.first)
                end)
                settings.financeRetention = button(card, 210, "")
                settings.financeRetention:SetPoint("TOPLEFT", settings.financePeriod, "BOTTOMLEFT", 0, -6)
                settings.financeRetention:SetScript("OnClick", function()
                    cycleSetting("financeRetention", addon.ledger.financeRetentions, 90); showSettings(settings.first)
                end)
                settings.financeReset = button(card, 230, "")
                settings.financeReset:SetPoint("LEFT", settings.financeRetention, "RIGHT", 8, 0)
                settings.financeReset:SetScript("OnClick", function() addon.ledger.confirmFinanceReset(addon.ledger.ALL) end)
            end
            if group.bankActions then
                local top = -34 - 29 * #(group.options or {})
                settings.bankOpen = button(card, 150, "")
                settings.bankOpen:SetPoint("TOPLEFT", 13, top)
                settings.bankOpen:SetScript("OnClick", function() addon.ledger.show("bank") end)
                settings.bankReset = button(card, 260, "")
                settings.bankReset:SetPoint("LEFT", settings.bankOpen, "RIGHT", 8, 0)
                settings.bankReset:SetScript("OnClick", function()
                    addon.ledger.confirmReset()
                end)
            end
            if group.economyModifier then
                settings.economyModifier = button(card, 300, "")
                settings.economyModifier:SetPoint("TOPLEFT", 13, -34 - 29 * #(group.options or {}))
                settings.economyModifier:SetScript("OnClick", function()
                    local nextKey = { shift = "ctrl", ctrl = "alt", alt = "shift" }
                    ForeverCraftDB.economyModifierKey = nextKey[ForeverCraftDB.economyModifierKey or "shift"] or "shift"
                    showSettings(settings.first)
                end)
            end
            if group.language then
                settings.language = button(card, 242, "")
                settings.language:SetPoint("TOPLEFT", 13, -36)
                settings.language:SetScript("OnClick", function()
                    ForeverCraftDB.language = addon.languageOrder[ForeverCraftDB.language] or "auto"
                    localize()
                    showSettings(settings.first)
                end)
            end
        end
    end

    settings.done = button(settings, 106, "")
    settings.done:SetPoint("BOTTOMRIGHT", -16, 17)
    settings.done:SetScript("OnClick", function() settings:Hide() end)
end

showSettings = function(first)
    local L = addon.GetText()
    local fallback = addon.strings.enUS
    if not settings then buildSettings() end
    settings.first = first
    settings:SetTitle(addon.HeaderTitle(first and L.setup or L.settingsTitle or fallback.settingsTitle))
    for index, pageData in ipairs(settingPages) do
        local view = settings.pages[index]
        local title = L[pageData.title] or fallback[pageData.title]
        view.nav:SetText(title)
        view.title:SetText(title)
        for groupIndex, group in ipairs(pageData.groups) do
            local widgets = view.groups[groupIndex]
            widgets.title:SetText(L[group.title] or fallback[group.title])
            if widgets.detail then widgets.detail:SetText(L[group.detail] or fallback[group.detail]) end
            if widgets.description then
                widgets.description:SetText(L.aboutDescription)
                widgets.author:SetText(L.aboutCredit:format("Fabian (Nimri)", version))
            end
            if widgets.changes then widgets.changes:SetText(L.changelogEntries:format(version)) end
        end
    end
    for _, entry in ipairs(settings.options) do
        local option = entry.option
        local value = ForeverCraftDB[option.key]
        if value == nil then value = not option.defaultOff end
        entry.control:SetChecked(value)
        entry.control.text:SetText(L[option.label] or fallback[option.label])
    end
    settings.fishingAudioLevel:SetText((L.settingsFishingAudioLevel or fallback.settingsFishingAudioLevel)
        :format(addon.GetFishingAudioLevel(), addon.GetFishingAudioReduction()))
    settings.language:SetText(L.language .. "  ·  " .. (addon.languageNames[ForeverCraftDB.language] or L.automatic))
    if settings.financePeriod then
        local function t(key) return L[key] or fallback[key] or key end
        settings.financePeriod:SetText(t("settingsFinancePeriod"):format(t("financePeriod_" .. (ForeverCraftDB.financeDefaultPeriod or "30d"))))
        settings.financeMethod:SetText(t("financeMethod_" .. (ForeverCraftDB.financeDefaultMethod or "best")))
        local days = ForeverCraftDB.financeRetention or 90
        settings.financeRetention:SetText(days == 0 and t("settingsFinanceKeepAll") or t("settingsFinanceKeepDays"):format(days))
        settings.financeReset:SetText(t("settingsFinanceReset"))
        local resetText = settings.financeReset:GetFontString()
        if resetText then resetText:SetTextColor(1, 0.35, 0.3) end
    end
    if settings.bankOpen then
        settings.bankOpen:SetText(L.settingsBankOpen or fallback.settingsBankOpen)
        settings.bankReset:SetText(L.settingsBankReset or fallback.settingsBankReset)
    end
    if settings.economyModifier then
        local modifierKey = ForeverCraftDB.economyModifierKey or "shift"
        local keyNames = {
            shift = L.keyShift or fallback.keyShift, ctrl = L.keyCtrl or fallback.keyCtrl,
            alt = L.keyAlt or fallback.keyAlt,
        }
        local text = L.settingsEconomyModifier or fallback.settingsEconomyModifier
        settings.economyModifier:SetText(text:format(keyNames[modifierKey]))
    end
    settings.macro:SetText(L.settingsMacroCreate)
    settings.done:SetText(L.done)
    selectSettingsPage(settings.selected or 1)
    settings:Show()
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
events:RegisterEvent("NEW_RECIPE_LEARNED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
local openSideEvents = { MERCHANT_SHOW = "merchant", AUCTION_HOUSE_SHOW = "auction" }

local visitEvents = {
    MERCHANT_CLOSED = true,
    MAIL_CLOSED = true,
    BANKFRAME_CLOSED = true,
    GUILDBANKFRAME_CLOSED = true,
}
for event in pairs(visitEvents) do events:RegisterEvent(event) end

local visitRefreshPending
local inventoryRefreshPending
local function queueInventoryRefresh()
    if inventoryRefreshPending then return end
    inventoryRefreshPending = true
    C_Timer.After(0, function()
        inventoryRefreshPending = false
        refreshShopping()
    end)
end

events:SetScript("OnEvent", function(_, event, name, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if preparedBatch and spellID and (not issecretvalue or not issecretvalue(spellID)) and spellID == preparedBatch.id then
            craftBatch, preparedBatch = preparedBatch, nil
        end
        if craftBatch and craftBatch.done < craftBatch.quantity and spellID
            and (not issecretvalue or not issecretvalue(spellID)) and spellID == craftBatch.id then
            craftBatch.done = craftBatch.done + 1
            updateCraftProgress()
        end
        if ForeverCraftShopping and spellID and (not issecretvalue or not issecretvalue(spellID))
            and addon.CompletePlannedCraft(ForeverCraftShopping, spellID) then
            queueInventoryRefresh()
        end
        return
    end
    if event == "MERCHANT_UPDATE" or event == "PLAYER_MONEY" then
        if MerchantFrame and MerchantFrame:IsVisible() then refreshShopping() end
        return
    end
    local side = openSideEvents[event]
    if side then
        local key = side == "merchant" and "merchantList" or "auctionList"
        C_Timer.After(0, function()
            if ForeverCraftDB[key] ~= false and addon.OpenSideShopping(side) then refreshShopping() end
        end)
        return
    end
    if event == "AUCTION_HOUSE_CLOSED" then addon.CloseSideShopping("auction"); return end
    if event == "MERCHANT_CLOSED" then addon.CloseSideShopping("merchant") end
    if visitEvents[event] then
        if not visitRefreshPending then
            visitRefreshPending = true
            C_Timer.After(0.5, function()
                visitRefreshPending = false
                refreshShopping()
            end)
        end
        return
    end
    if event == "BAG_UPDATE_DELAYED" then queueInventoryRefresh() end
    if event == "ITEM_DATA_LOAD_RESULT" then refreshShopping() end
    if event == "ADDON_LOADED" and name == "ForeverCraft" then
        ForeverCraftIntermediateRecipes = type(ForeverCraftIntermediateRecipes) == "table" and ForeverCraftIntermediateRecipes or {}
        ForeverCraftShopping = type(ForeverCraftShopping) == "table" and ForeverCraftShopping or {}
        addon.CleanupFinishedPlans(ForeverCraftShopping)
        ForeverCraftDisenchantLog = type(ForeverCraftDisenchantLog) == "table" and ForeverCraftDisenchantLog or {}
        ForeverCraftDB = type(ForeverCraftDB) == "table" and ForeverCraftDB or {}
        if ForeverCraftDB.wide == nil then ForeverCraftDB.wide = true end
        ForeverCraftDB.language = ForeverCraftDB.language or "auto"
    elseif event == "PLAYER_LOGIN" then
        refreshShopping()
        C_Timer.NewTicker(30, refreshShopping)
        attach()
        localize()
        if not ForeverCraftDB.setup then showSettings(true) end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "NEW_RECIPE_LEARNED" then
        attach()
        addon.InvalidateRecipes()
        queue()
    elseif event == "ADDON_LOADED" then
        if name == "Blizzard_Professions" then attach() end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        queueLayout()
    elseif page and page:IsVisible() then
        if event == "TRADE_SKILL_LIST_UPDATE" then addon.InvalidateRecipes() end
        queue()
    end
end)

SLASH_FOREVERCRAFT1 = "/forevercraft"
SlashCmdList.FOREVERCRAFT = function()
    if settings and settings:IsShown() then settings:Hide() else showSettings(false) end
end


SLASH_FOREVERCRAFTLIST1 = "/fclist"
SlashCmdList.FOREVERCRAFTLIST = showShopping
