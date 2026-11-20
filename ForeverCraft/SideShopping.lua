local _, addon = ...
local panel, host, mode
local rows = {}

function addon.HideUnusedScrollbar(scroll)
    local function update(self)
        if self.ScrollBar then self.ScrollBar:SetShown(self:GetVerticalScrollRange() > 0.5) end
    end
    scroll:HookScript("OnScrollRangeChanged", update)
    scroll:HookScript("OnShow", update)
    update(scroll)
end

function addon.CreateMaterialBranch(parent, anchor, point)
    local stem = parent:CreateTexture(nil, "ARTWORK")
    stem:SetColorTexture(0.64, 0.48, 0.28, 0.8)
    stem:SetSize(1, 8)
    stem:SetPoint("TOPLEFT", anchor, point, -10, 0)
    local elbow = parent:CreateTexture(nil, "ARTWORK")
    elbow:SetColorTexture(0.64, 0.48, 0.28, 0.8)
    elbow:SetSize(7, 1)
    elbow:SetPoint("BOTTOMLEFT", stem, "BOTTOMLEFT")
    return stem, elbow
end

local function searchAuction(itemID)
    if mode ~= "auction" or not host or not host:IsVisible() then return end
    local searchBar = host.SearchBar
    local name = C_Item.GetItemNameByID(itemID)
    if not name or not searchBar or not searchBar.StartSearch then return end

    if host.GetCategoriesList then host:GetCategoriesList():SetSelectedCategory(nil) end
    if host.SetDisplayMode and AuctionHouseFrameDisplayMode then
        host:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
    end
    if searchBar.FilterButton and searchBar.FilterButton.Reset then searchBar.FilterButton:Reset() end
    searchBar:SetSearchText(name)
    searchBar:StartSearch()
end

local pendingPurchase

local function merchantOffers()
    local offers = {}
    for index = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(index)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
            local info = C_MerchantFrame.GetItemInfo(index)
            if info then
                local standard = info.isPurchasable and not info.hasExtendedCost and not info.currencyID
                if not offers[id] or standard and not offers[id].standard then
                    offers[id] = { index = index, info = info, standard = standard }
                end
            end
        end
    end
    return offers
end

local function purchasableQuantity(offer, missing)
    if not offer or not offer.standard then return 0 end
    local info = offer.info
    local bundle = math.max(1, info.stackCount)
    local limit = math.min(missing, GetMerchantItemMaxStack(offer.index) or 0)
    if info.numAvailable >= 0 then limit = math.min(limit, info.numAvailable) end
    if info.price > 0 then limit = math.min(limit, math.floor(GetMoney() / info.price) * bundle) end
    return math.floor(limit / bundle) * bundle
end

local function currentPurchase(row)
    if pendingPurchase or mode ~= "merchant" or not host or not host:IsVisible() then return end
    local _, sections = addon.GetShoppingLines(ForeverCraftShopping)
    local missing = 0
    for _, section in ipairs(sections) do
        if section.id == row.professionID then
            for index, id in ipairs(section.itemIDs) do
                if id == row.itemID then missing = section.quantities[index] end
            end
            break
        end
    end
    local offer = merchantOffers()[row.itemID]
    local amount = purchasableQuantity(offer, missing)
    if amount == 0 then return end
    return offer, amount, math.ceil(offer.info.price * amount / math.max(1, offer.info.stackCount))
end

local function confirmPurchase(row)
    local offer, amount, price = currentPurchase(row)
    if not offer or amount ~= row.amount or price ~= row.price then return end
    pendingPurchase = true
    BuyMerchantItem(offer.index, amount)
    C_Timer.After(0.8, function()
        pendingPurchase = false
        local _, current = addon.GetShoppingLines(ForeverCraftShopping)
        addon.RefreshSideShopping(current)
    end)
end

StaticPopupDialogs["FOREVERCRAFT_CONFIRM_MERCHANT_BUY"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) confirmPurchase(data) end,
}

