local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local strmatch = strmatch

local GetMaterialTextColors = GetMaterialTextColors
local GetNumQuestLeaderBoards = GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = GetQuestLogLeaderBoard

local MAX_OBJECTIVES = MAX_OBJECTIVES or 10

local DEFAULT_COLOR = GetMaterialTextColors and GetMaterialTextColors("Default") or { 0.18, 0.12, 0.06 }
local COMPLETED_COLOR = 0.2

local function ApplyObjectiveTextColoring()
	if not _G.QuestInfoFrame.questLog then
		return
	end

	local numVisibleObjectives = 0

	-- Process all quest objectives
	for objectiveIndex = 1, GetNumQuestLeaderBoards() do
		local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(objectiveIndex)

		if
			description
			and objectiveType ~= "spell"
			and objectiveType ~= "log"
			and numVisibleObjectives < MAX_OBJECTIVES
		then
			numVisibleObjectives = numVisibleObjectives + 1
			local objectiveFrame = _G["QuestInfoObjective" .. numVisibleObjectives] --[[@as FontString?]]
			if objectiveFrame then
				if isCompleted then
					objectiveFrame:SetTextColor(0.2, 1, 0.2) -- Green for completed
				else
					objectiveFrame:SetTextColor(1, 1, 1) -- White for incomplete
				end
			end
		end
	end
end

---Replaces default quest text colors with enhanced visibility colors
---@param textObject FontString The text object to modify
---@param redValue number The red component of the current color
---@param greenValue number The green component of the current color
---@param blueValue number The blue component of the current color
local function ReplaceQuestTextColor(textObject, redValue, greenValue, blueValue)
	if F.IsAlmost({ redValue, greenValue, blueValue }, { 0, 0.82, 0.82 }, 0.002) then
		return
	elseif redValue == 0 or redValue == DEFAULT_COLOR[1] then
		textObject:SetTextColor(1, 1, 1) -- White for better readability
	elseif redValue == COMPLETED_COLOR then
		textObject:SetTextColor(0.7, 0.7, 0.7) -- Muted for completed objectives
	end
end

---Applies minimal styling to reward buttons while preserving functionality
---@param rewardButton Button The reward button frame to style
local function StyleRewardButton(rewardButton)
	if not rewardButton then
		return
	end

	if rewardButton.NameFrame then
		rewardButton.NameFrame:Hide()
	end

	if not rewardButton.Icon then
		return
	end

	rewardButton.Icon:CreateBackdrop("Transparent")
	rewardButton.Icon:SetTexCoords()
	S:CreateBackdropShadow(rewardButton.Icon)
	S:BindShadowColorWithBorder(rewardButton.Icon.backdrop)

	rewardButton:CreateBackdrop("Transparent")
	S:CreateBackdropShadow(rewardButton)
	rewardButton.backdrop:ClearAllPoints()
	rewardButton.backdrop:Point("TOPRIGHT", rewardButton, "TOPRIGHT", -4, 0)
	rewardButton.backdrop:Point("BOTTOMLEFT", rewardButton.Icon.backdrop, "BOTTOMRIGHT", 2, 0)
end

---Applies styling to reward buttons with specific size requirements
---@param rewardButton Button The reward button frame to style
local function StyleRewardButtonWithSize(rewardButton)
	if not rewardButton then
		return
	end

	StyleRewardButton(rewardButton)

	if rewardButton.Icon then
		rewardButton.Icon:Size(34)
	end
end

---Hook function to maintain yellow text color for headers
---@param textFrame FontString The text frame being modified
---@param redValue number Red component of the color
---@param greenValue number Green component of the color
---@param blueValue number Blue component of the color
local function MaintainYellowTextColor(textFrame, redValue, greenValue, blueValue)
	if redValue ~= 1 or greenValue ~= 0.8 or blueValue ~= 0 then
		textFrame:SetTextColor(1, 0.8, 0) -- Force yellow color
	end
end

---Configures font with yellow coloring and outline for quest headers
---@param fontObject FontString The font object to configure
local function ConfigureYellowHeaderFont(fontObject)
	if not fontObject then
		return
	end

	F.SetFont(fontObject)
	fontObject:SetTextColor(1, 0.8, 0) -- Yellow for headers
	fontObject:SetShadowColor(0, 0, 0, 0)
	hooksecurefunc(fontObject, "SetTextColor", MaintainYellowTextColor)
end

---Hook function to maintain white text color for content
---@param textFrame FontString The text frame being modified
---@param redValue number Red component of the color
---@param greenValue number Green component of the color
---@param blueValue number Blue component of the color
local function MaintainWhiteTextColor(textFrame, redValue, greenValue, blueValue)
	if redValue ~= 1 or greenValue ~= 1 or blueValue ~= 1 then
		textFrame:SetTextColor(1, 1, 1) -- Force white color
	end
end

