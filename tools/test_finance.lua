-- Tests for ForeverCraft/Finance.lua (money tracking and statistics) with a WoW API stub.
-- Usage: lua tools/test_finance.lua   (from the repository root)
local fails = 0
local function check(label, got, want)
    if got ~= want then fails = fails + 1; print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    else print("ok   " .. label) end
end

local clock, money, handler = 1000, 100000, nil
GetTime = function() return clock end
time = function(t) if type(t) == "table" then return os.time(t) end return 1700000000 + clock end
date = os.date
GetMoney = function() return money end
C_Timer = { After = function() end, NewTicker = function() end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(_, _, f) handler = f end } end
hooksecurefunc = function() end
UnitName = function() return "Händler" end
ForeverCraftDB = {}
local addon = { inventory = {
    currentKey = function() return "PvE-Nimri" end,
    db = function() return { characters = { ["PvE-Nimri"] = { name = "Nimri" }, ["PvE-Twink"] = { name = "Twink" } } } end,
} }
assert(loadfile("ForeverCraft/Finance.lua"))("ForeverCraft", addon)
local f = addon.finance
local function fire(event, ...) handler(nil, event, ...) end
local function pay(delta) money = money + delta; fire("PLAYER_MONEY") end
local entry = f.character()

fire("PLAYER_ENTERING_WORLD")
check("first login: no transaction", #entry.transactions, 0)
check("first login: base set", entry.base, 100000)
fire("PLAYER_ENTERING_WORLD")
check("reload: no duplicate", #entry.transactions, 0)

fire("QUEST_TURNED_IN", 1, 0, 240)
pay(240)
check("quest money matched by exact amount", f.category(entry.transactions[1]), "quest")

fire("MERCHANT_SHOW")
pay(500)
check("selling at merchant", f.category(entry.transactions[2]), "vendor")
fire("RepairAllItems hook") -- simulate hook by expecting directly:
f.expect("repair", -1, nil, nil, 3)
pay(-85)
check("repair recognized", f.category(entry.transactions[3]), "repair")
pay(-120)
check("buying at merchant", f.category(entry.transactions[4]), "vendor")
fire("MERCHANT_CLOSED")
clock = clock + 10
pay(-30)
check("no context: other expense", f.category(entry.transactions[5]), "otherExpense")

fire("TRAINER_SHOW")
pay(-1000)
check("trainer (no tradeskill API) = class trainer", f.category(entry.transactions[6]), "classTrainer")
fire("TRAINER_CLOSED")
clock = clock + 10

-- Mail to own twink: money as internal transfer, postage as mail expense.
f.expect("mail", -1, 10030, "Twink", 5, { { amount = -10000, category = "transfer" }, { amount = -30, category = "mail" } })
pay(-10030)
check("mail transfer split: transfer part", f.category(entry.transactions[7]), "transfer")
check("mail transfer split: postage part", entry.transactions[8].a, -30)

-- Money changed while not tracked (logged in with another amount) -> untracked.
money = money + 777
fire("PLAYER_ENTERING_WORLD")
check("offline change stored as untracked", f.category(entry.transactions[9]), "untracked")

check("reconciliation exact", f.reconcile(entry, GetMoney()), 0)

local range = { from = time() - 86400 * 2, to = time() }
local s = f.summary({ "PvE-Nimri" }, range)
check("income total excludes transfer/untracked", s.totalIncome, 740)
check("expense total excludes transfer", s.totalExpense, 85 + 120 + 30 + 1000 + 30)
check("transfer reported separately", s.transfers, -10000)

f.recategorize(entry, entry.transactions[5], "repair")
local s2 = f.summary({ "PvE-Nimri" }, range)
check("recategorize keeps total", s2.totalExpense, s.totalExpense)
check("recategorize moves amount", s2.expense.repair, 115)
check("recategorize does not change amount", entry.transactions[5].a, -30)

f.prune(entry, 1, time() + 3 * 86400)
check("prune drops old details", #entry.transactions, 0)
check("daily totals survive pruning", f.summary({ "PvE-Nimri" }, range).totalIncome, 740)

local series = f.series({ "PvE-Nimri" }, range)
local income = 0
for _, bucket in ipairs(series) do income = income + bucket.income end
check("chart series sums income", income, 740)

print(fails == 0 and "\nALL OK" or ("\n" .. fails .. " FAILURE(S)")); os.exit(fails == 0 and 0 or 1)
