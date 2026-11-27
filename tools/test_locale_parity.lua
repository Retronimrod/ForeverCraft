-- Checks every locale catalog's keys against enUS (the reference) and reports
-- missing/extra keys per catalog. Does not fail the run for missing keys in
-- non-German catalogs (the project intentionally keeps some new keys English-only
-- until translated, falling back gracefully), but always prints the full picture.
-- Usage: lua tools/test_locale_parity.lua   (run from the repository root)

local addonTable = {}
loadfile("ForeverCraft/Locale.lua")("ForeverCraft", addonTable)
loadfile("ForeverCraft/ClientLocales.lua")("ForeverCraft", addonTable)
loadfile("ForeverCraft/OfferLocales.lua")("ForeverCraft", addonTable)

local function keySet(dictionary)
    local keys = {}
    for key, value in pairs(dictionary) do
        if type(value) ~= "table" then keys[key] = true end
    end
    return keys
end

local reference = keySet(addonTable.strings.enUS)
local locales = {}
for name in pairs(addonTable.strings) do locales[#locales + 1] = name end
table.sort(locales)

local worstMissing = 0
for _, name in ipairs(locales) do
    if name ~= "enUS" then
        local keys = keySet(addonTable.strings[name])
        local missing, extra = {}, {}
        for key in pairs(reference) do
            if not keys[key] then missing[#missing + 1] = key end
        end
        for key in pairs(keys) do
            if not reference[key] then extra[#extra + 1] = key end
        end
        table.sort(missing)
        table.sort(extra)
        print(("%s: %d missing, %d extra"):format(name, #missing, #extra))
        if #missing > 0 then print("  missing: " .. table.concat(missing, ", ")) end
        if #extra > 0 then print("  extra:   " .. table.concat(extra, ", ")) end
        if name ~= "enGB" and name ~= "esMX" then worstMissing = math.max(worstMissing, #missing) end
    end
end

print("")
print(("Worst missing-key count among real catalogs (excluding enGB/esMX aliases): %d"):format(worstMissing))
os.exit(0)
