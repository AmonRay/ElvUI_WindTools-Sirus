local W = unpack((select(2, ...))) ---@class WindTools

local _G = _G
local Compatibility = {}

local function fallbackNoop()
	return nil
end

local function fallbackFalse()
	return false
end

local function bind(namespace, method, fallback)
	local api = _G[namespace]
	return api and type(api[method]) == "function" and api[method] or fallback or fallbackNoop
end

local function namespaceMethod(namespace, method)
	local api = _G[namespace]
	return api and not api.__WTPlaceholder and type(api[method]) == "function" and api[method]
end

-- Capture capabilities before placeholders are installed.
local function isNativeNamespace(name)
	local api = _G[name]
	return type(api) == "table"
end

local nativeTimerAPI = (_G.WindToolsPreflight and _G.WindToolsPreflight.HasTimerAPI) or (isNativeNamespace("C_Timer") and type(_G.C_Timer.NewTicker) == "function")
local nativeMapAPI = isNativeNamespace("C_Map") and type(_G.C_Map.GetBestMapForUnit) == "function"
local nativeQuestAPI = isNativeNamespace("C_QuestLog") and type(_G.C_QuestLog.GetInfo) == "function"
local nativeTooltipAPI = type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
local nativeContainerAPI = isNativeNamespace("C_Container")
local nativeItemAPI = isNativeNamespace("C_Item")
local nativeSpellAPI = isNativeNamespace("C_Spell")
local nativeChallengeAPI = isNativeNamespace("C_ChallengeMode")
local nativeMythicPlusAPI = isNativeNamespace("C_MythicPlus")
local nativeBattleNetAPI = isNativeNamespace("C_BattleNet")
local nativeClubAPI = isNativeNamespace("C_Club")
local nativeCollectionsAPI = isNativeNamespace("C_MountJournal") or isNativeNamespace("C_ToyBox")

-- Retail namespaces are optional on Wrath. Keep real client implementations intact;
-- missing methods become inert functions so addon files can still be parsed/loaded.
-- Kept as documentation for the audited optional API families.
local optionalNamespaces = {
	"C_AddOns", "C_UI", "C_PartyInfo", "C_Container", "C_Item", "C_CVar", "C_Spell",
	"C_SpellBook", "C_QuestLog", "C_Map", "C_MapExplorationInfo", "C_SuperTrack", "C_Navigation",
	"C_TaskQuest", "C_VignetteInfo", "C_ChallengeMode", "C_MythicPlus", "C_PlayerInfo", "C_TooltipInfo",
	"C_CurrencyInfo", "C_EquipmentSet", "C_MountJournal", "C_ToyBox", "C_BattleNet", "C_Club",
	"C_GuildInfo", "C_FriendList", "C_ChatInfo", "C_ChatBubbles", "C_Texture", "C_CreatureInfo",
	"C_SpecializationInfo", "C_Soulbinds", "C_GossipInfo", "C_Minimap", "C_QuestInfoSystem",
	"C_AchievementInfo", "C_ContentTracking", "C_ScenarioInfo", "C_RestrictedActions", "C_Transmog", "C_ClassColor", "C_SummonInfo", "C_LFGList", "C_Covenants", "C_Garrison", "C_Housing", "C_PetJournal",
}

