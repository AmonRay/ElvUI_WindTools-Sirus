local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs

function S:HandleMerchantItem(index)
	for currencyIndex = 1, 3 do
		local itemLine = _G["MerchantItem" .. index .. "AltCurrencyFrameItem" .. currencyIndex] --[[@as SmallDenominationTemplate?]]
		if itemLine then
			for _, region in pairs({ itemLine:GetRegions() }) do
				if region:GetObjectType() == "Texture" then
					region:SetTexCoords()
				end
			end
		end
	end
end

function S:MerchantFrame()
	if not self:CheckDB("merchant") then
		return
	end

	self:CreateShadow(_G.MerchantFrame)

	for i = 1, 2 do
		self:CreateBackdropShadow(_G["MerchantFrameTab" .. i])
	end

	for i = 1, 12 do
		self:HandleMerchantItem(i)
	end

	local goldButton = _G.MerchantMoneyFrame and _G.MerchantMoneyFrame.GoldButton
	if goldButton and goldButton.GetRegions then
		for _, region in pairs({ goldButton:GetRegions() }) do
			if region:GetObjectType() == "Texture" then
				F.Move(region, 0, 4)
			end
		end
	end

	-- Refresh alternate currency icons whenever the merchant list is updated.
	-- In Wrath this is handled by MerchantFrame_UpdateAltCurrency.
	hooksecurefunc("MerchantFrame_UpdateAltCurrency", function(index, itemIndex)
		for currencyIndex = 1, 3 do
			local itemLine = _G["MerchantItem" .. itemIndex .. "AltCurrencyFrameItem" .. currencyIndex]
			if itemLine then
				for _, region in pairs({ itemLine:GetRegions() }) do
					if region:GetObjectType() == "Texture" then
						region:SetTexCoords()
					end
				end
			end
		end
	end)
end

S:AddCallback("MerchantFrame")
