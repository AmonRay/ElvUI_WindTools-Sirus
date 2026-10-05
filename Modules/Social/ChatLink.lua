local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local C = W.Utilities.Color
local CL = W:NewModule("ChatLink") ---@class ChatLink : AceModule

local _G = _G
local format = format
local gsub = gsub
local next = next
local pairs = pairs
local select = select
local strmatch = strmatch
local tonumber = tonumber

local AddMessageEventFilter = ChatFrame_AddMessageEventFilter or function() end
local GetAchievementInfo = GetAchievementInfo
local GetItemInfo = GetItemInfo
local GetTalentInfo = GetTalentInfo

local GetNumTalentTabs = GetNumTalentTabs
local GetNumTalents = GetNumTalents
local GetTalentLink = GetTalentLink

-- 3.3.5a talent hyperlinks are "|Htalent:talentID:rank|h" (rank is -1 for an
-- unlearned talent), and the client has no GetTalentInfoByID. GetTalentInfo only
-- takes (tabIndex, talentIndex), so the player's own talents are mapped from
-- GetTalentLink once. Links of other classes stay without an icon. A
-- "tabIndex:talentIndex" payload is still accepted as a fallback.
local talentIDToIndex
local function GetTalentIndexByID(talentID)
	if not talentIDToIndex then
		talentIDToIndex = {}
		if GetNumTalentTabs and GetNumTalents and GetTalentLink then
			for tabIndex = 1, GetNumTalentTabs() or 0 do
				for talentIndex = 1, GetNumTalents(tabIndex) or 0 do
					local id = tonumber(strmatch(GetTalentLink(tabIndex, talentIndex) or "", "Htalent:(%d+)"))
					if id then
						talentIDToIndex[id] = { tabIndex, talentIndex }
					end
				end
			end
		end
		if not next(talentIDToIndex) then
			talentIDToIndex = nil -- talents not loaded yet, retry next time
			return
		end
	end
	local entry = talentIDToIndex[talentID]
	if entry then
		return entry[1], entry[2]
	end
end

local function GetTalentTextureFromLink(link)
	local first, second = strmatch(link, "Htalent:(%d+):(%-?%d+)")
	first, second = tonumber(first), tonumber(second)
	if not first then
		return
	end

	local tabIndex, talentIndex = GetTalentIndexByID(first)
	if not tabIndex and second and second > 0 and first <= 3 then
		tabIndex, talentIndex = first, second
	end
	if not tabIndex then
		return
	end

	-- GetTalentInfo(tabIndex, talentIndex) -> name, icon, tier, column, rank, ...
	return select(2, GetTalentInfo(tabIndex, talentIndex))
end

-- The client exposes C_Item.GetItemName(itemLocation), not the retail
-- C_Item.GetItemNameByID; GetItemInfo(itemID) returns the same client-localized
-- name for an item ID.
local function C_Item_GetItemNameByID(itemID)
	return GetItemInfo(itemID)
end

local C_ChallengeMode_GetMapUIInfo = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
local C_Item_GetDetailedItemLevelInfo = W.Compatibility.GetDetailedItemLevelInfo
local C_Item_GetItemIconByID = W.Compatibility.GetItemIconByID
local C_Item_GetItemInfoInstant = W.Compatibility.GetItemInfoInstant
local C_Spell_GetSpellTexture = W.Compatibility.GetSpellTexture

local RETRIEVING_ITEM_INFO = RETRIEVING_ITEM_INFO or "Retrieving item information"
local ITEM_LEVEL = ITEM_LEVEL or "Item Level %d"
local ITEM_LEVEL_ALT = ITEM_LEVEL_ALT or "Item Level %d (%d)"
local ITEM_MIN_LEVEL = ITEM_MIN_LEVEL or "Requires level %d"

local MATCH_ITEM_LEVEL = ITEM_LEVEL:gsub("%%d", "(%%d+)")
local MATCH_MIN_LEVEL = ITEM_MIN_LEVEL:gsub("%%d", "(%%d+)")
local MATCH_ITEM_LEVEL_ALT = ITEM_LEVEL_ALT:gsub("%%d(%s?)%(%%d%)", "%%d+%1%%((%%d+)%%)")

local function ParseItemLevelFromTooltipLine(text)
	if not text or text == "" then
		return
	end
	local ilvl = strmatch(text, MATCH_ITEM_LEVEL_ALT)
		or (not strmatch(text, MATCH_MIN_LEVEL) and strmatch(text, MATCH_ITEM_LEVEL))
	return ilvl and tonumber(ilvl)
end

