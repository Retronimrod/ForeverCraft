-- Tests for ForeverCraft/Inventory.lua (stock database) against a minimal WoW API stub.
-- Usage: lua tools/test_inventory.lua   (from the repository root)
local fails = 0
local function check(label, got, want)
    if got ~= want then fails = fails + 1; print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    else print("ok   " .. label) end
end

local player, bags, bankTabs, slotsPerBag = "Nimri", {}, nil, 4
NUM_BAG_SLOTS = 4
Enum = { BagIndex = { ReagentBag = 5, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7 }, BankType = { Character = 0 } }
UnitName = function() return player end
GetRealmName = function() return "Forever" end
UnitClass = function() return "Mage", "MAGE" end
UnitLevel = function() return 60 end
UnitFactionGroup = function() return "Alliance" end
GetMoney = function() return 12345 end
time = os.time
date = os.date
GetInventoryItemLink = function() return nil end
C_Timer = { After = function(_, callback) callback() end }
C_Item = { GetDetailedItemLevelInfo = function() return 1 end,
    GetItemCount = function(id) local n = 0; for _, item in pairs(bags) do if item.itemID == id then n = n + item.stackCount end end; return n end }
C_Container = {
    GetContainerNumSlots = function(bag) if bag >= 6 then return bankTabs and 3 or 0 end; return slotsPerBag end,
    GetContainerItemInfo = function(bag, slot) local key = bag .. ":" .. slot
        if bag >= 6 then return bankTabs and bankTabs[key] end; return bags[key] end,
}
C_Bank = { FetchPurchasedBankTabData = function() return bankTabs and { { name = "Tab 1", icon = 1 } } or {} end }
local handler
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(_, _, f) handler = f end } end
ForeverCraftDB = {}

local addon = { strings = { enUS = { stockElsewhere = "Bank %d · others %d" } } }
addon.GetText = function() return addon.strings.enUS end
assert(loadfile("ForeverCraft/Inventory.lua"))("ForeverCraft", addon)
local inv = addon.inventory
local RUNECLOTH = 14047

bags["0:1"] = { itemID = RUNECLOTH, stackCount = 10, hyperlink = "|Hitem:14047|h[Runecloth]|h", quality = 1 }
inv.scanBags()
local me = inv.db().characters["Forever-Nimri"]
check("bags recorded", #me.bags, 1)
check("money recorded", me.money, 12345)

slotsPerBag = 0
inv.scanBags()
check("empty slot list never overwrites a snapshot", #me.bags, 1)
slotsPerBag = 4

bankTabs = { ["6:1"] = { itemID = RUNECLOTH, stackCount = 20, hyperlink = "x", quality = 1 } }
inv.scanBank()
check("bank not read while closed", me.bank, nil)
handler(nil, "BANKFRAME_OPENED")
check("bank recorded when open", me.bank and #me.bank.tabs[1].items, 1)
handler(nil, "BANKFRAME_CLOSED")
bankTabs = nil
inv.scanBank()
check("closed bank keeps last snapshot", #me.bank.tabs[1].items, 1)

player = "Twink"
bags = { ["0:1"] = { itemID = RUNECLOTH, stackCount = 80, hyperlink = "x", quality = 1 } }
inv.scanBags()
local counts = inv.counts(RUNECLOTH)
check("index per character (main bank)", counts["Forever-Nimri"].bank, 20)
check("index per character (twink bags)", counts["Forever-Twink"].bags, 80)
player = "Nimri"
bags = { ["0:1"] = { itemID = RUNECLOTH, stackCount = 10, hyperlink = "x", quality = 1 } }
local inBags, ownBank, others = inv.stock(RUNECLOTH)
check("stock: live bags", inBags, 10)
check("stock: own bank", ownBank, 20)
check("stock: other characters", others, 80)
check("stock suffix shown", addon.StockSuffix(RUNECLOTH), "   ·   Bank 20 · others 80")
ForeverCraftDB.shoppingCrossCharacter = false
check("stock suffix respects setting", addon.StockSuffix(RUNECLOTH), "")

print(fails == 0 and "\nALL OK" or ("\n" .. fails .. " FAILURE(S)")); os.exit(fails == 0 and 0 or 1)
