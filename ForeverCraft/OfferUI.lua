local _, addon = ...
-- "Offer crafting": button in the professions window, offer window, recipe picker, own
-- templates, profiles and posting. Every post comes from a click (button, confirmation or
-- Shift-click); nothing is ever sent on a timer, on login or when entering a city.
local offers, ui = addon.offers, addon.ui
local UI = { state = {} }
addon.offerUI = UI

local COINS = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local OPTION_KEYS = { "showSkill", "showMax", "professionLinks", "recipeLinks", "highlightRecipes", "showConditions", "askWhisper" }
local OPTION_DB = { showSkill = "offerShowSkill", showMax = "offerShowMax", professionLinks = "offerProfessionLinks",
    recipeLinks = "offerRecipeLinks", highlightRecipes = "offerHighlightRecipes", showConditions = "offerShowConditions",
    askWhisper = "offerAskWhisper" }
local DEFAULT_OFF = { offerProfessionLinks = true, offerQuickPost = true }

local function L() return addon.GetText() end
local function t(key)
    local value = L()[key] or addon.strings.enUS[key]
    return value or key
end

function UI.option(key)
    local value = ForeverCraftDB and ForeverCraftDB[key]
    if value == nil then return not DEFAULT_OFF[key] end
    return value
end

-- Saved data -------------------------------------------------------------------------------------
local function store()
    ForeverCraftOffers = type(ForeverCraftOffers) == "table" and ForeverCraftOffers or {}
    ForeverCraftOffers.profiles = ForeverCraftOffers.profiles or {}
    return ForeverCraftOffers
end

local function templates()
    ForeverCraftDB.offerTemplates = ForeverCraftDB.offerTemplates or {}
    return ForeverCraftDB.offerTemplates
end

-- Learned professions of this character (GetProfessions/GetProfessionInfo).
function UI.professions()
    local list = {}
    for _, index in pairs({ GetProfessions() }) do
        local name, icon, rank, maximum, _, _, skillLine = GetProfessionInfo(index)
        if name and skillLine then
            list[#list + 1] = { id = skillLine, name = name, icon = icon, skill = rank, max = maximum,
                gathering = offers.gathering[skillLine] == true }
        end
    end
    table.sort(list, function(a, b)
        if a.gathering ~= b.gathering then return not a.gathering end
        return a.name < b.name
    end)
    return list
end

local function newConfig()
    local config = { professions = {}, perProfession = false, conditions = {}, recipes = {}, fee = 0, feeMode = "each",
        customText = "", condition = ForeverCraftDB.offerCondition or "matsTip", template = ForeverCraftDB.offerTemplate or "casual",
        language = ForeverCraftDB.offerLanguage or "auto", channel = ForeverCraftDB.offerChannel or "trade" }
    for _, profession in ipairs(UI.professions()) do
        if not profession.gathering then config.professions[profession.id] = true end
    end
    return config
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

-- The working configuration of the window (the active profile, edited in place).
function UI.config()
    local data = store()
    if not data.active or not data.profiles[data.active] then
        data.active = t("offerProfileDefault")
        data.profiles[data.active] = data.profiles[data.active] or newConfig()
    end
    return data.profiles[data.active]
end

local function options()
    local result = {}
    for _, key in ipairs(OPTION_KEYS) do result[key] = UI.option(OPTION_DB[key]) end
    return result
end

-- Profession link recorded when that profession was last opened (UI.scanOpenProfession).
local function professionLink(id)
    local links = store().links
    return links and links[id] or nil
end

