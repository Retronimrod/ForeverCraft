-- Regression tests for Offers.lua (message building, placeholders, channels, cooldown).
-- Usage: lua tools/test_offers.lua   (from the repository root)
local failures = 0
local function check(name, condition, detail)
    print((condition and "ok   " or "FAIL ") .. name .. ((not condition and detail) and ("\n     " .. detail) or ""))
    if not condition then failures = failures + 1 end
end

local addon = {}
assert(loadfile("ForeverCraft/Offers.lua"))("ForeverCraft", addon)
local offers = addon.offers

local tailoring = { id = 197, name = "Schneiderei", skill = 239, max = 300 }
local enchanting = { id = 333, name = "Verzauberkunst", skill = 225, max = 225 }
local options = { showSkill = true, showMax = true, showConditions = true, askWhisper = true, highlightRecipes = true }
local function build(config, data)
    data = data or {}
    data.clientLocale = data.clientLocale or "deDE"
    data.character = "Nimri"
    config.options = config.options or options
    return offers.build(config, data)
end

local text = build({ condition = "matsTip", template = "casual" }, { professions = { tailoring, enchanting } })
check("two professions, voluntary tip (German)", text ==
    "Hey zusammen! Biete Schneiderei (239/300) und Verzauberkunst (225/225) gegen eure Mats an. Über ein kleines Trinkgeld freue ich mich natürlich. Bei Interesse einfach anwhispern!", text)

text = build({ condition = "matsFixed", fee = 25000, feeMode = "each", template = "casual" }, { professions = { tailoring } })
check("fixed fee per craft", text:find("gegen eure Mats und 2g 50s pro Herstellung an.", 1, true) ~= nil, text)

text = build({ condition = "mats", template = "short", perProfession = true, conditions = { [333] = "free" } },
    { professions = { tailoring, enchanting } })
check("different conditions per profession, no duplicated greeting", text ==
    "Biete Schneiderei (239/300) gegen Mats. Außerdem Verzauberkunst (225/225) kostenlos gegen Mats. Bei Interesse whispern!", text)

text = build({ condition = "leveling", template = "casual", options = { showConditions = true, askWhisper = false } },
    { professions = { tailoring } })
check("leveling template without skill and whisper", text ==
    "Levele gerade Schneiderei. Falls jemand etwas braucht, crafte ich gerne kostenlos gegen eure Mats!", text)

text = build({ condition = "ownMats", template = "casual" }, { professions = { tailoring } })
check("own mats asks for contact once", select(2, text:gsub("anwhispern", "")) == 0 and text:find("Schreibt mir", 1, true) ~= nil, text)

text = build({ condition = "matsTip", template = "casual" },
    { recipes = { { name = "Runenstofftasche" }, { name = "Mondstofftasche" } } })
check("only recipes take the place of professions", text:find("Biete Runenstofftasche und Mondstofftasche gegen eure Mats an.", 1, true) ~= nil, text)

local link = "|cff1eff00|Hitem:14046::::::::60:::::|h[Runenstofftasche]|h|r"
text = build({ condition = "mats", template = "casual", options = { showConditions = true, recipeLinks = true, highlightRecipes = true } },
    { professions = { tailoring }, recipes = { { name = "Runenstofftasche", link = link } } })
check("recipe link stays intact", text:find(link, 1, true) ~= nil, text)

text = build({ condition = "matsTip", template = "casual", language = "enUS" }, { professions = { tailoring } })
check("English message from a German client", text ==
    "Hey all! Offering Tailoring (239/300) with your mats. Tips are appreciated but not required. Just whisper me!", text)

