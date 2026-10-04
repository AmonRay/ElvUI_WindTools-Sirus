local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local CM = W:NewModule("ContextMenu", "AceHook-3.0")

local _G = _G
local format = format
local gsub = gsub
local ipairs = ipairs
local max = max
local pairs = pairs
local select = select
local sort = sort
local strlower = strlower
local strmatch = strmatch
local strsub = strsub
local tinsert = tinsert
local tonumber = tonumber

local AbbreviateNumbers = AbbreviateNumbers
local BNGetFriendInfoByID = BNGetFriendInfoByID
local BNGetToonInfo = BNGetToonInfo
local BNSendWhisper = BNSendWhisper
local CanGuildInvite = CanGuildInvite
local GetAverageItemLevel = GetAverageItemLevel
local GetCombatRatingBonus = GetCombatRatingBonus
local GetCritChance = GetCritChance
local GetRangedCritChance = GetRangedCritChance
local GetSpellCritChance = GetSpellCritChance
local BNET_CLIENT_WOW = _G.BNET_CLIENT_WOW or "WoW" -- FrameXML/FriendsFrame.lua
local GuildInvite = GuildInvite
local SendWho = SendWho
local UnitAttackPower = UnitAttackPower
local UnitClass = UnitClass
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitPlayerControlled = UnitPlayerControlled

local SendChatMessage = W.Compatibility.SendChatMessage or function() end

-- This client builds unit popups from the classic UnitPopupMenus / UnitPopupButtons
-- tables (see FrameXML/UnitPopup.lua), keyed by "which" (PARTY, PLAYER, ...).
-- The retail build of this module registered "MENU_UNIT_<which>" tags with
-- Menu.ModifyMenu and appended buttons to a MenuDescription; on this client the
-- unit popup is not driven by the Menu framework at all, so no MENU_UNIT_* tag is
-- ever published and a Menu.ModifyMenu callback would never fire. The section is
-- therefore registered through the classic tables and the visibility/click hooks.
local UnitPopupButtons = _G.UnitPopupButtons
local UnitPopupMenus = _G.UnitPopupMenus
local UnitPopupShown = _G.UnitPopupShown

local BUTTON_PREFIX = "WINDTOOLS_"
local SECTION_TITLE_KEY = BUTTON_PREFIX .. "SECTION_TITLE"

local function featureButtonKey(feature)
	return BUTTON_PREFIX .. feature
end

local function featureFromButtonKey(key)
	return strmatch(key, "^" .. BUTTON_PREFIX .. "(.+)$")
end

-- Wrath identifies a Battle.net friend by presenceID and exposes its characters
-- through BNGetFriendInfoByID / BNGetToonInfo. The retail C_BattleNet helpers
-- (GetFriendAccountInfo / GetFriendGameAccountInfo / GetFriendNumGameAccounts and
-- the gameAccountInfo.clientProgram / wowProjectID / characterName / realmName
-- fields) do not exist on 3.3.5a.
local function GetBNetCharacterName(presenceID)
	if not presenceID then
		return
	end

	-- BNGetFriendInfoByID: presenceID, givenName, surname, toonName, toonID, client, isOnline, ...
	local _, _, _, toonName, toonID, client, isOnline = BNGetFriendInfoByID(presenceID)
	if not isOnline or client ~= BNET_CLIENT_WOW then
		return
	end

	local realmName
	if toonID then
		-- BNGetToonInfo: hasFocus, toonName, client, realmName, faction, ...
		local _, infoToonName, _, infoRealmName = BNGetToonInfo(toonID)
		toonName = infoToonName or toonName
		realmName = infoRealmName
	end

	if not toonName or toonName == "" then
		return
	end

	if realmName and realmName ~= "" then
		return format("%s-%s", toonName, realmName)
	end

	return toonName
end

local function GetPlayerNameFromContext(contextData)
	if contextData.chatTarget then
		return contextData.chatTarget
	end

	if contextData.name then
		if contextData.server and contextData.server ~= "" and contextData.server ~= E.myrealm then
			return format("%s-%s", contextData.name, contextData.server)
		end
		return contextData.name
	end
end