function UI.messageData(config)
    config = config or UI.config()
    local selected = {}
    for _, profession in ipairs(UI.professions()) do
        if config.professions[profession.id] then
            profession.link = professionLink(profession.id)
            selected[#selected + 1] = profession
        end
    end
    local recipes = {}
    for _, recipe in pairs(config.recipes) do
        recipes[#recipes + 1] = { name = recipe.name, link = UI.recipeLink(recipe) or recipe.link }
    end
    table.sort(recipes, function(a, b) return a.name < b.name end)
    local custom
    local id = config.template and config.template:match("^custom:(.+)$")
    if id then
        for _, template in ipairs(templates()) do
            if template.id == id then custom = template.text end
        end
        if not custom then config.template = "casual" end
    end
    local build = { condition = config.condition, perProfession = config.perProfession, conditions = config.conditions,
        fee = config.fee, feeMode = config.feeMode, customText = config.customText, template = config.template,
        language = config.language, options = options() }
    local data = { professions = selected, recipes = recipes, character = UnitName("player"),
        clientLocale = GetLocale(), customTemplate = custom }
    return data, build
end

function UI.message(config)
    local data, build = UI.messageData(config)
    return offers.build(build, data)
end

-- Channels and posting --------------------------------------------------------------------------
local function channelList()
    local list, raw = {}, { GetChannelList() }
    for index = 1, #raw, 3 do
        list[#list + 1] = { id = raw[index], name = raw[index + 1], disabled = raw[index + 2] }
    end
    return list
end

function UI.channelOptions()
    local list = { { "trade", t("channel_trade") }, { "guild", t("channel_guild") }, { "general", t("channel_general") } }
    for _, channel in ipairs(channelList()) do
        if not offers.isTradeChannel(channel.name) and not offers.isGeneralChannel(channel.name) then
            list[#list + 1] = { "name:" .. channel.name, channel.name }
        end
    end
    return list
end

-- Resolves the chosen channel; returns chatType, target, label or nil plus a reason.
function UI.resolveChannel(kind)
    if kind == "guild" then
        if not IsInGuild() then return nil, t("offerGuildUnavailable") end
        return "GUILD", nil, t("channel_guild")
    end
    local channel = offers.findChannel(kind, channelList())
    if not channel or channel.disabled then
        if kind == "trade" then return nil, t("offerTradeUnavailable") end
        return nil, t("offerChannelUnavailable"):format(kind:gsub("^name:", ""))
    end
    return "CHANNEL", channel.id, channel.name
end

function UI.remaining()
    return offers.remaining(store().lastPost, ForeverCraftDB.offerCooldown or 120, time())
end

local pending
local function setStatus(text, color)
    if UI.window then
        UI.window.status:SetText(text or "")
        local c = color or ui.colors.lightGold
        UI.window.status:SetTextColor(c[1], c[2], c[3])
    end
    if text then print("ForeverCraft: " .. text) end
end

-- Sends the message, split into at most two lines when it is too long. All lines are sent
-- right away inside the same click handler (hardware event) – never delayed by a timer.
local function send(message, kind)
    local chatType, target, label = UI.resolveChannel(kind)
    if not chatType then setStatus(target, ui.colors.red) return false end
    local parts = offers.split(message)
    if not parts then setStatus(t("offerSplitImpossible"), ui.colors.red) return false end
    local sender = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local keys = {}
    for _, part in ipairs(parts) do
        local ok, err = pcall(sender, part, chatType, nil, target)
        if not ok then setStatus(tostring(err), ui.colors.red) return false end
        keys[offers.echoKey(part)] = true
    end
    store().lastPost = time()
    store().last = copy(UI.config())
    pending = { text = message, keys = keys, open = #parts, at = GetTime() }
    setStatus(#parts > 1 and t("offerSentParts"):format(label, #parts) or t("offerSent"):format(label))
    -- The client echoes the own message; without echo the post is reported as unconfirmed.
    local current = pending
    C_Timer.After(6, function()
        if pending == current then
            pending = nil
            setStatus(t("offerNotConfirmed"), ui.colors.red)
        end
    end)
    UI.refreshButton()
    return true
end

local echo = CreateFrame("Frame", "ForeverCraftOfferEcho")
echo:RegisterEvent("CHAT_MSG_CHANNEL")
echo:RegisterEvent("CHAT_MSG_GUILD")
-- Own message in the chat? The sender is recognised by GUID (12th event argument), the name is
-- only a fallback; the text is compared by its visible content (links come back re-encoded).
local function isMe(author, guid)
    if guid and UnitGUID and guid == UnitGUID("player") then return true end
    local me = UnitName("player")
    if not author or not me then return false end
    local name = author:match("^([^%-]+)") or author
    return author == me or name:gsub("%s+$", "") == me
end

echo:SetScript("OnEvent", function(_, _, text, author, _, _, _, _, _, _, _, _, _, guid)
    if not pending or type(text) ~= "string" or not isMe(author, guid) then return end
    local key = offers.echoKey(text)
    if pending.keys[key] then
        pending.keys[key] = nil
        pending.open = pending.open - 1
        -- Confirmed only when every line of the offer appeared in the chat.
        if pending.open <= 0 then
            pending = nil
            setStatus(t("offerConfirmed"), ui.colors.green)
            UI.confirmedAt = GetTime()
            UI.refreshButton()
        end
        return
    end
    -- Own line that did not match: kept for diagnosis (last three), never shown in the chat.
    local data = store()
    data.echoDebug = data.echoDebug or {}
    table.insert(data.echoDebug, 1, { at = time(), sent = pending.text, received = text, author = author })
    while #data.echoDebug > 3 do table.remove(data.echoDebug) end
end)

StaticPopupDialogs["FOREVERCRAFT_OFFER_CONFIRM"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) send(data.message, data.kind) end,
}

-- Checks everything and posts (with confirmation if enabled). Called from clicks only.
function UI.post(message, kind, skipConfirm)
    message = offers.sanitize(message)
    if message == "" then setStatus(t("offerEmpty"), ui.colors.red) return end
    local parts = offers.split(message)
    if not parts then setStatus(t("offerSplitImpossible"), ui.colors.red) return end
    local remaining = UI.remaining()
    if remaining > 0 then setStatus(t("offerCooldownActive"):format(remaining), ui.colors.red) return end
    local chatType, reason, label = UI.resolveChannel(kind)
    if not chatType then setStatus(reason, ui.colors.red) return end
    if UI.option("offerConfirmSend") and not skipConfirm then
        StaticPopup_Show("FOREVERCRAFT_OFFER_CONFIRM", t("offerConfirm"):format(label, table.concat(parts, "\n\n")), nil,
            { message = message, kind = kind })
        return
    end
    send(message, kind)
end

-- Widgets -------------------------------------------------------------------------------------------
local function button(parent, text, minimum, onClick)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetHeight(24)
    control.Fit = function(self, caption)
        self:SetText(caption)
        local label = self:GetFontString()
        self:SetWidth(math.max(minimum or 90, math.ceil(label and label:GetStringWidth() or 60) + 30))
    end
    control:Fit(text)
    control:SetScript("OnClick", onClick)
    return control
end

local function check(parent, onClick)
    local control = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    control:SetSize(24, 24)
    control.label = ui.text(control, "GameFontHighlight")
    control.label:SetPoint("LEFT", control, "RIGHT", 3, 0)
    control:SetScript("OnClick", onClick)
    return control
end

local function moneyBoxes(parent, onChange)
    local group = CreateFrame("Frame", nil, parent)
    group:SetSize(222, 24)
    group.boxes = {}
    local x = 0
    for index, width in ipairs({ 64, 34, 34 }) do
        local box = CreateFrame("EditBox", nil, group, "InputBoxTemplate")
        box:SetSize(width, 20)
        box:SetPoint("LEFT", x + 6, 0)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(index == 1 and 6 or 2)
        box:SetJustifyH("RIGHT")
        box:SetScript("OnEscapePressed", box.ClearFocus)
        box:SetScript("OnTextChanged", function(_, user) if user then onChange() end end)
        local coin = group:CreateTexture(nil, "ARTWORK")
        coin:SetSize(14, 14)
        coin:SetPoint("LEFT", box, "RIGHT", 3, 0)
        coin:SetTexture(COINS[index])
        group.boxes[index] = box
        x = x + width + 26
    end
    function group.Get()
        return offers.copper(group.boxes[1]:GetText(), group.boxes[2]:GetText(), group.boxes[3]:GetText()) or 0
    end
    function group.Set(value)
        value = value or 0
        local gold, silver, copper = math.floor(value / 10000), math.floor(value / 100) % 100, value % 100
        group.boxes[1]:SetText(gold > 0 and tostring(gold) or "")
        group.boxes[2]:SetText(silver > 0 and tostring(silver) or "")
        group.boxes[3]:SetText(copper > 0 and tostring(copper) or "")
    end
    return group
end

local function conditionOptions()
    local list = {}
    for _, id in ipairs(offers.conditions) do list[#list + 1] = { id, t("cond_" .. id) } end
    return list
end

local function templateOptions()
    local list = { { "casual", t("template_casual") }, { "short", t("template_short") } }
    for _, template in ipairs(templates()) do list[#list + 1] = { "custom:" .. template.id, template.name } end
    return list
end

local function languageOptions()
    local list = { { "auto", t("offerLanguageAuto") } }
    for _, code in ipairs(offers.languages) do
        if code ~= "auto" then list[#list + 1] = { code, addon.languageNames[code] or code } end
    end
    return list
end

local function dropdown(parent, width, optionsFn, get, set)
    return addon.ledger.dropdown(parent, width, optionsFn, function(value) return get() == value end, set)
end

-- Offer window --------------------------------------------------------------------------------------
local function anyCondition(config, wanted)
    if not config.perProfession then return config.condition == wanted end
    for id in pairs(config.professions) do
        if (config.conditions[id] or config.condition) == wanted then return true end
    end
    return false
end

function UI.regenerate()
    local window = UI.window
    if not window then return end
    local message = UI.message()
    window.preview:SetText(message)
    window.edited = false
    UI.updateLength()
end

function UI.suggestShorter()
    local config = UI.config()
    local data, build = UI.messageData(config)
    local message, steps = offers.shorten(build, data)
    if not message then setStatus(t("offerShortenFailed"), ui.colors.red) return end
    UI.window.preview:SetText(message)
    local names = {}
    for _, step in ipairs(steps) do names[#names + 1] = t("shorten_" .. step) end
    setStatus(t("offerShortened"):format(table.concat(names, ", ")))
    UI.updateLength()
end

function UI.updateLength()
    local window = UI.window
    local text = offers.sanitize(window.preview:GetText())
    local length = offers.length(text)
    window.length:SetText(t("offerLengthBoth"):format(offers.visibleLength(offers.visibleText(text)), length, offers.MAX_LENGTH))
    local tooLong = length > offers.MAX_LENGTH
    window.shorten:SetShown(tooLong)
    -- Too long for one line: sent as two messages when that is possible.
    local parts = tooLong and offers.split(text)
    if parts then
        window.length:SetText(t("offerLengthParts"):format(window.length:GetText(), #parts))
        window.length:SetTextColor(ui.colors.lightGold[1], ui.colors.lightGold[2], ui.colors.lightGold[3])
    end
    local c = tooLong and ui.colors.red or ui.colors.grey
    window.length:SetTextColor(c[1], c[2], c[3])
    if parts then
        window.warning:SetText(t("offerSplitInfo"):format(#parts))
        window.warning:SetTextColor(ui.colors.lightGold[1], ui.colors.lightGold[2], ui.colors.lightGold[3])
    else
        window.warning:SetText(tooLong and t("offerSplitImpossible") or (text == "" and t("offerEmpty") or ""))
        window.warning:SetTextColor(ui.colors.red[1], ui.colors.red[2], ui.colors.red[3])
    end
    UI.refreshButton()
end

local function layoutLeft()
    local window, config = UI.window, UI.config()
    local professions = UI.professions()
    local y = -36
    for index, profession in ipairs(professions) do
        local row = window.professionRows[index]
        if not row then
            row = CreateFrame("Frame", nil, window.professionPanel)
            row:SetHeight(28)
            row.check = check(row, function(self)
                config = UI.config()
                config.professions[row.id] = self:GetChecked() and true or nil
                UI.changed()
            end)
            row.check:SetPoint("LEFT", 6, 0)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
            row.name = ui.text(row, "GameFontHighlight")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.skill = ui.text(row, "GameFontHighlightSmall", "RIGHT", ui.colors.lightGold)
            row.condition = dropdown(row, 170, conditionOptions, function()
                local current = UI.config()
                return current.conditions[row.id] or current.condition
            end, function(value)
                UI.config().conditions[row.id] = value
                UI.changed()
            end)
            row.condition:SetPoint("RIGHT", -6, 0)
            window.professionRows[index] = row
        end
        row.id = profession.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, y)
        row:SetPoint("RIGHT", window.professionPanel, "RIGHT", -6, 0)
        row.check:SetChecked(config.professions[profession.id] and true or false)
        row.icon:SetTexture(profession.icon)
        row.name:SetText(profession.name .. (profession.gathering and ("  |cff9d9d9d(" .. t("offerGathering") .. ")|r") or ""))
        row.skill:SetText(("%d / %d"):format(profession.skill or 0, profession.max or 0))
        row.skill:ClearAllPoints()
        if config.perProfession then
            row.skill:SetPoint("RIGHT", row.condition, "LEFT", -8, 0)
        else
            row.skill:SetPoint("RIGHT", -10, 0)
        end
        row.condition:SetShown(config.perProfession and config.professions[profession.id] and true or false)
        row.condition.Sync()
        row:Show()
        y = y - 28
    end
    for index = #professions + 1, #window.professionRows do window.professionRows[index]:Hide() end
    window.noProfessions:SetShown(#professions == 0)
    if #professions == 0 then y = y - 24 end
    window.perProfession:ClearAllPoints()
    window.perProfession:SetPoint("TOPLEFT", 12, y - 4)
    window.perProfession:SetChecked(config.perProfession)
    window.professionPanel:SetHeight(-y + 40)

    -- Terms
    local cy = -36
    window.condition:SetShown(not config.perProfession)
    window.condition.Sync()
    if not config.perProfession then cy = cy - 34 end
    local custom = anyCondition(config, "custom")
    window.customText:SetShown(custom)
    window.customText:ClearAllPoints()
    window.customText:SetPoint("TOPLEFT", 18, cy)
    window.customText:SetPoint("RIGHT", window.conditionPanel, "RIGHT", -14, 0)
    if custom then
        if not window.customText:HasFocus() then window.customText:SetText(config.customText or "") end
        cy = cy - 30
    end
    local fixed = anyCondition(config, "matsFixed")
    window.fee:SetShown(fixed)
    window.feeMode:SetShown(fixed)
    if fixed then
        window.fee:ClearAllPoints()
        window.fee:SetPoint("TOPLEFT", 10, cy)
        window.feeMode:ClearAllPoints()
        window.feeMode:SetPoint("LEFT", window.fee, "RIGHT", 6, 0)
        window.feeMode.Sync()
        cy = cy - 32
    end
    window.feeNote:ClearAllPoints()
    window.feeNote:SetPoint("TOPLEFT", 14, cy - 2)
    window.feeNote:SetPoint("RIGHT", window.conditionPanel, "RIGHT", -14, 0)
    cy = cy - math.ceil(window.feeNote:GetStringHeight()) - 14
    window.conditionPanel:SetHeight(-cy)

    -- Recipes
    local count = 0
    for _ in pairs(config.recipes) do count = count + 1 end
    window.recipeSummary:SetText(count > 0 and t("offerRecipesCount"):format(count) or t("offerRecipesNone"))
    window.clearRecipes:SetEnabled(count > 0)
end

function UI.changed()
    if not UI.window then return end
    layoutLeft()
    UI.regenerate()
end

local function buildWindow()
    local window = CreateFrame("Frame", "ForeverCraftOfferWindow", UIParent, "PortraitFrameTemplate")
    UI.window = window
    local _, screenHeight = UIParent:GetSize()
    window:SetSize(940, math.min(660, screenHeight - 60))
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
    tinsert(UISpecialFrames, "ForeverCraftOfferWindow")
    window.professionRows = {}

    -- Left column: professions, terms, recipes.
    local left = CreateFrame("Frame", nil, window)
    left:SetPoint("TOPLEFT", 14, -60)
    left:SetPoint("BOTTOMLEFT", 14, 14)
    left:SetWidth(440)
    window.left = left
    window.professionPanel = ui.panel(left)
    window.professionPanel:SetPoint("TOPLEFT")
    window.professionPanel:SetPoint("TOPRIGHT")
    window.professionTitle = ui.heading(window.professionPanel)
    window.professionTitle:SetPoint("TOPLEFT", 14, -12)
    window.noProfessions = ui.text(window.professionPanel, "GameFontDisable")
    window.noProfessions:SetPoint("TOPLEFT", 16, -40)
    window.perProfession = check(window.professionPanel, function(self)
        UI.config().perProfession = self:GetChecked() and true or false
        UI.changed()
    end)

    window.conditionPanel = ui.panel(left)
    window.conditionPanel:SetPoint("TOPLEFT", window.professionPanel, "BOTTOMLEFT", 0, -8)
    window.conditionPanel:SetPoint("TOPRIGHT", window.professionPanel, "BOTTOMRIGHT", 0, -8)
    window.conditionTitle = ui.heading(window.conditionPanel)
    window.conditionTitle:SetPoint("TOPLEFT", 14, -12)
    window.condition = dropdown(window.conditionPanel, 300, conditionOptions, function() return UI.config().condition end,
        function(value) UI.config().condition = value; UI.changed() end)
    window.condition:SetPoint("TOPLEFT", 14, -36)
    window.customText = CreateFrame("EditBox", nil, window.conditionPanel, "InputBoxTemplate")
    window.customText:SetHeight(22)
    window.customText:SetAutoFocus(false)
    window.customText:SetMaxLetters(90)
    window.customText:SetScript("OnEscapePressed", window.customText.ClearFocus)
    window.customText:SetScript("OnTextChanged", function(self, user)
        if user then UI.config().customText = self:GetText(); UI.regenerate() end
    end)
    window.fee = moneyBoxes(window.conditionPanel, function()
        UI.config().fee = window.fee.Get()
        UI.regenerate()
    end)
    window.feeMode = dropdown(window.conditionPanel, 180, function()
        return { { "each", t("offerFeeEach") }, { "total", t("offerFeeTotal") } }
    end, function() return UI.config().feeMode or "each" end, function(value) UI.config().feeMode = value; UI.regenerate() end)
    window.feeNote = ui.text(window.conditionPanel, "GameFontHighlightSmall", "LEFT", { 0.80, 0.72, 0.59 })
    window.feeNote:SetWordWrap(true)

    window.recipePanel = ui.panel(left)
    window.recipePanel:SetPoint("TOPLEFT", window.conditionPanel, "BOTTOMLEFT", 0, -8)
    window.recipePanel:SetPoint("TOPRIGHT", window.conditionPanel, "BOTTOMRIGHT", 0, -8)
    window.recipePanel:SetHeight(92)
    window.recipeTitle = ui.heading(window.recipePanel)
    window.recipeTitle:SetPoint("TOPLEFT", 14, -12)
    window.recipeSummary = ui.text(window.recipePanel, "GameFontHighlight")
    window.recipeSummary:SetPoint("TOPLEFT", 16, -36)
    window.chooseRecipes = button(window.recipePanel, "", 150, function() UI.showRecipes() end)
    window.chooseRecipes:SetPoint("BOTTOMLEFT", 12, 12)
    window.clearRecipes = button(window.recipePanel, "", 80, function()
        UI.config().recipes = {}
        UI.changed()
    end)
    window.clearRecipes:SetPoint("LEFT", window.chooseRecipes, "RIGHT", 6, 0)

    -- Right column: profile, template, language, channel, options, preview, posting.
    local right = ui.panel(window)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", -14, 14)
    window.right = right
    local function caption(parent, x, y)
        local label = ui.text(parent, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", x, y)
        return label
    end
    window.profileLabel = caption(right, 16, -14)
    window.profile = dropdown(right, 200, function()
        local list = {}
        for name in pairs(store().profiles) do list[#list + 1] = { name, name } end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        return list
    end, function() return store().active end, function(value)
        store().active = value
        UI.refreshAll()
    end)
    window.profile:SetPoint("TOPLEFT", 14, -30)
    window.newProfile = button(right, "", 90, function()
        StaticPopup_Show("FOREVERCRAFT_OFFER_PROFILE_NAME", t("offerProfileName"))
    end)
    window.newProfile:SetPoint("LEFT", window.profile, "RIGHT", 8, 0)
    window.deleteProfile = button(right, "", 80, function()
        local name = store().active
        StaticPopup_Show("FOREVERCRAFT_OFFER_PROFILE_DELETE", t("offerProfileDeleteConfirm"):format(name), nil, name)
    end)
    window.deleteProfile:SetPoint("LEFT", window.newProfile, "RIGHT", 6, 0)

    window.templateLabel = caption(right, 16, -66)
    window.template = dropdown(right, 200, templateOptions, function() return UI.config().template end,
        function(value) UI.config().template = value; UI.regenerate() end)
    window.template:SetPoint("TOPLEFT", 14, -82)
    window.manageTemplates = button(right, "", 120, function() UI.showTemplates() end)
    window.manageTemplates:SetPoint("LEFT", window.template, "RIGHT", 8, 0)
    window.languageLabel = caption(right, 16, -118)
    window.language = dropdown(right, 200, languageOptions, function() return UI.config().language end,
        function(value) UI.config().language = value; UI.regenerate() end)
    window.language:SetPoint("TOPLEFT", 14, -134)
    window.channelLabel = caption(right, 234, -118)
    window.channel = dropdown(right, 200, UI.channelOptions, function() return UI.config().channel end,
        function(value) UI.config().channel = value; UI.refreshButton() end)
    window.channel:SetPoint("TOPLEFT", 232, -134)

    window.optionsLabel = caption(right, 16, -172)
    window.options = {}
    for index, key in ipairs(OPTION_KEYS) do
        local control = check(right, function(self)
            ForeverCraftDB[OPTION_DB[key]] = self:GetChecked() and true or false
            UI.regenerate()
        end)
        control:SetPoint("TOPLEFT", 12, -188 - (index - 1) * 25)
        control.label:SetPoint("RIGHT", right, "RIGHT", -16, 0)
        control.key = key
        window.options[index] = control
    end

    window.previewLabel = caption(right, 16, -368)
    local previewBox = ui.panel(right)
    previewBox:SetPoint("TOPLEFT", 12, -384)
    previewBox:SetPoint("RIGHT", right, "RIGHT", -12, 0)
    previewBox:SetHeight(92)
    window.previewBox = previewBox
    local scroll = CreateFrame("ScrollFrame", nil, previewBox, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local preview = CreateFrame("EditBox", nil, scroll)
    preview:SetMultiLine(true)
    preview:SetAutoFocus(false)
    preview:SetFontObject(GameFontHighlight)
    preview:SetWidth(400)
    preview:SetScript("OnEscapePressed", preview.ClearFocus)
    preview:SetScript("OnTextChanged", function(_, user)
        if user then window.edited = true end
        UI.updateLength()
    end)
    scroll:SetScrollChild(preview)
    scroll:HookScript("OnSizeChanged", function(_, width) if width and width > 0 then preview:SetWidth(width) end end)
    window.preview = preview
    window.length = ui.text(right, "GameFontHighlightSmall", "RIGHT")
    window.length:SetPoint("TOPRIGHT", previewBox, "BOTTOMRIGHT", -4, -6)
    window.regenerate = button(right, "", 120, function() UI.regenerate() end)
    window.regenerate:SetPoint("TOPLEFT", previewBox, "BOTTOMLEFT", 0, -6)
    window.shorten = button(right, "", 150, function() UI.suggestShorter() end)
    window.shorten:SetPoint("LEFT", window.regenerate, "RIGHT", 6, 0)
    window.shorten:Hide()
    window.warning = ui.text(right, "GameFontHighlightSmall", "LEFT", ui.colors.red)
    window.warning:SetPoint("TOPLEFT", window.regenerate, "BOTTOMLEFT", 2, -6)
    window.warning:SetPoint("RIGHT", right, "RIGHT", -14, 0)
    window.warning:SetWordWrap(true)

    window.post = button(right, "", 160, function()
        UI.post(window.preview:GetText(), UI.config().channel)
    end)
    window.post:SetHeight(28)
    window.post:SetPoint("BOTTOMRIGHT", -14, 14)
    window.status = ui.text(right, "GameFontHighlightSmall", "LEFT", ui.colors.lightGold)
    window.status:SetPoint("BOTTOMLEFT", 16, 20)
    window.status:SetPoint("RIGHT", window.post, "LEFT", -10, 0)
    window.status:SetWordWrap(true)

    window:SetScript("OnShow", function() UI.refreshAll() end)
    window:Hide()
end

function UI.refreshTexts()
    local window = UI.window
    window:SetTitle(t("offerTitle"))
    window.professionTitle:SetText(t("offerProfessions"))
    window.noProfessions:SetText(t("offerNoProfessions"))
    window.perProfession.label:SetText(t("offerPerProfession"))
    window.conditionTitle:SetText(t("offerConditions"))
    window.feeNote:SetText(t("offerFeeNote"))
    window.recipeTitle:SetText(t("offerRecipes"))
    window.chooseRecipes:Fit(t("offerChooseRecipes"))
    window.clearRecipes:Fit(t("offerClearRecipes"))
    window.profileLabel:SetText(t("offerProfile"))
    window.newProfile:Fit(t("offerProfileNew"))
    window.deleteProfile:Fit(t("offerProfileDelete"))
    window.templateLabel:SetText(t("offerTemplate"))
    window.manageTemplates:Fit(t("offerManageTemplates"))
    window.languageLabel:SetText(t("offerLanguage"))
    window.channelLabel:SetText(t("offerChannel"))
    window.optionsLabel:SetText(t("offerOptions"))
    window.previewLabel:SetText(t("offerPreview"))
    window.regenerate:Fit(t("offerRegenerate"))
    window.shorten:Fit(t("offerShorten"))
    for _, control in ipairs(window.options) do
        control.label:SetText(t("opt_" .. control.key))
        control:SetChecked(UI.option(OPTION_DB[control.key]))
    end
    window.previewBox:SetShown(UI.option("offerPreviewShow"))
    window.previewLabel:SetShown(UI.option("offerPreviewShow"))
end

function UI.refreshAll()
    if not UI.window then return end
    UI.config()
    UI.refreshTexts()
    UI.window.fee.Set(UI.config().fee)
    for _, control in ipairs({ UI.window.profile, UI.window.template, UI.window.language, UI.window.channel }) do control.Sync() end
    UI.window.deleteProfile:SetEnabled(next(store().profiles, next(store().profiles)) ~= nil)
    UI.changed()
end

function UI.refreshButton()
    local remaining = UI.remaining()
    if UI.window then
        local window = UI.window
        local text = offers.sanitize(window.preview:GetText())
        window.post:Fit(remaining > 0 and t("offerPostWait"):format(remaining) or t("offerPost"))
        window.post:SetEnabled(remaining == 0 and text ~= "" and offers.split(text) ~= nil)
    end
    if UI.refreshPanel then UI.refreshPanel() end
    -- Countdown display only; nothing is posted by this timer.
    if remaining > 0 and not UI.ticking then
        UI.ticking = true
        C_Timer.After(1, function()
            UI.ticking = false
            UI.refreshButton()
        end)
    end
end

function UI.open()
    if InCombatLockdown() then return end
    if not UI.window then buildWindow() end
    UI.window:Show()
    UI.window:Raise()
end

StaticPopupDialogs["FOREVERCRAFT_OFFER_PROFILE_NAME"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, maxLetters = 40, timeout = 0,
    whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local box = self.editBox or self.EditBox
        local name = box and box:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        if not name or name == "" then return end
        local data = store()
        data.profiles[name] = data.profiles[name] or copy(UI.config())
        data.active = name
        UI.refreshAll()
    end,
}
StaticPopupDialogs["FOREVERCRAFT_OFFER_PROFILE_DELETE"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    OnAccept = function(_, name)
        local data = store()
        data.profiles[name] = nil
        data.active = next(data.profiles)
        UI.refreshAll()
    end,
}

-- Recipe knowledge per profession ----------------------------------------------------------------------
-- The client only lists the recipes (and the profession link) of the profession window that is
-- open. ForeverCraft therefore records them per profession whenever one is opened, so every
-- profession stays available afterwards. Linked or guild views of other players are skipped.
local function openProfession()
    if not Professions or not Professions.GetProfessionInfo then return nil end
    local ok, info = pcall(Professions.GetProfessionInfo)
    if not ok or not info then return nil end
    local trade = C_TradeSkillUI
    for _, method in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if trade[method] then
            local fine, value = pcall(trade[method])
            if fine and value then return nil end
        end
    end
    return info.parentProfessionID or info.professionID, info
end

function UI.scanOpenProfession()
    local trade = C_TradeSkillUI
    local id = openProfession()
    if not id or not trade or not trade.GetAllRecipeIDs then return end
    local mine = false
    for _, profession in ipairs(UI.professions()) do
        if profession.id == id then mine = true end
    end
    if not mine then return end
    local recipes = {}
    for _, recipeID in ipairs(trade.GetAllRecipeIDs() or {}) do
        local recipe = trade.GetRecipeInfo(recipeID)
        if recipe and recipe.learned and recipe.name then
            local category = ""
            if recipe.categoryID and trade.GetCategoryInfo then
                local found, categoryInfo = pcall(trade.GetCategoryInfo, recipe.categoryID)
                category = found and type(categoryInfo) == "table" and categoryInfo.name or ""
            end
            local schematic = trade.GetRecipeSchematic and trade.GetRecipeSchematic(recipeID, false)
            local output = schematic and schematic.outputItemID
            if output and output < 1 then output = nil end
            local recipeLink
            if trade.GetRecipeLink then
                local linked, value = pcall(trade.GetRecipeLink, recipeID)
                recipeLink = linked and type(value) == "string" and value:find("|H", 1, true) and value or nil
            end
            recipes[#recipes + 1] = { id = recipeID, name = recipe.name, icon = recipe.icon, category = category,
                output = output, recipeLink = recipeLink }
        end
    end
    local data = store()
    data.recipeData = data.recipeData or {}
    -- An empty list right after opening is the client still loading; never overwrite with it.
    if #recipes > 0 then data.recipeData[id] = { at = time(), recipes = recipes } end
    if trade.GetTradeSkillListLink then
        local linked, link = pcall(trade.GetTradeSkillListLink)
        if linked and type(link) == "string" and link:find("|H", 1, true) then
            data.links = data.links or {}
            data.links[id] = link
        end
    end
    if UI.recipeWindow and UI.recipeWindow:IsShown() then UI.refreshRecipes() end
end

local scanQueued
local scanner = CreateFrame("Frame")
for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED" }) do
    scanner:RegisterEvent(event)
end
scanner:SetScript("OnEvent", function()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(.5, function()
        scanQueued = false
        UI.scanOpenProfession()
    end)
end)

-- Link of a crafted item (loaded on demand) or the recipe/enchant link recorded by the client.
function UI.recipeLink(entry)
    if entry.output then
        local link = select(2, C_Item.GetItemInfo(entry.output))
        if link then return link end
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, entry.output) end
    end
    return entry.recipeLink
end

-- Recipe picker: every selected crafting profession, grouped by profession and category ---------------
local function professionCaption(profession)
    return profession.name
end

local function buildRecipeWindow()
    local frame = CreateFrame("Frame", "ForeverCraftOfferRecipes", UIParent, "PortraitFrameTemplate")
    UI.recipeWindow = frame
    local _, screenHeight = UIParent:GetSize()
    frame:SetSize(560, math.min(620, screenHeight - 60))
    frame:SetPoint("CENTER", 120, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
    tinsert(UISpecialFrames, "ForeverCraftOfferRecipes")
    frame.collapsed = {}
    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetHeight(22)
    frame.search:SetPoint("TOPLEFT", 74, -36)
    frame.search:SetPoint("TOPRIGHT", -18, -36)
    frame.search:SetAutoFocus(false)
    frame.search:SetScript("OnEscapePressed", frame.search.ClearFocus)
    frame.search:SetScript("OnTextChanged", function() UI.refreshRecipes() end)
    frame.placeholder = ui.text(frame.search, "GameFontDisableSmall")
    frame.placeholder:SetPoint("LEFT", 4, 0)
    frame.professionDrop = dropdown(frame, 220, function()
        local list = { { 0, t("offerAllProfessions") } }
        for _, profession in ipairs(UI.selectedProfessions()) do list[#list + 1] = { profession.id, profession.name } end
        return list
    end, function() return frame.profession or 0 end, function(value)
        frame.profession = value ~= 0 and value or nil
        frame.category = nil
        UI.refreshRecipes()
    end)
    frame.professionDrop:SetPoint("TOPLEFT", 16, -66)
    frame.categoryDrop = dropdown(frame, 220, function()
        local list, seen = { { "*", t("offerRecipeAllCategories") } }, {}
        for _, profession in ipairs(UI.selectedProfessions()) do
            if not frame.profession or frame.profession == profession.id then
                local data = store().recipeData and store().recipeData[profession.id]
                for _, recipe in ipairs(data and data.recipes or {}) do
                    if recipe.category ~= "" and not seen[recipe.category] then
                        seen[recipe.category] = true
                        list[#list + 1] = { recipe.category, recipe.category }
                    end
                end
            end
        end
        return list
    end, function() return frame.category or "*" end, function(value)
        frame.category = value ~= "*" and value or nil
        UI.refreshRecipes()
    end)
    frame.categoryDrop:SetPoint("LEFT", frame.professionDrop, "RIGHT", 10, 0)
    local body = ui.panel(frame)
    body:SetPoint("TOPLEFT", 12, -96)
    body:SetPoint("BOTTOMRIGHT", -12, 50)
    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    frame.content = CreateFrame("Frame", nil, scroll)
    frame.content:SetSize(480, 10)
    scroll:SetScrollChild(frame.content)
    scroll:HookScript("OnSizeChanged", function(_, width) if width and width > 0 then frame.content:SetWidth(width) end end)
    frame.rows = {}
    frame.total = ui.text(frame, "GameFontHighlight")
    frame.total:SetPoint("BOTTOMLEFT", 18, 20)
    frame.apply = button(frame, "", 150, function()
        UI.config().recipes = copy(frame.selection)
        frame:Hide()
        UI.changed()
    end)
    frame.apply:SetPoint("BOTTOMRIGHT", -14, 14)
    frame.clear = button(frame, "", 120, function()
        frame.selection = {}
        UI.refreshRecipes()
    end)
    frame.clear:SetPoint("RIGHT", frame.apply, "LEFT", -8, 0)
    frame:Hide()
end

-- Crafting professions ticked in the offer window (gathering professions have no recipes here).
function UI.selectedProfessions()
    local list, config = {}, UI.config()
    for _, profession in ipairs(UI.professions()) do
        if config.professions[profession.id] and not profession.gathering then list[#list + 1] = profession end
    end
    return list
end

function UI.showRecipes()
    if not UI.recipeWindow then buildRecipeWindow() end
    local frame = UI.recipeWindow
    -- Work on a copy; "Apply" stores it in the profile, closing discards it.
    frame.selection = copy(UI.config().recipes)
    frame.profession, frame.category = nil, nil
    frame.search:SetText("")
    UI.scanOpenProfession()
    frame:Show()
    frame:Raise()
    UI.refreshRecipes()
end

local function recipeRow(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, frame.content)
    row:SetHeight(24)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.check = check(row, function(self)
        local entry = self:GetParent().entry
        if self:GetChecked() and entry.offerable then
            frame.selection[entry.recipe.id] = { name = entry.recipe.name, output = entry.recipe.output,
                recipeLink = entry.recipe.recipeLink, profession = entry.profession }
        else
            frame.selection[entry.recipe.id] = nil
            self:SetChecked(false)
        end
        UI.refreshRecipes()
    end)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.name = ui.text(row, "GameFontHighlight")
    row.info = ui.text(row, "GameFontHighlightSmall", "RIGHT")
    row.info:SetPoint("RIGHT", -6, 0)
    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if entry and entry.key then
            frame.collapsed[entry.key] = not frame.collapsed[entry.key] or nil
            UI.refreshRecipes()
        end
    end)
    row:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry or not entry.recipe then return end
        local link = UI.recipeLink(entry.recipe)
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, link:match("|H(.-)|h") or link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.rows[index] = row
    return row
end

function UI.refreshRecipes()
    local frame = UI.recipeWindow
    if not frame or not frame:IsShown() then return end
    frame:SetTitle(t("offerRecipesTitle"))
    frame.placeholder:SetText(t("offerRecipeSearch"))
    frame.placeholder:SetShown(frame.search:GetText() == "")
    frame.clear:Fit(t("offerRecipesClear"))
    frame.apply:Fit(t("offerRecipesApply"))
    frame.professionDrop.Sync()
    frame.categoryDrop.Sync()
    local query = (frame.search:GetText() or ""):lower()
    local entries, total = {}, 0
    -- Cooldowns are only reported reliably for the profession that is open right now.
    local openID = openProfession()
    local function cooldownOf(recipeID, professionID)
        local trade = C_TradeSkillUI
        if professionID ~= openID or not trade.GetRecipeCooldown then return nil end
        local fine, seconds = pcall(trade.GetRecipeCooldown, recipeID)
        return fine and type(seconds) == "number" and seconds > 0 and seconds or nil
    end
    for _ in pairs(frame.selection) do total = total + 1 end
    for _, profession in ipairs(UI.selectedProfessions()) do
        if not frame.profession or frame.profession == profession.id then
            local data = store().recipeData and store().recipeData[profession.id]
            local selectedHere = 0
            for _, recipe in pairs(frame.selection) do
                if recipe.profession == profession.id then selectedHere = selectedHere + 1 end
            end
            local professionKey = "p" .. profession.id
            entries[#entries + 1] = { key = professionKey, depth = 0, icon = profession.icon, text = professionCaption(profession),
                info = t("offerRecipesSelectedCount"):format(selectedHere), header = true }
            if not data then
                entries[#entries + 1] = { depth = 1, hint = t("offerRecipesNotScanned"):format(profession.name, profession.name) }
            elseif not frame.collapsed[professionKey] then
                local categories, order = {}, {}
                for _, recipe in ipairs(data.recipes) do
                    local category = recipe.category ~= "" and recipe.category or t("offerRecipeOther")
                    if (not frame.category or frame.category == recipe.category)
                        and (query == "" or recipe.name:lower():find(query, 1, true) or category:lower():find(query, 1, true)) then
                        if not categories[category] then
                            categories[category] = {}
                            order[#order + 1] = category
                        end
                        table.insert(categories[category], recipe)
                    end
                end
                table.sort(order)
                for _, category in ipairs(order) do
                    local list = categories[category]
                    table.sort(list, function(a, b) return a.name < b.name end)
                    local categoryKey = professionKey .. "/" .. category
                    entries[#entries + 1] = { key = categoryKey, depth = 1, icon = list[1].icon, text = category, header = true,
                        info = tostring(#list) }
                    if not frame.collapsed[categoryKey] or query ~= "" then
                        for _, recipe in ipairs(list) do
                            local status = offers.recipeStatus(recipe.output, profession.id)
                            entries[#entries + 1] = { depth = 2, recipe = recipe, profession = profession.id, status = status,
                                offerable = offers.offerable(status), cooldown = cooldownOf(recipe.id, profession.id) }
                        end
                    end
                end
                if #order == 0 then entries[#entries + 1] = { depth = 1, hint = t("offerRecipesNoMatch") } end
            end
        end
    end
    if #UI.selectedProfessions() == 0 then entries[#entries + 1] = { depth = 0, hint = t("offerRecipesNoProfession") } end
    for index, entry in ipairs(entries) do
        local row = recipeRow(frame, index)
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 24)
        row:SetPoint("RIGHT", frame.content, "RIGHT")
        local indent = 6 + entry.depth * 18
        row.check:SetShown(entry.recipe ~= nil)
        row.toggle:SetShown(entry.header == true)
        row.icon:SetShown(entry.icon ~= nil or entry.recipe ~= nil)
        row.icon:ClearAllPoints()
        if entry.header then
            row.toggle:ClearAllPoints()
            row.toggle:SetPoint("LEFT", indent, 0)
            row.toggle:SetTexture(frame.collapsed[entry.key] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            row.icon:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
            row.icon:SetTexture(entry.icon)
        elseif entry.recipe then
            row.check:ClearAllPoints()
            row.check:SetPoint("LEFT", indent, 0)
            row.check:SetEnabled(entry.offerable)
            row.check:SetChecked(frame.selection[entry.recipe.id] ~= nil)
            row.icon:SetPoint("LEFT", row.check, "RIGHT", 3, 0)
            row.icon:SetTexture(entry.recipe.icon)
        end
        row.name:ClearAllPoints()
        if entry.hint then
            row.name:SetPoint("LEFT", indent, 0)
        else
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        end
        row.name:SetPoint("RIGHT", -150, 0)
        row.name:SetWordWrap(entry.hint ~= nil)
        row:SetHeight(entry.hint and 40 or 24)
        row.name:SetFontObject(entry.depth == 0 and entry.header and GameFontNormal or GameFontHighlight)
        local info, color = entry.info or "", ui.colors.grey
        if entry.recipe then
            if entry.status == "NON_TRADEABLE" then info, color = t("offerRecipeBound"), ui.colors.red
            elseif entry.status == "UNKNOWN" then info = t("offerRecipeLoading")
            elseif entry.cooldown then info, color = t("offerRecipeCooldown"):format(SecondsToTime(entry.cooldown)), ui.colors.orange
            elseif entry.status == "SERVICE" then info = t("offerRecipeService")
            else info = "" end
            row.name:SetText(entry.recipe.name)
            local shade = entry.offerable and 1 or 0.55
            row.name:SetTextColor(shade, shade, shade)
        else
            row.name:SetText(entry.hint or entry.text)
            local c = entry.hint and ui.colors.orange or (entry.depth == 0 and ui.colors.gold or ui.colors.lightGold)
            row.name:SetTextColor(c[1], c[2], c[3])
        end
        row.info:SetText(info)
        row.info:SetTextColor(color[1], color[2], color[3])
        row:Show()
    end
    -- Rows may have different heights (hints); stack them.
    local y = 0
    for index, entry in ipairs(entries) do
        local row = frame.rows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", frame.content, "RIGHT")
        y = y + (entry.hint and 40 or 24)
    end
    for index = #entries + 1, #frame.rows do frame.rows[index]:Hide() end
    frame.content:SetHeight(math.max(10, y))
    frame.total:SetText(t("offerRecipesCount"):format(total))
end

-- Own templates ----------------------------------------------------------------------------------------
local manager
function UI.showTemplates()
    if not manager then
        manager = CreateFrame("Frame", "ForeverCraftOfferTemplates", UIParent, "PortraitFrameTemplate")
        manager:SetSize(640, 420)
        manager:SetPoint("CENTER", 60, -30)
        manager:SetFrameStrata("DIALOG")
        manager:SetToplevel(true)
        manager:SetClampedToScreen(true)
        manager:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
        tinsert(UISpecialFrames, "ForeverCraftOfferTemplates")
        local list = ui.panel(manager)
        list:SetPoint("TOPLEFT", 14, -60)
        list:SetPoint("BOTTOMLEFT", 14, 50)
        list:SetWidth(200)
        manager.rows = {}
        manager.list = list
        manager.empty = ui.text(list, "GameFontDisable")
        manager.empty:SetPoint("TOPLEFT", 12, -12)
        local editor = ui.panel(manager)
        editor:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
        editor:SetPoint("BOTTOMRIGHT", -14, 50)
        manager.nameLabel = ui.text(editor, "GameFontNormalSmall")
        manager.nameLabel:SetPoint("TOPLEFT", 14, -12)
        manager.name = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        manager.name:SetHeight(22)
        manager.name:SetPoint("TOPLEFT", 18, -28)
        manager.name:SetPoint("RIGHT", editor, "RIGHT", -14, 0)
        manager.name:SetAutoFocus(false)
        manager.name:SetMaxLetters(40)
        local box = ui.panel(editor)
        box:SetPoint("TOPLEFT", 10, -58)
        box:SetPoint("BOTTOMRIGHT", -10, 70)
        local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)
        manager.text = CreateFrame("EditBox", nil, scroll)
        manager.text:SetMultiLine(true)
        manager.text:SetAutoFocus(false)
        manager.text:SetFontObject(GameFontHighlight)
        manager.text:SetWidth(330)
        manager.text:SetScript("OnEscapePressed", manager.text.ClearFocus)
        scroll:SetScrollChild(manager.text)
        manager.help = ui.text(editor, "GameFontHighlightSmall", "LEFT", { 0.80, 0.72, 0.59 })
        manager.help:SetPoint("BOTTOMLEFT", 14, 12)
        manager.help:SetPoint("RIGHT", editor, "RIGHT", -14, 0)
        manager.help:SetWordWrap(true)
        local function selected()
            for _, template in ipairs(templates()) do
                if template.id == manager.selected then return template end
            end
        end
        manager.newButton = button(manager, "", 90, function()
            local id = tostring(time()) .. "-" .. math.random(1000, 9999)
            templates()[#templates() + 1] = { id = id, name = t("templateDefaultName"), text = UI.message() }
            manager.selected = id
            UI.showTemplates()
        end)
        manager.newButton:SetPoint("BOTTOMLEFT", 14, 16)
        manager.duplicate = button(manager, "", 90, function()
            local template = selected()
            if not template then return end
            local id = tostring(time()) .. "-" .. math.random(1000, 9999)
            templates()[#templates() + 1] = { id = id, name = template.name .. " (2)", text = template.text }
            manager.selected = id
            UI.showTemplates()
        end)
        manager.duplicate:SetPoint("LEFT", manager.newButton, "RIGHT", 6, 0)
        manager.delete = button(manager, "", 90, function()
            for index, template in ipairs(templates()) do
                if template.id == manager.selected then table.remove(templates(), index) break end
            end
            manager.selected = nil
            UI.showTemplates()
            UI.changed()
        end)
        manager.delete:SetPoint("LEFT", manager.duplicate, "RIGHT", 6, 0)
        manager.save = button(manager, "", 110, function()
            local template = selected()
            if not template then return end
            local name = manager.name:GetText():gsub("^%s+", ""):gsub("%s+$", "")
            template.name = name ~= "" and name or template.name
            -- Own texts are stored exactly as written (never translated or changed).
            template.text = manager.text:GetText()
            UI.showTemplates()
            UI.changed()
        end)
        manager.save:SetPoint("BOTTOMRIGHT", -14, 16)
    end
    manager:SetTitle(t("templatesTitle"))
    manager.nameLabel:SetText(t("templateName"))
    manager.help:SetText(t("templatePlaceholders"))
    manager.empty:SetText(t("templateNone"))
    manager.newButton:Fit(t("templateNew"))
    manager.duplicate:Fit(t("templateDuplicate"))
    manager.delete:Fit(t("templateDelete"))
    manager.save:Fit(t("templateSave"))
    local list = templates()
    if not manager.selected and list[1] then manager.selected = list[1].id end
    manager.empty:SetShown(#list == 0)
    for index, template in ipairs(list) do
        local row = manager.rows[index]
        if not row then
            row = CreateFrame("Button", nil, manager.list)
            row:SetHeight(24)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.active = row:CreateTexture(nil, "BACKGROUND")
            row.active:SetAllPoints()
            row.active:SetColorTexture(0.36, 0.24, 0.10, 0.8)
            row.label = ui.text(row, "GameFontHighlight")
            row.label:SetPoint("LEFT", 8, 0)
            row.label:SetPoint("RIGHT", -8, 0)
            row:SetScript("OnClick", function(self) manager.selected = self.id; UI.showTemplates() end)
            manager.rows[index] = row
        end
        row.id = template.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, -8 - (index - 1) * 26)
        row:SetPoint("RIGHT", manager.list, "RIGHT", -6, 0)
        row.label:SetText(template.name)
        row.active:SetShown(template.id == manager.selected)
        row:Show()
        if template.id == manager.selected then
            manager.name:SetText(template.name)
            manager.text:SetText(template.text or "")
        end
    end
    for index = #list + 1, #manager.rows do manager.rows[index]:Hide() end
    local has = manager.selected ~= nil and #list > 0
    manager.duplicate:SetEnabled(has)
    manager.delete:SetEnabled(has)
    manager.save:SetEnabled(has)
    manager.name:SetEnabled(has)
    manager:Show()
    manager:Raise()
end

-- Buttons in the crafting log of the professions window ---------------------------------------------------
-- "Configure offer" opens the existing offer window; "Offer crafting" posts the saved offer
-- (the active profile) with one click. Every post needs this click (hardware event); the
-- cooldown, channel check, optional confirmation and echo check of UI.post stay as they are.
local function savedConfig()
    local data = store()
    local config = data.active and data.profiles[data.active] or data.last
    if not config then return nil end
    local ok, message = pcall(UI.message, config)
    message = ok and offers.sanitize(message or "") or ""
    if message == "" or not offers.split(message) then return nil end
    return config, message
end
UI.savedConfig = savedConfig

local function clock(seconds)
    return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Current state of the post button: ready, setup, wait, nochannel, posted.
function UI.postState()
    local config = savedConfig()
    if not config then return "setup" end
    if UI.confirmedAt and GetTime() - UI.confirmedAt < 20 then return "posted", config end
    local remaining = UI.remaining()
    if remaining > 0 then return "wait", config, remaining end
    local chatType = UI.resolveChannel(config.channel or "trade")
    if not chatType then return "nochannel", config end
    return "ready", config
end

local function actionButton(parent, primary)
    local control = CreateFrame("Button", nil, parent, "BackdropTemplate")
    control:SetHeight(primary and 58 or 52)
    control:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, tile = true, tileSize = 64,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    control:SetBackdropColor(0.32, 0.22, 0.13, 1)
    if primary then control:SetBackdropBorderColor(1, 0.8, 0.32) else control:SetBackdropBorderColor(0.62, 0.45, 0.24) end
    local shade = control:CreateTexture(nil, "BORDER")
    shade:SetPoint("TOPLEFT", 3, -3)
    shade:SetPoint("BOTTOMRIGHT", -3, 3)
    shade:SetColorTexture(1, 1, 1, 1)
    if CreateColor then
        shade:SetGradient("HORIZONTAL", CreateColor(0.10, 0.07, 0.04, 0.55), CreateColor(0.10, 0.07, 0.04, 0.05))
    else
        shade:SetColorTexture(0.10, 0.07, 0.04, 0.3)
    end
    local glow = control:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetPoint("TOPLEFT", 3, -3)
    glow:SetPoint("BOTTOMRIGHT", -3, 3)
    glow:SetColorTexture(1, 0.8, 0.3, primary and 0.14 or 0.1)
    glow:Hide()
    control.glow = glow
    control.icon = control:CreateTexture(nil, "ARTWORK", nil, 2)
    control.icon:SetSize(primary and 38 or 34, primary and 38 or 34)
    control.icon:SetPoint("LEFT", 10, 0)
    control.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    control.title = control:CreateFontString(nil, "OVERLAY", primary and "GameFontNormalLarge" or "GameFontNormal")
    control.title:SetPoint("TOPLEFT", control.icon, "TOPRIGHT", 10, -2)
    control.title:SetPoint("RIGHT", -10, 0)
    control.title:SetJustifyH("LEFT")
    control.title:SetWordWrap(false)
    control.sub = control:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.sub:SetPoint("TOPLEFT", control.title, "BOTTOMLEFT", 0, -3)
    control.sub:SetPoint("RIGHT", -10, 0)
    control.sub:SetJustifyH("LEFT")
    control.sub:SetWordWrap(false)
    control.sub:SetTextColor(0.9, 0.83, 0.68)
    control:HookScript("OnEnter", function(self) self.glow:Show() end)
    control:HookScript("OnLeave", function(self) self.glow:Hide(); GameTooltip:Hide() end)
    return control
end

local function postSaved()
    local config, message = savedConfig()
    if not config then UI.open(); return end
    UI.post(message, config.channel or "trade")
    UI.refreshPanel()
end

local function previewMessage()
    local config, message = savedConfig()
    if not config then UI.open(); return end
    print("ForeverCraft · " .. t("offerMenuPreview") .. ": " .. message)
end

function addon.AttachOfferButtons(column)
    if UI.postButton or not column then return end
    local configure = actionButton(column, false)
    configure:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 12, 82)
    configure:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", -12, 82)
    configure.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    configure:SetScript("OnClick", function() if UI.window and UI.window:IsShown() then UI.window:Hide() else UI.open() end end)
    configure:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t("offerConfigure"))
        GameTooltip:AddLine(t("offerTooltip"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local post = actionButton(column, true)
    post:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 12, 16)
    post:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", -12, 16)
    post.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    post:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    post:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            local entries = { { t("offerConfigure"), UI.open } }
            local names = {}
            for name in pairs(store().profiles) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                local active = store().active == name
                entries[#entries + 1] = { t("offerMenuProfile"):format((active and "|cff73dc73" or "") .. name .. (active and "|r" or "")),
                    function() store().active = name; UI.refreshAll(); UI.refreshPanel() end }
            end
            entries[#entries + 1] = { t("offerMenuPreview"), previewMessage }
            entries[#entries + 1] = { t("offerMenuPost"), postSaved }
            ui.contextMenu(self, entries)
            return
        end
        postSaved()
    end)
    post:SetScript("OnEnter", function(self)
        local config, message = savedConfig()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t("offerButton"))
        if config then
            local _, _, label = UI.resolveChannel(config.channel or "trade")
            GameTooltip:AddDoubleLine(t("offerTipProfile"), store().active or "–", 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddDoubleLine(t("offerTipChannel"), label or t("offerStateNoChannel"), 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(message, 0.93, 0.87, 0.74, true)
        else
            GameTooltip:AddLine(t("offerStateSetup"), 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(t("offerTipClicks"), 0.62, 0.57, 0.5, true)
        GameTooltip:Show()
    end)
    column:HookScript("OnShow", function() UI.refreshPanel() end)
    UI.configButton, UI.postButton = configure, post
    -- Channel availability changes when entering or leaving a city.
    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "CHANNEL_UI_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do pcall(watcher.RegisterEvent, watcher, event) end
    watcher:SetScript("OnEvent", function() if post:IsVisible() then UI.refreshPanel() end end)
    UI.refreshPanel()
end

function UI.refreshPanel()
    local configure, post = UI.configButton, UI.postButton
    if not post then return end
    configure.title:SetText(t("offerConfigure"))
    configure.sub:SetText(t("offerConfigureSub"))
    post.title:SetText(t("offerButton"))
    local state, config, remaining = UI.postState()
    local subtitle
    if state == "setup" then subtitle = t("offerStateSetup")
    elseif state == "wait" then subtitle = t("offerStateWait"):format(clock(remaining))
    elseif state == "posted" then subtitle = t("offerStatePosted")
    elseif state == "nochannel" then
        subtitle = (config.channel or "trade") == "trade" and t("offerStateNoTrade") or t("offerStateNoChannel")
    else
        local _, _, label = UI.resolveChannel(config.channel or "trade")
        subtitle = (config.channel or "trade") == "trade" and t("offerStateTrade") or t("offerStateChannel"):format(label or "")
    end
    post.sub:SetText(subtitle)
    local ready = state == "ready" or state == "setup"
    post.title:SetTextColor(ready and 1 or 0.75, ready and 0.82 or 0.68, ready and 0 or 0.5)
    post.icon:SetDesaturated(state == "wait" or state == "nochannel")
    if state == "posted" then post.sub:SetTextColor(0.45, 0.86, 0.45) else post.sub:SetTextColor(0.9, 0.83, 0.68) end
end

-- Settings hooks (Core.lua settings page).
function UI.cycle(key, values, fallback)
    local current = ForeverCraftDB[key] or fallback
    for index, value in ipairs(values) do
        if value == current then ForeverCraftDB[key] = values[index % #values + 1]; return end
    end
    ForeverCraftDB[key] = values[1]
end

function UI.labelFor(key)
    if key == "offerCondition" then return t("cond_" .. (ForeverCraftDB.offerCondition or "matsTip")) end
    if key == "offerChannel" then return t("channel_" .. (ForeverCraftDB.offerChannel or "trade")) end
    if key == "offerLanguage" then
        local code = ForeverCraftDB.offerLanguage or "auto"
        return code == "auto" and t("offerLanguageAuto") or addon.languageNames[code] or code
    end
    if key == "offerTemplate" then return t("template_" .. (ForeverCraftDB.offerTemplate or "casual")) end
end
