local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G

function S:LootFrame()
	if not self:CheckDB("loot") then
		return
	end

	-- BonusRoll* (bonus loot / warfront roll) frames are retail-only and do not
	-- exist on 3.3.5a; GroupLootHistoryFrame is the Wrath equivalent.
	if _G.BonusRollFrame then
		self:CreateShadow(_G.BonusRollFrame)
		self:CreateBackdropShadow(_G.BonusRollLootWonFrame)
		self:CreateBackdropShadow(_G.BonusRollMoneyWonFrame)
		F.SetFont(_G.BonusRollFrame.PromptFrame.InfoFrame.Cost)
		F.SetFont(_G.BonusRollFrame.PromptFrame.InfoFrame.Label)
	end

	-- GroupLootHistoryFrame is retail-only (Cata+ group loot history) absent on
	-- 3.3.5a, so apply its skin only when the frame exists.
	if _G.GroupLootHistoryFrame then
		self:CreateShadow(_G.GroupLootHistoryFrame)

		local ResizeButton = _G.GroupLootHistoryFrame.ResizeButton
		if ResizeButton then
			ResizeButton:SetTemplate("Transparent")
			self:CreateShadow(ResizeButton)
		end

		local Timer = _G.GroupLootHistoryFrame.Timer
		if Timer then
			F.Move(Timer, 0, -7)
		end
	end
end

S:AddCallback("LootFrame")
