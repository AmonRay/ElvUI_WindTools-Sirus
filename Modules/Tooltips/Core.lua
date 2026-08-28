local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local ET = E:GetModule("Tooltip")
local T = W.Modules.Tooltips ---@class Tooltips

local _G = _G
local assert = assert
local next = next
local pairs = pairs
local select = select
local strsplit = strsplit
local tinsert = tinsert
local type = type
local xpcall = xpcall

local CanInspect = CanInspect
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer

local RAID_CLASS_COLORS_PRIEST = RAID_CLASS_COLORS.PRIEST

T.load = {} -- functions that need to be called when module is loaded
T.updateProfile = {} -- functions that need to be called when profile is updated
T.modifierInspect = {}
T.normalInspect = {}
T.clearInspect = {}
T.eventCallback = {}

function T:AddCallback(name, func)
	tinsert(self.load, func or self[name])
end

function T:AddCallbackForUpdate(name, func)
	tinsert(self.updateProfile, func or self[name])
end

function T:AddInspectInfoCallback(priority, inspectFunc, useModifier, clearFunc)
	if type(inspectFunc) == "string" then
		inspectFunc = self[inspectFunc]
	end

	assert(type(inspectFunc) == "function", "Invalid inspect function")

	if useModifier then
		self.modifierInspect[priority] = inspectFunc
	else
		self.normalInspect[priority] = inspectFunc
	end

	if clearFunc then
		if type(clearFunc) == "string" then
			clearFunc = self[clearFunc]
		end

		assert(type(clearFunc) == "function", "Invalid clear function")

		self.clearInspect[priority] = clearFunc
	end
end

function T:ClearInspectInfo(tt)
	if not tt or (tt.IsForbidden and tt:IsForbidden()) then
		return
	end

	-- Run all registered callbacks (clear)
	for _, func in next, self.clearInspect do
		xpcall(function()
			return func(self, tt)
		end, F.Developer.ThrowError)
	end
end

function T:CheckModifier()
	if not self.db or self.db.modifier == "NONE" then
		return true
	end

	local modifierStatus = {
		SHIFT = IsShiftKeyDown(),
		ALT = IsAltKeyDown(),
		CTRL = IsControlKeyDown(),
	}

	local results = {}
	for _, modifier in next, { strsplit("_", self.db.modifier) } do
		tinsert(results, modifierStatus[modifier] or false)
	end

	for _, v in next, results do
		if not v then
			return false
		end
	end

	return true
end

---@param tt GameTooltip
---@param data table
---@param triedTimes number?
function T:InspectInfo(tt, data, triedTimes)
	if (tt.IsForbidden and tt:IsForbidden()) or tt ~= GameTooltip or (ET.db and not ET.db.visibility) then
		return
	end

	if tt.windInspectLoaded then
		return
	end

	triedTimes = triedTimes or 0

	-- ET:GetDisplayedUnit is a retail ElvUI method absent on the 3.3.5a fork;
	-- fall back to GameTooltip:GetUnit (Wrath API) when present.
	local unit
	if ET and type(ET.GetDisplayedUnit) == "function" then
		unit = ET:GetDisplayedUnit(tt)
	elseif tt and tt.GetUnit then
		unit = tt:GetUnit()
	end

	if not unit then
		local GMF = E:GetMouseFocus()
		local focusUnit = GMF and GMF.GetAttribute and GMF:GetAttribute("unit")
		if focusUnit then
			unit = focusUnit
		end
		if not unit or not UnitExists(unit) then
			return
		end
	end

	if E:IsSecretValue(unit) or not unit or not data or not data.guid then
		return
	end

	-- Run all registered callbacks (normal)
	for _, func in next, self.normalInspect do
		xpcall(function()
			return func(self, tt, unit, data.guid)
		end, F.Developer.ThrowError)
	end

	-- General
	local inCombatLockdown = InCombatLockdown()
	local isShiftKeyDown = IsShiftKeyDown()
	local isPlayerUnit = UnitIsPlayer(unit)
	local isInspecting = _G.InspectPaperDollFrame and _G.InspectPaperDollFrame:IsShown()

	-- Item Level
	local itemLevelAvailable = isPlayerUnit and not inCombatLockdown and ET.db.inspectDataEnable

	if self.profiledb.elvUITweaks.forceItemLevel and not isInspecting then
		if not isShiftKeyDown and itemLevelAvailable and not tt.ItemLevelShown and ET and type(ET.AddInspectInfo) == "function" then
			local _, class = UnitClass(unit)
			local color = class and E:ClassColor(class) or RAID_CLASS_COLORS_PRIEST
			ET:AddInspectInfo(tt, unit, 0, color.r, color.g, color.b)
		end
	end

	-- Modifier callbacks pre-check
	if not self:CheckModifier() or not CanInspect(unit) then
		return
	end

	-- It ElvUI Item Level is enabled, we need to delay the modifier callbacks
	if self.db.forceItemLevel or isShiftKeyDown and itemLevelAvailable then
		if not tt.ItemLevelShown and triedTimes <= 4 then
			E:Delay(0.33, T.InspectInfo, T, tt, data, triedTimes + 1)
			return
		end
	end

	-- Run all registered callbacks (modifier)
	for _, func in next, self.modifierInspect do
		xpcall(function()
			return func(self, tt, unit, data.guid)
		end, F.Developer.ThrowError)
	end

	tt.windInspectLoaded = true
