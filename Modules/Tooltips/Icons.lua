local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local T = W.Modules.Tooltips ---@class Tooltips
local C = W.Utilities.Color
local _G = _G
local pairs = pairs
local select = select
local strfind = strfind
local tContains = tContains
local tonumber = tonumber
local tostring = tostring
local GetAchievementInfo = GetAchievementInfo
local UnitBattlePetSpeciesID = UnitBattlePetSpeciesID
local UnitBattlePetType = UnitBattlePetType
local UnitFactionGroup = UnitFactionGroup
local UnitIsBattlePet = UnitIsBattlePet
local UnitIsBattlePetCompanion = UnitIsBattlePetCompanion
local UnitIsPlayer = UnitIsPlayer
local UnitIsWildBattlePet = UnitIsWildBattlePet
local Compatibility = W.Compatibility
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo or GetCurrencyInfo
local C_EquipmentSet_GetEquipmentSetInfo = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo or GetEquipmentSetInfo
local C_Item_GetItemIconByID = Compatibility.GetItemIconByID
local C_MountJournal_GetMountInfoByID = C_MountJournal and C_MountJournal.GetMountInfoByID
local C_Spell_GetSpellTexture = Compatibility.GetSpellTexture
local TooltipDataProcessor_AddTooltipPostCall = _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall
local TooltipDataType = _G.Enum and _G.Enum.TooltipDataType or {}
local Enum_TooltipDataType_Achievement = TooltipDataType.Achievement
local Enum_TooltipDataType_Currency = TooltipDataType.Currency
local Enum_TooltipDataType_EquipmentSet = TooltipDataType.EquipmentSet
local Enum_TooltipDataType_Item = TooltipDataType.Item
local Enum_TooltipDataType_Macro = TooltipDataType.Macro
local Enum_TooltipDataType_Mount = TooltipDataType.Mount
local Enum_TooltipDataType_Spell = TooltipDataType.Spell
local Enum_TooltipDataType_Toy = TooltipDataType.Toy
local tooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ElvUI_SpellBookTooltip" }
local PET_TYPE_SUFFIX = PET_TYPE_SUFFIX
_G.BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT = "|T%1$s:16:16:0:0:64:64:5:59:5:59|t |cffffffff%2$s|r %3$s"
_G.BONUS_OBJECTIVE_REWARD_FORMAT = "|T%1$s:16:16:0:0:64:64:5:59:5:59|t %2$s"
local iconFunctions = {}
if Enum_TooltipDataType_Achievement then iconFunctions[Enum_TooltipDataType_Achievement] = function(data) local id = tonumber(data and data.id); local icon = id and select(10, GetAchievementInfo(id)); return icon and tostring(icon) end end
if Enum_TooltipDataType_Item then iconFunctions[Enum_TooltipDataType_Item] = function(data) local icon = data and data.id and C_Item_GetItemIconByID(data.id); return icon and tostring(icon) end end
if Enum_TooltipDataType_Spell then iconFunctions[Enum_TooltipDataType_Spell] = function(data) local icon = data and data.id and C_Spell_GetSpellTexture(data.id); return icon and tostring(icon) end end
if Enum_TooltipDataType_Toy then iconFunctions[Enum_TooltipDataType_Toy] = iconFunctions[Enum_TooltipDataType_Item] end
if Enum_TooltipDataType_Mount then iconFunctions[Enum_TooltipDataType_Mount] = function(data) local icon = data and data.id and select(3, C_MountJournal_GetMountInfoByID(data.id)); return icon and tostring(icon) end end
if Enum_TooltipDataType_Currency then iconFunctions[Enum_TooltipDataType_Currency] = function(data) local info = data and data.id and C_CurrencyInfo_GetCurrencyInfo(data.id); local fileID = info and info.iconFileID; return fileID and tostring(fileID) end end
if Enum_TooltipDataType_EquipmentSet then iconFunctions[Enum_TooltipDataType_EquipmentSet] = function(data) local icon = data and data.id and select(2, C_EquipmentSet_GetEquipmentSetInfo(data.id)); return icon and tostring(icon) end end
if Enum_TooltipDataType_Macro then iconFunctions[Enum_TooltipDataType_Macro] = function(data) local lineData = data and data.lines and data.lines[1]; local tooltipType = lineData and lineData.tooltipType; if tooltipType == Enum_TooltipDataType_Item then return tostring(C_Item_GetItemIconByID(lineData.tooltipID) or "") elseif tooltipType == Enum_TooltipDataType_Spell then return tostring(C_Spell_GetSpellTexture(lineData.tooltipID) or "") end end end
local function SetTooltipIcon(tt, data, typeID)
	if not data or not data.lines or E:IsSecretValue(data.lines) then return end
	local icon = iconFunctions[typeID] and iconFunctions[typeID](data)
	local title = data.lines[1] and data.lines[1].leftText
	local iconDB = E.private.WT.tooltips.titleIcon
	local iconString = icon and F.GetIconString(icon, iconDB.height, iconDB.width, true)
	if not title or not iconString then return end
	for i = 1, 3 do
		local row = _G[tt:GetName() .. "TextLeft" .. i]
		local existingText = row and row:GetText()
		if existingText and strfind(existingText, title, 1, true) and not strfind(existingText, "^|T") then row:SetText(iconString .. " " .. existingText); return end
	end
end
local function Handle(typeID)
	TooltipDataProcessor_AddTooltipPostCall(typeID, function(tt, data)
		if not tt or (tt.IsForbidden and tt:IsForbidden()) then return end
		local name = tt.GetName and tt:GetName()
		if not data or not data.id or not data.lines or not tContains(tooltips, name) then return end
		SetTooltipIcon(tt, data, typeID)
	end)
end
if TooltipDataProcessor_AddTooltipPostCall then
	for _, typeID in pairs({ Enum_TooltipDataType_Achievement, Enum_TooltipDataType_Item, Enum_TooltipDataType_Spell, Enum_TooltipDataType_Toy, Enum_TooltipDataType_Mount, Enum_TooltipDataType_Currency, Enum_TooltipDataType_EquipmentSet, Enum_TooltipDataType_Macro }) do if typeID then Handle(typeID) end end
end
function T:UpdateTitleIcon() end
