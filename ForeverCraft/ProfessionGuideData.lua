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