CM.Features = {
	GUILD_INVITE = {
		order = 1,
		configKey = "guildInvite",
		name = L["Guild Invite"],
		-- Only the "which" values this client actually publishes; the retail
		-- GUILD / GUILD_OFFLINE / ENEMY_PLAYER / WORLD_STATE_SCORE / COMMUNITIES_*
		-- menus have no equivalent on 3.3.5a.
		supportTypes = {
			PARTY = true,
			PLAYER = true,
			RAID_PLAYER = true,
			RAID = true,
			FRIEND = true,
			BN_FRIEND = true,
			CHAT_ROSTER = true,
			TARGET = true,
			FOCUS = true,
		},
		func = function(contextData)
			local playerName = contextData.presenceID and GetBNetCharacterName(contextData.presenceID)
				or GetPlayerNameFromContext(contextData)

			if playerName then
				GuildInvite(playerName)
			else
				CM:Log("debug", "Cannot get the name.")
			end
		end,
		hidden = function(contextData)
			if not CanGuildInvite() then
				return true
			end

			if contextData.which == "BN_FRIEND" then
				if not GetBNetCharacterName(contextData.presenceID) then
					return true
				end
			end

			if contextData.unit and contextData.unit == "target" then
				if not UnitPlayerControlled("target") then
					return true
				end
			end

			if contextData.unit and contextData.unit == "focus" then
				if not UnitPlayerControlled("focus") then
					return true
				end
			end

			if contextData.name == E.myname then
				if not contextData.server or contextData.server == E.myrealm then
					return true
				end
			end

			return false
		end,
	},
	WHO = {
		order = 2,
		configKey = "who",
		name = _G.WHO,
		supportTypes = {
			PARTY = true,
			PLAYER = true,
			RAID_PLAYER = true,
			RAID = true,
			FRIEND = true,
			CHAT_ROSTER = true,
			TARGET = true,
			ARENAENEMY = true,
			FOCUS = true,
		},
		func = function(contextData)
			local playerName = GetPlayerNameFromContext(contextData)
			if playerName then
				SendWho(playerName)
			else
				CM:Log("debug", "Cannot get the name.")
			end
		end,
		hidden = function(contextData)
			if contextData.unit and contextData.unit == "target" then
				if not UnitPlayerControlled("target") then
					return true
				end
			end

			if contextData.unit and contextData.unit == "focus" then
				if not UnitPlayerControlled("focus") then
					return true
				end
			end

			if contextData.name == E.myname then
				if not contextData.server or contextData.server == E.myrealm then
					return true
				end
			end

			return false
		end,
	},
	ARMORY = {
		order = 3,
		configKey = "armory",
		name = L["Armory"],
		supportTypes = {
			SELF = true,
			PARTY = true,
			PLAYER = true,
			RAID_PLAYER = true,
			RAID = true,
			FRIEND = true,
			CHAT_ROSTER = true,
			TARGET = true,
			ARENAENEMY = true,
			FOCUS = true,
		},
		func = function(contextData)
			local name = contextData.name
			local server = contextData.server or E.myrealm
			local slug = server and W.RealmSlugs[server]

			if name and slug then
				local link = format("%s/%s/%s", CM:GetArmoryBaseURL(), slug, name)
				E:StaticPopup_Show("ELVUI_EDITBOX", nil, nil, link)
			else
				CM:Log("debug", "Cannot get the armory link.")
			end
		end,
		hidden = function(contextData)
			if contextData.unit and contextData.unit == "target" then
				if not UnitPlayerControlled("target") then
					return true
				end
			end

			if contextData.unit and contextData.unit == "focus" then
				if not UnitPlayerControlled("focus") then
					return true
				end
			end

			return false
		end,
	},
	REPORT_STATS = {
		order = 4,
		configKey = "reportStats",
		name = L["Report Stats"],
		supportTypes = {
			PARTY = true,
			PLAYER = true,
			RAID_PLAYER = true,
			FRIEND = true,
			BN_FRIEND = true,
			CHAT_ROSTER = true,
			TARGET = true,
			FOCUS = true,
		},
		func = function(contextData)
			local name
			local _SendChatMessage = SendChatMessage

			-- Wrath whispers to a Battle.net friend go through BNSendWhisper(presenceID, text),
			-- there is no bnetIDAccount to address.
			if contextData.presenceID then
				_SendChatMessage = function(message)
					BNSendWhisper(contextData.presenceID, message)
				end
				name = "BN"
			else
				name = GetPlayerNameFromContext(contextData)
			end

			if not name then
				CM:Log("debug", "Cannot get the name.")
				return
			end

			local CRITICAL = gsub(_G.TEXT_MODE_A_STRING_RESULT_CRITICAL or "Critical", "[()]", "")

			-- Mastery, versatility and lifesteal do not exist on 3.3.5a and the
			-- client ships no GetMasteryEffect/GetVersatilityBonus/GetLifesteal, so
			-- the report lists the ratings Wrath actually tracks: crit, haste and
			-- attack power.
			local haste = max(
				GetCombatRatingBonus(_G.CR_HASTE_MELEE) or 0,
				GetCombatRatingBonus(_G.CR_HASTE_RANGED) or 0,
				GetCombatRatingBonus(_G.CR_HASTE_SPELL) or 0
			)

			for i, message in ipairs({
				format(
					"(%s) %s: %.1f %s: %s",
					select(2, W.Compatibility.GetSpecializationInfo(W.Compatibility.GetSpecialization()))
						.. select(1, UnitClass("player")),
					_G.ITEM_LEVEL_ABBR,
					select(2, GetAverageItemLevel()),
					_G.HP,
					AbbreviateNumbers(UnitHealthMax("player"))
				),
				format(" * %s: %.2f%%", CRITICAL, max(GetRangedCritChance(), GetCritChance(), GetSpellCritChance())),
				format(" * %s: %.2f%%", _G.SPELL_HASTE, haste),
				format(" * %s: %d", _G.MELEE_ATTACK_POWER, select(1, UnitAttackPower("player")) or 0),
			}) do
				E:Delay(0.1 + i * 0.2, function()
					_SendChatMessage(message, "WHISPER", nil, name)
				end)
			end
		end,
		hidden = function(contextData)
			if contextData.unit and contextData.unit == "target" then
				if not UnitPlayerControlled("target") then
					return true
				end
			end

			if contextData.unit and contextData.unit == "focus" then
				if not UnitPlayerControlled("focus") then
					return true
				end
			end

			if contextData.which == "BN_FRIEND" then
				if not contextData.presenceID then
					return true
				end
			end

			if contextData.name == E.myname then
				if not contextData.server or contextData.server == E.myrealm then
					return true
				end
			end

			return false
		end,
	},
}

