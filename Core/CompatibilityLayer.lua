local W, F, E = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI

local _G = _G
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local pairs = pairs
local select = select
local setmetatable = setmetatable
local Compatibility = {}

-- Ambiguate is a retail helper; the 3.3.5a client has no such global. Install a
-- Wrath-compatible fallback so every `Ambiguate(name, ...)` call in this addon
-- (ChatText, SmartTab, KeystoneInfo, LibKeystone, LibOpenRaid) resolves. The
-- shim strips the realm suffix for "short" (and the "none" WindTools call sites),
-- matching what the genius users' addons on this client do.
if not _G.Ambiguate then
	function _G.Ambiguate(name, mode)
		if type(name) ~= "string" then
			return name
		end
		if mode == "full" then
			return name
		end
		local stripped = name:match("^([^%-]+)")
		return stripped and stripped ~= "" and stripped or name
	end
end

-- Resolves a client API at call time so namespaces/methods that the modified
-- 3.3.5 client registers after addon load are still picked up. A nil return
-- means the client genuinely does not implement the function; this matches the
-- client's own APIDocumentation addon (e.g. C_QuestLog has no GetQuestTagInfo)
-- and Questie-335's compat layer, which reimplements those APIs itself.
local function resolve(namespace, method)
	local api = _G[namespace]
	if type(api) ~= "table" then
		return nil
	end
	return type(api[method]) == "function" and api[method] or nil
end

-- Call-time wrapper for a namespace method (the namespace is passed as self).
local function namespaceMethod(namespace, method)
	return function(...)
		local api = _G[namespace]
		local fn = api and type(api[method]) == "function" and api[method]
		return fn and fn(api, ...)
	end
end

-- Namespaces this client does NOT ship (per APIDocumentation): C_CVar, C_Item,
-- C_Container, C_Map, C_Spell, C_BattleNet, C_ChallengeMode, C_MythicPlus,
-- C_ScenarioInfo. For those the Wrath globals ARE the native client API.
Compatibility.GetCVar = _G.GetCVar
Compatibility.SetCVar = _G.SetCVar
Compatibility.GetCVarBool = function(name)
	return Compatibility.GetCVar(name) == "1"
end
Compatibility.GetItemInfo = _G.GetItemInfo
Compatibility.GetItemInfoInstant = _G.GetItemInfoInstant
Compatibility.GetItemCount = _G.GetItemCount
Compatibility.GetItemCooldown = _G.GetItemCooldown
Compatibility.GetItemQualityColor = _G.GetItemQualityColor
Compatibility.GetDetailedItemLevelInfo = _G.GetDetailedItemLevelInfo
Compatibility.GetItemIconByID = _G.GetItemIcon or function(itemID)
	local _, _, _, _, _, _, _, _, _, icon = Compatibility.GetItemInfo(itemID)
	return icon
end
Compatibility.GetSpellInfo = _G.GetSpellInfo
Compatibility.GetSpellTexture = _G.GetSpellTexture
Compatibility.GetSpellLink = _G.GetSpellLink
Compatibility.GetContainerNumSlots = _G.GetContainerNumSlots
Compatibility.GetContainerItemID = _G.GetContainerItemID
Compatibility.GetContainerItemLink = _G.GetContainerItemLink
Compatibility.GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
Compatibility.UseContainerItem = _G.UseContainerItem

-- AddOns: only GetAddOnMetadata is a C_AddOns method; the rest are Wrath globals.
Compatibility.IsAddOnLoaded = _G.IsAddOnLoaded
Compatibility.GetAddOnMetadata = _G.GetAddOnMetadata or namespaceMethod("C_AddOns", "GetAddOnMetadata")
-- DoesAddOnExist is a Cataclysm+ global; GetAddOnInfo is the native Wrath check.
Compatibility.DoesAddOnExist = _G.DoesAddOnExist or function(name)
	return _G.GetAddOnInfo and _G.GetAddOnInfo(name) ~= nil
end
Compatibility.DisableAddOn = _G.DisableAddOn
Compatibility.EnableAddOn = _G.EnableAddOn
Compatibility.GetNumAddOns = _G.GetNumAddOns
Compatibility.GetAddOnInfo = _G.GetAddOnInfo
Compatibility.ReloadUI = _G.ReloadUI
Compatibility.InviteUnit = _G.InviteUnit
Compatibility.IsAddOnRestrictionActive = resolve("C_RestrictedActions", "IsAddOnRestrictionActive")

