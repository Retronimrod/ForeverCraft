-- Luacheck-Konfiguration fuer ForeverCraft (WoW Forever, Interface 16001, Lua 5.1).
-- Globals wurden aus den tatsaechlich im Code referenzierten Namen abgeleitet
-- (luacheck-Lauf vom 2026-11-25), nicht geraten.
std = "lua51"

exclude_files = {
    ".git/**",
    ".claude-context/**",
    -- Standalone Lua test harnesses (run via plain `lua`, not shipped with the addon);
    -- they intentionally stub WoW API globals, which trips "read-only global" checks.
    "tools/test_*.lua",
}

-- Blizzard-WoW-API, Lua-Erweiterungen und optionale Fremd-Addons (AucAdvanced/Auctionator),
-- die dieses Addon lesend verwendet.
read_globals = {
    "ACCEPT", "AucAdvanced", "AuctionHouseFrameDisplayMode", "Auctionator", "BuyMerchantItem",
    "CANCEL", "C_AddOns", "C_Bank", "GetNormalizedRealmName", "MenuResponse", "UNKNOWNOBJECT", "UnitFullName", "AutoLootMailItem", "C_AuctionHouse", "C_QuestLog", "GetInboxHeaderInfo", "GetInboxInvoiceInfo", "GetSendMailMoney", "GetSendMailPrice", "IsTradeskillTrainer", "RepairAllItems", "SendMail", "TakeInboxMoney", "CLASS_ICON_TCOORDS", "GetRealmName", "ITEM_QUALITY_COLORS", "PanelTemplates_DeselectTab", "PanelTemplates_SelectTab", "PanelTemplates_SetNumTabs", "PanelTemplates_TabResize", "PanelTemplates_SetTab", "RAID_CLASS_COLORS", "UISpecialFrames", "UnitClass", "UnitLevel", "UnitName", "tinsert", "unpack", "C_Browser", "C_CVar", "C_Container", "C_Item", "C_MerchantFrame", "C_Spell",
    "C_SpellBook", "C_Timer", "C_TradeSkillUI", "ClearOverrideBindings", "CreateColor",
    "CreateFrame", "CreateMacro", "Enum", "GREEN_FONT_COLOR", "GameFontHighlight",
    "GameFontNormal", "GameTooltip", "GetBindingAction", "GetBindingKey", "GetBindingText",
    "GetCurrentBindingSet", "GetCursorInfo", "GetDetailedItemLevelInfo", "GetInventoryItemLink", "GetInventoryItemQuality", "GetLocale", "GetLootSlotInfo", "GetLootSlotLink",
    "GetMacroBody", "GetMacroIndexByName", "GetMerchantItemLink", "GetMerchantItemMaxStack",
    "GetMerchantNumItems", "GetMoney", "GetMoneyString", "GetNumLootItems", "GetProfessionInfo",
    "GetProfessions", "GetTime", "INTERRUPTED", "ItemRefTooltip", "InCombatLockdown", "IsAltKeyDown",
    "IsControlKeyDown", "IsFishingLoot", "IsPlayerSpell", "IsShiftKeyDown", "ItemLocation",
    "LibStub", "LootFrame", "LootSlot", "MerchantFrame", "NUM_BAG_SLOTS", "PickupMacro",
    "Professions", "RED_FONT_COLOR", "RegisterStateDriver", "SPELL_FAILED_INTERRUPTED",
    "SaveBindings", "SecondsToTime", "SetBinding", "SetOverrideBinding",
    "SetOverrideBindingClick", "SpellIsTargeting", "StaticPopup_Hide", "StaticPopup_Show",
    "TooltipDataProcessor", "UIParent", "UnitCastingInfo", "UnitChannelInfo", "UnitFactionGroup",
    "UpdateUIPanelPositions", "date", "hooksecurefunc", "issecretvalue", "time", "wipe",
}

-- Vom Addon selbst gesetzte globale Namen (SavedVariables, Slash-Befehle, Bindings).
globals = {
    "ForeverCraftDB", "ForeverCraftDisenchantLog", "ForeverCraftInventory", "ForeverCraftFinance", "SLASH_FOREVERCRAFTBANK1", "SLASH_FOREVERCRAFTFINANCE1", "ForeverCraftIntermediateRecipes",
    "ForeverCraftShopping", "ForeverCraftWorkshopLog", "BINDING_HEADER_FOREVERCRAFT",
    "SLASH_FOREVERCRAFT1", "SLASH_FOREVERCRAFTLIST1", "StaticPopupDialogs",
}

-- Lokalisierungskataloge: lange Zeilen durch uebersetzte Strings sind hier unvermeidbar.
files["ForeverCraft/Locale.lua"] = { max_line_length = false }
files["ForeverCraft/ClientLocales.lua"] = { max_line_length = false }