for _, language in ipairs({ "frFR", "esES", "ptBR", "ruRU", "koKR", "zhTW" }) do
    for _, condition in ipairs(offers.conditions) do
        for _, template in ipairs(offers.templates) do
            text = build({ condition = condition, template = template, language = language, fee = 15000, customText = "x" },
                { professions = { tailoring, enchanting }, recipes = { { name = "R" } } })
            if text:find("{", 1, true) or text == "" or (#text > 255 and language ~= "ruRU") then
                check(("%s %s %s"):format(language, condition, template), false, text)
            end
        end
    end
end
check("all languages, conditions and templates produce complete text", true)

-- Own templates: placeholders replaced, lines with empty placeholders dropped, unknown removed.
local custom = "Hey Leute! Biete {berufe_skill} gegen eure Mats an.\n{rezepte} kann ich ebenfalls herstellen.\nÜber ein kleines Trinkgeld freue ich mich. {unbekannt}\nBei Interesse einfach anwhispern!"
text = build({ condition = "mats", template = "custom:1" }, { professions = { tailoring }, customTemplate = custom })
check("custom template without recipes drops the recipe line", text ==
    "Hey Leute! Biete Schneiderei (239/300) gegen eure Mats an. Über ein kleines Trinkgeld freue ich mich. Bei Interesse einfach anwhispern!", text)
text = build({ condition = "matsFixed", fee = 10000, template = "custom:1" },
    { professions = { tailoring }, recipes = { { name = "Tasche" } }, customTemplate = "{charakter}: {berufe} – {verguetung}. {rezepte}!" })
check("custom template with character, fee and recipes", text == "Nimri: Schneiderei – 1g pro Herstellung. Tasche!", text)
check("no raw placeholder ever remains", not text:find("{", 1, true))

-- Visible vs technical length: link codes count for the limit, readers only see [Name].
local linked = "Biete " .. link .. " an."
check("visible text shows the link name", offers.visibleText(linked) == "Biete [Runenstofftasche] an.")
check("visible length counts characters", offers.visibleLength("Stärke") == 6)
check("technical length counts the whole link code", offers.length(linked) > offers.visibleLength(offers.visibleText(linked)) + 30)

-- Echo check: the server returns links with a different link code but the same names.
local sentText = "Biete |cffffd000|Htrade:Player-1:2:197|h[Schneiderei]|h|r an."
local echoText = "Biete |cffffd000|Htrade:Player-4711-0ABC:2:197:239:300|h[Schneiderei]|h|r  an."
check("echo with different link code is recognised", offers.echoKey(sentText) == offers.echoKey(echoText))
check("different message is not taken as echo", offers.echoKey(sentText) ~= offers.echoKey("ist nur ein test"))
check("echo with other case and colour codes is recognised",
    offers.echoKey(sentText) == offers.echoKey("biete |cff00ff00|Htrade:x|h[schneiderei]|h|r AN."))

-- Shorter suggestion: professions stay, links are never cut.
local many = {}
for index = 1, 6 do many[index] = { name = "Rezept " .. index, link = link:gsub("Runenstofftasche", "Rezept " .. index) } end
local longConfig = { condition = "matsTip", template = "casual", options = { showSkill = true, showMax = true,
    recipeLinks = true, highlightRecipes = true, showConditions = true, askWhisper = true } }
local longData = { professions = { tailoring, enchanting }, recipes = many, clientLocale = "deDE" }
check("long message is over the limit", #offers.build(longConfig, longData) > 255)
local shorter, steps = offers.shorten(longConfig, longData)
check("shorter version fits", shorter ~= nil and #shorter <= 255, shorter)
check("shorter version keeps every profession", shorter and shorter:find("Schneiderei", 1, true) and shorter:find("Verzauberkunst", 1, true))
check("shorter version replaced links before dropping content", #steps >= 1)
check("no half link remains", not (shorter or ""):find("|H", 1, true) or select(2, shorter:gsub("|H", "")) == select(2, shorter:gsub("|h|r", "")))
check("original configuration untouched", longConfig.options.recipeLinks == true and longConfig.template == "casual")

-- Two messages: split between sentences, links stay whole, never more than two parts.
local splitData = { professions = longData.professions, recipes = { many[1], many[2], many[3] }, clientLocale = "deDE" }
local longText = offers.build(longConfig, splitData)
check("split sample is over the limit", offers.length(longText) > 255)
local parts = offers.split(longText)
check("long offer split into two messages", parts and #parts == 2, longText)
check("each part fits the limit", parts and #parts[1] <= 255 and #parts[2] <= 255)
check("parts together are the whole message", parts and (parts[1] .. " " .. parts[2]) == offers.sanitize(longText))
check("first part ends a sentence", parts and offers.visibleText(parts[1]):match("[%.!%?]$") ~= nil, parts and parts[1])
local function wholeLinks(text) return select(2, text:gsub("|H", "")) == select(2, text:gsub("|h|r", "")) end
check("no link is cut", parts and wholeLinks(parts[1]) and wholeLinks(parts[2]))
check("short message stays one part", #offers.split("Biete Schneiderei.") == 1)
check("more than two messages are refused", offers.split(string.rep("Satz mit etwas Text. ", 40)) == nil)
check("one endless word cannot be split", offers.split(string.rep("x", 300)) == nil)


-- Chat safety and length.
check("stray escape characters removed", offers.sanitize("a|b||c\nd") == "abc d")
check("length in bytes", offers.length("äb") == 3)

-- Channels by name, never by number.
local list = { { id = 1, name = "Allgemein - Orgrimmar" }, { id = 2, name = "Handel - Stadt" }, { id = 5, name = "MeinKanal" } }
check("trade found by name", offers.findChannel("trade", list).id == 2)
list[2].id = 4
check("trade found when the number changes", offers.findChannel("trade", list).id == 4)
check("general found", offers.findChannel("general", list).id == 1)
check("custom channel by name", offers.findChannel("name:MeinKanal", list).id == 5)
check("trade missing outside cities", offers.findChannel("trade", { { id = 1, name = "General - Durotar" } }) == nil)

-- Cooldown.
check("cooldown remaining", offers.remaining(100, 120, 150) == 70)
check("cooldown over", offers.remaining(100, 120, 300) == 0)

-- Services and money.
check("enchanting without item is a service", offers.recipeStatus(nil, 333) == "SERVICE")
check("other recipe without item is unknown", offers.recipeStatus(nil, 197) == "UNKNOWN")
check("copper", offers.copper(2, 50, 3) == 25003)
check("money text per language", offers.moneyText(25003, "frFR") == "2po 50pa 3pc")

print(failures == 0 and "\nALL OK" or ("\n" .. failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