Compatibility.ChatInfo = _G.C_ChatInfo
Compatibility.SendAddonMessage = _G.SendAddonMessage
Compatibility.RegisterAddonMessagePrefix = _G.RegisterAddonMessagePrefix
Compatibility.SendChatMessage = _G.SendChatMessage

Compatibility.AuraUtil = _G.AuraUtil
Compatibility.HasModernAuraUtil = type(Compatibility.AuraUtil) == "table"

-- Quest log. This client's C_QuestLog documents the modern method names:
-- GetQuestInfo, GetQuestObjectives, IsOnQuest, IsQuestFlaggedCompleted,
-- ShouldShowQuestRewards, GetMaxNumQuests, GetMaxNumQuestsCanAccept.
-- GetQuestTagInfo and IsQuestFlaggedCompletedOnAccount are NOT implemented by the
-- client (Questie-335 reimplements tag lookup from a data table); the accessors
-- resolve at call time and return nil when the client lacks them.
Compatibility.GetQuestInfo = namespaceMethod("C_QuestLog", "GetQuestInfo")
Compatibility.GetQuestObjectives = namespaceMethod("C_QuestLog", "GetQuestObjectives")
Compatibility.IsOnQuest = namespaceMethod("C_QuestLog", "IsOnQuest")
Compatibility.ShouldShowQuestRewards = namespaceMethod("C_QuestLog", "ShouldShowQuestRewards")
Compatibility.GetMaxNumQuests = namespaceMethod("C_QuestLog", "GetMaxNumQuests")
Compatibility.GetQuestTagInfo = namespaceMethod("C_QuestLog", "GetQuestTagInfo")

-- Completion checks must never crash in tracker polls; resolve lazily and
-- degrade to "not completed" when the client lacks the API.
local function makeQuestCompletedChecker(method)
	return function(questID)
		if type(questID) ~= "number" then
			return false
		end
		local api = _G.C_QuestLog
		local fn = api and type(api[method]) == "function" and api[method]
		if fn then
			return fn(api, questID)
		end
		return false
	end
end
Compatibility.IsQuestFlaggedCompleted = makeQuestCompletedChecker("IsQuestFlaggedCompleted")
Compatibility.IsQuestFlaggedCompletedOnAccount = makeQuestCompletedChecker("IsQuestFlaggedCompletedOnAccount")

-- C_Timer on Sirus is implemented in Lua (SharedXML/C_TimerAugment.lua) with
-- MIXED calling conventions, unlike retail where everything is a dot call:
--   function C_Timer:After(duration, callback)                 -- colon
--   function C_Timer:NewTicker(duration, callback, iterations) -- colon
--   function C_Timer.NewTimer(duration, callback)              -- dot
-- Calling them with the wrong convention shifts the arguments and corrupts the
-- timer queue (compare errors inside its OnUpdate). These wrappers expose the
-- retail dot-call signatures and pick the right convention per method: if the
-- first parameter of the Sirus function is the namespace, pass C_Timer as self.
local function bindTimerMethod(method, isColonMethod)
	local timer = _G.C_Timer
	if not timer or type(timer[method]) ~= "function" then
		return nil
	end
	local timerMethod = timer[method]
	if isColonMethod then
		return function(duration, callback, ...)
			return timerMethod(timer, duration, callback, ...)
		end
	end
	return function(duration, callback, ...)
		return timerMethod(duration, callback, ...)
	end
end
-- Retail (native C_Timer): all dot. Sirus: After/NewTicker colon, NewTimer dot.
-- The Sirus Lua augment wraps the native C_Timer2 table, so its presence
-- identifies the Sirus convention.
local isSirusTimer = type(_G.C_Timer2) == "table"
Compatibility.IsSirusTimer = isSirusTimer
Compatibility.NewTicker = bindTimerMethod("NewTicker", isSirusTimer)
Compatibility.After = bindTimerMethod("After", isSirusTimer)
Compatibility.NewTimer = bindTimerMethod("NewTimer", false)

-- Specializations. This client ships C_SpecializationInfo with an EMPTY function
-- table (per APIDocumentation) and no GetSpecialization / GetInspectSpecialization
-- / GetSpecializationInfoByID globals; the real API is implemented by the
-- ElvUI-Sirus fork on E.* (Core/Init.lua): GetSpecialization returns the talent
-- tab index and GetSpecializationInfo returns id, name, description, icon,
-- background, role. Retail clients provide the C_SpecializationInfo methods
-- (specID, name, description, icon, role). Resolved at call time; the Sirus
-- signature is normalized to the retail one (the extra "background" field is
-- dropped so select(5, ...) is always the role, as retail callers expect).
Compatibility.GetSpecialization = function()
	local api = _G.C_SpecializationInfo
	local method = api and type(api.GetSpecialization) == "function" and api.GetSpecialization
	if method then
		return method(api)
	end
	local fn = E.GetSpecialization
	return type(fn) == "function" and fn()
