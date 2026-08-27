local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local M = W.Modules.Misc ---@class Misc

local _G = _G
local strmatch = strmatch
local tContains = tContains

local TooltipDataProcessor_AddTooltipPostCall = _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall
local Enum_TooltipDataType_Item = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item

local tooltips = {
	"GameTooltip",
	"ItemRefTooltip",
	"ShoppingTooltip1",
	"ShoppingTooltip2",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
}

local function removeCraftInformation(tooltip, data)
	if not E.db.WT.misc.hideCrafter then
		return
	end

	local tooltipName = tooltip:GetName()
	if tContains(tooltips, tooltipName) then
		for dataIndex = #data.lines, (10 < #data.lines and 10 or 0), -1 do
			local line = data.lines[dataIndex] and data.lines[dataIndex].leftText
			if line and strmatch(line, "^|cff00ff00<(.+)>|r$") then
				for tooltipLineIndex = dataIndex, dataIndex + 2 do
					local realLine = _G[tooltipName .. "TextLeft" .. tooltipLineIndex]
					local realText = realLine and realLine:GetText()
					if E:NotSecretValue(realText) and realText == line then
						realLine:SetText("")
					end
				end
			end
		end
	end
end

function M:HideCrafter()
	if TooltipDataProcessor_AddTooltipPostCall and Enum_TooltipDataType_Item then
		TooltipDataProcessor_AddTooltipPostCall(Enum_TooltipDataType_Item, removeCraftInformation)
	end
end

M:AddCallback("HideCrafter")
