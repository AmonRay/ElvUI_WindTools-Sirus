local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local ET = E:GetModule("Tooltip")
local T = W.Modules.Tooltips

local GameTooltipStatusBar = _G.GameTooltipStatusBar

function T:ChangeHealthBarPosition(_, tt)
	local barYOffset = E.db.WT.tooltips.elvUITweaks.healthBar.barYOffset
	local textYOffset = E.db.WT.tooltips.elvUITweaks.healthBar.textYOffset

	if barYOffset == 0 and textYOffset == 0 then
		return
	end

	if E.private.tooltip.enable ~= true then
		return
	end

	if (not tt or (tt.IsForbidden and tt:IsForbidden())) or not ET.db.visibility then
		return
	end

	if tt:GetAnchorType() ~= "ANCHOR_NONE" then
		return
	end

	if GameTooltipStatusBar then
		local spacing = E.Spacing * 3
		local position = ET.db.healthBar.statusPosition
		if position == "BOTTOM" then
			GameTooltipStatusBar:ClearAllPoints()
			GameTooltipStatusBar:Point("TOPLEFT", tt, "BOTTOMLEFT", E.Border, -spacing + barYOffset)
			GameTooltipStatusBar:Point("TOPRIGHT", tt, "BOTTOMRIGHT", -E.Border, -spacing + barYOffset)
			GameTooltipStatusBar.Text:Point("CENTER", GameTooltipStatusBar, 0, textYOffset)
		else
			GameTooltipStatusBar:ClearAllPoints()
			GameTooltipStatusBar:Point("BOTTOMLEFT", tt, "TOPLEFT", E.Border, spacing + barYOffset)
			GameTooltipStatusBar:Point("BOTTOMRIGHT", tt, "TOPRIGHT", -E.Border, spacing + barYOffset)
			GameTooltipStatusBar.Text:Point("CENTER", GameTooltipStatusBar, 0, textYOffset)
		end
	end
end

function T:HealthBar()
	T:SecureHook(ET, "GameTooltip_SetDefaultAnchor", "ChangeHealthBarPosition")
end

if T.AddCallback then
	T:AddCallback("HealthBar")
elseif not T.__windtoolsCoreMissingWarned then
	T.__windtoolsCoreMissingWarned = true
	F.Developer.ThrowError(
		"Tooltips HealthBar was skipped: Modules/Tooltips/Core.lua did not load (T:AddCallback is missing), so tooltip callbacks were not registered. Reinstall ElvUI_WindTools with a complete copy of all files, then /reload."
	)
end