---Configures font with white coloring and outline for quest content
---@param fontObject FontString The font object to configure
local function ConfigureWhiteContentFont(fontObject)
	if not fontObject then
		return
	end

	F.SetFont(fontObject)
	fontObject:SetTextColor(1, 1, 1) -- White for content
	fontObject:SetShadowColor(0, 0, 0, 0)
	hooksecurefunc(fontObject, "SetTextColor", MaintainWhiteTextColor)
end

local function QuestInfo_Display()
	for objectiveIndex = 1, MAX_OBJECTIVES do
		local objectiveText = _G["QuestInfoObjective" .. objectiveIndex]
		if objectiveText and not objectiveText.__windSkin then
			if E.private.skins.parchmentRemoverEnable then
				F.SetFont(objectiveText)

				if not objectiveText.colorHooked then
					hooksecurefunc(objectiveText, "SetTextColor", ReplaceQuestTextColor)
					local currentRed, currentGreen, currentBlue = objectiveText:GetTextColor()
					objectiveText:SetTextColor(currentRed, currentGreen, currentBlue)
					objectiveText.colorHooked = true
				end
			end
			objectiveText.__windSkin = true
		end
	end

	-- In Wrath quest rewards are plain QuestInfoItem1..10 buttons
	for itemIndex = 1, 10 do
		local rewardButton = _G["QuestInfoItem" .. itemIndex]
		if rewardButton and not rewardButton.__windSkin then
			StyleRewardButton(rewardButton)
			rewardButton.__windSkin = true
		end
	end
end

function S:BlizzardQuestFrames()
	if not self:CheckDB("quest") then
		return
	end

	-- Apply shadow effects to main quest frames
	self:CreateShadow(_G.QuestFrame)
	self:CreateShadow(_G.QuestLogDetailFrame)
	self:CreateShadow(_G.QuestLogFrame)

	hooksecurefunc("QuestInfo_Display", QuestInfo_Display)

	if _G.QuestInfoItemHighlight then
		_G.QuestInfoItemHighlight:Kill()
	end

	if _G.QuestInfoPlayerTitleFrame then
		local titleRewardFrame = _G.QuestInfoPlayerTitleFrame
		local titleIcon = _G.QuestInfoPlayerTitleFrameIconTexture

		if titleIcon then
			titleIcon:SetTexCoords()
			titleIcon:CreateBackdrop("Transparent")
		end

		-- Hide decorative regions while preserving functionality
		for regionIndex = 2, 4 do
			local region = select(regionIndex, titleRewardFrame:GetRegions())
			if region then
				region:Hide()
			end
		end

		titleRewardFrame:CreateBackdrop("Transparent")
		if titleIcon then
			titleRewardFrame.backdrop:Point("TOPLEFT", titleIcon, "TOPRIGHT", 0, 2)
			titleRewardFrame.backdrop:Point("BOTTOMRIGHT", titleIcon, "BOTTOMRIGHT", 220, -1)
		end
	end

	if _G.QuestFrame and _G.QuestFrame.TitleText then
		F.SetFont(_G.QuestFrame.TitleText)
	end

	if not E.private.skins.parchmentRemoverEnable then
		return
	end

	hooksecurefunc("QuestInfo_Display", ApplyObjectiveTextColoring)

	if _G.QuestInfoRequiredMoneyText then
		hooksecurefunc(_G.QuestInfoRequiredMoneyText, "SetTextColor", function(textFrame, redValue)
			if redValue == 0 then
				textFrame:SetTextColor(0.8, 0.8, 0.8, 1) -- Insufficient funds - muted
			elseif redValue == 0.2 then
				textFrame:SetTextColor(1, 1, 1, 1) -- Sufficient funds - white
			end
		end)
		hooksecurefunc(_G.QuestInfoRequiredMoneyText, "SetTextColor", ReplaceQuestTextColor)
	end

	local questHeaderFonts = {
		_G.QuestInfoTitleHeader,
		_G.QuestInfoDescriptionHeader,
		_G.QuestInfoObjectivesHeader,
		_G.QuestInfoRewardsHeader,
	}

	for _, headerFont in pairs(questHeaderFonts) do
		if headerFont then
			ConfigureYellowHeaderFont(headerFont)
		end
	end

	local questContentFonts = {
		_G.QuestInfoDescriptionText,
		_G.QuestInfoObjectivesText,
		_G.QuestInfoGroupSize,
		_G.QuestInfoRewardText,
		_G.QuestInfoTimerText,
		_G.QuestInfoItemChooseText,
		_G.QuestInfoItemReceiveText,
		_G.QuestInfoSpellLearnText,
		_G.QuestInfoXPFrameReceiveText,
	}

	for _, contentFont in pairs(questContentFonts) do
		if contentFont then
			ConfigureWhiteContentFont(contentFont)
		end
	end
end

S:AddCallback("BlizzardQuestFrames")
