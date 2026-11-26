-- Unit/integration tests for ForeverCraft/Economy.lua: the sell-value math (vendor vs.
-- auction-net vs. disenchant-net) and the empirical disenchant statistics.
-- Usage: lua tools/test_economy.lua   (run from the repository root)

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    else
        print(("ok   %s = %s"):format(label, tostring(got)))
    end
end

local function loadEconomy()
    local addonTable = {}
    local chunk = assert(loadfile("ForeverCraft/Economy.lua"))
    chunk("ForeverCraft", addonTable)
    return addonTable
end

print("-- Pure math: AH cut and net value --")
do
    Auctionator = nil
    local addon = loadEconomy()
    check("default cut multiplier (no Auctionator)", addon.GetAuctionCutMultiplier(), 0.95)
    check("net of 1000g gross", addon.NetAuctionValue(10000), 9500)
    check("net of nil is nil", addon.NetAuctionValue(nil), nil)
    check("net of 0 is nil", addon.NetAuctionValue(0), nil)

    Auctionator = { Constants = { AfterAHCut = 0.90 } }
    check("cut multiplier reads Auctionator.Constants.AfterAHCut", addon.GetAuctionCutMultiplier(), 0.90)
    check("net respects Auctionator's cut", addon.NetAuctionValue(10000), 9000)
    Auctionator = nil
end

print("-- BuildRecommendation --")
do
    local addon = loadEconomy()
    local rec = addon.BuildRecommendation({
        vendor = { net = 100, confident = true },
        auction = { net = 300, confident = true },
        disenchant = { net = 200, confident = true },
    })
    check("best key", rec.bestKey, "auction")
    check("best net", rec.bestNet, 300)
    check("upside over next-best", rec.upside, 100)

    rec = addon.BuildRecommendation({ vendor = { net = 100, confident = true } })
    check("single known option: no upside claimed", rec.upside, nil)
    check("single known option: key", rec.bestKey, "vendor")

    rec = addon.BuildRecommendation({})
    check("no known options -> nil", rec, nil)

    rec = addon.BuildRecommendation({
        vendor = { net = 100, confident = true },
        disenchant = { net = 500, confident = false }, -- unconfident (too small a sample)
    })
    check("unconfident option excluded from comparison", rec.bestKey, "vendor")

    rec = addon.BuildRecommendation({
        vendor = { net = 200, confident = true },
        auction = { net = 200, confident = true },
    })
    check("tie: no misleading upside", rec.upside, 0)
    check("tie flag set", rec.tie, true)
end

print("-- Empirical disenchant statistics --")
do
    local addon = loadEconomy()
    ForeverCraftDisenchantLog = nil
    check("no data -> nil", addon.GetEmpiricalDisenchantValue(9999, function() return 100 end), nil)

    -- 4 disenchants of item 9999: always 2x material A (price 10c), half the time also 1x material B (price 1000c).
    addon.RecordDisenchantResult(9999, { [1111] = 2, [2222] = 1 })
    addon.RecordDisenchantResult(9999, { [1111] = 2, [2222] = 1 })
    addon.RecordDisenchantResult(9999, { [1111] = 2 })
    addon.RecordDisenchantResult(9999, { [1111] = 2 })

    local prices = { [1111] = 10, [2222] = 1000 }
    local result = addon.GetEmpiricalDisenchantValue(9999, function(id) return prices[id] end)
    check("sample size", result.sampleSize, 4)
    check("below minimum sample -> not confident", result.confident, false)
    -- expected = (2 * 10) + (0.5 * 1000) = 20 + 500 = 520
    check("expected gross value", result.gross, 520)

    for _ = 1, 10 do addon.RecordDisenchantResult(9999, { [1111] = 2 }) end
    result = addon.GetEmpiricalDisenchantValue(9999, function(id) return prices[id] end)
    check("sample size grows", result.sampleSize, 14)
    check("reaches minimum sample -> confident", result.confident, true)

    local incomplete = addon.GetEmpiricalDisenchantValue(9999, function() return nil end)
    check("missing price for a material -> gross unknown, not fabricated", incomplete.gross, nil)
end

print("-- SortDisenchantRows (Disenchant.lua panel sort/filter modes) --")
do
    local addon = loadEconomy()
    local rows = {
        { name = "A", evaluation = { disenchant = { gross = 100 }, recommendation = { bestKey = "vendor", upside = 50 } } },
        { name = "B", evaluation = { disenchant = { gross = 500 }, recommendation = { bestKey = "disenchant", upside = 10 } } },
        { name = "C", evaluation = nil },
        { name = "D", evaluation = { disenchant = nil, recommendation = { bestKey = "auction", upside = 200 } } },
    }

    local function names(list)
        local out = {}
        for i, row in ipairs(list) do out[i] = row.name end
        return table.concat(out, ",")
    end

    check("default: unchanged order", names(addon.SortDisenchantRows(rows, "default")), "A,B,C,D")
    -- C and D both have no known disenchant value, so their relative order is unspecified.
    local byDisenchant = names(addon.SortDisenchantRows(rows, "disenchantValue"))
    check("disenchantValue: highest DE gross first", byDisenchant:sub(1, 4), "B,A,")
    check("upside: highest expected extra gain first", names(addon.SortDisenchantRows(rows, "upside")), "D,A,B,C")
    check("disenchantRecommended: only disenchant-best rows", names(addon.SortDisenchantRows(rows, "disenchantRecommended")), "B")
    check("vendorRecommended: only vendor-best rows", names(addon.SortDisenchantRows(rows, "vendorRecommended")), "A")
    check("auctionRecommended: only auction-best rows", names(addon.SortDisenchantRows(rows, "auctionRecommended")), "D")
    check("noData: only rows without any recommendation", names(addon.SortDisenchantRows(rows, "noData")), "C")
    check("unknown mode behaves like default", names(addon.SortDisenchantRows(rows, "bogus")), "A,B,C,D")
end

print("")
if failures == 0 then
    print("ALL OK")
    os.exit(0)
else
    print(failures .. " FAILURE(S)")
    os.exit(1)
end
