local _, addon = ...

-- Training locations for WoW Forever. Skill requirements are for learning
-- the rank; the ranges describe progression after learning it.
addon.professionGuides = {
    [197] = {
        ranks = {
            { minimum = 1, cap = 75, trainers = 1 },
            { minimum = 76, cap = 150, requiresSkill = 50, requiresLevel = 10, trainers = 1 },
            { minimum = 151, cap = 225, requiresSkill = 125, requiresLevel = 20, trainers = 2 },
            { minimum = 226, cap = 300, requiresSkill = 200, requiresLevel = 35, trainers = 3 },
        },
        trainers = {
            {
                Horde = {
                    { "Snang", "Orgrimmar", "Orgrimmar", "62.9, 49.4" },
                    { "Victor Ward", "Undercity", "Unterstadt", "70.4, 29.7" },
                    { "Vhan", "Thunder Bluff", "Donnerfels", "44.1, 45.1" },
                },
                Alliance = {
                    { "Lawrence Schneider", "Stormwind", "Sturmwind" },
                    { "Uthrar Threx", "Ironforge", "Eisenschmiede", "43.8, 28.0" },
                    { "Trianna", "Darnassus", "Darnassus", "63.6, 21.2" },
                },
            },
            {
                Horde = { { "Josef Gregorian", "Undercity (Magic Quarter)", "Unterstadt (Magieviertel)", "70.6, 30.6" } },
                Alliance = { { "Georgio Bolero", "Stormwind (Mage Quarter)", "Sturmwind (Magieviertel)" } },
            },
            {
                Horde = { { "Daryl Stack", "Tarren Mill, Hillsbrad Foothills", "Tarrens Mühle, Vorgebirge des Hügellands", "63.6, 20.8" } },
                Alliance = { { "Timothy Worthington", "Theramore, Dustwallow Marsh", "Theramore, Marschen von Dustwallow", "66.2, 51.6" } },
            },
        },
    },
}

local guides = addon.professionGuides

local function addGuide(id, english, german, sources, gathering)
    local ranks = {}
    for index, cap in ipairs({ 75, 150, 225, 300 }) do
        local source = sources[index]
        ranks[index] = {
            minimum = cap - 74,
            cap = cap,
            requiresSkill = source.skill or ({ nil, 50, 125, 200 })[index],
            requiresLevel = not gathering and (({ nil, 10, 20, 35 })[index]) or nil,
            source = source,
        }
        if source.item and source.level == false then ranks[index].requiresLevel = nil end
    end
    guides[id] = { ranks = ranks, names = { english, german } }
end

local function factions(horde, alliance)
    return { Horde = { horde }, Alliance = { alliance } }
end

local function shared(npc)
    return { Neutral = { npc } }
end

local function city(name, en, de, coordinates)
    return { name, en, de, coordinates }
end

local function orgrimmar(name, coordinates) return city(name, "Orgrimmar", "Orgrimmar", coordinates) end
local function stormwind(name, coordinates) return city(name, "Stormwind", "Sturmwind", coordinates) end
local function ironforge(name, coordinates) return city(name, "Ironforge", "Eisenschmiede", coordinates) end
local function undercity(name, coordinates) return city(name, "Undercity", "Unterstadt", coordinates) end

guides[197].names = { "Tailoring", "Schneiderei" }

local alchemy = factions(orgrimmar("Yelmak", "56.8, 33.0"), stormwind("Lilyssia Nightbreeze", "55.6, 85.9"))
addGuide(171, "Alchemy", "Alchemie", {
    alchemy, alchemy,
    factions(undercity("Doctor Herbert Halsey", "47.8, 73.3"), city("Ainethil", "Darnassus", "Darnassus", "54.9, 24.0")),
    factions(city("Rogvar", "Stonard, Swamp of Sorrows", "Steinard, Sümpfe des Elends", "48.5, 55.9"),
        city("Kylanna Windwhisper", "Feathermoon Stronghold, Feralas", "Mondfederfeste, Feralas", "32.6, 43.8")),
})

local smithing = factions(orgrimmar("Saru Steelfury"), stormwind("Therum Deepforge"))
addGuide(164, "Blacksmithing", "Schmiedekunst", {
    smithing, smithing,
    factions(orgrimmar("Saru Steelfury"), ironforge("Bengus Deepforge")),
    shared(city("Brikk Keencraft", "Booty Bay, Stranglethorn Vale", "Beutebucht, Schlingendorntal")),
})

addGuide(333, "Enchanting", "Verzauberkunst", {
    factions(orgrimmar("Jhag", "53.5, 38.4"), stormwind("Betty Quin")),
    factions(orgrimmar("Godan"), stormwind("Lucan Cordell")),
    factions(city("Hgarth", "Sun Rock Retreat, Stonetalon Mountains", "Sonnenfels, Steinkrallengebirge"),
        city("Kitta Firewind", "Tower of Azora, Elwynn Forest", "Turm von Azora, Wald von Elwynn", "64.9, 70.6")),
    shared(city("Annora", "Uldaman, inside the dungeon", "Uldaman, in der Instanz")),
})
guides[333].ranks[4].source.note = {
    "The back entrance is in the Badlands (65.3, 42.6). Clear the scorpions in her room.",
    "Der Hintereingang liegt im Ödland (65.3, 42.6). Besiege die Skorpione in ihrem Raum.",
}