CM.TypeToFeatureMap = {}
for feature, featureConfig in pairs(CM.Features) do
	for supportType in pairs(featureConfig.supportTypes) do
		if not CM.TypeToFeatureMap[supportType] then
			CM.TypeToFeatureMap[supportType] = {}
		end
		tinsert(CM.TypeToFeatureMap[supportType], feature)
	end
end

function CM:GetArmoryBaseURL()
	local language = strlower(W.Locale)
	local region = self.db and self.db.armoryOverride[E.myrealm] or W.RealRegion
	region = strlower(region or "US")

	-- China uses a different armory URL
	if region == "cn" then
		return "https://wow.blizzard.cn/character/#"
	end

	if language == "zhcn" then
		language = "zhtw" -- Simplified Chinese armory bugged outside of China
	end

	return format(
		"https://worldofwarcraft.com/%s-%s/character/%s",
		strsub(language, 1, 2),
		strsub(language, 3, 4),
		region
	)
end

--- The classic UnitPopup hands the dropdown frame to every consumer; the retail
--- contextData table (which carried bnetIDAccount, communityClubID, ...) has no
--- equivalent, so it is rebuilt from the fields the client populates itself.
function CM:BuildContextData(dropdownMenu)
	return {
		which = dropdownMenu.which,
		unit = dropdownMenu.unit,
		name = dropdownMenu.name,
		server = dropdownMenu.server,
		userData = dropdownMenu.userData,
		-- Set by the callers that have them; FriendsFrame fills presenceID and
		-- chatTarget for the Battle.net menus, chat frames fill chatTarget.
		chatTarget = dropdownMenu.chatTarget,
		presenceID = dropdownMenu.presenceID,
	}
end

function CM:GetAvailableButtonTypes(contextData)
	if not contextData.which or not self.TypeToFeatureMap[contextData.which] then
		return
	end

	local features = {}
	for _, feature in pairs(self.TypeToFeatureMap[contextData.which]) do
		features[feature] = true
	end

	local availableButtonTypes = {}
	for feature in pairs(features) do
		if self.db[self.Features[feature].configKey] and self.Features[feature].hidden(contextData) ~= true then
			tinsert(availableButtonTypes, feature)
		end
	end

	sort(availableButtonTypes, function(a, b)
		return self.Features[a].order < self.Features[b].order
	end)

	return availableButtonTypes
end

function CM:MenuHasSection(menu)
	for index = 1, #menu do
		if menu[index] == SECTION_TITLE_KEY then
			return true
		end
	end

	return false
end

