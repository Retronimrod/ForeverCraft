local _, addon = ...

-- Item-value evaluation for the tooltip extension: vendor price, auction house
-- value (via addon.GetMarketEstimate, Materials.lua) and disenchant value.
--
-- Disenchant data sources, in order of preference:
--   1. Auctionator's own Enchant module (Auctionator.Enchant.*), when Auctionator is
--      installed. This is Auctionator's real, shipped disenchant-probability table,
--      not data invented here.
--   2. The account-wide local log (ForeverCraftDisenchantLog) built from the player's
--      own actual disenchant results (see Disenchant.lua). Values from this source are
--      only ever an empirical average of observed outcomes, with the sample size always
--      shown alongside the estimate, and never claim a probability breakdown we have not
--      observed.
-- If neither source has data for an item, the disenchant value is simply unknown; no
-- placeholder or guessed number is produced.

local MIN_EMPIRICAL_SAMPLE = 5

function addon.GetAuctionCutMultiplier()
    local constants = Auctionator and Auctionator.Constants
    local value = constants and constants.AfterAHCut
    if type(value) == "number" and value > 0 and value <= 1 then return value end
    return 0.95
end

function addon.NetAuctionValue(gross)
    if type(gross) ~= "number" or gross <= 0 then return nil end
    return math.floor(gross * addon.GetAuctionCutMultiplier() + 0.5)
end

-- lootItems is { [materialItemID] = quantity, ... } for everything looted from a
-- SINGLE disenchant. The sample count is incremented exactly once per call so that a
-- disenchant yielding several distinct materials does not inflate the sample size.
function addon.RecordDisenchantResult(sourceItemID, lootItems)
    if not sourceItemID or not lootItems or not next(lootItems) then return end
    ForeverCraftDisenchantLog = type(ForeverCraftDisenchantLog) == "table" and ForeverCraftDisenchantLog or {}
    local entry = ForeverCraftDisenchantLog[sourceItemID]
    if not entry then
        entry = { count = 0, materials = {} }
        ForeverCraftDisenchantLog[sourceItemID] = entry
    end
    entry.count = entry.count + 1
    for lootItemID, quantity in pairs(lootItems) do
        if type(lootItemID) == "number" and type(quantity) == "number" and quantity > 0 then
            entry.materials[lootItemID] = (entry.materials[lootItemID] or 0) + quantity
        end
    end
end

