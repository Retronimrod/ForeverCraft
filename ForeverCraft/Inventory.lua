local _, addon = ...

-- Central, account-wide item stock database (ForeverCraftInventory): bags and bank of every
-- character this account has logged in with. Shared by the bank view, the stock tooltip,
-- crafting/shopping planning and (later) the finance valuation. Snapshots of other
-- characters are never live data; every snapshot carries its timestamp.
--
-- WoW Forever uses character bank tabs (Enum.BagIndex.CharacterBankTab_n, C_Bank) like
-- Retail, not classic bank bags; the bank can only be read while it is open, so a bank
-- snapshot is only ever written from BANKFRAME_OPENED until BANKFRAME_CLOSED.

local inventory = {}
addon.inventory = inventory
local DB_VERSION = 1
local bankOpen, index, listeners = false, nil, {}
local bagPending, bankPending

local function setting(key)
    return not ForeverCraftDB or ForeverCraftDB[key] ~= false
end

function inventory.db()
    if type(ForeverCraftInventory) ~= "table" then ForeverCraftInventory = {} end
    local db = ForeverCraftInventory
    db.version = db.version or DB_VERSION
    db.characters = db.characters or {}
    return db
end

-- The realm can come back empty from GetRealmName on WoW Forever; fall back like
-- Syndicator does (normalized realm name, then UnitFullName).
local function realmName()
    local realm = GetRealmName and GetRealmName()
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
    if not realm or realm == "" then realm = select(2, UnitFullName("player")) end
    if not realm or realm == "" then realm = "Forever" end
    return realm
end

function inventory.currentKey()
    local name = UnitName("player")
    if not name or name == "" or name == UNKNOWNOBJECT then return nil end
    return realmName() .. "-" .. name
end

local function currentCharacter()
    local key = inventory.currentKey()
    if not key then return end
    local characters = inventory.db().characters
    local character = characters[key] or {}
    characters[key] = character
    local _, class = UnitClass("player")
    character.name, character.realm, character.class = UnitName("player"), realmName(), class
    character.level, character.faction = UnitLevel("player"), UnitFactionGroup("player")
    return character
end

