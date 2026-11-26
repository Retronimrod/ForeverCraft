-- Regression test for the planning-list quantity bug (see CHANGELOG/ROADMAP).
-- Runs the real addon.AddShoppingRecipe / addon.CompletePlannedCraft / addon.GetPlanRows
-- functions from ForeverCraft/Materials.lua against a minimal stub of the WoW API,
-- so the actual state machine is exercised, not a re-implementation of it.
-- Usage: lua tools/test_materials.lua   (run from the repository root)

local RECIPE_ID = 12345
local OUTPUT_ITEM_ID = 2000
local REAGENT_ITEM_ID = 1000
local REAGENT_PER_CRAFT = 2

Enum = { CraftingReagentType = { Basic = 1 } }

local schematic = {
    name = "Test Recipe",
    outputItemID = OUTPUT_ITEM_ID,
    quantityMin = 1,
    reagentSlotSchematics = {
        {
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = REAGENT_PER_CRAFT,
            reagents = { { itemID = REAGENT_ITEM_ID } },
        },
    },
}

C_TradeSkillUI = {
    GetRecipeSchematic = function(id) return id == RECIPE_ID and schematic or nil end,
    GetAllRecipeIDs = function() return { RECIPE_ID } end,
    GetRecipeInfo = function(id) return id == RECIPE_ID and { learned = true, isRecraft = false, name = "Test Recipe" } or nil end,
    GetProfessionInfoByRecipeID = function() return nil end,
    GetProfessionInfoBySkillLineID = function() return nil end,
}
C_Item = {
    GetItemNameByID = function() return nil end,
    RequestLoadItemDataByID = function() end,
    GetItemCount = function() return 0 end,
}
C_Spell = { GetSpellName = function() return nil end }

local addonTable = {}
local chunk = assert(loadfile("ForeverCraft/Materials.lua"))
chunk("ForeverCraft", addonTable)

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    else
        print(("ok   %s = %s"):format(label, tostring(got)))
    end
end

local function openCount(plan, recipeID)
    local entry = plan[recipeID]
    if not entry then return 0 end
    return entry.target - entry.done
end

local function craftOnce(plan)
    return addonTable.CompletePlannedCraft(plan, RECIPE_ID)
end

print("-- Case: plan 1, craft it, re-plan 1 (bug scenario) --")
local plan = {}
addonTable.AddShoppingRecipe(plan, RECIPE_ID, 1)
check("plan 1 -> open", openCount(plan, RECIPE_ID), 1)
craftOnce(plan)
check("after crafting 1, entry removed", plan[RECIPE_ID], nil)
addonTable.AddShoppingRecipe(plan, RECIPE_ID, 1)
check("re-plan 1 -> open", openCount(plan, RECIPE_ID), 1)

print("-- Case: finish again, re-plan 2 --")
craftOnce(plan)
check("after crafting again, entry removed", plan[RECIPE_ID], nil)
addonTable.AddShoppingRecipe(plan, RECIPE_ID, 2)
check("re-plan 2 -> open", openCount(plan, RECIPE_ID), 2)

print("-- Case: 5 planen, 2 herstellen -> 3 offen --")
plan = {}
addonTable.AddShoppingRecipe(plan, RECIPE_ID, 5)
craftOnce(plan)
craftOnce(plan)
check("5 planned, 2 crafted -> open", openCount(plan, RECIPE_ID), 3)

print("-- Case: 3 offen, UI 'weitere 2 hinzufuegen' -> 5 offen --")
-- Mirrors Core.lua's createPlannedJobRow save(): SetPlanTarget(entry, entry.done + amount)
-- where amount is the *new remaining* quantity entered in the shopping-list editbox.
local entry = plan[RECIPE_ID]
addonTable.SetPlanTarget(entry, entry.done + 5)
check("3 open + 2 added -> open", openCount(plan, RECIPE_ID), 5)

print("-- Case: craft remaining 5, then fully done --")
for _ = 1, 5 do craftOnce(plan) end
check("fully completed -> entry removed", plan[RECIPE_ID], nil)

print("-- Case: CleanupFinishedPlans migrates stale finished entries --")
plan = { [RECIPE_ID] = { target = 1, done = 1, items = {}, perCraft = { [REAGENT_ITEM_ID] = REAGENT_PER_CRAFT } } }
local removed = addonTable.CleanupFinishedPlans(plan)
check("stale finished entry removed", removed, 1)
check("plan now empty", plan[RECIPE_ID], nil)

print("-- Case: CleanupFinishedPlans leaves open entries alone --")
plan = { [RECIPE_ID] = { target = 5, done = 2, items = { [REAGENT_ITEM_ID] = 6 }, perCraft = { [REAGENT_ITEM_ID] = REAGENT_PER_CRAFT } } }
removed = addonTable.CleanupFinishedPlans(plan)
check("open entry not removed", removed, 0)
check("open entry still present", plan[RECIPE_ID] ~= nil, true)

print("")
if failures == 0 then
    print("ALL OK")
    os.exit(0)
else
    print(failures .. " FAILURE(S)")
    os.exit(1)
end