--- Item level as shown on the item tooltip (post-squish display), not C_Item.GetDetailedItemLevelInfo.
local function GetDisplayedItemLevelFromHyperlink(link)
	local info = E:ScanTooltip_HyperlinkInfo(link)
	if not info or not info.lines then
		return
	end
	local firstLine = info.lines[1]
	local firstText = firstLine and firstLine.leftText
	if firstText == RETRIEVING_ITEM_INFO then
		return
	end
	for i = 1, #info.lines do
		local line = info.lines[i]
		if line then
			local lv = ParseItemLevelFromTooltipLine(line.leftText)
			if lv then
				return lv
			end
			lv = ParseItemLevelFromTooltipLine(line.rightText)
			if lv then
				return lv
			end
		end
	end
end

local SearchArmorType = {
	INVTYPE_HEAD = true,
	INVTYPE_SHOULDER = true,
	INVTYPE_CHEST = true,
	INVTYPE_WRIST = true,
	INVTYPE_HAND = true,
	INVTYPE_WAIST = true,
	INVTYPE_LEGS = true,
	INVTYPE_FEET = true,
}

local abbrList = {
	INVTYPE_HEAD = L["[ABBR] Head"],
	INVTYPE_NECK = L["[ABBR] Neck"],
	INVTYPE_SHOULDER = L["[ABBR] Shoulders"],
	INVTYPE_CLOAK = L["[ABBR] Back"],
	INVTYPE_CHEST = L["[ABBR] Chest"],
	INVTYPE_WRIST = L["[ABBR] Wrist"],
	INVTYPE_HAND = L["[ABBR] Hands"],
	INVTYPE_WAIST = L["[ABBR] Waist"],
	INVTYPE_LEGS = L["[ABBR] Legs"],
	INVTYPE_FEET = L["[ABBR] Feet"],
	INVTYPE_HOLDABLE = L["[ABBR] Held In Off-hand"],
	INVTYPE_FINGER = L["[ABBR] Finger"],
	INVTYPE_TRINKET = L["[ABBR] Trinket"],
}

local tierColor = {
	["1"] = "|cffa5493b",
	["2"] = "|cffaaaeb2",
	["3"] = "|cffe4c55b",
	["4"] = "|cff09d3ff",
	["5"] = "|cffe8ac1b",
}

local function AddItemInfo(link)
	local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = C_Item_GetItemInfoInstant(link)

	if not itemID then
		return
	end

	if CL.db.translateItem then
		local localizedName = C_Item_GetItemNameByID(itemID)
		if localizedName then
			local professionIcon = strmatch(link, "|A:Professions.-|a")
			if professionIcon then
				localizedName = localizedName .. " " .. professionIcon
			end
			link = gsub(link, "|h%[(.+)%]|h", "|h[" .. localizedName .. "]|h")
		end
	end

	if CL.db.numericalQualityTier then
		link = gsub(link, "|A:Professions%-ChatIcon%-Quality%-Tier(%d):(%d+):(%d+)::1|a", function(tier, width, height)
			if tierColor[tier] then
				return tierColor[tier] .. tier .. "|r"
			end
			return format("|A:Professions-ChatIcon-Quality-Tier%s:%s:%s::1|a", tier, width, height)
		end)
	end

	local level, slot

	-- item level: tooltip display value; the client has no GetDetailedItemLevelInfo.
	if CL.db.level then
		level = GetDisplayedItemLevelFromHyperlink(link)
		if not level and C_Item_GetDetailedItemLevelInfo then
			level = C_Item_GetDetailedItemLevelInfo(link)
		end
	end

	-- armor
	if itemType == _G.ARMOR and CL.db.armorCategory then
		if itemEquipLoc ~= "" then
			if SearchArmorType[itemEquipLoc] then
				if E.global.general.locale == "zhTW" or E.global.general.locale == "zhCN" then
					slot = itemSubType .. (abbrList[itemEquipLoc] or _G[itemEquipLoc])
				else
					slot = itemSubType .. " " .. (abbrList[itemEquipLoc] or _G[itemEquipLoc])
				end
			else
				slot = abbrList[itemEquipLoc] or _G[itemEquipLoc]
			end
		end
	end

	-- weapon
	if itemType == _G.WEAPON and CL.db.weaponCategory then
		if itemEquipLoc ~= "" then
			slot = itemSubType or abbrList[itemEquipLoc] or _G[itemEquipLoc]
		end
	end

	if level and slot then
		link = gsub(link, "|h%[(.-)%]|h", "|h[" .. level .. "-" .. slot .. ":%1]|h")
	elseif level then
		link = gsub(link, "|h%[(.-)%]|h", "|h[" .. level .. ":%1]|h")
	elseif slot then
		link = gsub(link, "|h%[(.-)%]|h", "|h[" .. slot .. ":%1]|h")
	end

	if CL.db.icon then
		link = F.GetIconString(icon, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio) .. " " .. link
	end

	return link
end

