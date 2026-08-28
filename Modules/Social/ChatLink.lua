local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local C = W.Utilities.Color
local CL = W:NewModule("ChatLink") ---@class ChatLink : AceModule

local _G = _G
local format = format
local gsub = gsub
local pairs = pairs
local select = select
local strmatch = strmatch
local tonumber = tonumber

local ChatFrameUtil = _G.ChatFrameUtil
local ChatFrameUtil_AddMessageEventFilter = ChatFrame_AddMessageEventFilter or function() end
local GetAchievementInfo = GetAchievementInfo
local GetPvpTalentInfoByID = GetPvpTalentInfoByID
local GetTalentInfoByID = GetTalentInfoByID
local GetTalentInfo = GetTalentInfo

-- GetTalentInfoByID is not documented by this client, but addons (Details) call it
-- with the retail signature (talentID, name, texture, selected, available). The
-- classic signature (tabIndex, tier, column, rank) has no icon, so fall back to
-- GetTalentInfo(tab, tier, column) -> (name, icon, ...) when the third return is
-- not a texture.
local function GetTalentTextureByID(talentID)
	if not GetTalentInfoByID or not GetTalentInfo then
		return
	end

	local first, second, third = GetTalentInfoByID(talentID)
	if not first then
		return
	end

	if third and first ~= talentID then -- classic (tabIndex, tier, column, rank)
		return select(2, GetTalentInfo(first, second, third))
	end

	return third -- retail (talentID, name, texture, ...)
end

-- PvP talents are retail-only; the helper stays inert when the API is absent.
local function GetPvPTalentTextureByID(pvpTalentID)
	if not GetPvpTalentInfoByID then
		return
	end

	return select(3, GetPvpTalentInfoByID(pvpTalentID))
end

local C_ChallengeMode_GetMapUIInfo = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
local C_Item_GetDetailedItemLevelInfo = W.Compatibility.GetDetailedItemLevelInfo
local C_Item_GetItemIconByID = W.Compatibility.GetItemIconByID
local C_Item_GetItemInfoInstant = W.Compatibility.GetItemInfoInstant
local C_Item_GetItemNameByID = C_Item and C_Item.GetItemNameByID or function(itemID) return select(1, GetItemInfo(itemID)) end
local C_Soulbinds_GetConduitCollectionData = C_Soulbinds and C_Soulbinds.GetConduitCollectionData or function() return nil end
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
	local itemID, mapID, level = strmatch(link, "Hkeystone:(%d-):(%d-):(%d-):")
	if not (itemID and mapID and level and itemID == "180653") then
		return
	end

	if CL.db.icon then
		local mapIDNum = tonumber(mapID)
		local texture = mapIDNum and select(4, C_ChallengeMode_GetMapUIInfo(mapIDNum))
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddConduitIcon(link)
	local conduitID = strmatch(link, "Hconduit:(%d-):")
	if not conduitID then
		return
	end

	if CL.db.icon then
		local conduitCollectionData = C_Soulbinds_GetConduitCollectionData(conduitID)
		local conduitItemID = conduitCollectionData and conduitCollectionData.conduitItemID

		if conduitItemID then
			local texture = C_Item_GetItemIconByID(conduitItemID)
			local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
			if icon then
				link = icon .. " " .. link
			end
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

local function AddPvPTalentInfo(link)
	-- PVP talent
	local id = strmatch(link, "Hpvptal:(%d-)|")
	if not id then
		return
	end

	if CL.db.icon then
		local pvpTalentIDNum = tonumber(id)
		local texture = pvpTalentIDNum and GetPvPTalentTextureByID(pvpTalentIDNum)
		local icon = texture and F.GetIconString(texture, CL.db.iconHeight, CL.db.iconWidth, CL.db.keepRatio)
		if icon then
			link = icon .. " " .. link
		end
	end

	return link
end

local function AddTalentInfo(link)
	-- talent
	local id = strmatch(link, "Htalent:(%d-)|")
	if not id then
		return
	end

	if CL.db.icon then
		local talentIDNum = tonumber(id)
		local texture = talentIDNum and GetTalentTextureByID(talentIDNum)
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
		msg = gsub(msg, "(|cff71d5ff|Hconduit:%d+:.-|h.-|h|r)", AddConduitIcon)
		msg = gsub(msg, "(|cffa335ee|Hkeystone:%d+:.-|h.-|h|r)", AddKeystoneIcon)
		msg = gsub(msg, "(|Hitem:%d+:.-|h.-|h)", AddItemInfo)
		msg = gsub(msg, "(|Hcurrency:%d+:.-|h.-|h)", AddCurrencyInfo)
		msg = gsub(msg, "(|Hspell:%d+:%d+|h.-|h)", AddSpellInfo)
		msg = gsub(msg, "(|Henchant:%d+|h.-|h)", AddEnchantInfo)
		msg = gsub(msg, "(|Htalent:%d+|h.-|h)", AddTalentInfo)
		msg = gsub(msg, "(|Hpvptal:%d+|h.-|h)", AddPvPTalentInfo)
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
		ChatFrameUtil_AddMessageEventFilter(event, self.Filter)
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
