local _, addon = ...

-- Adds a compact "vendor vs. auction house vs. disenchant" value summary to the
-- standard item tooltip, using addon.EvaluateItem (Economy.lua). Hooked once via
-- TooltipDataProcessor, which fires for every GameTooltip-driven item display
-- (bags, bank, auction house, character, merchant, loot, chat links, quest rewards,
-- and ForeverCraft's own GameTooltip:SetHyperlink calls), so no per-context wiring
-- is needed. Falls back to doing nothing if the client has no TooltipDataProcessor.

local function setting(key, defaultOff)
    local value = ForeverCraftDB and ForeverCraftDB[key]
    if value == nil then return not defaultOff end
    return value ~= false
end

local function modifierHeld()
    local key = ForeverCraftDB and ForeverCraftDB.economyModifierKey or "shift"
    if key == "ctrl" then return IsControlKeyDown() end
    if key == "alt" then return IsAltKeyDown() end
    return IsShiftKeyDown()
end

local function showDetail()
    return setting("economyDetailAlways", true) or modifierHeld()
end

local function iconMarkup(itemID)
    local icon = itemID and C_Item.GetItemIconByID(itemID)
    return icon and ("|T%s:14:14|t "):format(icon) or ""
end

-- A tooltip addon convention: a custom tooltip frame opts out of price-style
-- add-ons (this one included) by naming itself starting with "NotGameTooltip".
local function validTooltip(tooltip)
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then return true end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return false end
    local name = tooltip.GetName and tooltip:GetName()
    return not (name and name:match("^NotGameTooltip"))
end

-- Looks a key up in the active locale, falling back to enUS (same convention as
-- Core.lua's settings panel) so a catalog that has not picked up these new keys yet
-- shows English for them instead of erroring on a nil string.
local function text(key)
    local L = addon.GetText()
    return L[key] or addon.strings.enUS[key]
end

local function addEconomyLines(tooltip, itemLink)
    if not ForeverCraftDB or not setting("economyTooltip") then return end
    local evaluation = addon.EvaluateItem(itemLink)
    if not evaluation then return end

    local haveAny = false
    tooltip:AddLine(" ")
    tooltip:AddLine(text("economyHeading"), 1, 0.82, 0)

    if setting("economyShowVendor") and evaluation.vendorGross then
        tooltip:AddDoubleLine(text("economyVendor"), GetMoneyString(evaluation.vendorGross), 1, 1, 1, 1, 1, 1)
        haveAny = true
    end

    if setting("economyShowAuction") then
        if evaluation.auctionGross then
            local gross = GetMoneyString(evaluation.auctionGross)
            tooltip:AddDoubleLine(text("economyAuction"), gross, 1, 1, 1, 1, 1, 1)
            if setting("economyShowNet") and evaluation.auctionNet then
                local net = GetMoneyString(evaluation.auctionNet)
                tooltip:AddDoubleLine("  " .. text("economyNet"), net, 0.75, 0.75, 0.75, 1, 1, 1)
            end
            if setting("economyShowAge") and evaluation.auctionAge then
                tooltip:AddLine(text("economyAge"):format(evaluation.auctionAge), 0.55, 0.55, 0.55)
            end
            haveAny = true
        elseif not evaluation.tradeable then
            tooltip:AddLine(text("economyNotTradeable"), 0.6, 0.6, 0.6)
        else
            tooltip:AddLine(text("economyAuctionUnknown"), 0.6, 0.6, 0.6)
        end
    end

    if setting("economyShowDisenchant") then
        local disenchant = evaluation.disenchant
        if disenchant and disenchant.canDisenchant == false then
            tooltip:AddLine(text("economyNotDisenchantable"), 0.6, 0.6, 0.6)
        elseif disenchant and disenchant.gross then
            local label = disenchant.source == "empirical"
                and text("economyDisenchantEmpirical"):format(disenchant.sampleSize) or text("economyDisenchant")
            tooltip:AddDoubleLine(label, GetMoneyString(disenchant.gross), 1, 1, 1, 1, 1, 1)
            if setting("economyShowNet") and evaluation.disenchantNet then
                local net = GetMoneyString(evaluation.disenchantNet)
                tooltip:AddDoubleLine("  " .. text("economyNet"), net, 0.75, 0.75, 0.75, 1, 1, 1)
            end
            if disenchant.source == "empirical" and not disenchant.confident then
                local minimum = addon.GetDisenchantMinimumSample()
                local line = text("economySmallSample"):format(disenchant.sampleSize, minimum)
                tooltip:AddLine(line, 0.95, 0.65, 0.35, true)
            end
            if not evaluation.knowsEnchanting then
                tooltip:AddLine(text("economyNoEnchanting"), 0.6, 0.6, 0.6, true)
            end
            haveAny = true
            local hasBreakdown = disenchant.breakdownLines or disenchant.breakdown
            if hasBreakdown and setting("economyShowBreakdown") then
                if showDetail() then
                    if disenchant.breakdownLines then
                        for _, line in ipairs(disenchant.breakdownLines) do tooltip:AddLine(line, 0.85, 0.85, 0.85) end
                    else
                        for _, material in ipairs(disenchant.breakdown) do
                            local icon = setting("economyShowIcons") and iconMarkup(material.itemID) or ""
                            local name = addon.GetLoadedItemName(material.itemID) or ("#" .. material.itemID)
                            local price = material.unitPrice and GetMoneyString(material.unitPrice)
                                or text("economyUnknown")
                            local line = ("  %s%.1f x %s (%s)"):format(icon, material.avgQuantity, name, price)
                            tooltip:AddLine(line, 0.85, 0.85, 0.85)
                        end
                    end
                else
                    local keyNames = { shift = text("keyShift"), ctrl = text("keyCtrl"), alt = text("keyAlt") }
                    local keyName = keyNames[ForeverCraftDB.economyModifierKey or "shift"] or text("keyShift")
                    tooltip:AddLine(text("economyHoldForDetail"):format(keyName), 0.55, 0.55, 0.55)
                end
            end
        else
            tooltip:AddLine(text("economyDisenchantUnknown"), 0.6, 0.6, 0.6)
        end
    end

    if setting("economyShowRecommendation") then
        local rec = evaluation.recommendation
        if rec and rec.tie then
            tooltip:AddLine(text("economyTie"), 0.9, 0.9, 0.6)
        elseif rec then
            local names = {
                vendor = text("economyVendor"), auction = text("economyAuction"),
                disenchant = text("economyDisenchant"),
            }
            tooltip:AddLine(text("economyRecommend"):format(names[rec.bestKey] or rec.bestKey), 0.3, 1, 0.3)
            if setting("economyShowUpside") and rec.upside and rec.upside > 0 then
                tooltip:AddLine(text("economyUpside"):format(GetMoneyString(rec.upside)), 0.3, 1, 0.3)
            end
        elseif not haveAny then
            tooltip:AddLine(text("economyNoData"), 0.6, 0.6, 0.6)
        end
    end

    if setting("economyShowSource") and evaluation.auctionSource then
        tooltip:AddLine(text("economySource"):format(evaluation.auctionSource), 0.55, 0.55, 0.55)
    end
end

-- Compact "~<value>" suffix for a list row (Disenchant.lua's bag list), reusing the
-- same wording as the shopping list's market-estimate suffix (Core.lua). Returns ""
-- when there is nothing worth comparing (Materials.lua only exists if available).
function addon.FormatDisenchantRowValue(evaluation)
    local rec = evaluation and evaluation.recommendation
    if not rec or not rec.bestNet then return "" end
    return "   ·   " .. text("marketEstimate"):format(GetMoneyString(rec.bestNet))
end

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        -- Some item tooltips (embedded/comparison frames) have no GetItem; skip them.
        if not validTooltip(tooltip) or type(tooltip.GetItem) ~= "function" then return end
        local _, link = tooltip:GetItem()
        if link then addEconomyLines(tooltip, link) end
    end)
end
