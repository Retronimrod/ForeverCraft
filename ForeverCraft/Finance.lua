local _, addon = ...

-- Money tracking and statistics (ForeverCraftFinance, account-wide, per character).
--
-- Every change of the real money amount (PLAYER_MONEY) is recorded exactly once as the
-- difference to the last known amount, which is saved, so reloads and logins never create
-- duplicates. The category comes from the context the change happened in: an exact
-- pending action (quest reward amount, repair, auction post, mail send/take, talent reset)
-- first, then the open window (merchant, trainer, flight master, auction house, mail,
-- trade, bank, guild bank, loot). Anything else is "other" – never a guessed category.
-- A change that happened while ForeverCraft was not running (e.g. addon disabled) is
-- stored as "untracked" and never counted as income or expense.

local finance = {}
addon.finance = finance
local DB_VERSION = 1

finance.income = { "quest", "loot", "vendor", "auction", "trade", "mail", "refund", "guildbank", "otherIncome" }
finance.expense = { "vendor", "classTrainer", "professionTrainer", "auction", "auctionFee", "trade", "repair",
    "flight", "bank", "mail", "talent", "guildbank", "otherExpense" }
-- Never income/expense in combined statistics:
finance.neutral = { transfer = true, untracked = true }

local function enabled()
    return not ForeverCraftDB or ForeverCraftDB.financeTracking ~= false
end

function finance.db()
    if type(ForeverCraftFinance) ~= "table" then ForeverCraftFinance = {} end
    local db = ForeverCraftFinance
    db.version = db.version or DB_VERSION
    db.characters = db.characters or {}
    return db
end

function finance.character(key)
    key = key or (addon.inventory and addon.inventory.currentKey())
    if not key then return end
    local characters = finance.db().characters
    local entry = characters[key]
    if not entry then
        entry = { transactions = {}, daily = {}, snapshots = {}, sum = 0 }
        characters[key] = entry
    end
    return entry
end

local function dayKey(t) return date("%Y-%m-%d", t) end

-- Daily buckets keep the totals forever even after detailed transactions are pruned.
-- Keys are "+category"/"-category"; "#+category" counts transactions.
local function addDaily(entry, t, amount, category)
    local key = (amount > 0 and "+" or "-") .. category
    local bucket = entry.daily[dayKey(t)] or {}
    entry.daily[dayKey(t)] = bucket
    bucket[key] = (bucket[key] or 0) + amount
    bucket["#" .. key] = (bucket["#" .. key] or 0) + 1
end

