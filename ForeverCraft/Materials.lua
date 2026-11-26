local _, addon = ...
local outputs
local requested = {}

function addon.InvalidateRecipes()
    outputs = nil
end

local function schematic(recipeID)
    return C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
end

local function requiredItems(data)
    local items, hasChoice = {}, false
    for _, slot in ipairs(data.reagentSlotSchematics or {}) do
        if slot.reagentType == Enum.CraftingReagentType.Basic then
            local reagents = slot.reagents or {}
            local itemID = #reagents == 1 and reagents[1].itemID
            if itemID and itemID > 0 and slot.quantityRequired and slot.quantityRequired > 0 then
                items[itemID] = (items[itemID] or 0) + slot.quantityRequired
            elseif #reagents > 0 then
                hasChoice = true
            end
        end
    end
    return items, hasChoice
end

local function buildOutputIndex()
    local index = {}
    local getIDs = C_TradeSkillUI.GetAllRecipeIDs or C_TradeSkillUI.GetFilteredRecipeIDs
    for _, recipeID in ipairs(getIDs and getIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and info.learned and not info.isRecraft then
            local data = schematic(recipeID)
            if data and not data.isRecraft and data.outputItemID and data.outputItemID > 0 and data.quantityMin and data.quantityMin > 0 then
                local items, hasChoice = requiredItems(data)
                if next(items) and not hasChoice then
                    local itemID = data.outputItemID
                    if index[itemID] == nil then
                        index[itemID] = { recipeID = recipeID, items = items, count = data.quantityMin }
                    else
                        index[itemID] = false
                    end
                end
            end
        end
    end
    return index
end

function addon.RememberIntermediateRecipes()
    if not ForeverCraftIntermediateRecipes or outputs then return end
    outputs = buildOutputIndex()
    for itemID, recipe in pairs(outputs) do ForeverCraftIntermediateRecipes[itemID] = recipe end
end

function addon.GetLoadedItemName(id)
    local name = C_Item.GetItemNameByID(id)
    if name then return name end
    if not requested[id] then
        requested[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
end

local function itemName(id)
    return addon.GetLoadedItemName(id) or ("#" .. id)
end

local function orderedIDs(items)
    local ids = {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function recipeProfession(recipeID, fallback)
    local lookup = C_TradeSkillUI.GetProfessionInfoByRecipeID
    local info = lookup and lookup(recipeID)
    if not info or not info.professionID or info.professionID == 0 then info = fallback end
    if not info then return 0 end
    return info.parentProfessionID or info.professionID or 0,
        info.parentProfessionName or info.professionName
end

local professionNames = {}

function addon.GetPlanProfessionName(entry)
    local id = entry.professionID
    local lookup = C_TradeSkillUI.GetProfessionInfoBySkillLineID
    if id and id > 0 and lookup and not professionNames[id] then
        local info = lookup(id)
        if info then
            professionNames[id] = info.parentProfessionName or info.professionName
        end
    end
    return (id and professionNames[id]) or entry.professionName
end

function addon.AddShoppingRecipe(plan, recipeID, quantity, profession)
    local data = recipeID and schematic(recipeID)
    if not data then return false end
    local items = requiredItems(data)
    if not next(items) then return false end
    local id, name = recipeProfession(recipeID, profession)
    local previous = plan[recipeID]
    local dataName = data.name or C_TradeSkillUI.GetRecipeInfo(recipeID)
    plan[recipeID] = {
        items = {}, perCraft = items, done = previous and previous.done or 0,
        professionID = id, professionName = name,
        recipeName = type(dataName) == "table" and dataName.name or dataName,
    }
    addon.SetPlanTarget(plan[recipeID], quantity)
    return true
end

function addon.SetPlanTarget(entry, quantity)
    quantity = tonumber(quantity)
    if not entry.perCraft or not quantity then return end
    entry.target = math.max(entry.done, 1, math.min(9999, math.floor(quantity)))
    entry.items = {}
    for id, count in pairs(entry.perCraft) do
        local remaining = count * (entry.target - entry.done)
        if remaining > 0 then entry.items[id] = remaining end
    end
end

function addon.GetLegacyPlanQuantity(recipeID, entry)
    local data = schematic(recipeID)
    if not data then return end
    local perCraft = requiredItems(data)
    local quantity
    for id, count in pairs(entry.items or {}) do
        local per = perCraft[id]
        if not per or count % per ~= 0 then return end
        local crafts = count / per
        if quantity and crafts ~= quantity then return end
        quantity = crafts
    end
    return quantity and quantity > 0 and quantity or nil
end

function addon.GetPlanRows(plan)
    local rows, stock = {}, {}
    for id, entry in pairs(plan) do
        rows[#rows + 1] = { id = id, entry = entry }
    end
    table.sort(rows, function(a, b)
        local ap, bp = a.entry.professionID or 0, b.entry.professionID or 0
        if ap ~= bp then return ap < bp end
        return a.id < b.id
    end)
    for _, row in ipairs(rows) do
        local entry = row.entry
        local spellName = C_Spell and C_Spell.GetSpellName(row.id)
        row.name = spellName or entry.recipeName or ("#" .. row.id)
        row.finished = entry.target and entry.done >= entry.target
        row.missing = {}
        for _, id in ipairs(orderedIDs(entry.items or {})) do
            local owned = stock[id]
            if owned == nil then owned = C_Item.GetItemCount(id, false) end
            local need = entry.items[id]
            stock[id] = math.max(0, owned - need)
            if need > owned then
                row.missing[#row.missing + 1] = ("%d × %s"):format(need - owned, itemName(id))
                    .. (addon.StockSuffix and addon.StockSuffix(id) or "")
            end
        end
    end
    return rows
end

function addon.CompletePlannedCraft(plan, recipeID)
    local entry = plan[recipeID]
    if not entry then return false end
    if entry.target then
        if entry.done >= entry.target then return false end
        entry.done = entry.done + 1
        if entry.done >= entry.target then
            -- Finished: drop the entry so a later AddShoppingRecipe() for the same
            -- recipe starts a fresh order (done = 0) instead of inheriting this one's
            -- done count from a stale, already-completed plan.
            plan[recipeID] = nil
        else
            addon.SetPlanTarget(entry, entry.target)
        end
        return true
    end

    local data = schematic(recipeID)
    if not data then return false end
    local perCraft = requiredItems(data)
    local items = entry.items or entry
    local changed = false
    for itemID, count in pairs(perCraft) do
        if items[itemID] then
            local left = items[itemID] - count
            items[itemID] = left > 0 and left or nil
            changed = true
        end
    end
    if changed and not next(items) then plan[recipeID] = nil end
    return changed
end

function addon.CleanupFinishedPlans(plan)
    -- Migration for saves written before the CompletePlannedCraft fix above: a
    -- finished order (done >= target) could be left behind forever and would make
    -- the next AddShoppingRecipe() for that recipe inherit its done count. Remove
    -- only entries that are actually finished; open orders are left untouched.
    local removed = 0
    for recipeID, entry in pairs(plan) do
        if type(entry) == "table" and entry.target and entry.done and entry.done >= entry.target then
            plan[recipeID] = nil
            removed = removed + 1
        end
    end
    return removed
end

function addon.RemoveShoppingItem(plan, professionID, itemID)
    for recipeID, entry in pairs(plan) do
        if entry.professionID == professionID and entry.items then
            entry.items[itemID] = nil
            if entry.perCraft then entry.perCraft[itemID] = nil
            elseif not next(entry.items) then plan[recipeID] = nil end
        end
    end
end

function addon.GetShoppingLines(plan)
    local groups, stock, lines, sections = {}, {}, {}, {}
    local totalNeeded, totalOwned = 0, 0
    for recipeID, entry in pairs(plan) do
        if not entry.items then
            local id, name = recipeProfession(recipeID)
            entry = { items = entry, professionID = id, professionName = name }
            plan[recipeID] = entry
        elseif entry.professionID == 0 then
            entry.professionID, entry.professionName = recipeProfession(recipeID)
        end
        local id = entry.professionID
        local group = groups[id]
        if not group then
            group = { name = addon.GetPlanProfessionName(entry), totals = {} }
            groups[id] = group
        end
        for itemID, count in pairs(entry.items) do
            group.totals[itemID] = (group.totals[itemID] or 0) + count
        end
    end
    for _, id in ipairs(orderedIDs(groups)) do
        local group = groups[id]
        local rows, itemIDs, quantities = {}, {}, {}
        for _, itemID in ipairs(orderedIDs(group.totals)) do
            local owned = stock[itemID]
            if owned == nil then owned = C_Item.GetItemCount(itemID, false) end
            local needed = group.totals[itemID]
            totalNeeded = totalNeeded + needed
            totalOwned = totalOwned + math.min(owned, needed)
            stock[itemID] = math.max(owned - needed, 0)
            if needed > owned then
                itemIDs[#itemIDs + 1] = itemID
                quantities[#quantities + 1] = needed - owned
                rows[#rows + 1] = ("%d × %s"):format(needed - owned, itemName(itemID))
                    .. (addon.StockSuffix and addon.StockSuffix(itemID) or "")
            end
        end
        if #rows > 0 then
            if #lines > 0 then lines[#lines + 1] = "" end
            lines[#lines + 1] = group.name or addon.GetText().unknownProfession
            sections[#sections + 1] = { id = id, name = lines[#lines], rows = rows, itemIDs = itemIDs, quantities = quantities }
            for _, row in ipairs(rows) do lines[#lines + 1] = row end
        end
    end
    local known = ForeverCraftIntermediateRecipes or {}
    for _, section in ipairs(sections) do
        section.alternatives = {}
        section.alternativeItems = {}
        section.intermediateCrafts = {}
        for index, id in ipairs(section.itemIDs) do
            local source = known[id]
            if source and not source.items[id] then
                local crafts = math.ceil(section.quantities[index] / source.count)
                local parts, materials = {}, {}
                local craftable = crafts
                for _, materialID in ipairs(orderedIDs(source.items)) do
                    local owned = stock[materialID]
                    if owned == nil then owned = C_Item.GetItemCount(materialID, false) end
                    local perCraft = source.items[materialID]
                    craftable = math.min(craftable, math.floor(owned / perCraft))
                    local missing = math.max(0, perCraft * crafts - owned)
                    if missing > 0 then
                        local text = ("%d × %s"):format(missing, itemName(materialID))
                        parts[#parts + 1] = text
                        materials[#materials + 1] = { id = materialID, text = text, quantity = missing }
                    end
                end
                if craftable > 0 then
                    section.intermediateCrafts[index] = {
                        recipeID = source.recipeID, crafts = craftable, output = craftable * source.count,
                    }
                end
                section.alternativeItems[index] = materials
                local L = addon.GetText()
                section.alternatives[index] = #parts > 0 and table.concat(parts, "\n") or L.alternativeReady
            end
        end
    end
    return lines, sections, totalOwned, totalNeeded
end

function addon.GetMaterialLines(recipeID, quantity)
    local L = addon.GetText()
    if not recipeID then return { L.select } end
    local data = schematic(recipeID)
    if not data then return { L.loading } end

    local items, hasChoice = requiredItems(data)
    local lines, intermediates, totals = {}, {}, {}
    for _, id in ipairs(orderedIDs(items)) do
        local needed = items[id] * quantity
        local owned = C_Item.GetItemCount(id, false)
        local missing = math.max(needed - owned, 0)
        if missing == 0 then
            lines[#lines + 1] = "|cff80c980" .. L.ready:format(itemName(id), owned, needed) .. "|r"
        else
            lines[#lines + 1] = "|cffff8080" .. L.missing:format(itemName(id), owned, needed, missing) .. "|r"
                .. (addon.StockSuffix and addon.StockSuffix(id) or "")
            outputs = outputs or buildOutputIndex()
            local source = outputs[id]
            if source and source.recipeID ~= recipeID and not source.items[id] then
                local crafts = math.ceil(missing / source.count)
                local amount = crafts * source.count
                intermediates[#intermediates + 1] = L.intermediate:format(amount, itemName(id))
                for inputID, count in pairs(source.items) do
                    totals[inputID] = (totals[inputID] or 0) + count * crafts
                end
            end
        end
    end
    if hasChoice then lines[#lines + 1] = L.unsupported end
    if #lines == 0 then lines[1] = L.none end
    local details = {}
    for _, line in ipairs(intermediates) do details[#details + 1] = line end
    for _, id in ipairs(orderedIDs(totals)) do
        details[#details + 1] = L.input:format(itemName(id), totals[id], C_Item.GetItemCount(id, false))
    end
    return lines, details
end


function addon.GetAuctioneerEstimate(itemID, quantity)
    local api = AucAdvanced and AucAdvanced.API
    if not api or not api.GetMarketValue then return end
    local ok, price = pcall(api.GetMarketValue, itemID)
    if ok and type(price) == "number" and price > 0 and price < math.huge then
        return math.floor(price * quantity + 0.5)
    end
end

local function auctionatorEstimate(itemID, quantity)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.GetAuctionPriceByItemID then return end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "ForeverCraft", itemID)
    if ok and type(price) == "number" and price > 0 and price < math.huge then
        return math.floor(price * quantity + 0.5)
    end
end

function addon.GetMarketEstimate(itemID, quantity)
    local db = ForeverCraftDB
    if db and db.showMarketPrices == false then return end
    local preferAuctionator = db and db.preferAuctionator
    if preferAuctionator then
        local estimate = auctionatorEstimate(itemID, quantity)
        if estimate then return estimate, "Auctionator" end
    end
    local estimate = addon.GetAuctioneerEstimate(itemID, quantity)
    if estimate then return estimate, "Auctioneer" end
    if not preferAuctionator then
        estimate = auctionatorEstimate(itemID, quantity)
        if estimate then return estimate, "Auctionator" end
    end
end

function addon.GetRecipeMaterialEstimate(recipeID)
    local data = schematic(recipeID)
    if not data then return end
    local items, hasChoice = requiredItems(data)
    if hasChoice or not next(items) then return end
    local total = 0
    for itemID, quantity in pairs(items) do
        local estimate = addon.GetMarketEstimate(itemID, quantity)
        if not estimate then return end
        total = total + estimate
    end
    return total
end