local engineering = factions(orgrimmar("Nogg"), stormwind("Lilliam Sparkspindle"))
addGuide(202, "Engineering", "Ingenieurskunst", {
    engineering, engineering,
    factions(orgrimmar("Roxxik", "76.2, 25.2"), ironforge("Springspindle Fizzlegear", "68.5, 43.5")),
    shared(city("Buzzek Bracketswing", "Gadgetzan, Tanaris", "Gadgetzan, Tanaris", "52.3, 27.7")),
})

local leatherworking = factions(orgrimmar("Karolek", "62.8, 44.1"), stormwind("Simon Tanner", "71.7, 63.0"))
addGuide(165, "Leatherworking", "Lederverarbeitung", {
    leatherworking, leatherworking,
    factions(city("Una", "Thunder Bluff", "Donnerfels", "41.5, 42.6"), city("Telonis", "Darnassus", "Darnassus", "64.4, 21.5")),
    factions(city("Hahrana Ironhide", "Camp Mojache, Feralas", "Camp Mojache, Feralas", "74.4, 43.1"),
        city("Drakk Stonehand", "Aerie Peak, The Hinterlands", "Nistgipfel, Hinterland", "13.4, 43.5")),
})

local herbalism = factions(orgrimmar("Jandi"), stormwind("Tannysa"))
addGuide(182, "Herbalism", "Kräuterkunde", { herbalism, herbalism, herbalism, herbalism }, true)
local mining = factions(orgrimmar("Makaru", "73.0, 26.4"), stormwind("Gelman Stonehand"))
addGuide(186, "Mining", "Bergbau", { mining, mining, mining, mining }, true)
local skinning = factions(city("Mooranta", "Thunder Bluff", "Donnerfels"), ironforge("Balthus Stoneflayer", "39.7, 32.3"))
addGuide(393, "Skinning", "Kürschnerei", { skinning, skinning, skinning, skinning }, true)

local cooking = factions(orgrimmar("Zamja", "57.4, 54.0"), stormwind("Stephen Ryback"))
local cookbook = factions(city("Wulan", "Shadowprey Village, Desolace", "Schattenflucht, Desolace", "26.2, 69.6"),
    city("Shandrina", "Silverwind Refuge, Ashenvale", "Silberwindzuflucht, Eschental", "49.6, 67.1"))
cookbook.item = { "Expert Cookbook", "Expertenkochbuch" }
cookbook.level = false
local cookingQuest = shared(city("Dirge Quikcleave", "Gadgetzan, Tanaris", "Gadgetzan, Tanaris", "52.6, 28.1"))
cookingQuest.quest = { "Clamlette Surprise", "Muschelette Surprise" }
cookingQuest.skill = 225
cookingQuest.note = {
    "Bring 12 Giant Eggs, 10 Zesty Clam Meat and 20 Alterac Swiss.",
    "Bring 12 Rieseneier, 10 scharfes Muschelfleisch und 20 Alterac-Lochkäse mit.",
}
addGuide(185, "Cooking", "Kochkunst", { cooking, cooking, cookbook, cookingQuest })

local fishing = factions(orgrimmar("Lumak", "69.8, 29.6"), stormwind("Arnold Leland"))
local fishingBook = shared(city("Old Man Heming", "Booty Bay, Stranglethorn Vale", "Beutebucht, Schlingendorntal", "27.4, 77.0"))
fishingBook.item = { "Expert Fishing – The Bass and You", "Expertenangeln – Der Barsch und du" }
local fishingQuest = shared(city("Nat Pagle", "Southwest of Theramore, Dustwallow Marsh",
    "Südwestlich von Theramore, Marschen von Dustwallow", "58.6, 60.0"))
fishingQuest.quest = { "Nat Pagle, Angler Extreme", "Nat Pagle, Extremangler" }
fishingQuest.skill = 225
fishingQuest.note = {
    "Catch a quest fish in each of these areas: Verdantis River (Feralas), Misty Reed Strand (Swamp of Sorrows), Sar'theris Strand (Desolace) and the Savage Coast (Stranglethorn Vale).",
    "Fange je einen Questfisch am Fluss Verdantis (Feralas), an der Nebelschilfküste (Sümpfe des Elends), am Sar'therisstrand (Desolace) und an der Ungezähmten Küste (Schlingendorntal).",
}
addGuide(356, "Fishing", "Angeln", { fishing, fishing, fishingBook, fishingQuest })

local firstAid = factions(orgrimmar("Arnok", "34.0, 84.4"), stormwind("Shaina Fuller"))
local aidBook = factions(city("Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh",
    "Brackenwall, Marschen von Dustwallow", "36.4, 30.4"),
    city("Deneb Walker", "Stromgarde Keep, Arathi Highlands", "Burg Stromgarde, Arathihochland", "27.0, 58.8"))
aidBook.item = { "Expert First Aid – Under Wraps", "Erste Hilfe für Experten – Verbinden, aber richtig" }
aidBook.level = false
local aidQuest = factions(city("Doctor Gregory Victor", "Hammerfall, Arathi Highlands", "Hammerfall, Arathihochland", "73.4, 36.8"),
    city("Doctor Gustaf VanHowzen", "Theramore, Dustwallow Marsh", "Theramore, Marschen von Dustwallow", "67.6, 48.8"))
aidQuest.quest = { "Triage", "Triage" }
aidQuest.skill = 225
aidQuest.note = {
    "Treat the wounded with the quest bandages. Prioritize the critically injured.",
    "Versorge die Verwundeten mit den Questverbänden. Behandle die Schwerstverletzten zuerst.",
}
addGuide(129, "First Aid", "Erste Hilfe", { firstAid, firstAid, aidBook, aidQuest })