function finance.record(entry, amount, category, detail, t)
    if amount == 0 then return end
    t = t or time()
    entry.transactions[#entry.transactions + 1] = { t = t, a = amount, c = category, d = detail }
    entry.sum = (entry.sum or 0) + amount
    addDaily(entry, t, amount, category)
    if finance.onChange then finance.onChange() end
end

-- Manual correction: only the category changes, never the amount.
function finance.recategorize(entry, transaction, category)
    local old = transaction.o or transaction.c
    if old == category then return end
    local sign, day = transaction.a > 0 and "+" or "-", dayKey(transaction.t)
    local bucket = entry.daily[day] or {}
    entry.daily[day] = bucket
    bucket[sign .. old] = (bucket[sign .. old] or 0) - transaction.a
    bucket["#" .. sign .. old] = math.max(0, (bucket["#" .. sign .. old] or 1) - 1)
    bucket[sign .. category] = (bucket[sign .. category] or 0) + transaction.a
    bucket["#" .. sign .. category] = (bucket["#" .. sign .. category] or 0) + 1
    transaction.o = category
    if finance.onChange then finance.onChange() end
end

function finance.category(transaction)
    return transaction.o or transaction.c
end

-- Context tracking ---------------------------------------------------------------------
local contexts, pending = {}, {}
local function now() return GetTime() end
local function openContext(name, data) contexts[name] = { until_ = math.huge, data = data } end
local function closeContext(name)
    if contexts[name] then contexts[name].until_ = now() + 2 end
end
local function active(name)
    local context = contexts[name]
    return context and context.until_ >= now() and context or nil
end

-- sign: 1 income, -1 expense; amount: exact amount in copper or nil for "any".
function finance.expect(category, sign, amount, detail, seconds, split)
    pending[#pending + 1] = { category = category, sign = sign, amount = amount, detail = detail,
        expires = now() + (seconds or 3), split = split }
end

local function ownCharacter(name)
    if not name or name == "" then return false end
    local short = name:match("^([^-]+)") or name
    for key, character in pairs(addon.inventory.db().characters) do
        if key ~= addon.inventory.currentKey() and (character.name == short or key:match("%-(.+)$") == short) then
            return true
        end
    end
    return false
end
finance.isOwnCharacter = ownCharacter

function finance.classify(delta)
    local sign, t = delta > 0 and 1 or -1, now()
    for i = #pending, 1, -1 do
        if pending[i].expires < t then table.remove(pending, i) end
    end
    for i, p in ipairs(pending) do
        if p.sign == sign and (not p.amount or p.amount == math.abs(delta)) then
            table.remove(pending, i)
            return p.category, p.detail, p.split
        end
    end
    local trade = active("trade")
    if trade then return ownCharacter(trade.data) and "transfer" or "trade", trade.data end
    if active("merchant") then return "vendor", active("merchant").data end
    if active("guildbank") then return "guildbank" end
    if sign > 0 then
        if active("mail") then return "mail" end
        if active("loot") then return "loot" end
        return "otherIncome"
    end
    local trainer = active("trainer")
    if trainer then return trainer.data and "professionTrainer" or "classTrainer" end
    if active("taxi") then return "flight" end
    if active("auction") then return "auction" end
    if active("mail") then return "mail" end
    if active("bank") then return "bank" end
    return "otherExpense"
end

function finance.moneyChanged(money)
    local entry = finance.character()
    if not entry then return end
    if entry.lastMoney == nil then
        entry.lastMoney, entry.base, entry.baseAt = money, money, time()
        return
    end
    local delta = money - entry.lastMoney
    entry.lastMoney = money
    if delta == 0 then return end
    if not enabled() then
        finance.record(entry, delta, "untracked")
        return
    end
    local category, detail, split = finance.classify(delta)
    if split then
        for _, part in ipairs(split) do finance.record(entry, part.amount, part.category, part.detail) end
    else
        finance.record(entry, delta, category, detail)
    end
end

-- Logging in with a different amount than last saved means money changed while this
-- addon was not tracking (another addon set, disabled addon): keep it out of statistics.
function finance.login(money)
    local entry = finance.character()
    if not entry then return end
    if entry.lastMoney == nil then
        entry.lastMoney, entry.base, entry.baseAt = money, money, time()
    elseif entry.lastMoney ~= money then
        local delta = money - entry.lastMoney
        entry.lastMoney = money
        finance.record(entry, delta, "untracked")
    end
end

-- Reconciliation: start amount plus every recorded change must equal the real amount.
function finance.reconcile(entry, money)
    if not entry or entry.base == nil or money == nil then return nil end
    return money - (entry.base + (entry.sum or 0))
end

-- Retention: detailed transactions older than the configured number of days are dropped;
-- their totals stay in the daily buckets.
function finance.prune(entry, days, t)
    if not days or days <= 0 then return end
    local limit, kept = (t or time()) - days * 86400, {}
    for _, transaction in ipairs(entry.transactions) do
        if transaction.t >= limit then kept[#kept + 1] = transaction end
    end
    entry.transactions = kept
end

-- Statistics -------------------------------------------------------------------------
-- range: { from = t1, to = t2 }; keys: list of character keys. Returns per-category
-- income/expense sums and counts; internal transfers are reported separately and,
-- across several characters, excluded from income/expense.
function finance.summary(keys, range)
    local result = { income = {}, expense = {}, counts = {}, transfers = 0, untracked = 0 }
    local fromDay, toDay = dayKey(range.from), dayKey(range.to)
    local partialDays = range.to - range.from < 86400
    for _, key in ipairs(keys) do
        local entry = finance.db().characters[key]
        if entry then
            if partialDays then
                for _, transaction in ipairs(entry.transactions) do
                    if transaction.t >= range.from and transaction.t <= range.to then
                        finance.addToSummary(result, finance.category(transaction), transaction.a, 1, #keys)
                    end
                end
            else
                for day, bucket in pairs(entry.daily) do
                    if day >= fromDay and day <= toDay then
                        for key2, amount in pairs(bucket) do
                            if key2:sub(1, 1) ~= "#" then
                                finance.addToSummary(result, key2:sub(2), amount, bucket["#" .. key2] or 0, #keys)
                            end
                        end
                    end
                end
            end
        end
    end
    local income, expense = 0, 0
    for _, amount in pairs(result.income) do income = income + amount end
    for _, amount in pairs(result.expense) do expense = expense + amount end
    result.totalIncome, result.totalExpense, result.net = income, expense, income - expense
    return result
end

function finance.addToSummary(result, category, amount, count, characterCount)
    if category == "untracked" then result.untracked = result.untracked + amount; return end
    if category == "transfer" then
        result.transfers = result.transfers + amount
        if characterCount > 1 or (ForeverCraftDB and ForeverCraftDB.financeSeparateTransfers ~= false) then return end
    end
    local side = amount > 0 and result.income or result.expense
    side[category] = (side[category] or 0) + math.abs(amount)
    local countKey = (amount > 0 and "+" or "-") .. category
    result.counts[countKey] = (result.counts[countKey] or 0) + count
end

-- Bar chart buckets: hours for one day, days up to ~2 months, months beyond.
function finance.series(keys, range)
    local span = range.to - range.from
    local step = span <= 86400 and "hour" or span <= 62 * 86400 and "day" or "month"
    local buckets, order = {}, {}
    local function bucketFor(t)
        local format = step == "hour" and "%Y-%m-%d %H" or step == "day" and "%Y-%m-%d" or "%Y-%m"
        local key = date(format, t)
        local bucket = buckets[key]
        if not bucket then
            bucket = { key = key, income = 0, expense = 0, t = t }
            buckets[key] = bucket
            order[#order + 1] = bucket
        end
        return bucket
    end
    local t = range.from
    while t <= range.to do
        bucketFor(t)
        t = t + (step == "hour" and 3600 or 86400)
    end
    for _, key in ipairs(keys) do
        local entry = finance.db().characters[key]
        if entry then
            if step == "hour" then
                for _, transaction in ipairs(entry.transactions) do
                    local category = finance.category(transaction)
                    if transaction.t >= range.from and transaction.t <= range.to and not finance.neutral[category] then
                        local bucket = bucketFor(transaction.t)
                        if transaction.a > 0 then bucket.income = bucket.income + transaction.a
                        else bucket.expense = bucket.expense - transaction.a end
                    end
                end
            else
                for day, values in pairs(entry.daily) do
                    local y, m, d = day:match("^(%d+)-(%d+)-(%d+)$")
                    local dayTime = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
                    if dayTime >= range.from - 43200 and dayTime <= range.to + 43200 then
                        local bucket = bucketFor(dayTime)
                        for k, amount in pairs(values) do
                            local category = k:sub(2)
                            if k:sub(1, 1) ~= "#" and not finance.neutral[category] then
                                if amount > 0 then bucket.income = bucket.income + amount
                                else bucket.expense = bucket.expense - amount end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(order, function(a, b) return a.key < b.key end)
    return order, step
end

-- Valuation ----------------------------------------------------------------------------
finance.methods = { "best", "vendor", "auction", "auctionNet", "disenchant" }
local unitCache = {}
function finance.resetValues() wipe(unitCache) end

-- Unit value of one item for a method; nil = cannot be valued (never counted as 0).
function finance.unitValue(link, method, bound)
    if not link then return nil end
    local cacheKey = method .. "|" .. link
    local cached = unitCache[cacheKey]
    if cached == nil then
        local e = addon.EvaluateItem(link, 1)
        local value
        if e then
            if method == "vendor" then value = e.vendorGross
            elseif method == "auction" then value = not bound and e.auctionGross or nil
            elseif method == "auctionNet" then value = not bound and e.auctionNet or nil
            elseif method == "disenchant" then value = e.disenchant and e.disenchant.gross or nil
            else value = e.recommendation and e.recommendation.bestNet or e.vendorGross end
        end
        cached = value or false
        unitCache[cacheKey] = cached
    end
    return cached or nil
end

function finance.valueItems(items, method)
    local total, unvalued, best, bestValue = 0, 0, nil, 0
    for _, item in ipairs(items or {}) do
        local unit = finance.unitValue(item.link, method, item.bound)
        if unit then
            local value = unit * (item.count or 1)
            total = total + value
            if value > bestValue then best, bestValue = item, value end
        else
            unvalued = unvalued + 1
        end
    end
    return total, unvalued, best, bestValue
end

function finance.bankItems(character)
    local items = {}
    for _, tab in pairs(character and character.bank and character.bank.tabs or {}) do
        for _, item in ipairs(tab.items) do items[#items + 1] = item end
    end
    return items
end

-- Current known wealth of one character (snapshot data, not live for other characters).
function finance.wealth(key, method)
    local character = addon.inventory.db().characters[key]
    local entry = finance.db().characters[key]
    local includeEquipment = ForeverCraftDB and ForeverCraftDB.financeIncludeEquipment
    local bags, bagsUnvalued, bestBag, bestBagValue = finance.valueItems(character and character.bags, method)
    local bank, bankUnvalued, bestBank, bestBankValue = finance.valueItems(finance.bankItems(character), method)
    local equip, equipUnvalued = finance.valueItems(character and character.equipped, method)
    local money = key == addon.inventory.currentKey() and GetMoney()
        or (entry and entry.lastMoney) or (character and character.money) or 0
    local total = money + bags + bank + (includeEquipment and equip or 0)
    return { money = money, bags = bags, bank = bank, equip = equip, total = total,
        unvalued = bagsUnvalued + bankUnvalued + (includeEquipment and equipUnvalued or 0),
        bestBag = bestBag, bestBagValue = bestBagValue, bestBank = bestBank, bestBankValue = bestBankValue }
end

-- Snapshots of known wealth for the history chart. Values are stored as they were at
-- that time; old values are never recalculated with today's prices.
function finance.snapshot(t)
    if ForeverCraftDB and ForeverCraftDB.financeSnapshots == false then return end
    local key = addon.inventory.currentKey()
    local entry = finance.character(key)
    if not entry then return end
    t = t or time()
    local last = entry.snapshots[#entry.snapshots]
    if last and t - last.t < 3600 then return end
    finance.resetValues()
    local w = finance.wealth(key, "best")
    entry.snapshots[#entry.snapshots + 1] = { t = t, money = w.money, bags = w.bags, bank = w.bank,
        equip = w.equip, unvalued = w.unvalued, method = "best" }
    -- Thin out: hourly for 14 days, then one per day.
    local kept, seenDay = {}, {}
    for _, s in ipairs(entry.snapshots) do
        local day = dayKey(s.t)
        if t - s.t <= 14 * 86400 or not seenDay[day] then
            kept[#kept + 1] = s
            seenDay[day] = true
        end
    end
    entry.snapshots = kept
end

-- Events --------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local windowEvents = {
    MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
    TAXIMAP_OPENED = { "taxi", true }, TAXIMAP_CLOSED = { "taxi", false },
    AUCTION_HOUSE_SHOW = { "auction", true }, AUCTION_HOUSE_CLOSED = { "auction", false },
    MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
    BANKFRAME_OPENED = { "bank", true }, BANKFRAME_CLOSED = { "bank", false },
    GUILDBANKFRAME_OPENED = { "guildbank", true }, GUILDBANKFRAME_CLOSED = { "guildbank", false },
    LOOT_OPENED = { "loot", true }, LOOT_CLOSED = { "loot", false },
    TRADE_CLOSED = { "trade", false }, TRAINER_CLOSED = { "trainer", false },
}
for event in pairs(windowEvents) do pcall(events.RegisterEvent, events, event) end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "QUEST_TURNED_IN", "CHAT_MSG_MONEY",
    "TRADE_SHOW", "TRAINER_SHOW", "CONFIRM_TALENT_WIPE", "PLAYER_LOGOUT" }) do
    pcall(events.RegisterEvent, events, event)
end

local hooked
local function installHooks()
    if hooked then return end
    hooked = true
    if RepairAllItems then
        hooksecurefunc("RepairAllItems", function() finance.expect("repair", -1, nil, nil, 3) end)
    end
    if C_AuctionHouse then
        for _, name in ipairs({ "PostItem", "PostCommodity" }) do
            if C_AuctionHouse[name] then
                hooksecurefunc(C_AuctionHouse, name, function() finance.expect("auctionFee", -1, nil, nil, 5) end)
            end
        end
    end
    -- Mail API is used only if this client provides it (not confirmed by any installed
    -- addon); without it, money at the mailbox is recorded as plain "mail".
    if TakeInboxMoney and GetInboxHeaderInfo then
        local function takeMoney(index)
            local _, _, sender, subject, money = GetInboxHeaderInfo(index)
            if not money or money <= 0 then return end
            local invoiceType, itemName
            if GetInboxInvoiceInfo then invoiceType, itemName = GetInboxInvoiceInfo(index) end
            local category = invoiceType == "seller" and "auction" or ownCharacter(sender) and "transfer"
                or invoiceType and "refund" or "mail"
            finance.expect(category, 1, money, itemName or sender or subject, 5)
        end
        hooksecurefunc("TakeInboxMoney", takeMoney)
        if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", takeMoney) end
    end
    if SendMail and GetSendMailMoney and GetSendMailPrice then
        hooksecurefunc("SendMail", function(recipient)
            local money, postage = GetSendMailMoney() or 0, GetSendMailPrice() or 0
            local split = {}
            if money > 0 then
                local category = ownCharacter(recipient) and "transfer" or "mail"
                split[#split + 1] = { amount = -money, category = category, detail = recipient }
            end
            if postage > 0 then split[#split + 1] = { amount = -postage, category = "mail", detail = recipient } end
            if #split > 0 then finance.expect("mail", -1, money + postage, recipient, 5, split) end
        end)
    end
end

events:SetScript("OnEvent", function(_, event, ...)
    local window = windowEvents[event]
    if window then
        if window[2] then openContext(window[1]) else closeContext(window[1]) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        installHooks()
        finance.login(GetMoney())
        local entry = finance.character()
        local days = ForeverCraftDB and tonumber(ForeverCraftDB.financeRetention) or 90
        if entry then finance.prune(entry, days) end
        C_Timer.After(15, function() finance.snapshot() end)
    elseif event == "PLAYER_MONEY" then
        finance.moneyChanged(GetMoney())
    elseif event == "QUEST_TURNED_IN" then
        local questID, _, money = ...
        if money and money > 0 then
            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
            finance.expect("quest", 1, money, title, 5)
        end
    elseif event == "CHAT_MSG_MONEY" then
        openContext("loot")
        closeContext("loot")
    elseif event == "TRADE_SHOW" then
        openContext("trade", UnitName("NPC"))
    elseif event == "TRAINER_SHOW" then
        openContext("trainer", IsTradeskillTrainer and IsTradeskillTrainer() or false)
    elseif event == "CONFIRM_TALENT_WIPE" then
        finance.expect("talent", -1, nil, nil, 60)
    elseif event == "PLAYER_LOGOUT" then
        finance.snapshot()
    end
end)
C_Timer.NewTicker(1800, function() finance.snapshot() end)
