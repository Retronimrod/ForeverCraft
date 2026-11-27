-- Smoke test for OfferUI.lua with a permissive mock of the WoW frame API: builds the offer
-- window, recipe picker and template manager and runs the posting flows. It checks logic and
-- nil errors, not layout or fonts (in-game test still required).
-- Usage: lua tools/test_offer_ui.lua   (from the repository root)
local failures = 0
local function check(name, condition, detail)
    io.write((condition and "ok   " or "FAIL ") .. name .. ((not condition and detail) and (" -- " .. tostring(detail)) or "") .. "\n")
    if not condition then failures = failures + 1 end
end

local timers, sent, popups, menu = {}, {}, {}, nil
local function object()
    local state = { text = "", shown = true, width = 400, height = 300, scripts = {}, checked = false }
    local methods = {
        SetText = function(_, value) state.text = value end, GetText = function() return state.text end,
        GetWidth = function() return state.width end, SetWidth = function(_, v) state.width = v end,
        GetHeight = function() return state.height end, SetHeight = function(_, v) state.height = v end,
        SetSize = function(_, w, h) state.width, state.height = w, h end, GetSize = function() return state.width, state.height end,
        GetStringWidth = function() return #tostring(state.text) * 6 end, GetStringHeight = function() return 14 end,
        SetScript = function(_, name, fn) state.scripts[name] = fn end, HookScript = function(_, name, fn) state.scripts[name] = fn end,
        Show = function(self) state.shown = true; if state.scripts.OnShow then state.scripts.OnShow(self) end end,
        Hide = function() state.shown = false end, SetShown = function(_, v) state.shown = v and true or false end,
        IsShown = function() return state.shown end, IsVisible = function() return state.shown end,
        GetChecked = function() return state.checked end, SetChecked = function(_, v) state.checked = v end,
        CreateTexture = function() return _G.CreateFrame("Texture") end,
        CreateFontString = function() return _G.CreateFrame("FontString") end,
        GetFontString = function(self) state.font = state.font or _G.CreateFrame("FontString"); return state.font end,
        GetParent = function() return state.parent end, HasFocus = function() return false end,
        GetFrameLevel = function() return 5 end, GetFrameStrata = function() return "MEDIUM" end,
        Click = function(self, button) if state.scripts.OnClick then state.scripts.OnClick(self, button or "LeftButton") end end,
        SetupMenu = function() end,
    }
    return setmetatable({ _state = state }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
end
_G.CreateFrame = function(_, name, parent)
    local frame = object()
    frame._state.parent = parent
    if name then _G[name] = frame end
    return frame
end
_G.UIParent = object()
_G.UIParent:SetSize(1920, 1080)
_G.GameTooltip = object()
_G.UISpecialFrames, _G.tinsert = {}, table.insert
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.GetLocale = function() return "deDE" end
_G.InCombatLockdown = function() return false end
_G.UnitName = function() return "Nimri" end
_G.UnitGUID = function() return "Player-1-00ABCDEF" end
_G.GetTime, _G.time = os.clock, os.time
_G.ACCEPT, _G.CANCEL = "OK", "Abbrechen"
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(name, text, _, data) popups[#popups + 1] = { name = name, text = text, data = data } end
_G.SecondsToTime = function(s) return s .. "s" end
_G.GetProfessions = function() return 1, 2, nil, 4 end
local professionData = { [1] = { "Schneiderei", 136249, 239, 300, nil, nil, 197 },
    [2] = { "Verzauberkunst", 136244, 225, 225, nil, nil, 333 }, [4] = { "Angeln", 136245, 150, 300, nil, nil, 356 } }
_G.GetProfessionInfo = function(index) return unpack(professionData[index]) end
local channels = { 1, "Allgemein - Orgrimmar", false, 2, "Handel - Stadt", false }
_G.GetChannelList = function() return unpack(channels) end
_G.IsInGuild = function() return true end
local shift = false
_G.IsShiftKeyDown = function() return shift end
_G.SendChatMessage = function(text, chatType, _, target) sent[#sent + 1] = { text = text, type = chatType, target = target } end
_G.C_Item = { GetItemInfo = function() return nil end }
-- The client only lists recipes and the profession link of the open profession.
local open = 197
local recipesOf = { [197] = { 10, 11, 12 }, [333] = { 20, 21 } }
local recipeInfo = { [10] = { learned = true, name = "Runenstofftasche", icon = 1, categoryID = 1 },
    [11] = { learned = true, name = "Gebundener Umhang", icon = 1, categoryID = 2 }, [12] = { learned = false, name = "Ungelernt" },
    [20] = { learned = true, name = "Waffe - Feurige Waffe", icon = 2, categoryID = 3 },
    [21] = { learned = true, name = "Stiefel - Beweglichkeit", icon = 2, categoryID = 4 } }
local categories = { [1] = "Taschen", [2] = "Umhänge", [3] = "Waffen", [4] = "Stiefel" }
local professionLinks = { [197] = "|cffffd000|Htrade:Player-1:2:197|h[Schneiderei]|h|r",
    [333] = "|cffffd000|Htrade:Player-1:3:333|h[Verzauberkunst]|h|r" }
_G.Professions = { GetProfessionInfo = function()
    return { professionID = open, professionName = open == 197 and "Schneiderei" or "Verzauberkunst" }
end }
_G.C_TradeSkillUI = {
    GetAllRecipeIDs = function() return recipesOf[open] end,
    GetRecipeInfo = function(id) return recipeInfo[id] end,
    GetCategoryInfo = function(id) return { name = categories[id] } end,
    GetRecipeSchematic = function(id) return { outputItemID = (id == 10 and 14046) or (id == 11 and 2000) or nil } end,
    GetRecipeLink = function(id) return id >= 20 and ("|cffffd000|Henchant:%d|h[%s]|h|r"):format(id, recipeInfo[id].name) or nil end,
    GetTradeSkillListLink = function() return professionLinks[open] end,
}
_G.ForeverCraftDB = {}

local addon = { strings = {} }
for _, file in ipairs({ "Locale.lua", "ClientLocales.lua", "Offers.lua", "OfferLocales.lua" }) do
    assert(loadfile("ForeverCraft/" .. file))("ForeverCraft", addon)
end
addon.ui = { colors = { gold = { 1, 1, 1 }, lightGold = { 1, 1, 1 }, green = { 0, 1, 0 }, red = { 1, 0, 0 },
    grey = { .5, .5, .5 }, orange = { 1, .5, 0 } },
    panel = function(parent) return CreateFrame("Frame", nil, parent) end,
    heading = function() return CreateFrame("FontString") end, text = function() return CreateFrame("FontString") end,
    contextMenu = function(_, entries) menu = entries end }
addon.ledger = { dropdown = function()
    local control = CreateFrame("DropdownButton")
    control.Sync = function() end
    return control
end }
addon.languageNames = { deDE = "Deutsch", enUS = "English" }
-- Item status: bag tradeable, cloak bound on pickup.
addon.offers = nil
assert(loadfile("ForeverCraft/Offers.lua"))("ForeverCraft", addon)
local offers = addon.offers
offers.itemStatus = function(id) return id == 14046 and "TRADEABLE" or "NON_TRADEABLE" end
assert(loadfile("ForeverCraft/OfferUI.lua"))("ForeverCraft", addon)
local UI = addon.offerUI

local function runTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end

local ok, err = pcall(function()
    -- Buttons in the crafting log card.
    local column = CreateFrame("Frame")
    addon.AttachOfferButtons(column)
    check("offer buttons attached", UI.postButton ~= nil and UI.configButton ~= nil)
    check("no offer yet: configure first", UI.postState() == "setup"
        and (UI.postButton.sub:GetText() or ""):find("konfigurieren", 1, true) ~= nil, UI.postButton.sub:GetText())
    UI.postButton:Click("LeftButton")
    check("post without offer opens the window", UI.window and UI.window:IsShown())
    UI.window:Hide()
    UI.configButton:Click("LeftButton")
    check("configure opens the window", UI.window:IsShown())
    UI.open()
    check("window opened", UI.window and UI.window:IsShown())
    local config = UI.config()
    check("crafting professions preselected, gathering not", config.professions[197] and config.professions[333] and not config.professions[356])
    local text = UI.window.preview:GetText()
    check("preview generated", text:find("Schneiderei (239/300)", 1, true) ~= nil, text)
    -- Recipes and links are recorded per profession; opening one never replaces the other.
    open = 197
    UI.scanOpenProfession()
    UI.showRecipes()
    local frame = UI.recipeWindow
    local function rowsWith(text)
        local found = {}
        for _, row in ipairs(frame.rows) do
            if row._state.shown and row.entry and ((row.entry.recipe and row.entry.recipe.name == text) or row.entry.hint and row.entry.hint:find(text, 1, true)) then
                found[#found + 1] = row
            end
        end
        return found
    end
    check("enchanting not recorded yet: clear hint", #rowsWith("Verzauberkunst wurden noch nicht erfasst") == 1)
    open = 333
    UI.scanOpenProfession()
    open = 197
    check("tailoring recipes kept after opening enchanting", #(ForeverCraftOffers.recipeData[197].recipes) == 2)
    check("enchanting recipes recorded", #(ForeverCraftOffers.recipeData[333].recipes) == 2)
    check("both profession links recorded", ForeverCraftOffers.links[197] ~= nil and ForeverCraftOffers.links[333] ~= nil)
    UI.refreshRecipes()
    local bag, cloak, enchant = rowsWith("Runenstofftasche")[1], rowsWith("Gebundener Umhang")[1], rowsWith("Waffe - Feurige Waffe")[1]
    check("recipes of both professions listed while tailoring is open", bag and enchant)
    check("unlearned recipe not listed", #rowsWith("Ungelernt") == 0)
    check("bind-on-pickup result not selectable", cloak and cloak.entry.offerable == false)
    check("enchantment without item is a service", enchant and enchant.entry.status == "SERVICE")
    bag.check:SetChecked(true)
    bag.check._state.scripts.OnClick(bag.check)
    enchant = rowsWith("Waffe - Feurige Waffe")[1]
    enchant.check:SetChecked(true)
    enchant.check._state.scripts.OnClick(enchant.check)
    check("selection is a working copy until applied", next(UI.config().recipes) == nil)
    frame.apply:Click()
    local count = 0
    for _ in pairs(UI.config().recipes) do count = count + 1 end
    check("selection from two professions stored in the profile", count == 2)
    UI.showRecipes()
    check("selection restored when reopened", frame.selection[10] ~= nil and frame.selection[20] ~= nil)
    frame:Hide()
    -- Profession links for both professions, independent of the open window.
    ForeverCraftDB.offerProfessionLinks, ForeverCraftDB.offerRecipeLinks = true, true
    UI.regenerate()
    local preview = UI.window.preview:GetText()
    check("both profession links in the message", preview:find(professionLinks[197], 1, true) and preview:find(professionLinks[333], 1, true), preview)
    check("enchant link in the message", preview:find("|Henchant:20|h", 1, true) ~= nil, preview)
    -- Too long with links: a shorter version keeps both professions.
    if #offers.sanitize(preview) > 255 then
        UI.suggestShorter()
        local shorter = UI.window.preview:GetText()
        check("shorter suggestion fits and keeps professions", #shorter <= 255 and shorter:find("Schneiderei", 1, true)
            and shorter:find("Verzauberkunst", 1, true), shorter)
    end
    ForeverCraftDB.offerProfessionLinks, ForeverCraftDB.offerRecipeLinks = nil, nil
    UI.config().recipes = {}
    UI.regenerate()
    -- Post: confirmation popup, then accept.
    ForeverCraftDB.offerConfirmSend = true
    UI.window.post:Click()
    check("confirmation shown before sending", #popups == 1 and #sent == 0)
    StaticPopupDialogs.FOREVERCRAFT_OFFER_CONFIRM.OnAccept(nil, popups[1].data)
    check("sent to trade channel by name", #sent == 1 and sent[1].type == "CHANNEL" and sent[1].target == 2)
    -- Echo confirms the post: links re-encoded by the server, sender name in another spelling,
    -- recognised by GUID.
    local echo = sent[1].text
    check("message within limit", #echo <= 255)
    local echoed = echo:gsub("|H(.-)|h", "|H%1:server|h")
    _G.ForeverCraftOfferEcho._state.scripts.OnEvent(nil, "CHAT_MSG_CHANNEL", echoed, "Sonarok Nimrison-Realm",
        nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-00ABCDEF")
    check("own echo confirms the post", (UI.window.status:GetText() or ""):find("im Chat erschienen", 1, true) ~= nil
        and not (UI.window.status:GetText() or ""):find("nicht", 1, true), UI.window.status:GetText())
    -- Clicking again within the cooldown does not send.
    UI.window.post:Click()
    check("cooldown blocks double posts", #sent == 1)
    ForeverCraftOffers.lastPost = time() - 1000
    -- Trade channel number changes: still found by name.
    channels = { 1, "Allgemein - Orgrimmar", false, 4, "Handel - Stadt", false }
    ForeverCraftDB.offerConfirmSend = false
    UI.window.post:Click()
    check("trade found after channel number change", #sent == 2 and sent[2].target == 4)
    -- Outside a city: no trade channel, nothing is sent elsewhere.
    ForeverCraftOffers.lastPost = time() - 1000
    channels = { 1, "Allgemein - Durotar", false }
    UI.window.post:Click()
    check("no trade chat: nothing sent", #sent == 2)
    check("clear message about trade chat", (UI.window.status:GetText() or ""):find("Handelschat", 1, true) ~= nil,
        UI.window.status:GetText())
    -- Too long messages are blocked.
    channels = { 2, "Handel - Stadt", false }
    UI.window.preview:SetText(string.rep("x", 300))
    UI.updateLength()
    UI.window.post:Click()
    check("too long message blocked", #sent == 2)
    -- Long offer: two messages in the same click, confirmed only after both echoes.
    ForeverCraftOffers.lastPost = time() - 1000
    local first = "Hey zusammen! Biete Schneiderei und Verzauberkunst gegen eure Mats an. " .. string.rep("Lange Zusatzinfo dazu. ", 7)
    local second = string.rep("Noch mehr Details hier. ", 6) .. "Bei Interesse einfach anwhispern!"
    UI.window.preview:SetText(first .. second)
    UI.updateLength()
    local before = #sent
    UI.window.post:Click()
    check("long offer sent as two messages in one click", #sent == before + 2 and #sent[before + 1].text <= 255
        and #sent[before + 2].text <= 255)
    local echoOne, echoTwo = sent[before + 1].text, sent[before + 2].text
    _G.ForeverCraftOfferEcho._state.scripts.OnEvent(nil, "CHAT_MSG_CHANNEL", echoOne, "Nimri",
        nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-00ABCDEF")
    check("not confirmed after the first part", not (UI.window.status:GetText() or ""):find("im Chat erschienen", 1, true)
        or (UI.window.status:GetText() or ""):find("nicht", 1, true))
    _G.ForeverCraftOfferEcho._state.scripts.OnEvent(nil, "CHAT_MSG_CHANNEL", echoTwo, "Nimri",
        nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-00ABCDEF")
    check("confirmed after both parts", (UI.window.status:GetText() or ""):find("im Chat erschienen", 1, true) ~= nil
        and not (UI.window.status:GetText() or ""):find("nicht", 1, true), UI.window.status:GetText())
    ForeverCraftOffers.lastPost = time() - 1000
    -- "Offer crafting" posts the saved offer with one click; then the cooldown shows.
    UI.regenerate()
    UI.confirmedAt = nil -- the "posted" hint of the earlier test post has expired
    UI.refreshPanel()
    check("ready state", UI.postState() == "ready" and (UI.postButton.sub:GetText() or ""):find("Handelschat", 1, true) ~= nil,
        UI.postState() .. " " .. tostring(UI.postButton.sub:GetText()))
    local quickBefore = #sent
    UI.postButton:Click("LeftButton")
    check("one click posts the saved offer", #sent > quickBefore, #sent - quickBefore)
    UI.confirmedAt = nil
    UI.refreshPanel()
    check("cooldown shown", UI.postState() == "wait" and (UI.postButton.sub:GetText() or ""):find("Erneut verfügbar in 0", 1, true) ~= nil,
        UI.postButton.sub:GetText())
    UI.confirmedAt = nil
    local afterPost = #sent
    UI.postButton:Click("LeftButton")
    check("no second post during the cooldown", #sent == afterPost)
    ForeverCraftOffers.lastPost = time() - 1000
    channels = { 1, "Allgemein - Durotar", false }
    UI.refreshPanel()
    check("no trade chat shown", UI.postState() == "nochannel"
        and (UI.postButton.sub:GetText() or ""):find("Handelschat", 1, true) ~= nil, UI.postButton.sub:GetText())
    channels = { 2, "Handel - Stadt", false }
    -- Right-click menu: configure, profiles, preview, post.
    UI.postButton:Click("RightButton")
    check("context menu with profiles, preview and post", menu and #menu >= 4)
    -- Own templates.
    UI.showTemplates()
    _G.ForeverCraftOfferTemplates.newButton:Click()
    local template = ForeverCraftDB.offerTemplates[1]
    check("own template created", template ~= nil)
    template.text = "Biete {berufe_skill}! {rezepte} {charakter}"
    UI.config().template = "custom:" .. template.id
    UI.regenerate()
    check("own template used without raw placeholders", not UI.window.preview:GetText():find("{", 1, true),
        UI.window.preview:GetText())
    -- Profiles.
    StaticPopupDialogs.FOREVERCRAFT_OFFER_PROFILE_NAME.OnAccept({ editBox = { GetText = function() return "Schneider" end } })
    check("profile created and active", ForeverCraftOffers.active == "Schneider")
    runTimers()
end)
if not ok then
    failures = failures + 1
    io.write("FAIL runtime error: " .. tostring(err) .. "\n")
end
io.write((failures == 0 and "ALL OK" or (failures .. " FAILED")) .. "\n")
os.exit(failures == 0 and 0 or 1)