--- Publishes the section into every unit popup this module supports.
function CM:RegisterPopupButtons()
	if not UnitPopupButtons or not UnitPopupMenus then
		return
	end

	-- Mirrors FrameXML's makeUnitPopupSubsectionTitle so the client's own
	-- UnitPopup_CheckAddSubsection draws the divider and heading for us.
	UnitPopupButtons[SECTION_TITLE_KEY] = {
		text = self.sectionName,
		isTitle = true,
		isUninteractable = true,
		isSubsection = true,
		isSubsectionTitle = true,
		isSubsectionSeparator = true,
	}

	local featureOrder = {}
	for feature, featureConfig in pairs(self.Features) do
		featureOrder[#featureOrder + 1] = feature
		-- UnitPopup_AddDropDownButton always routes the click to UnitPopup_OnClick,
		-- so the feature is resolved from the button key there (see OnPopupClick).
		UnitPopupButtons[featureButtonKey(feature)] = {
			text = featureConfig.name,
		}
	end

	sort(featureOrder, function(a, b)
		return self.Features[a].order < self.Features[b].order
	end)

	for which in pairs(self.TypeToFeatureMap) do
		local menu = UnitPopupMenus[which]
		if menu and not self:MenuHasSection(menu) then
			-- Keep the section above the trailing cancel entry.
			local insertAt = #menu + 1
			for index = #menu, 1, -1 do
				local key = menu[index]
				if key == "CANCEL" or key == "CLOSE" then
					insertAt = index
				else
					break
				end
			end

			tinsert(menu, insertAt, SECTION_TITLE_KEY)
			for index = #featureOrder, 1, -1 do
				tinsert(menu, insertAt + 1, featureButtonKey(featureOrder[index]))
			end
		end
	end
end

--- Runs inside UnitPopup_HideButtons, i.e. after the client has decided the default
--- visibility of every entry and before UnitPopup_ShowMenu lays the menu out, which
--- is the only window in which the shown flags can still be overridden.
function CM:HideButtons()
	if not self.initialized then
		return
	end

	local dropdownMenu = _G.UIDROPDOWNMENU_INIT_MENU
	if not dropdownMenu then
		return
	end

	-- Resolve the menu the same way UnitPopup_HideButtons does. The section only ever
	-- lives in the top-level menus, so a nested "which" simply finds no WindTools keys
	-- and nothing is written into that level's shown flags.
	local which = _G.UIDROPDOWNMENU_MENU_VALUE or dropdownMenu.which
	local menu = which and UnitPopupMenus[which]
	local shown = UnitPopupShown and UnitPopupShown[_G.UIDROPDOWNMENU_MENU_LEVEL or 1]
	if not menu or not shown then
		return
	end

	local availableMap = {}
	for _, feature in ipairs(self:GetAvailableButtonTypes(self:BuildContextData(dropdownMenu)) or {}) do
		availableMap[feature] = true
	end

	local anyAvailable = false
	local sectionTitleIndex

	for index, value in ipairs(menu) do
		if value == SECTION_TITLE_KEY then
			sectionTitleIndex = index
		elseif type(value) == "string" and strsub(value, 1, #BUTTON_PREFIX) == BUTTON_PREFIX then
			local enabled = self.db.enable and availableMap[featureFromButtonKey(value)] and true or false
			shown[index] = enabled and 1 or 0
			anyAvailable = anyAvailable or enabled
		end
	end

	if sectionTitleIndex then
		shown[sectionTitleIndex] = anyAvailable and 1 or 0
	end
end

--- UnitPopup_OnClick(self) hands us the dropdown button; its .value is the key we
--- registered in UnitPopupMenus, which is how the feature is recovered here.
function CM:OnPopupClick(button)
	local value = type(button) == "table" and button.value or button
	local feature = type(value) == "string" and featureFromButtonKey(value)
	local featureConfig = feature and self.Features[feature]
	local dropdownMenu = _G.UIDROPDOWNMENU_INIT_MENU

	if featureConfig and dropdownMenu then
		featureConfig.func(self:BuildContextData(dropdownMenu))
	end
end

function CM:InstallHooks()
	if self.hooked or type(_G.UnitPopup_HideButtons) ~= "function" or type(_G.UnitPopup_OnClick) ~= "function" then
		return
	end

	self:SecureHook("UnitPopup_HideButtons", function()
		CM:HideButtons()
	end)

	self:SecureHook("UnitPopup_OnClick", function(button)
		CM:OnPopupClick(button)
	end)

	self.hooked = true
end

function CM:Initialize()
	self.db = E.db.WT.social.contextMenu

	if not self.db.enable then
		return
	end

	local sectionText = W.PlainTitle
	if not W.ChineseLocale then
		sectionText = sectionText .. " "
	end
	self.sectionName = F.GetWindStyleText(sectionText .. L["Menu"])

	self:InstallHooks()
	self:RegisterPopupButtons()

	self.initialized = true
end

CM.ProfileUpdate = CM.Initialize

W:RegisterModule(CM:GetName())