end

Compatibility.GetSpecializationInfo = function(specIndex, isInspect, isPet, specGroup)
	if type(specIndex) ~= "number" then
		return
	end
	local api = _G.C_SpecializationInfo
	local method = api and type(api.GetSpecializationInfo) == "function" and api.GetSpecializationInfo
	if method then
		return method(api, specIndex, isInspect, isPet, specGroup)
	end
	local fn = E.GetSpecializationInfo
	if type(fn) == "function" then
		local id, name, description, icon, _, role = fn(specIndex, isInspect, isPet, specGroup)
		return id, name, description, icon, role
	end
end

Compatibility.GetInspectSpecialization = function(unit)
	local fn = E.GetInspectSpecialization
	if type(fn) == "function" then
		return fn(unit)
	end
	local global = _G.GetInspectSpecialization
	return type(global) == "function" and global(unit)
end

Compatibility.GetSpecializationInfoByID = function(specID)
	local fn = E.GetSpecializationInfoByID
	if type(fn) == "function" then
		return fn(specID)
	end
	local global = _G.GetSpecializationInfoByID
	return type(global) == "function" and global(specID)
end

-- Item APIs absent from this client. C_Item ships here with a REAL but partial
-- function table (GetItemInfo / GetItemGem / GetItemStats / GetItemQualityColor
-- / GetItemCooldown / IsUsableItem exist, per APIDocumentation), while several
-- retail-only methods are missing and the Wrath globals for them do not exist
-- either (checked against APIDocumentation, the client FrameXML and Questie-335).
-- All resolved at call time; nil/false fallbacks keep retail callers safe.
Compatibility.GetCurrentItemLevel = function(itemLocation)
	local method = resolve("C_Item", "GetCurrentItemLevel")
	if method then
		return method(_G.C_Item, itemLocation)
	end
	-- Wrath has no per-item "current" level API; callers fall back to
	-- E:GetGearSlotInfo(unit, slot).iLvl and GetDetailedItemLevelInfo.
end

Compatibility.GetDetailedItemLevelInfo = function(link)
	local method = resolve("C_Item", "GetDetailedItemLevelInfo")
	if method then
		return method(_G.C_Item, link)
	end
	-- Wrath: item level is the 4th return value of GetItemInfo.
	if type(link) == "string" and type(_G.GetItemInfo) == "function" then
		return select(4, _G.GetItemInfo(link))
	end
end

Compatibility.GetItemNumSockets = function(link)
	local method = resolve("C_Item", "GetItemNumSockets")
	if method then
		return method(_G.C_Item, link)
	end
	-- Wrath has no GetItemNumSockets (Cata+); treat the item as unsocketed so
	-- the addable-sockets suggestion logic keeps working instead of crashing.
	return 0
end

Compatibility.IsCorruptedItem = function(link)
	local method = resolve("C_Item", "IsCorruptedItem")
	if method then
		return method(_G.C_Item, link)
	end
	return false -- no corrupted items on Wrath
end

Compatibility.IsItemKeystoneByID = function(itemID)
	local method = resolve("C_Item", "IsItemKeystoneByID")
	if method then
		return method(_G.C_Item, itemID)
	end
	return false -- Mythic+ keystones do not exist on Wrath
end

Compatibility.IsCosmeticItem = function(itemID)
	local method = resolve("C_Item", "IsCosmeticItem")
	if method then
		return method(_G.C_Item, itemID)
	end
	return false -- transmog cosmetics do not exist on Wrath
end

-- Capability probes (resolved at load; used to gate retail-only modules).
-- Sirus defines many retail-named namespaces in Lua with only a subset of the
-- retail methods (e.g. C_Container only has sort/flag helpers, C_Map only
-- GetAreaNameByID/GetParentMapID, C_Spell only IsSpellCrowdControl/
-- IsSpellImportant, C_MountJournal/C_ToyBox are Sirus collection backends).
-- A namespace table therefore proves nothing; probe the method a module needs.
local function hasMethod(namespace, method)
	local api = _G[namespace]
	return type(api) == "table" and type(api[method]) == "function"
end
local function isNativeNamespace(name)
	return type(_G[name]) == "table"
end
Compatibility.HasMethod = hasMethod

