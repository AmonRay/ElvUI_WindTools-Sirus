local W ---@class WindTools
local F, E, L ---@type Functions, ElvUI, LocaleTable
W, F, E, L = unpack((select(2, ...)))

local KI = W:NewModule("KeystoneInfo", "AceEvent-3.0") ---@class KeystoneInfo : AceModule, AceEvent-3.0

-- Keystone exchange on this client
-- --------------------------------
-- The modified 3.3.5a client implements Mythic+ itself (FrameXML/Utils/C_Mythic.lua),
-- so the keystone of the local player comes straight from the client:
--
--   C_MythicPlus.GetOwnerKeystoneInfo() -> itemID, mapChallengeModeID, level, affixIDs
--   C_MythicPlus.GetOwnerKeystoneTime() -> seconds until the keystone expires
--   GetContainerItemLink(bag, slot)     -> |Hkeystone:itemID:randomPropertyID:mapID:level:affixes|h
--                                          (the client rebuilds that link for the owned
--                                          keystone in SharedXML/Utils/C_Item.lua)
--
-- The client never publishes another player's keystone, so group data still comes
-- from LibKeystone (the BigWigs library) - the same exchange BigWigs and Details
-- use on this realm. LibOpenRaid is not used here at all: it is a retail library
-- and stays opt-in on this client (see Preflight.lua).
local KS = E.Libs.Keystone
local hasKeystoneExchange = type(KS) == "table"
	and type(KS.Register) == "function"
	and type(KS.Request) == "function"

local select = select
local strfind = strfind
local strmatch = strmatch
local tonumber = tonumber
local type = type

local Ambiguate = Ambiguate
local GetUnitName = GetUnitName
local IsInGroup = IsInGroup
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit

local Compatibility = W.Compatibility
local GetContainerItemLink = Compatibility.GetContainerItemLink
local GetContainerNumSlots = Compatibility.GetContainerNumSlots

local NUM_BAG_SLOTS = NUM_BAG_SLOTS

-- The client writes and reads keystone hyperlinks in its own layout:
--   |c<rarity>|Hkeystone:itemID:randomPropertyID:mapChallengeModeID:level:affix1..5|h[name]|h|r
-- so the map and the level are read from that suffix instead of splitting the
-- whole link on ":" (the color prefix would otherwise shift every field).
local KEYSTONE_LINK_PATTERN = "Hkeystone:%d+:%d+:(%d+):(%d+)"

---@param link string?
---@return boolean
local function isKeystoneLink(link)
	return type(link) == "string" and strfind(link, "Hkeystone:", 1, true) ~= nil
end

---@class KeystoneInfoData
---@field level number
---@field challengeMapID number
---@field rating number

---Keystones other players reported through LibKeystone, keyed by short name.
---@type table<string, KeystoneInfoData>
KI.LibKeystoneInfo = {}

---@class KeystoneInfo.PlayerKeystone
---@field level number?
---@field mapID number?
KI.PlayerKeystone = {}

---The keystone the player owns, according to the client's own Mythic+ bookkeeping.
---@return number? challengeMapID
---@return number? level
---@return number? itemID
function KI:GetOwnedKeystone()
	local api = _G.C_MythicPlus
	local method = api and api.GetOwnerKeystoneInfo
	if type(method) ~= "function" then
		return
	end

	local itemID, challengeMapID, level = method(api)
	if type(challengeMapID) ~= "number" or type(level) ~= "number" or challengeMapID <= 0 or level <= 0 then
		return
	end

	return challengeMapID, level, itemID
end

---A link carrying the keystone payload is the player's own keystone: the client
---enriches only that one, every other keystone stays a plain item link.
---@return string? link
function KI:GetPlayerKeystoneLink()
	for bagIndex = 0, NUM_BAG_SLOTS do
		for slotIndex = 1, GetContainerNumSlots(bagIndex) do
			local link = GetContainerItemLink(bagIndex, slotIndex)
			if isKeystoneLink(link) then
				return link
			end
		end
	end
end

