local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local C = W.Utilities.Color
local ET = E:GetModule("Tooltip")
local T = W.Modules.Tooltips

local _G = _G

local pairs = pairs
local select = select
local strmatch = strmatch
local tinsert = tinsert
local tonumber = tonumber

local UnitGUID = UnitGUID

local cache = {}
local locked = {}

local formatSets = {
	[1] = C.StringByTemplate(" (1/4)", "emerald-400"),
	[2] = C.StringByTemplate(" (2/4)", "blue-500"),
	[3] = C.StringByTemplate(" (3/4)", "blue-500"),
	[4] = C.StringByTemplate(" (4/4)", "fuchsia-500"),
	[5] = C.StringByTemplate(" (5/5)", "fuchsia-500"),
}

local function ResetCache(_, _, guid)
	cache[guid] = {}
	locked[guid] = nil
end

function T:ElvUITooltipPopulateInspectGUIDCache(_, unitGUID, itemLevel)
	-- After ElvUI calculated the average item level, the process of scanning should be done.
	locked[unitGUID] = true
end

function T:ElvUIScanTooltipSetInventoryItem(tt, unit)
	local guid = UnitGUID(unit)
	if E:IsSecretValue(guid) or not guid or not cache[guid] or locked[guid] then
		return
	end

	local itemLink = select(2, tt:GetItem())
	local itemID = itemLink and strmatch(itemLink, "item:(%d+):")
	if itemID then
		itemID = tonumber(itemID)
		if W.CurrentTierSetItemIDTable[itemID] then
			for _, i in pairs(cache[guid]) do
				if i == itemID then
					return
				end
			end
			tinsert(cache[guid], itemID)
		end
	end
end

function T:TierSet(tt, _, guid)
	-- ElvUI do not scan player itself
	if guid == E.myguid then
		ResetCache(nil, nil, guid)
		for i = 1, 17 do
			if i ~= 4 then
				E:GetGearSlotInfo("player", i)
			end
		end
		locked[guid] = true
	end

	if not cache[guid] or #cache[guid] == 0 then
		return
	end

	for i = 1, tt:NumLines() do
		local leftTip = _G["GameTooltipTextLeft" .. i]
		local leftTipText = leftTip:GetText()
		if E:NotSecretValue(leftTipText) and leftTipText and leftTipText == L["Item Level:"] then
			local rightTip = _G["GameTooltipTextRight" .. i]
			local rightTipText = rightTip:GetText()
			if E:NotSecretValue(rightTipText) and rightTipText then
				rightTip:SetText(formatSets[#cache[guid]] .. "|r " .. rightTipText)
			end
			return
		end
	end
end

function T:InitializeTierSet()
	if not self.db.tierSet then
		return
	end

	-- ET (ElvUI Tooltip) lacks the INSPECT_READY handler and PopulateInspectGUIDCache
	-- method on the 3.3.5a fork; hook them only when actually present.
	if ET and type(ET.INSPECT_READY) == "function" then
		self:Hook(ET, "INSPECT_READY", ResetCache, true)
	end
	if ET and type(ET.PopulateInspectGUIDCache) == "function" then
		self:Hook(ET, "PopulateInspectGUIDCache", "ElvUITooltipPopulateInspectGUIDCache")
	end
	-- E.ScanTooltip:SetInventoryItem may not exist on the 3.3.5a ElvUI fork
	if E.ScanTooltip and type(E.ScanTooltip.SetInventoryItem) == "function" then
		self:SecureHook(E.ScanTooltip, "SetInventoryItem", "ElvUIScanTooltipSetInventoryItem")
	end
	self:AddInspectInfoCallback(1, "TierSet", true)
end

if T.AddCallback then
	T:AddCallback("InitializeTierSet")
elseif not T.__windtoolsCoreMissingWarned then
	T.__windtoolsCoreMissingWarned = true
	F.Developer.ThrowError(
		"Tooltips TierSet was skipped: Modules/Tooltips/Core.lua did not load (T:AddCallback is missing), so tooltip callbacks were not registered. Reinstall ElvUI_WindTools with a complete copy of all files, then /reload."
	)
end