local function formatMerchantPrice(copper)
    if GetMoneyString then return GetMoneyString(copper) end
    return addon.GetText().merchantPriceFallback:format(
        math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function buyFromList(row)
    local offer, amount, price = currentPurchase(row)
    if not offer then return end
    local name = C_Item.GetItemNameByID(row.itemID) or offer.info.name or ("#" .. row.itemID)
    local text = addon.GetText().confirmMerchantBuy:format(amount, name, formatMerchantPrice(price))
    StaticPopup_Show("FOREVERCRAFT_CONFIRM_MERCHANT_BUY", text, nil, {
        itemID = row.itemID, professionID = row.professionID, amount = amount, price = price,
    })
end

local function makeRow()
    local row = CreateFrame("Frame", nil, panel.content)
    row:SetHeight(23)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.title:SetPoint("LEFT", 4, 0)
    row.branchStem, row.branchElbow = addon.CreateMaterialBranch(row, row.title, "TOPLEFT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)
    row.search = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.search:SetSize(42, 19)
    row.search:SetPoint("RIGHT", -2, 0)
    local lens = row.search:CreateTexture(nil, "OVERLAY")
    lens:SetSize(15, 15)
    lens:SetPoint("CENTER")
    lens:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    row.search:SetScript("OnClick", function() searchAuction(row.itemID) end)
    row.search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(addon.GetText().searchAuction)
        GameTooltip:Show()
    end)
    row.search:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.buy:SetSize(72, 19)
    row.buy:SetPoint("RIGHT", -2, 0)
    row.buy:SetScript("OnClick", function() buyFromList(row) end)
    local heading = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.heading = heading
    heading:SetHeight(18)
    heading:SetPoint("LEFT", 23, 0)
    heading:SetPoint("RIGHT", -2, 0)
    heading:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    heading:SetBackdropColor(0.14, 0.085, 0.038, 1)
    heading:SetBackdropBorderColor(0.33, 0.24, 0.14, 1)
    heading.title = heading:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading.title:SetPoint("LEFT", 5, 0)
    heading.title:SetPoint("RIGHT", -5, 0)
    heading.title:SetJustifyH("LEFT")
    heading.title:SetWordWrap(false)
    return row
end

function addon.RefreshSideShopping(sections)
    if not panel or not panel:IsVisible() then return end
    local L = addon.GetText()
    panel:SetTitle(addon.HeaderTitle(L.sideShopping))
    local count = 0
    local offers = mode == "merchant" and merchantOffers() or {}
    local function addRow(text, icon, itemID, missing, professionID, alternative)
        count = count + 1
        local row = rows[count] or makeRow()
        rows[count] = row
        row.itemID, row.professionID = itemID, professionID
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -(count - 1) * 23)
        row:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", 0, -(count - 1) * 23)
        row.icon:SetTexture(icon)
        row.icon:SetShown(icon ~= nil)
        row.title:SetPoint("LEFT", icon and 24 or (alternative and 23 or itemID and 12 or 4), 0)
        row.title:SetText(text)
        row.branchStem:SetShown(alternative == true)
        row.branchElbow:SetShown(alternative == true)
        row.title:SetShown(not icon)
        row.heading:SetShown(icon ~= nil)
        if icon then row.heading.title:SetText(text) end
        local offer = itemID and offers[itemID]
        local buying = mode == "merchant" and itemID ~= nil
        local canBuy = buying and purchasableQuantity(offer, missing) or 0
        if buying and (not offer or offer.info.numAvailable == 0) then
            row.title:SetTextColor(0.48, 0.46, 0.43)
        elseif alternative then
            row.title:SetTextColor(0.78, 0.66, 0.49)
        else
            row.title:SetTextColor(1, 1, 1)
        end
        row.buy:SetShown(buying)
        row.buy:SetText(canBuy > 0 and L.buyQuantity:format(canBuy) or L.buyUnavailable)
        row.buy:SetEnabled(canBuy > 0 and not pendingPurchase)
        local searchable = mode == "auction" and itemID ~= nil and host.SearchBar and host.SearchBar.StartSearch
        row.search:SetShown(searchable and true or false)
        row.search:SetEnabled(itemID and C_Item.GetItemNameByID(itemID) ~= nil or false)
        row.title:SetPoint("RIGHT", buying and -78 or searchable and -48 or -4, 0)
        row:Show()
    end

    for _, section in ipairs(sections) do
        local icon = section.id > 0 and C_TradeSkillUI.GetTradeSkillTexture(section.id)
        addRow(section.name, icon or "Interface\\Icons\\INV_Misc_Bag_10")
        for index, text in ipairs(section.rows) do
            addRow(text, nil, section.itemIDs[index], section.quantities[index], section.id)
            local alternative = section.alternatives[index]
            if alternative then
                local materials = section.alternativeItems[index]
                if materials and #materials > 0 then
                    for _, material in ipairs(materials) do
                        addRow(material.text, nil, mode == "auction" and material.id or nil, nil, nil, true)
                    end
                else
                    addRow(alternative, nil, nil, nil, nil, true)
                end
            end
        end
    end
    if count == 0 then addRow(L.sideShoppingEmpty) end
    for index = count + 1, #rows do rows[index]:Hide() end
    panel.content:SetHeight(count * 23)
    panel.scroll:SetVerticalScroll(math.min(panel.scroll:GetVerticalScroll(), panel.scroll:GetVerticalScrollRange()))
