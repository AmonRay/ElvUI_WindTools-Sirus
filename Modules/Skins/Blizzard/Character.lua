local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G

function S:BlizzardCharacterFrame()
	if not self:CheckDB("character") then
		return
	end

	-- Character
	if _G.CharacterFrame then
		self:CreateShadow(_G.CharacterFrame)
	end
	if _G.GearManagerDialogPopup then
		self:CreateShadow(_G.GearManagerDialogPopup)
	end
	if _G.EquipmentFlyoutFrame then
		self:CreateShadow(_G.EquipmentFlyoutFrame)
	end
	for i = 1, 4 do
		self:ReskinTab(_G["CharacterFrameTab" .. i])
	end

	-- Remove the model background textures (Wrath: CharacterModelFrame)
	local modelFrame = _G.CharacterModelFrame
	if modelFrame then
		if modelFrame.BackgroundTopLeft then
			modelFrame.BackgroundTopLeft:Hide()
		end
		if modelFrame.BackgroundTopRight then
			modelFrame.BackgroundTopRight:Hide()
		end
		if modelFrame.BackgroundBotLeft then
			modelFrame.BackgroundBotLeft:Hide()
		end
		if modelFrame.BackgroundBotRight then
			modelFrame.BackgroundBotRight:Hide()
		end
		if modelFrame.BackgroundOverlay then
			modelFrame.BackgroundOverlay:Hide()
		end
		if modelFrame.backdrop then
			modelFrame.backdrop:Kill()
		end
	end

	-- Token (Sirus client adds a Token tab to CharacterFrame)
	if _G.TokenFrame then
		self:CreateShadow(_G.TokenFrame)
	end
	if _G.TokenFramePopup then
		self:CreateShadow(_G.TokenFramePopup)
	end

	-- Reputation (Wrath: ReputationDetailFrame is a global frame, not a child of ReputationFrame)
	if _G.ReputationDetailFrame then
		self:CreateShadow(_G.ReputationDetailFrame)
		_G.ReputationDetailFrame:ClearAllPoints()
		_G.ReputationDetailFrame:Point("TOPLEFT", _G.ReputationFrame, "TOPRIGHT", 3, 0)
	end
end

-- CharacterFrame is created by FrameXML (PaperDollFrame), no addon gate needed.
S:AddCallback("BlizzardCharacterFrame")
