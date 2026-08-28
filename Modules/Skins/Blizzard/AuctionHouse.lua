local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local _G = _G
local pairs = pairs

function S:AuctionHouseFrame()
	if not self:CheckDB("auctionhouse", "auctionHouse") then
		return
	end

	if not _G.AuctionHouseFrame then
		return
	end

	self:CreateShadow(_G.AuctionHouseFrame)

	local tabs = { _G.AuctionHouseFrameBuyTab, _G.AuctionHouseFrameSellTab, _G.AuctionHouseFrameAuctionsTab }
	for _, tab in pairs(tabs) do
		if tab then
			self:CreateBackdropShadow(tab)
		end
	end
end

-- The client ships a retail-style AuctionHouseFrame created from FrameXML
-- (Custom_AuctionHouseUI), so it exists before addon load callbacks fire.
S:AddCallback("AuctionHouseFrame")