Compatibility.HasTimerAPI = type(_G.C_Timer) == "table" and type(_G.C_Timer.NewTicker) == "function" and type(_G.C_Timer.NewTimer) == "function"
Compatibility.HasModernContainers = hasMethod("C_Container", "GetContainerNumSlots") and hasMethod("C_Container", "GetContainerItemInfo")
Compatibility.HasModernItemAPI = hasMethod("C_Item", "GetItemInfo")
Compatibility.HasModernSpellAPI = hasMethod("C_Spell", "GetSpellInfo")
Compatibility.HasLegacyQuestAPI = type(_G.GetNumQuestLogEntries) == "function"
Compatibility.HasLegacyTooltipAPI = type(_G.GameTooltip) == "table"
Compatibility.HasModernMapAPI = hasMethod("C_Map", "GetBestMapForUnit")
Compatibility.HasModernQuestAPI = hasMethod("C_QuestLog", "GetQuestInfo")
Compatibility.HasTooltipDataProcessor = hasMethod("TooltipDataProcessor", "AddTooltipPostCall")
-- Sirus ships a Lua Mythic+ system (FrameXML/Utils/C_Mythic.lua) with the
-- retail names for keystones, map info and dungeon score.
Compatibility.HasChallengeModeAPI = hasMethod("C_ChallengeMode", "GetMapUIInfo")
Compatibility.HasMythicPlusAPI = hasMethod("C_MythicPlus", "GetOwnedKeystoneLevel")
-- Retail-only per-player rating summary (used by the M+ tooltip module).
Compatibility.HasMythicPlusRatingAPI = hasMethod("C_PlayerInfo", "GetPlayerMythicPlusRatingSummary")
Compatibility.HasBattleNetAPI = isNativeNamespace("C_BattleNet")
Compatibility.HasClubAPI = isNativeNamespace("C_Club")
Compatibility.HasModernSocialAPI = Compatibility.HasBattleNetAPI or Compatibility.HasClubAPI
Compatibility.HasModernUnitAPI = type(_G.UnitHealthPercent) == "function" and type(_G.UnitGetTotalAbsorbs) == "function"
Compatibility.HasModernCollectionsAPI = hasMethod("C_MountJournal", "GetMountIDs") and hasMethod("C_ToyBox", "GetToyInfo")
-- Retail achievement/content tracking (10.1+); Sirus uses the legacy
-- AddTrackedAchievement API and has no Constants.ContentTrackingConsts.
Compatibility.HasContentTrackingAPI = hasMethod("C_ContentTracking", "GetTrackedIDs")
	and type(_G.Constants) == "table" and type(_G.Constants.ContentTrackingConsts) == "table"
-- Retail premade groups with M+ affix requests (LFGList module). Sirus has its
-- own C_MythicPlus without RequestCurrentAffixes.
Compatibility.HasPremadeMythicPlusAPI = hasMethod("C_MythicPlus", "RequestCurrentAffixes") and hasMethod("C_LFGList", "GetSearchResultInfo")
-- Retail cooldown manager (Blizzard_CooldownViewer, 11.1+).
Compatibility.HasCooldownViewerAPI = type(_G.C_CooldownViewer) == "table"
-- MuteSoundFile/UnmuteSoundFile (8.2+) do not exist on 3.3.5a/Sirus.
Compatibility.HasSoundFileMuteAPI = type(_G.MuteSoundFile) == "function" and type(_G.UnmuteSoundFile) == "function"
Compatibility.HasModernSettingsAPI = type(_G.Settings) == "table"
-- Retail scroll box helpers (CreateDataProvider / CreateScrollBoxListLinearView)
-- are absent on Wrath; modules that build a ScrollBox UI cannot run there.
Compatibility.HasScrollBoxAPI = type(_G.CreateDataProvider) == "function" and type(_G.CreateScrollBoxListLinearView) == "function"
Compatibility.HasModernCinematicAPI = type(_G.EventRegistry) == "table" and type(_G.MovieFrame_PlayMovie) == "function" and type(_G.Enum) == "table" and type(_G.Enum.CinematicType) == "table"
Compatibility.HasSpellActivationOverlay = type(_G.SpellActivationOverlayFrame) == "table" and type(_G.SpellActivationOverlayFrame.ShowOverlay) == "function"

-- Wrath has no Blizzard "secret values" (retail protection that hides secure
-- data from insecure code). On this client nothing is secret, so the correct
-- semantics are IsSecretValue() == false and NotSecretValue() == true.
-- ElvUI 9.05 does not ship these helpers, while WindTools relies on them.
if type(E.IsSecretValue) ~= "function" then
	function E:IsSecretValue()
		return false
	end

	function E:NotSecretValue()
		return true
	end
end

W.Compatibility = Compatibility
