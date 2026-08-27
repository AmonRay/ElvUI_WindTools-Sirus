local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local QK = W:NewModule("QuickKeystone", "AceHook-3.0", "AceEvent-3.0")

local _G = _G

local C_AddOns_IsAddOnLoaded = W.Compatibility.IsAddOnLoaded
local C_Container_GetContainerItemID = W.Compatibility.GetContainerItemID
local C_Container_GetContainerNumSlots = W.Compatibility.GetContainerNumSlots
local C_Container_UseContainerItem = W.Compatibility.UseContainerItem
local C_Item_IsItemKeystoneByID = C_Item and C_Item.IsItemKeystoneByID or function() return false end

local NUM_BAG_SLOTS = NUM_BAG_SLOTS

function QK:PutKeystone()
	for bagIndex = 0, NUM_BAG_SLOTS do
		for slotIndex = 1, C_Container_GetContainerNumSlots(bagIndex) do
			local itemID = C_Container_GetContainerItemID(bagIndex, slotIndex)
			if itemID and C_Item_IsItemKeystoneByID(itemID) then
				C_Container_UseContainerItem(bagIndex, slotIndex)
				return
			end
		end
	end
end

function QK:UpdateHook(event, addon)
	if event then
		if addon == "Blizzard_ChallengesUI" then
			self:UnregisterEvent("ADDON_LOADED")
		else
			return
		end
	end

	local frame = _G.ChallengesKeystoneFrame
	if not frame then
		return
	end

	if self.db.enable then
		if not self:IsHooked(frame, "OnShow") then
			self:SecureHookScript(frame, "OnShow", "PutKeystone")
		end
	else
		if self:IsHooked(frame, "OnShow") then
			self:Unhook(frame, "OnShow")
		end
	end
end

function QK:ProfileUpdate()
	self.db = E.db.WT.combat.quickKeystone

	if C_AddOns_IsAddOnLoaded("Blizzard_ChallengesUI") then
		self:UpdateHook()
	else
		self:RegisterEvent("ADDON_LOADED", "UpdateHook")
	end
end

QK.Initialize = QK.ProfileUpdate

W:RegisterModule(QK:GetName())
