local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local M = W.Modules.Misc ---@class Misc

local _G = _G
local format = format

local GenericTraitUI_LoadUI = GenericTraitUI_LoadUI
local GetInventoryItemID = GetInventoryItemID
local InCombatLockdown = InCombatLockdown
local ShowUIPanel = ShowUIPanel

local Enum_TooltipDataType_Item = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item
local TooltipDataProcessor_AddTooltipPostCall = _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall

local ScrollButtonIcon = "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:127:204|t"

local INVSLOT_BACK = INVSLOT_BACK

-- This is a module from NDui_Plus
local WARPS_TREE_ID = 1115
local WARPS_ITEM_ID = 235499

function M:ReshiiWrapsUpgrade()
	if not E.private.WT.misc.reshiiWrapsUpgrade then
		return
	end

	-- The trait UI (GenericTraitUI_LoadUI / GenericTraitFrame) and the Reshii
	-- wraps item are retail-only; without them the middle-click shortcut cannot
	-- work, so do not install the hook at all on 3.3.5a.
	if type(GenericTraitUI_LoadUI) ~= "function" or not _G.CharacterBackSlot then
		return
	end

	_G.CharacterBackSlot:HookScript("OnMouseDown", function(_, button)
		if button == "MiddleButton" then
			local itemID = GetInventoryItemID("player", INVSLOT_BACK)
			if itemID and itemID == WARPS_ITEM_ID then
				if not InCombatLockdown() then
					GenericTraitUI_LoadUI()
					_G.GenericTraitFrame:SetTreeID(WARPS_TREE_ID)
					ShowUIPanel(_G.GenericTraitFrame)
				else
					_G.UIErrorsFrame:AddMessage(E.InfoColor .. _G.ERR_NOT_IN_COMBAT)
				end
			end
		end
	end)
end

if TooltipDataProcessor_AddTooltipPostCall and Enum_TooltipDataType_Item then
	TooltipDataProcessor_AddTooltipPostCall(Enum_TooltipDataType_Item, function(tooltip, data)
	if tooltip:GetOwner() ~= _G.CharacterBackSlot or data.id ~= WARPS_ITEM_ID then
		return
	end

	if not E or not E.private or not E.private.WT or not E.private.WT.misc.reshiiWrapsUpgrade then
		return
	end

	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(
		format("%s %s", ScrollButtonIcon, L["Middle Button"]),
		F.GetWindStyleText(L["Open Upgrade Menu"])
	)
end)
end

M:AddCallback("ReshiiWrapsUpgrade")