function inventory.onChange(callback)
    listeners[#listeners + 1] = callback
end

function inventory.changed()
    index = nil
    for _, callback in ipairs(listeners) do callback() end
end

-- Item level lookup exists as C_Item.GetDetailedItemLevelInfo or as the older global
-- depending on the client (other addons on WoW Forever use the same fallback).
local itemLevelOf = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo

local function readSlot(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then return end
    local level
    if itemLevelOf and info.hyperlink then
        local ok, value = pcall(itemLevelOf, info.hyperlink)
        level = ok and value or nil
    end
    return { id = info.itemID, link = info.hyperlink, count = info.stackCount or 1,
        quality = info.quality, level = level, bound = info.isBound or nil, slot = slot }
end

local function bagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do ids[#ids + 1] = bag end
    if Enum.BagIndex and Enum.BagIndex.ReagentBag then ids[#ids + 1] = Enum.BagIndex.ReagentBag end
    return ids
end

function inventory.bankTabIDs()
    local ids = {}
    for tab = 1, 9 do
        local id = Enum.BagIndex and Enum.BagIndex["CharacterBankTab_" .. tab]
        if id then ids[#ids + 1] = id end
    end
    return ids
end

function inventory.scanBags()
    bagPending = false
    if not setting("inventoryTracking") then return end
    local character = currentCharacter()
    if not character then return end
    local items, total, free = {}, 0, 0
    for _, bag in ipairs(bagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            total = total + 1
            local ok, item = pcall(readSlot, bag, slot)
            if not ok then item = nil end
            if item then
                item.bag = bag
                items[#items + 1] = item
            else
                free = free + 1
            end
        end
    end
    -- During loading screens the client can report no bag slots at all; never replace a
    -- real snapshot with an empty one.
    if total == 0 then inventory.lastBagScan = "no bag slots"; return end
    character.bags, character.bagSlots, character.bagFree, character.bagsAt = items, total, free, time()
    -- Equipped items (counted as bound: equipping binds them) for the optional equipment value.
    local equipped = {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            equipped[#equipped + 1] = { id = C_Item.GetItemInfoInstant(link), link = link, count = 1,
                quality = GetInventoryItemQuality and GetInventoryItemQuality("player", slot) or nil,
                bound = true, slot = slot }
        end
    end
    character.equipped = equipped
    inventory.lastBagScan = ("%d items, %d slots, %s"):format(#items, total, date("%H:%M:%S"))
    character.money = GetMoney()
    inventory.changed()
end

function inventory.scanBank()
    bankPending = false
    if not bankOpen or not setting("bankTracking") then return end
    if not (C_Bank and C_Bank.FetchPurchasedBankTabData and Enum.BankType) then return end
    local data = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
    if type(data) ~= "table" then return end
    local character = currentCharacter()
    if not character then return end
    local ids, tabs, total, free = inventory.bankTabIDs(), {}, 0, 0
    for tabIndex, details in ipairs(data) do
        local bag = ids[tabIndex]
        if not bag then break end
        local size = C_Container.GetContainerNumSlots(bag) or 0
        local tab = { name = details.name, icon = details.icon, size = size, items = {} }
        for slot = 1, size do
            total = total + 1
            local ok, item = pcall(readSlot, bag, slot)
            if not ok then item = nil end
            if item then tab.items[#tab.items + 1] = item else free = free + 1 end
        end
        tabs[tabIndex] = tab
    end
    -- Tabs reported but no slots loaded yet: wait for the next update instead of saving
    -- an empty bank.
    if #data > 0 and total == 0 then inventory.lastBankScan = "tabs without slots"; return end
    character.bank = { tabs = tabs, slots = total, free = free, at = time() }
    inventory.lastBankScan = ("%d tabs, %d slots, %s"):format(#tabs, total, date("%H:%M:%S"))
    inventory.changed()
end

local function queue(kind)
    if kind == "bank" then
        if bankPending then return end
        bankPending = true
        C_Timer.After(0.4, function() inventory.safe(inventory.scanBank) end)
    else
        if bagPending then return end
        bagPending = true
        C_Timer.After(0.5, function() inventory.safe(inventory.scanBags) end)
    end
end

-- Errors in a scan must never stay silent: keep the last one for /fcbank status.
function inventory.safe(scan)
    local ok, err = pcall(scan)
    if not ok then inventory.lastError = tostring(err) end
end

function inventory.status()
    local count = 0
    for _ in pairs(inventory.db().characters) do count = count + 1 end
    return {
        ("ForeverCraft · key=%s · characters=%d · bank open=%s"):format(tostring(inventory.currentKey()), count, tostring(bankOpen)),
        ("bags: %s · bank: %s"):format(inventory.lastBagScan or "-", inventory.lastBankScan or "-"),
        ("last error: %s"):format(inventory.lastError or "-"),
    }
end

function inventory.isBankOpen()
    return bankOpen
end

-- itemID -> { [characterKey] = { bags = n, bank = n } }, rebuilt lazily after changes.
local function buildIndex()
    index = {}
    local function add(id, key, where, count)
        local byCharacter = index[id] or {}
        index[id] = byCharacter
        local entry = byCharacter[key] or { bags = 0, bank = 0 }
        byCharacter[key] = entry
        entry[where] = entry[where] + count
    end
    for key, character in pairs(inventory.db().characters) do
        for _, item in ipairs(character.bags or {}) do add(item.id, key, "bags", item.count) end
        for _, tab in pairs(character.bank and character.bank.tabs or {}) do
            for _, item in ipairs(tab.items) do add(item.id, key, "bank", item.count) end
        end
    end
end

function inventory.counts(itemID)
    if not index then buildIndex() end
    return itemID and index[itemID]
end

-- Stock of an item for planning: what the current character carries (live), what lies on
-- its own bank and what other characters hold (saved snapshots, not directly usable).
function inventory.stock(itemID)
    local bags = C_Item.GetItemCount(itemID, false)
    local ownBank, others = 0, 0
    local current = inventory.currentKey()
    for key, entry in pairs(inventory.counts(itemID) or {}) do
        if key == current then ownBank = entry.bank else others = others + entry.bags + entry.bank end
    end
    return bags, ownBank, others
end

function addon.StockSuffix(itemID)
    if not itemID or not ForeverCraftDB or ForeverCraftDB.shoppingCrossCharacter == false then return "" end
    local _, ownBank, others = inventory.stock(itemID)
    if ownBank == 0 and others == 0 then return "" end
    local L, fallback = addon.GetText(), addon.strings.enUS
    return "   ·   " .. (L.stockElsewhere or fallback.stockElsewhere):format(ownBank, others)
end

function inventory.characterKeys()
    local keys, characters = {}, inventory.db().characters
    for key in pairs(characters) do keys[#keys + 1] = key end
    local current = inventory.currentKey()
    table.sort(keys, function(a, b)
        if a == current or b == current then return a == current end
        return a < b
    end)
    return keys
end

function inventory.classColor(character)
    local color = character and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class]
    return color and color.r or 1, color and color.g or 0.82, color and color.b or 0
end

local function text(key)
    local L = addon.GetText()
    return L[key] or addon.strings.enUS[key]
end

-- Stock tooltip: on which characters an item lies (bags/bank), plus the total.
local function addStockLines(tooltip, link)
    if not ForeverCraftDB or ForeverCraftDB.inventoryTooltip == false then return end
    local itemID = C_Item.GetItemInfoInstant(link)
    local counts = itemID and inventory.counts(itemID)
    if not counts or not next(counts) then return end
    local characters, total = inventory.db().characters, 0
    tooltip:AddLine(" ")
    tooltip:AddLine(text("stockHeading"), 1, 0.82, 0)
    for _, key in ipairs(inventory.characterKeys()) do
        local entry = counts[key]
        if entry then
            local parts = {}
            if entry.bags > 0 then parts[#parts + 1] = text("stockBags"):format(entry.bags) end
            if entry.bank > 0 then parts[#parts + 1] = text("stockBank"):format(entry.bank) end
            local character = characters[key]
            local r, g, b = inventory.classColor(character)
            tooltip:AddDoubleLine("  " .. (character.name or key), table.concat(parts, " · "), r, g, b, 1, 1, 1)
            total = total + entry.bags + entry.bank
        end
    end
    tooltip:AddDoubleLine("  " .. text("stockTotal"), tostring(total), 1, 0.82, 0, 1, 1, 1)
end

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or type(tooltip.GetItem) ~= "function" then return end
        local _, link = tooltip:GetItem()
        if link then addStockLines(tooltip, link) end
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "BAG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
        inventory.db()
        C_Timer.After(3, function() inventory.safe(inventory.scanBags) end)
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        queue("bank")
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "BAG_UPDATE_DELAYED" then
        queue("bags")
        if bankOpen then queue("bank") end
    elseif event == "BAG_UPDATE" then
        if bankOpen and type(arg) == "number" and arg > NUM_BAG_SLOTS then queue("bank") end
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        if bankOpen then queue("bank") end
    elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_MONEY" then
        local character = currentCharacter()
        if character then character.money = GetMoney() end
    end
end)