-- priceFn(itemID, quantity) -> copper or nil, matching addon.GetMarketEstimate's signature.
function addon.GetEmpiricalDisenchantValue(sourceItemID, priceFn)
    local log = ForeverCraftDisenchantLog
    local entry = log and log[sourceItemID]
    if not entry or entry.count <= 0 then return nil end
    local total, breakdown, complete = 0, {}, true
    local ids = {}
    for itemID in pairs(entry.materials) do ids[#ids + 1] = itemID end
    table.sort(ids)
    for _, itemID in ipairs(ids) do
        local totalQuantity = entry.materials[itemID]
        local avgQuantity = totalQuantity / entry.count
        local unitPrice = priceFn and priceFn(itemID, 1)
        if unitPrice then
            total = total + avgQuantity * unitPrice
        else
            complete = false
        end
        breakdown[#breakdown + 1] = { itemID = itemID, avgQuantity = avgQuantity, unitPrice = unitPrice }
    end
    return {
        gross = complete and math.floor(total + 0.5) or nil,
        sampleSize = entry.count,
        confident = entry.count >= MIN_EMPIRICAL_SAMPLE,
        breakdown = breakdown,
        source = "empirical",
    }
end

function addon.GetDisenchantMinimumSample()
    return MIN_EMPIRICAL_SAMPLE
end

-- Builds the sell-option comparison. Each of vendor/auction/disenchant is either nil
-- (value unknown/not applicable) or { net = copper, confident = bool }. "confident"
-- defaults to true (vendor and Auctionator-sourced AH/DE values are always treated as
-- confident; an empirical disenchant estimate with too small a sample is not).
-- Returns nil if fewer than one option has a known, confident value, otherwise
-- { bestKey, bestNet, upside } where upside is nil when there is nothing to compare
-- the best option against.
function addon.BuildRecommendation(options)
    local known = {}
    for _, key in ipairs({ "vendor", "auction", "disenchant" }) do
        local option = options[key]
        if option and type(option.net) == "number" and option.net > 0 and option.confident ~= false then
            known[#known + 1] = { key = key, net = option.net }
        end
    end
    if #known == 0 then return nil end
    table.sort(known, function(a, b) return a.net > b.net end)
    local best = known[1]
    local second = known[2]
    if not second then
        return { bestKey = best.key, bestNet = best.net, upside = nil }
    end
    if best.net - second.net <= 0 then
        return { bestKey = best.key, bestNet = best.net, upside = 0, tie = true }
    end
    return { bestKey = best.key, bestNet = best.net, upside = best.net - second.net }
end

function addon.GetVendorValue(itemLink, stackCount)
    stackCount = stackCount or 1
    local itemInfo = itemLink and { C_Item.GetItemInfo(itemLink) }
    local sellPrice = itemInfo and itemInfo[11]
    if type(sellPrice) == "number" and sellPrice > 0 then return sellPrice * stackCount end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetVendorPriceByItemLink then
        local ok, price = pcall(api.GetVendorPriceByItemLink, "ForeverCraft", itemLink)
        if ok and type(price) == "number" and price > 0 then return price * stackCount end
    end
end

-- itemInfo is the { C_Item.GetItemInfo(itemLink) } array; classID/quality are read
-- from indices 12/3 as documented for C_Item.GetItemInfo.
function addon.GetDisenchantValue(itemLink, itemInfo)
    local enchant = Auctionator and Auctionator.Enchant
    if enchant and enchant.DisenchantStatus and enchant.GetDisenchantAuctionPrice then
        local status = enchant.DisenchantStatus(itemInfo)
        if status and status.isDisenchantable then
            local gross = enchant.GetDisenchantAuctionPrice(itemLink, itemInfo)
            local breakdown = enchant.GetDisenchantBreakdown and enchant.GetDisenchantBreakdown(itemLink, itemInfo)
            return {
                canDisenchant = true,
                gross = type(gross) == "number" and gross > 0 and gross or nil,
                confident = true,
                source = "auctionator",
                breakdownLines = breakdown,
            }
        end
        return { canDisenchant = false }
    end

    local itemID = itemLink and select(1, C_Item.GetItemInfoInstant(itemLink))
    local empirical = itemID and addon.GetEmpiricalDisenchantValue(itemID, addon.GetMarketEstimate)
    if empirical then
        empirical.canDisenchant = true
        return empirical
    end
    return nil
end

-- Days since this item was last seen on the auction house (Auctionator's own age
-- tracking), or nil if unknown/not installed. Never guessed.
function addon.GetAuctionAge(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.GetAuctionAgeByItemID or not itemID then return nil end
    local ok, age = pcall(api.GetAuctionAgeByItemID, "ForeverCraft", itemID)
    if ok and type(age) == "number" then return age end
end

-- Sort/filter modes for the disenchant panel's bag list (Disenchant.lua), cycled through
-- by a single button. "default" is the panel's original bag order (unchanged).
addon.disenchantSortOrder = {
    "default", "disenchantValue", "upside", "disenchantRecommended",
    "vendorRecommended", "auctionRecommended", "noData",
}

-- rows is a list of { evaluation = <addon.EvaluateItem result or nil>, ... }; other
-- fields are preserved as-is. Returns a new, possibly filtered and/or reordered list;
-- never mutates the input. Unknown modes behave like "default" (no-op).
function addon.SortDisenchantRows(rows, mode)
    if mode == "disenchantValue" then
        local sorted = {}
        for i, row in ipairs(rows) do sorted[i] = row end
        table.sort(sorted, function(a, b)
            local av = a.evaluation and a.evaluation.disenchant and a.evaluation.disenchant.gross or -1
            local bv = b.evaluation and b.evaluation.disenchant and b.evaluation.disenchant.gross or -1
            return av > bv
        end)
        return sorted
    elseif mode == "upside" then
        local sorted = {}
        for i, row in ipairs(rows) do sorted[i] = row end
        table.sort(sorted, function(a, b)
            local au = a.evaluation and a.evaluation.recommendation and a.evaluation.recommendation.upside or -1
            local bu = b.evaluation and b.evaluation.recommendation and b.evaluation.recommendation.upside or -1
            return au > bu
        end)
        return sorted
    elseif mode == "disenchantRecommended" or mode == "vendorRecommended" or mode == "auctionRecommended" then
        local key = mode == "disenchantRecommended" and "disenchant"
            or mode == "vendorRecommended" and "vendor" or "auction"
        local filtered = {}
        for _, row in ipairs(rows) do
            local rec = row.evaluation and row.evaluation.recommendation
            if rec and rec.bestKey == key then filtered[#filtered + 1] = row end
        end
        return filtered
    elseif mode == "noData" then
        local filtered = {}
        for _, row in ipairs(rows) do
            if not (row.evaluation and row.evaluation.recommendation) then filtered[#filtered + 1] = row end
        end
        return filtered
    end
    return rows
end

-- Locale key per sort mode, for the disenchant panel's sort/filter button label.
addon.disenchantSortLabelKeys = {
    default = "settingsEconomySortDefault",
    disenchantValue = "settingsEconomySortDisenchantValue",
    upside = "settingsEconomySortUpside",
    disenchantRecommended = "settingsEconomySortDisenchantRecommended",
    vendorRecommended = "settingsEconomySortVendorRecommended",
    auctionRecommended = "settingsEconomySortAuctionRecommended",
    noData = "settingsEconomySortNoData",
}

function addon.KnowsEnchanting()
    local lookup = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    local info = lookup and lookup(333)
    return info and info.maxSkillLevel and info.maxSkillLevel > 0 or false
end

-- Full evaluation for one item link, gathering vendor/auction/disenchant values and a
-- recommendation. Returns nil if the item cannot be identified at all.
function addon.EvaluateItem(itemLink, stackCount)
    if not itemLink then return nil end
    stackCount = stackCount or 1
    local itemInfo = { C_Item.GetItemInfo(itemLink) }
    if not itemInfo[1] then return nil end
    local bindType = itemInfo[14]
    local tradeable = bindType ~= 1
    local itemID = C_Item.GetItemInfoInstant(itemLink)

    local vendorGross = addon.GetVendorValue(itemLink, stackCount)
    local auctionGross, auctionSource, auctionAge
    if tradeable and itemID then
        auctionGross, auctionSource = addon.GetMarketEstimate(itemID, stackCount)
        auctionAge = addon.GetAuctionAge(itemID)
    end
    local auctionNet = addon.NetAuctionValue(auctionGross)

    local disenchant = addon.GetDisenchantValue(itemLink, itemInfo)
    local disenchantNet, disenchantConfident
    if disenchant and disenchant.gross then
        disenchantNet = addon.NetAuctionValue(disenchant.gross)
        disenchantConfident = disenchant.confident ~= false
    end

    local recommendation = addon.BuildRecommendation({
        vendor = vendorGross and { net = vendorGross, confident = true },
        auction = auctionNet and { net = auctionNet, confident = true },
        disenchant = disenchantNet and { net = disenchantNet, confident = disenchantConfident },
    })

    return {
        itemLink = itemLink,
        tradeable = tradeable,
        vendorGross = vendorGross,
        auctionGross = auctionGross,
        auctionNet = auctionNet,
        auctionSource = auctionSource,
        auctionAge = auctionAge,
        disenchant = disenchant,
        disenchantNet = disenchantNet,
        knowsEnchanting = addon.KnowsEnchanting(),
        recommendation = recommendation,
    }
end