---@return number? mapID
---@return number? level
---@return string? link
function KI:GetPlayerKeystone()
	local link = self:GetPlayerKeystoneLink()

	-- The client's bookkeeping is authoritative: it updates as soon as the key is
	-- created, before the container link is rebuilt from the item cache.
	local challengeMapID, level = self:GetOwnedKeystone()
	if challengeMapID and level then
		return challengeMapID, level, link
	end

	-- Clients without the Mythic+ API can still describe the key through the link.
	if link then
		local mapID, keystoneLevel = strmatch(link, KEYSTONE_LINK_PATTERN)
		mapID, keystoneLevel = tonumber(mapID), tonumber(keystoneLevel)
		if mapID and keystoneLevel then
			return mapID, keystoneLevel, link
		end
	end

	return nil, nil, link
end

---Asks the group (or the guild) for their keystones. The exchange itself belongs to
---LibKeystone, which answers through the callback registered below.
---@param channel "PARTY"|"GUILD"
function KI:RequestPeerKeystones(channel)
	if hasKeystoneExchange then
		KS.Request(channel)
	end
end

---@param skipEmit boolean? the flag to skip sending custom message to other modules
function KI:RequestAndCheckPlayerKeystone(skipEmit)
	self:RequestData()
	self:CheckPlayerKeystone(skipEmit)
end

---@param skipEmit boolean? the flag to skip sending custom message to other modules
function KI:CheckPlayerKeystone(skipEmit)
	local challengeMapID, level, link = self:GetPlayerKeystone()

	if self.PlayerKeystone.mapID ~= challengeMapID or self.PlayerKeystone.level ~= level then
		if not skipEmit then
			self:SendMessage("WINDTOOLS_PLAYER_KEYSTONE_CHANGED", challengeMapID, level, link)
		end

		self:RequestPeerKeystones("GUILD")
	end

	self.PlayerKeystone.mapID, self.PlayerKeystone.level = challengeMapID, level
end

function KI:DelayedCheckPlayerKeystone()
	E:Delay(0.5, KI.CheckPlayerKeystone, KI)
end

function KI:RequestData()
	if IsInGroup() then
		self:RequestPeerKeystones("PARTY")
	end
end

---@param unit UnitToken
---@return KeystoneInfoData?
function KI:UnitData(unit)
	if not unit or E:IsSecretValue(unit) or not UnitIsPlayer(unit) then
		return
	end

	local name = GetUnitName(unit, true)
	local sender = name and Ambiguate(name, "none")
	if not sender then
		return
	end

	local data = self.LibKeystoneInfo[sender]
	if data and data.level and data.level > 0 then
		return data
	end

	-- The player's own keystone never needs the exchange, the client knows it.
	if unit == "player" or (UnitIsUnit and UnitIsUnit(unit, "player")) then
		local challengeMapID, level = self:GetPlayerKeystone()
		if challengeMapID and level then
			return {
				challengeMapID = challengeMapID,
				level = level,
				rating = (data and data.rating) or 0,
			}
		end
	end

	return data
end

if hasKeystoneExchange then
	KS.Register(KI, function(keyLevel, keyChallengeMapID, playerRating, sender)
		KI.LibKeystoneInfo[sender] = {
			level = keyLevel,
			challengeMapID = keyChallengeMapID,
			rating = playerRating,
		}
	end)
else
	-- Only the player's own keystone can be reported without the exchange.
	W.Compatibility:Report(
		"KeystoneInfo",
		L["LibKeystone did not load, so keystones of other players cannot be exchanged; only your own keystone is shown."],
		{ "LibKeystone" }
	)
end

KI:RegisterEvent("GROUP_ROSTER_UPDATE", "RequestData")
KI:RegisterEvent("CHALLENGE_MODE_START", "RequestData")
KI:RegisterEvent("CHALLENGE_MODE_RESET", "RequestData")
KI:RegisterEvent("CHALLENGE_MODE_COMPLETED", "RequestAndCheckPlayerKeystone")
KI:RegisterEvent("ITEM_CHANGED", "DelayedCheckPlayerKeystone")
KI:RegisterEvent("ITEM_PUSH", "DelayedCheckPlayerKeystone")
-- Sirus: server-pushed keystone info (FrameXML/Utils/C_Mythic.lua, custom event)
KI:RegisterEvent("MYTHIC_PLUS_OWNED_KEYSTONE_UPDATE", "DelayedCheckPlayerKeystone")

F.TaskManager:AfterLogin(KI.RequestAndCheckPlayerKeystone, KI, true)