end

function T:ElvUIRemoveTrashLines(_, tt)
	if not tt or (tt.IsForbidden and tt:IsForbidden()) then
		return
	end

	tt.windInspectLoaded = false
end

function T:AddEventCallback(eventName, func)
	if type(func) == "string" then
		func = self[func]
	end
	if self.eventCallback[eventName] then
		tinsert(self.eventCallback[eventName], func)
	else
		self.eventCallback[eventName] = { func }
	end
end

function T:Event(event, ...)
	if self.eventCallback[event] then
		-- Lua 5.1: '...' is a compile error inside a non-vararg closure, so
		-- capture the event args first and unpack them in the handler.
		local args = { ... }
		for _, func in next, self.eventCallback[event] do
			xpcall(function()
				return func(self, event, unpack(args))
			end, F.Developer.ThrowError)
		end
	end
end

T:SecureHook(ET, "GameTooltip_OnTooltipSetUnit", function(...)
	if not T or not T.initialized then
		return
	end

	T:InspectInfo(...)
end)

function T:Initialize()
	self.db = E.private.WT.tooltips
	self.profiledb = E.db.WT.tooltips
	for index, func in next, self.load do
		xpcall(function()
			return func(self)
		end, F.Developer.ThrowError)
		self.load[index] = nil
	end

	for name, _ in pairs(self.eventCallback) do
		self:RegisterEvent(name, "Event")
	end

	-- ET here is ElvUI's Tooltips module; AddMythicInfo is mythic+-retail and some
	-- of these methods are absent on the 3.3.5a fork, so guard each hook.
	if ET and type(ET.AddMythicInfo) == "function" then
		self:RawHook(ET, "AddMythicInfo")
	end
	if ET and type(ET.SetUnitText) == "function" then
		self:SecureHook(ET, "SetUnitText", "SetUnitText")
	end
	if ET and type(ET.RemoveTrashLines) == "function" then
		self:SecureHook(ET, "RemoveTrashLines", "ElvUIRemoveTrashLines")
	end
	self:SecureHookScript(GameTooltip, "OnTooltipCleared", "ClearInspectInfo")

	self.initialized = true
end

function T:ProfileUpdate()
	self.profiledb = E.db.WT.tooltips
	for index, func in next, self.updateProfile do
		xpcall(function()
			return func(self)
		end, F.Developer.ThrowError)
		self.updateProfile[index] = nil
	end
end

if W and type(W.RegisterModule) == "function" then
	W:RegisterModule(T:GetName())
end