end

function addon.OpenSideShopping(kind)
    local owner = kind == "auction" and _G.AuctionHouseFrame or kind == "merchant" and _G.MerchantFrame
    if not owner or not owner:IsVisible() then return false end
    if not panel then
        panel = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
        addon.AddSettingsGear(panel)
        panel:Hide()
        panel:SetSize(330, 300)
        panel:SetPortraitToAsset("Interface\\AddOns\\ForeverCraft\\Art\\ForeverCraftIcon")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)

        local inset = CreateFrame("Frame", nil, panel)
        inset:SetPoint("TOPLEFT", 8, -51)
        inset:SetPoint("BOTTOMRIGHT", -8, 8)
        local base = inset:CreateTexture(nil, "BACKGROUND")
        base:SetAllPoints()
        base:SetColorTexture(33 / 255, 25 / 255, 19 / 255, 1)
        local artwork = inset:CreateTexture(nil, "BACKGROUND", nil, 1)
        artwork:SetTexture("Interface\\AddOns\\ForeverCraft\\Art\\TradingLedger")
        artwork:SetSize(245, 74)
        artwork:SetPoint("BOTTOMRIGHT", -2, 2)

        local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
        panel.scroll = scroll
        scroll:SetPoint("TOPLEFT", 4, -6)
        scroll:SetPoint("BOTTOMRIGHT", -21, 5)
        local content = CreateFrame("Frame", nil, scroll)
        panel.content = content
        content:SetSize(230, 1)
        scroll:SetScrollChild(content)
        addon.HideUnusedScrollbar(scroll)
        scroll:HookScript("OnSizeChanged", function(self) content:SetWidth(self:GetWidth()) end)
    end
    if not owner.ForeverCraftSideShoppingHook then
        owner.ForeverCraftSideShoppingHook = true
        owner:HookScript("OnHide", function(self)
            if host == self then panel:Hide() end
        end)
    end
    host, mode = owner, kind
    panel:ClearAllPoints()
    panel:SetHeight(math.max(190, math.min(390, owner:GetHeight())))
    local ownerScale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = (owner:GetRight() or 0) * ownerScale
    local left = (owner:GetLeft() or 0) * ownerScale
    if UIParent:GetWidth() - right < panel:GetWidth() + 8 and left > UIParent:GetWidth() - right then
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
    else
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0)
    end
    panel:Show()
    return true
end

function addon.CloseSideShopping(kind)
    if panel and mode == kind then panel:Hide() end
    if kind == "merchant" then StaticPopup_Hide("FOREVERCRAFT_CONFIRM_MERCHANT_BUY") end
end
