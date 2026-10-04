local E, _, V, P, G = unpack(ElvUI) ---@type ElvUI
local addonName, addon = ...
local EP = E.Libs.EP
local AceAddon = E.Libs.AceAddon
local L = E.Libs.ACL:GetLocale("ElvUI", E.global.general.locale)

local _G = _G
local collectgarbage = collectgarbage
local format = format
local hooksecurefunc = hooksecurefunc
local next = next
local print = print
local strfind = strfind
local strmatch = strmatch
local tContains = tContains

-- The retail namespace is absent on stock 3.3.5, while the modified client may provide it.
local C_AddOns = _G.C_AddOns
local C_AddOns_GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

---@class WindTools : AceAddon, AceConsole-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
local W = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")

V.WT = {} ---@class ProfileDB
P.WT = {} ---@class PrivateDB
G.WT = {} ---@class GlobalDB

addon[1] = W
addon[2] = {} ---@class Functions
addon[3] = E
addon[4] = L ---@alias LocaleTable table<string, string>
addon[5] = V.WT
addon[6] = P.WT
addon[7] = G.WT

_G["WindTools"] = addon

local versionString = C_AddOns_GetAddOnMetadata(addonName, "Version") or ""
local xVersionString = C_AddOns_GetAddOnMetadata(addonName, "X-Version") or "0.0"

local function getVersion()
	local version, variant, subversion

	-- Git
	if strfind(versionString, "project%-version") then
		return xVersionString, "git", nil
	end

	version, variant = strmatch(versionString, "^(%d+%.%d+)(.*)$")

	if not version then
		return xVersionString, nil, nil
	end

	if not variant or variant == "" then
		return version, nil, nil
	end

	local variantName, subversionNum = strmatch(variant, "^%-([%w]+)%-?(%d*)$")
	if variantName and subversionNum then
		variant = variantName
		subversion = subversionNum ~= "" and subversionNum or nil
	end

	return version, variant, subversion
end

W.Version, W.Variant, W.SubVersion = getVersion()

W.DisplayVersion = W.Version
if W.Variant then
	W.DisplayVersion = format("%s-%s", W.DisplayVersion, W.Variant)
	if W.SubVersion then
		W.DisplayVersion = format("%s-%s", W.DisplayVersion, W.SubVersion)
	end
end