Compatibility.IsAddOnLoaded = bind("C_AddOns", "IsAddOnLoaded", _G.IsAddOnLoaded)
Compatibility.GetAddOnMetadata = bind("C_AddOns", "GetAddOnMetadata", _G.GetAddOnMetadata)
Compatibility.DoesAddOnExist = bind("C_AddOns", "DoesAddOnExist", _G.DoesAddOnExist)
Compatibility.DisableAddOn = bind("C_AddOns", "DisableAddOn", _G.DisableAddOn)
Compatibility.EnableAddOn = bind("C_AddOns", "EnableAddOn", _G.EnableAddOn)
Compatibility.GetNumAddOns = bind("C_AddOns", "GetNumAddOns", _G.GetNumAddOns)
Compatibility.GetAddOnInfo = bind("C_AddOns", "GetAddOnInfo", _G.GetAddOnInfo)
Compatibility.ReloadUI = bind("C_UI", "Reload", _G.ReloadUI)
Compatibility.InviteUnit = bind("C_PartyInfo", "InviteUnit", _G.InviteUnit)
Compatibility.GetContainerNumSlots = bind("C_Container", "GetContainerNumSlots", _G.GetContainerNumSlots)
Compatibility.GetContainerItemID = bind("C_Container", "GetContainerItemID", _G.GetContainerItemID)
Compatibility.GetContainerItemLink = bind("C_Container", "GetContainerItemLink", _G.GetContainerItemLink)
Compatibility.GetContainerNumFreeSlots = bind("C_Container", "GetContainerNumFreeSlots", _G.GetContainerNumFreeSlots)
Compatibility.UseContainerItem = bind("C_Container", "UseContainerItem", _G.UseContainerItem)
Compatibility.GetItemInfo = bind("C_Item", "GetItemInfo", _G.GetItemInfo)
Compatibility.GetItemInfoInstant = bind("C_Item", "GetItemInfoInstant", _G.GetItemInfoInstant)
Compatibility.GetItemCount = bind("C_Item", "GetItemCount", _G.GetItemCount)
Compatibility.GetItemCooldown = bind("C_Item", "GetItemCooldown", _G.GetItemCooldown)
Compatibility.GetItemQualityColor = bind("C_Item", "GetItemQualityColor", function() return nil end)
Compatibility.GetDetailedItemLevelInfo = bind("C_Item", "GetDetailedItemLevelInfo", _G.GetDetailedItemLevelInfo)
Compatibility.GetItemIconByID = bind("C_Item", "GetItemIconByID", function(itemID)
	local _, _, _, _, _, _, _, _, _, icon = Compatibility.GetItemInfo(itemID)
	return icon
end)
Compatibility.GetCVar = bind("C_CVar", "GetCVar", _G.GetCVar)
Compatibility.GetCVarBool = bind("C_CVar", "GetCVarBool", function(name)
	return Compatibility.GetCVar(name) == "1"
end)
Compatibility.SetCVar = bind("C_CVar", "SetCVar", _G.SetCVar)
Compatibility.GetSpellInfo = bind("C_Spell", "GetSpellInfo", _G.GetSpellInfo)
Compatibility.GetSpellTexture = bind("C_Spell", "GetSpellTexture", _G.GetSpellTexture)
Compatibility.GetSpellLink = bind("C_Spell", "GetSpellLink", _G.GetSpellLink)
Compatibility.IsAddOnRestrictionActive = bind("C_RestrictedActions", "IsAddOnRestrictionActive", fallbackFalse)

Compatibility.ChatInfo = _G.C_ChatInfo
Compatibility.SendAddonMessage = namespaceMethod("C_ChatInfo", "SendAddonMessage") or _G.SendAddonMessage
Compatibility.RegisterAddonMessagePrefix = namespaceMethod("C_ChatInfo", "RegisterAddonMessagePrefix") or _G.RegisterAddonMessagePrefix
Compatibility.SendChatMessage = namespaceMethod("C_ChatInfo", "SendChatMessage") or _G.SendChatMessage

Compatibility.AuraUtil = _G.AuraUtil
Compatibility.HasModernAuraUtil = type(Compatibility.AuraUtil) == "table"
Compatibility.HasTimerAPI = nativeTimerAPI
Compatibility.HasModernContainers = nativeContainerAPI
Compatibility.HasModernItemAPI = nativeItemAPI
Compatibility.HasModernSpellAPI = nativeSpellAPI
Compatibility.HasLegacyQuestAPI = type(_G.GetNumQuestLogEntries) == "function"
Compatibility.HasLegacyTooltipAPI = type(_G.GameTooltip) == "table"
Compatibility.HasModernMapAPI = nativeMapAPI
Compatibility.HasModernQuestAPI = nativeQuestAPI
Compatibility.HasTooltipDataProcessor = nativeTooltipAPI
Compatibility.HasChallengeModeAPI = nativeChallengeAPI
Compatibility.HasMythicPlusAPI = nativeMythicPlusAPI
Compatibility.HasBattleNetAPI = nativeBattleNetAPI
Compatibility.HasClubAPI = nativeClubAPI
Compatibility.HasModernSocialAPI = Compatibility.HasBattleNetAPI or Compatibility.HasClubAPI
Compatibility.HasModernUnitAPI = type(_G.UnitHealthPercent) == "function" and type(_G.UnitGetTotalAbsorbs) == "function"
Compatibility.HasModernCollectionsAPI = nativeCollectionsAPI
Compatibility.HasModernSettingsAPI = type(_G.Settings) == "table"
Compatibility.HasModernCinematicAPI = type(_G.EventRegistry) == "table" and type(_G.MovieFrame_PlayMovie) == "function" and type(_G.Enum) == "table" and type(_G.Enum.CinematicType) == "table"
Compatibility.HasSpellActivationOverlay = type(_G.SpellActivationOverlayFrame) == "table" and type(_G.SpellActivationOverlayFrame.ShowOverlay) == "function"

W.Compatibility = Compatibility
