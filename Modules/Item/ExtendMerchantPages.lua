local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local EMP = W:NewModule("ExtendMerchantPages", "AceHook-3.0")

local _G = _G

local C_AddOns_IsAddOnLoaded = W.Compatibility.IsAddOnLoaded

local BLIZZARD_MERCHANT_ITEMS_PER_PAGE = 10

function EMP:Initialize()
	for _, addon in pairs({
		"ExtVendor",
		"Krowi_ExtendedVendorUI",
		"CompactVendor",
	}) do
		if C_AddOns_IsAddOnLoaded(addon) then
			self.StopRunning = addon
			return
		end
	end

	if not E.private.WT.item.extendMerchantPages.enable then
		return
	end

	self.db = E.private.WT.item.extendMerchantPages

	-- This client ships 12 built-in merchant slots (MerchantItem1..12 in
	-- MerchantFrame.xml); creating additional slots via MerchantItemTemplate from
	-- Lua does not produce the $parentItemButton globals the client's update loop
	-- reads, so the page size is clamped to the slots that actually exist.
	local maxSlots = BLIZZARD_MERCHANT_ITEMS_PER_PAGE
	for i = BLIZZARD_MERCHANT_ITEMS_PER_PAGE + 1, 30 do
		if _G["MerchantItem" .. i] then
			maxSlots = i
		end
	end

	local desired = max(self.db.numberOfPages or 1, 1) * BLIZZARD_MERCHANT_ITEMS_PER_PAGE
	_G.MERCHANT_ITEMS_PER_PAGE = min(maxSlots, max(desired, BLIZZARD_MERCHANT_ITEMS_PER_PAGE))

	self.initialized = true
end

function EMP:ProfileUpdate()
	self.db = E.private.WT.item.extendMerchantPages

	if self.db.enable and not self.initialized then
		self:Initialize()
	end
end

W:RegisterModule(EMP:GetName())
