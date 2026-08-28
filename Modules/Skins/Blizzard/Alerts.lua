local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs

function S:SkinAlert(alert)
	if not alert or alert.__windSkin then
		return
	end

	self:CreateBackdropShadow(alert)

	F.SetFrameFontOutline(alert)

	if alert.EncounterIcon and alert.EncounterIcon.PortraitBorder then
		alert.EncounterIcon.PortraitBorder:Hide()
	end

	alert.__windSkin = true
end

function S:SkinAchievementAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Unlocked)
	F.SetFont(frame.Name, nil, "+4")
	frame.Name.SetFont = E.noop
	F.SetFont(frame.GuildName)

	if frame.Icon.Texture.b then
		frame.Icon.Texture.b:Point("TOPLEFT", frame.Icon.Texture, "TOPLEFT", -1, 1)
		frame.Icon.Texture.b:Point("BOTTOMRIGHT", frame.Icon.Texture, "BOTTOMRIGHT", 1, -1)
	end

	frame.Name:ClearAllPoints()
	frame.Name:Point("TOP", frame.Unlocked, "BOTTOM", 0, -5)

	frame.GuildBanner:ClearAllPoints()
	frame.GuildBanner:Point("TOPRIGHT", frame, "TOPRIGHT", -13, -12)

	frame.GuildBorder:ClearAllPoints()
	frame.GuildBorder:Point("TOPRIGHT", frame, "TOPRIGHT", -13, -12)

	frame.__windSkin = true
end

function S:SkinGuildChallengeAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)
	F.SetFrameFontOutline(frame)

	frame.__windSkin = true
end

function S:SkinCriteriaAlert(frame)
	if not frame or frame.__windSkin or not frame.hooked then
		return
	end

	self:CreateBackdropShadow(frame)

	frame:Width(frame:GetWidth() + 10)

	F.SetFont(frame.Unlocked, nil, "+1")
	F.SetFont(frame.Name, nil, "+3")

	if frame.Icon.Texture.b then
		frame.Icon.Texture.b:Point("TOPLEFT", frame.Icon.Texture, "TOPLEFT", -1, 1)
		frame.Icon.Texture.b:Point("BOTTOMRIGHT", frame.Icon.Texture, "BOTTOMRIGHT", 1, -1)
		S:CreateShadow(frame.Icon.Texture.b)

		frame.Icon.Texture:ClearAllPoints()
		frame.Icon.Texture:Point("LEFT", frame.backdrop, "LEFT", 10, 0)
	end

	frame.__windSkin = true
end

function S:SkinMoneyWonAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)
	F.SetFont(frame.Label)
	F.SetFont(frame.Amount, nil, "+1")

	frame.Label:ClearAllPoints()
	frame.Label:Point("TOP", frame.backdrop, "TOP", 24, -5)
	frame.Label:SetJustifyH("CENTER")
	frame.Label:SetJustifyV("TOP")

	frame.Amount:ClearAllPoints()
	local xOffset = (180 - frame.Amount:GetStringWidth()) / 2
	frame.Amount:Point("BOTTOMLEFT", frame.Icon, "BOTTOMRIGHT", xOffset, 2)

	frame.__windSkin = true
end

function S:SkinNewRecipeLearnedAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)
	F.SetFont(frame.Name, nil, "+4")
	F.SetFont(frame.Title)

	if frame.Icon.b then
		frame.Icon.b:Point("TOPLEFT", frame.Icon, "TOPLEFT", -1, 1)
		frame.Icon.b:Point("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 1, -1)
	end

	frame.__windSkin = true
end

function S:SkinInvasionAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	for _, child in pairs({ frame:GetChildren() }) do
		if child.template and child.template == "Default" then
			for _, region in pairs({ child:GetRegions() }) do
				if region.b then
					frame.Icon = region
					region:ClearAllPoints()
					region:Point("LEFT", frame.backdrop, "LEFT", 18, 0)
					break
				end
			end
		end
	end

	frame.BonusStar:ClearAllPoints()
	frame.BonusStar:Point("RIGHT", frame.backdrop, "RIGHT", -10, 0)

	-- 完成标题
	for _, region in pairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") then
			if region ~= frame.ZoneName then
				frame.Title = region
				break
			end
		end
	end

	if frame.Title then
		F.SetFont(frame.Title)
		frame.Title:ClearAllPoints()
		frame.Title:Point("TOP", frame.backdrop, "TOP", 23, -31)
		frame.Title:SetJustifyH("CENTER")

		-- 地区
		F.SetFont(frame.ZoneName, nil, "+2")
		frame.ZoneName:ClearAllPoints()
		frame.ZoneName:Point("TOP", frame.Title, "BOTTOM", 0, -5)
		frame.ZoneName:SetJustifyH("CENTER")
	end

	frame.__windSkin = true
end

function S:SkinWorldQuestCompleteAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	for _, child in pairs({ frame:GetChildren() }) do
		if child.template and child.template == "Default" then
			for _, region in pairs({ child:GetRegions() }) do
				if region.b then
					frame.Icon = region
					region:ClearAllPoints()
					region:Point("LEFT", frame.backdrop, "LEFT", 12, 0)
					break
				end
			end
		end
	end

	F.SetFont(frame.ToastText, nil, "+2")
	F.SetFont(frame.QuestName, nil, "+2")

	frame.__windSkin = true
end

function S:SkinLootUpgradeAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.TitleText)
	frame.TitleText:ClearAllPoints()
	frame.TitleText:Point("TOP", frame.backdrop, 30, -12)
	frame.TitleText:SetJustifyH("CENTER")
	frame.TitleText:SetJustifyV("TOP")

	local texts = { frame.BaseQualityItemName, frame.UpgradeQualityItemName, frame.WhiteText, frame.WhiteText2 }

	for _, text in pairs(texts) do
		F.SetFont(text, nil, "+2")
		text:ClearAllPoints()
		text:Point("BOTTOM", frame.backdrop, 30, 12)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("BOTTOM")
	end

	frame.__windSkin = true
end

function S:SkinLootAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Label)

	if frame.Label and frame.Label.GetNumPoints and frame.Label:GetNumPoints() == 1 then
		F.Move(frame.Label, 0, -6)
		hooksecurefunc(frame.Label, "SetPoint", function(_, point, relativeTo, relativePoint, xOffset, yOffset)
			if F.IsAlmost({ xOffset, yOffset }, { 7, 5 }) then
				F.Move(frame.Label, 0, -6)
			end
		end)
	end

	F.SetFont(frame.RollValue)
	F.SetFont(frame.ItemName)

	frame.__windSkin = true
end

function S:SkinLegendaryItemAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	frame.Icon:ClearAllPoints()
	frame.Icon:Point("LEFT", frame.backdrop, "LEFT", 16, 0)

	F.SetFont(frame.ItemName, nil, "+1")
	frame.ItemName:ClearAllPoints()
	frame.ItemName:Point("BOTTOM", frame.backdrop, "BOTTOM", 32, 16)
	frame.ItemName:SetJustifyH("CENTER")
	frame.ItemName:SetJustifyV("BOTTOM")

	for _, region in pairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") and region ~= frame.ItemName then
			F.SetFont(region)
			region:ClearAllPoints()
			region:Point("TOP", frame.backdrop, "TOP", 32, -16)
			region:SetJustifyH("CENTER")
			region:SetJustifyV("TOP")
			break
		end
	end

	frame.__windSkin = true
end

function S:SkinDigsiteCompleteAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Title)
	F.SetFont(frame.DigsiteType, nil, "+2")

	frame.__windSkin = true
end

function S:SkinRafRewardDeliveredAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Title, nil, "+1")
	frame.Title:ClearAllPoints()
	frame.Title:Point("BOTTOM", frame.backdrop, "BOTTOM", 24, 16)
	frame.Title:SetJustifyH("CENTER")
	frame.Title:SetJustifyV("BOTTOM")

	F.SetFont(frame.Description)
	frame.Description:ClearAllPoints()
	frame.Description:Point("TOP", frame.backdrop, "TOP", 24, -16)
	frame.Description:SetJustifyH("CENTER")
	frame.Description:SetJustifyV("TOP")

	frame.__windSkin = true
end

function S:SkinHousingItemEarnedAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	frame.__windSkin = true
end
function S:SkinNewItemAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Label)
	frame.Label:ClearAllPoints()
	frame.Label:Point("TOP", frame.backdrop, "TOP", 32, -13)
	frame.Label:SetJustifyH("CENTER")
	frame.Label:SetJustifyV("TOP")

	F.SetFont(frame.Name, nil, "+1")
	frame.Name:ClearAllPoints()
	frame.Name:Point("BOTTOM", frame.backdrop, "BOTTOM", 32, 15)
	frame.Name:SetJustifyH("CENTER")
	frame.Name:SetJustifyV("BOTTOM")

	if frame.Icon.b then
		frame.Icon.b:ClearAllPoints()
		frame.Icon.b:Point("TOPLEFT", frame.Icon, "TOPLEFT", -1, 1)
		frame.Icon.b:Point("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 1, -1)
	end

	frame.__windSkin = true
end

function S:SkinGarrisonTalentAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	F.SetFont(frame.Title, nil, "+5")
	frame.Title:ClearAllPoints()
	frame.Title:Point("TOP", frame.backdrop, "TOP", 26, -18)
	frame.Title:SetJustifyH("CENTER")
	frame.Title:SetJustifyV("TOP")

	F.SetFont(frame.Name)
	frame.Name:ClearAllPoints()
	frame.Name:Point("BOTTOM", frame.backdrop, "BOTTOM", 26, 15)
	frame.Name:SetJustifyH("CENTER")
	frame.Name:SetJustifyV("BOTTOM")

	frame.__windSkin = true
end

function S:SkinGarrisonBuildingAlert(frame)
	if not frame or frame.__windSkin then
		return
	end

	self:CreateBackdropShadow(frame)

	frame.Icon:ClearAllPoints()
	frame.Icon:Point("LEFT", frame.backdrop, "LEFT", 12, 0)

	F.SetFont(frame.Title, nil, "+1")
	frame.Title:ClearAllPoints()
	frame.Title:Point("TOP", frame.backdrop, "TOP", 26, -13)
	frame.Title:SetJustifyH("CENTER")
	frame.Title:SetJustifyV("TOP")

	F.SetFont(frame.Name, nil, "+1")
	frame.Name:ClearAllPoints()
	frame.Name:Point("BOTTOM", frame.backdrop, "BOTTOM", 26, 15)
	frame.Name:SetJustifyH("CENTER")
	frame.Name:SetJustifyV("BOTTOM")

	frame.__windSkin = true
end

function S:SkinAlertRewardIcons(frame)
	if frame.RewardFrames then
		for i = 1, frame.numUsedRewardFrames do
			local reward = frame.RewardFrames[i]
			if not reward.__windSkin then
				for _, region in pairs({ reward:GetRegions() }) do
					if region:GetObjectType() == "Texture" and region:GetTexture() == 337498 then
						region:SetTexture("")
					end
				end

				if reward.texture.SetMask then
					reward.texture:SetMask("")
				end
				reward.texture:SetTexCoords()
				reward.texture:ClearAllPoints()
				reward.texture:SetInside(reward, 7, 7)
				reward.texture:CreateBackdrop()
				self:CreateBackdropShadow(reward.texture)
				reward.__windSkin = true
			end
		end
	end
end

function S:AlertFrames()
	if not self:CheckDB("alertframes", "alerts") then
		return
	end

	-- Achievements (MonthlyActivityAlertSystem is retail-only and absent on 3.3.5a)
	if _G.AchievementAlertSystem then
		self:SecureHook(_G.AchievementAlertSystem, "setUpFunction", "SkinAchievementAlert")
	end
	if _G.CriteriaAlertSystem then
		self:SecureHook(_G.CriteriaAlertSystem, "setUpFunction", "SkinCriteriaAlert")
	end
	if _G.MonthlyActivityAlertSystem then
		self:SecureHook(_G.MonthlyActivityAlertSystem, "setUpFunction", "SkinCriteriaAlert")
	end

	-- Nearly all of these alert systems are retail-only (dungeon/garrison/world
	-- quest/new-item/cosmetics) and are simply absent on 3.3.5a, so wrap every
	-- hook in a nil-safe check and only wire the ones that actually exist.
	local function secureHook(frame, method, handler)
		if frame then
			self:SecureHook(frame, method, handler)
		end
	end

	-- Encounters
	secureHook(_G.DungeonCompletionAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.GuildChallengeAlertSystem, "setUpFunction", "SkinGuildChallengeAlert")
	secureHook(_G.InvasionAlertSystem, "setUpFunction", "SkinInvasionAlert")
	secureHook(_G.ScenarioAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.WorldQuestCompleteAlertSystem, "setUpFunction", "SkinWorldQuestCompleteAlert")

	-- Garrisons
	secureHook(_G.GarrisonFollowerAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.GarrisonShipFollowerAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.GarrisonTalentAlertSystem, "setUpFunction", "SkinGarrisonTalentAlert")
	secureHook(_G.GarrisonBuildingAlertSystem, "setUpFunction", "SkinGarrisonBuildingAlert")
	secureHook(_G.GarrisonMissionAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.GarrisonShipMissionAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.GarrisonRandomMissionAlertSystem, "setUpFunction", "SkinAlert")

	-- Loot
	secureHook(_G.LegendaryItemAlertSystem, "setUpFunction", "SkinLegendaryItemAlert")
	secureHook(_G.LootAlertSystem, "setUpFunction", "SkinLootAlert")
	secureHook(_G.LootUpgradeAlertSystem, "setUpFunction", "SkinLootUpgradeAlert")
	secureHook(_G.MoneyWonAlertSystem, "setUpFunction", "SkinMoneyWonAlert")
	secureHook(_G.HonorAwardedAlertSystem, "setUpFunction", "SkinMoneyWonAlert")
	secureHook(_G.EntitlementDeliveredAlertSystem, "setUpFunction", "SkinAlert")
	secureHook(_G.RafRewardDeliveredAlertSystem, "setUpFunction", "SkinRafRewardDeliveredAlert")
	secureHook(_G.HousingItemEarnedAlertFrameSystem, "setUpFunction", "SkinHousingItemEarnedAlert")
	secureHook(_G.InitiativeTaskCompleteAlertFrameSystem, "setUpFunction", "SkinHousingItemEarnedAlert")

	-- Professions
	secureHook(_G.DigsiteCompleteAlertSystem, "setUpFunction", "SkinDigsiteCompleteAlert")
	secureHook(_G.NewRecipeLearnedAlertSystem, "setUpFunction", "SkinNewRecipeLearnedAlert")
	secureHook(_G.SkillLineSpecsUnlockedAlertSystem, "setUpFunction", "SkinNewRecipeLearnedAlert")

	-- Pets/Mounts
	secureHook(_G.NewPetAlertSystem, "setUpFunction", "SkinNewItemAlert")
	secureHook(_G.NewMountAlertSystem, "setUpFunction", "SkinNewItemAlert")
	secureHook(_G.NewToyAlertSystem, "setUpFunction", "SkinNewItemAlert")

	-- Cosmetics
	secureHook(_G.NewCosmeticAlertFrameSystem, "setUpFunction", "SkinNewItemAlert")

	-- Reward Icons (retail FrameXML function, nil on 3.3.5a)
	secureHook(_G.StandardRewardAlertFrame_AdjustRewardAnchors, "SkinAlertRewardIcons")
end

S:AddCallback("AlertFrames")
