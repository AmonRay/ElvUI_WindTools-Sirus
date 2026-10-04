local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G

function S:PetBattle()
	if not self:CheckDB("petbattleui", "petBattle") then
		return
	end

	-- Pet battles were introduced in MoP; the 3.3.5a client has neither
	-- PetBattleFrame nor ElvUIPetBattleActionBar, so this retail-only skin is a
	-- no-op there instead of an "attempt to index a nil value" error.
	local f = _G.PetBattleFrame
	local actionBar = _G.ElvUIPetBattleActionBar
	if not (f and actionBar and f.BottomFrame and f.ActiveAlly and f.ActiveEnemy) then
		W.Compatibility:Report("PetBattle", L["This client has no pet battle frame, so the pet battle UI skin is skipped."])
		return
	end

	local bf = f.BottomFrame

	self:CreateShadow(actionBar)

	if actionBar.shadow then
		actionBar.shadow:ClearAllPoints()
		actionBar.shadow:Point("TOPLEFT", bf.xpBar, "TOPLEFT", -5, 5)
		actionBar.shadow:Point("BOTTOMRIGHT", actionBar, "BOTTOMRIGHT", 5, -5)
	end

	self:CreateBackdropShadow(f.ActiveAlly.ActualHealthBar)
	self:CreateBackdropShadow(f.ActiveAlly.Icon)
	F.SetFont(f.ActiveAlly.Name)

	self:CreateBackdropShadow(f.ActiveEnemy.ActualHealthBar)
	self:CreateBackdropShadow(f.ActiveEnemy.Icon)
	F.SetFont(f.ActiveEnemy.Name)

	self:CreateShadow(f.Ally2)
	self:CreateShadow(f.Ally3)
	self:CreateShadow(f.Enemy2)
	self:CreateShadow(f.Enemy3)
end

S:AddCallback("PetBattle")