local function AddKeystoneIcon(link)
	-- Sirus builds keystone hyperlinks in FrameXML/Utils/C_Item.lua as
	--   |c<rarity>|Hkeystone:itemID:randomPropertyID:mapChallengeModeID:keystoneLevel:affix1..5|h[name]|h|r
	-- The retail link put the map and the level in the second and third slots and
	-- hardcoded the keystone itemID, so neither can be reused here.
	local itemID, _, mapChallengeModeID = strmatch(link, "Hkeystone:(%d+):(%d+):(%d+):")
	if not (itemID and mapChallengeModeID) then
		return
	end

	if CL.db.icon and C_ChallengeMode_GetMapUIInfo then
		-- C_ChallengeMode.GetMapUIInfo -> name, id, criteria1, criteria2, criteria3, texture, backgroundTexture
		local texture = select(6, C_ChallengeMode_GetMapUIInfo(tonumber(mapChallengeModeID)))
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddSpellInfo(link)
	-- spell icon
	local id = strmatch(link, "Hspell:(%d-):")
	if not id then
		return
	end

	if CL.db.icon then
		local spellIDNum = tonumber(id)
		local texture = spellIDNum and C_Spell_GetSpellTexture(spellIDNum)
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. C.StringByTemplate(link, "sky-400")
		end
	end

	return link
end

local function AddEnchantInfo(link)
	-- enchant
	local id = strmatch(link, "Henchant:(%d-)\124")
	if not id then
		return
	end

	if CL.db.icon then
		local enchantIDNum = tonumber(id)
		local texture = enchantIDNum and C_Spell_GetSpellTexture(enchantIDNum)
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddTalentInfo(link)
	-- talent
	local id = strmatch(link, "Htalent:(%d+)")
	if not id then
		return
	end

	if CL.db.icon then
		local texture = GetTalentTextureFromLink(link)
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddAchievementInfo(link)
	-- achievement
	local id = strmatch(link, "Hachievement:(%d+)")
	if not id then
		return
	end

	if CL.db.icon then
		local achievementIDNum = tonumber(id)
		-- This client returns the icon at index 10 (id, name, points, completed,
		-- month, day, year, description, flags, icon, rewardText) -- see AlertFrames.lua.
		local texture = achievementIDNum and select(10, GetAchievementInfo(achievementIDNum))
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddCurrencyInfo(link)
	-- currency
	local id = strmatch(link, "Hcurrency:(%d+)")
	if not id then
		return
	end

	if CL.db.icon then
		-- This client's C_CurrencyInfo.GetCurrencyInfo returns
		-- (name, quantity, icon, ...) -- icon is the third return.
		local icon = C_CurrencyInfo_GetCurrencyInfo and select(3, C_CurrencyInfo_GetCurrencyInfo(id))
		icon = icon and F.GetIconString(icon, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

function CL:Filter(event, msg, ...)
	if CL.db.enable and E:NotSecretValue(msg) then
		msg = gsub(msg, "(|c%x+|Hkeystone:%d+:.-|h.-|h|r)", AddKeystoneIcon)
		msg = gsub(msg, "(|Hitem:%d+:.-|h.-|h)", AddItemInfo)
		msg = gsub(msg, "(|Hcurrency:%d+:.-|h.-|h)", AddCurrencyInfo)
		msg = gsub(msg, "(|Hspell:%d+:%d+|h.-|h)", AddSpellInfo)
		msg = gsub(msg, "(|Henchant:%d+|h.-|h)", AddEnchantInfo)
		msg = gsub(msg, "(|Htalent:%d+:%-?%d+|h.-|h)", AddTalentInfo)
		msg = gsub(msg, "(|Hachievement:%d+:.-|h.-|h)", AddAchievementInfo)
	end
	return false, msg, ...
end

function CL:Initialize()
	self.db = E.db.WT.social.chatLink

	local events = {
		"CHAT_MSG_ACHIEVEMENT",
		"CHAT_MSG_BATTLEGROUND",
		"CHAT_MSG_BN_WHISPER",
		"CHAT_MSG_CHANNEL",
		"CHAT_MSG_COMMUNITIES_CHANNEL",
		"CHAT_MSG_EMOTE",
		"CHAT_MSG_GUILD",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"CHAT_MSG_LOOT",
		"CHAT_MSG_OFFICER",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_SAY",
		"CHAT_MSG_TRADESKILLS",
		"CHAT_MSG_WHISPER",
		"CHAT_MSG_WHISPER_INFORM",
		"CHAT_MSG_YELL",
	}

	for _, event in pairs(events) do
		AddMessageEventFilter(event, self.Filter)
	end

	self.initialized = true
end

function CL:ProfileUpdate()
	self.db = E.db.WT.social.chatLink

	if self.db.enable and not self.initialized then
		self:Initialize()
	end
end

W:RegisterModule(CL:GetName())