-- Pre-register some WindTools modules
W.Modules = {
	---@class Misc : AceModule, AceHook-3.0, AceEvent-3.0
	Misc = W:NewModule("Misc", "AceHook-3.0", "AceEvent-3.0"),
	---@class Skins : AceModule, AceHook-3.0, AceEvent-3.0, AceTimer-3.0
	Skins = W:NewModule("Skins", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0"),
	---@class Tooltips : AceModule, AceHook-3.0, AceEvent-3.0
	Tooltips = W:NewModule("Tooltips", "AceHook-3.0", "AceEvent-3.0"),
	---@class MoveFrames : AceModule, AceHook-3.0, AceEvent-3.0
	MoveFrames = W:NewModule("MoveFrames", "AceEvent-3.0", "AceHook-3.0"),
}

W:NewModule("QuestProgress", "AceEvent-3.0")

-- Utilities namespace
W.Utilities = {}

-- Modules that require modern structured APIs. They remain unloaded on stock Wrath
-- instead of aborting the whole addon during file evaluation.
W.ModuleRequirements = {
	PreyHunt = { "HasModernQuestAPI", "HasModernMapAPI" },
	SuperTracker = { "HasModernMapAPI" },
	-- Needs per-unit retail ratings (C_PlayerInfo.GetPlayerMythicPlusRatingSummary);
	-- Sirus only exposes the player's own score.
	MythicPlus = { "HasChallengeModeAPI", "HasMythicPlusAPI", "HasMythicPlusRatingAPI" },
	ObjectiveProgress = { "HasModernQuestAPI" },
	-- Sirus ships ScrollBox, but tracking uses retail C_ContentTracking/Constants.
	AchievementTracker = { "HasScrollBoxAPI", "HasContentTrackingAPI" },
	-- Retail premade-group (LFGList) + M+ affix requests; Sirus' LFG/M+ are custom.
	LFGList = { "HasPremadeMythicPlusAPI" },
	-- Not a module: Skins/Blizzard/CooldownViewer.lua (retail 11.1 cooldown manager).
	CooldownViewerSkin = { "HasCooldownViewerAPI" },
	Icons = { "HasTooltipDataProcessor" },
	ReshiiWrapsUpgrade = { "HasTooltipDataProcessor" },
	HideCrafter = { "HasTooltipDataProcessor" },
	SkipCutScene = { "HasModernCinematicAPI" },
	SpellActivationAlert = { "HasSpellActivationOverlay" },
	-- Retail raid/M+ statistic IDs and MuteSoundFile (absent on 3.3.5a/Sirus).
	Progression = { "HasSoundFileMuteAPI" },
}

-- Core/Load_Core.xml is evaluated after this file on the legacy client. The
-- compatibility layer is loaded there, so keep this pre-registration inert.
-- Initialize.lua must not dereference it before Core/CompatibilityLayer.lua.
W.Compatibility = W.Compatibility or {}
W.Compatibility.HasLegacyQuestAPI = type(GetNumQuestLogEntries) == "function"
-- Method probes (Sirus defines partial C_Spell/C_Map tables); kept in sync with
-- Core/CompatibilityLayer.lua, which replaces this table.
W.Compatibility.HasModernSpellAPI = type(_G.C_Spell) == "table" and type(_G.C_Spell.GetSpellInfo) == "function"
W.Compatibility.HasModernMapAPI = type(_G.C_Map) == "table" and type(_G.C_Map.GetBestMapForUnit) == "function"

-- Pre-register libs into ElvUI
E:AddLib("Deflate", "LibDeflate")
E.Libs.Deflate.compressLevel = { level = 5 }
-- LibOpenRaid is opt-in (resolved in Preflight.lua) and is not started when the
-- switch is off, so never register it with LibStub/ElvUI unless it really loaded.
if _G.WindTools_OpenRaidEnabled then
	local openRaid = E.Libs.OpenRaid or (LibStub and LibStub("LibOpenRaid-1.0", true))
	if openRaid then
		E.Libs.OpenRaid = openRaid
	end
end
E:AddLib("ObjectiveProgressWT", "LibObjectiveProgress-WT")
E:AddLib("RangeCheck", "LibRangeCheck-3.0")
E:AddLib("Keystone", "LibKeystone")
E:AddLib("WTItemEnchant", "LibItemEnchant-WT")

_G.WindTools_OnAddonCompartmentClick = function()
	E:ToggleOptions("WindTools")
end

function W:Initialize()
	-- ElvUI -> WindTools -> WindTools Modules
	if not self:CheckElvUIVersion() then
		return
	end

	for _, module in self:IterateModules() do
		addon[2].Developer.InjectLogger(module)
	end

	hooksecurefunc(W, "NewModule", function(_, name)
		addon[2].Developer.InjectLogger(name)
	end)

	self.initialized = true

	self:AddCustomLinkSupport()
	self:UpdateScripts()

	-- To avoid the update tips from ElvUI when alpha/beta versions are used
	EP:RegisterPlugin(addonName, W.OptionsCallback, false, xVersionString)

	self:SecureHook(E, "UpdateAll", "UpdateModules")
	-- Init Modules
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LOGIN")
end

function W:AutoCopyPrivateProfile()
	if
		not E.global.WT.core.autoCopyPrivateProfile.enable
		or E.global.WT.core.autoCopyPrivateProfile.initializedCharacters[E.mynameRealm]
	then
		return
	end

	local copyFrom = E.global.WT.core.autoCopyPrivateProfile.copyFrom
	if not copyFrom or E.charSettings:GetCurrentProfile() == copyFrom then
		return
	end

	local profiles = E.charSettings:GetProfiles()
	if tContains(profiles, copyFrom) then
		E.charSettings:CopyProfile(copyFrom)
		E.global.WT.core.autoCopyPrivateProfile.initializedCharacters[E.mynameRealm] = true
	end
end

do
	-- Legacy Sirus/ElvUI profiles can persist color tables that only contain an
	-- alpha channel (e.g. ["bordercolor"] = {["a"] = 1}). E:SetColorTable throws
	-- on missing RGB channels, which aborts E:UpdateMedia and leaves
	-- E.media.bordercolor/backdropcolor nil. Every subsequent SetTemplate /
	-- HandleButton then calls SetBackdropBorderColor(nil, nil, nil), which falls
	-- back to the WoW default white border on all frames. Fill the missing
	-- channels from the ElvUI defaults before refreshing the media.
	local function RepairElvUIColorTables()
		local db = E.db
		local general = db and db.general
		if not general then
			return
		end

		local defaults = E.DF and E.DF.profile and E.DF.profile.general

		local function repair(tbl, key)
			local value = tbl and tbl[key]
			if type(value) ~= "table" or (value.r and value.g and value.b) then
				return
			end

			local fallback = defaults and defaults[key]
			value.r = value.r or (fallback and fallback.r) or 0
			value.g = value.g or (fallback and fallback.g) or 0
			value.b = value.b or (fallback and fallback.b) or 0
		end

		repair(general, "bordercolor")
		repair(general, "backdropcolor")
		repair(general, "backdropfadecolor")
		repair(general, "valuecolor")
		repair(general.customGlow, "color")

		local unitframe = db and db.unitframe
		repair(unitframe and unitframe.colors, "borderColor")
	end

	local checked = false
	function W:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
		if isInitialLogin then
			self:AutoCopyPrivateProfile()
		end

		RepairElvUIColorTables()

		if E.media and E.media.bordercolor and E.media.bordercolor.r then
			if isInitialLogin then
				E:UpdateMedia()
				E:UpdateFontTemplates()
			end
		else
			-- E:UpdateMedia() aborted during ElvUI initialization because of an
			-- incomplete legacy color table. After the repair above, refresh the
			-- media and recolor the already-created template frames.
			if E.UpdateMediaItems then
				E:UpdateMediaItems()
			else
				E:UpdateMedia()
			end
		end

		if isInitialLogin then
			E:Delay(6, self.ChangelogReadAlert, self)
			-- Queue the native ElvUI plugin installer on the first login when the
			-- WindTools setup has not been completed yet.
			if W.Install and W.Install.CheckInstall then
				W.Install:CheckInstall()
			end
			if E.global.WT.core.loginMessage then
				local icon = addon[2].GetIconString(self.Media.Textures.smallLogo, 14)
				print(
					format(
						icon
							.. " "
							.. L["%s %s Loaded."]
							.. " "
							.. L["You can send your suggestions or bugs via %s, %s, %s and the thread in %s."],
						self.Title,
						self.Version,
						L["QQ Group"],
						L["Discord"],
						L["GitHub"],
						L["NGA.cn"]
					)
				)
			end
		end

		if not (checked or _G.ElvUIInstallFrame) then
			self:CheckCompatibility()
			checked = true
		end

		if _G.ElvDB then
			if isInitialLogin or not _G.ElvDB.WT then
				_G.ElvDB.WT = {
					DisabledAddOns = {},
				}
			end

			if next(_G.ElvDB.WT.DisabledAddOns) then
				E:Delay(4, self.PrintDebugEnviromentTip)
			end
		end

		self:HookUIError()
		self:GameFixing()

		E:Delay(1, collectgarbage, "collect")
	end
end

EP:HookInitialize(W, W.Initialize)
