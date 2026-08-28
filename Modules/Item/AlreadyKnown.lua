local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local AK = W:NewModule("AlreadyKnown", "AceEvent-3.0", "AceHook-3.0") ---@class AlreadyKnown : AceModule, AceEvent-3.0, AceHook-3.0

-- Some check logic references code from Legion Remix Helper & AlreadyKnown

local _G = _G
local ceil = ceil
local format = format
local ipairs = ipairs
local mod = mod
local select = select
local strfind = strfind
local strmatch = strmatch
local tonumber = tonumber

local ContainsIf = ContainsIf
local GetBuybackItemInfo = GetBuybackItemInfo
local GetBuybackItemLink = GetBuybackItemLink
local GetCurrentGuildBankTab = GetCurrentGuildBankTab
local GetGuildBankItemInfo = GetGuildBankItemInfo
local GetGuildBankItemLink = GetGuildBankItemLink
local GetMerchantItemLink = GetMerchantItemLink
local GetMerchantNumItems = GetMerchantNumItems
local GetNumBuybackItems = GetNumBuybackItems
local PlayerHasToy = PlayerHasToy
local SetItemButtonDesaturated = SetItemButtonDesaturated
local SetItemButtonTextureVertexColor = SetItemButtonTextureVertexColor

local C_AddOns_IsAddOnLoaded = W.Compatibility.IsAddOnLoaded
local C_Item = _G.C_Item
local C_MerchantFrame = _G.C_MerchantFrame
local C_MountJournal = _G.C_MountJournal
local C_PetJournal = _G.C_PetJournal
local C_TooltipInfo = _G.C_TooltipInfo
local C_ToyBox = _G.C_ToyBox
local C_TransmogCollection = _G.C_TransmogCollection
local C_TransmogSets = _G.C_TransmogSets
local C_Transmog = _G.C_Transmog
local C_Item_GetItemInfoInstant = W.Compatibility.GetItemInfoInstant
local C_Item_GetItemInventoryTypeByID = C_Item and C_Item.GetItemInventoryTypeByID
local function GetItemInventoryType(itemID)
	if C_Item_GetItemInventoryTypeByID then return C_Item_GetItemInventoryTypeByID(itemID) end
	return select(9, GetItemInfo(itemID))
end
local C_Item_GetItemLearnTransmogSet = C_Item and C_Item.GetItemLearnTransmogSet
local C_Item_IsCosmeticItem = W.Compatibility.IsCosmeticItem
local C_Heirloom = _G.C_Heirloom
local C_Heirloom_IsItemHeirloom = C_Heirloom and C_Heirloom.IsItemHeirloom
local C_Heirloom_PlayerHasHeirloom = C_Heirloom and C_Heirloom.PlayerHasHeirloom
local C_MerchantFrame_GetItemInfo = C_MerchantFrame and C_MerchantFrame.GetItemInfo
local C_MountJournal_IsMountItem = C_MountJournal and C_MountJournal.IsMountItem
local C_MountJournal_GetMountFromItem = C_MountJournal and C_MountJournal.GetMountFromItem
local C_MountJournal_GetMountInfoByID = C_MountJournal and C_MountJournal.GetMountInfoByID
local C_PetJournal_GetNumCollectedInfo = C_PetJournal and C_PetJournal.GetNumCollectedInfo
local C_PetJournal_IsPetItem = C_PetJournal and C_PetJournal.IsPetItem
local C_PetJournal_GetPetInfoByItemID = C_PetJournal and C_PetJournal.GetPetInfoByItemID
local C_TooltipInfo_GetGuildBankItem = C_TooltipInfo and C_TooltipInfo.GetGuildBankItem
local function GetGuildBankTooltipData(tab, index)
	if C_TooltipInfo_GetGuildBankItem then return C_TooltipInfo_GetGuildBankItem(tab, index) end
	if not GameTooltip or not GameTooltip.SetGuildBankItem then return nil end
	GameTooltip:SetGuildBankItem(tab, index)
	local lines = {}
	for lineIndex = 1, GameTooltip:NumLines() do
		local left = _G["GameTooltipTextLeft" .. lineIndex]
		lines[lineIndex] = { leftText = left and left:GetText() }
	end
	return { lines = lines }
end
local C_TooltipInfo_GetHyperlink = C_TooltipInfo and C_TooltipInfo.GetHyperlink
local function GetHyperlinkTooltipData(link)
	if C_TooltipInfo_GetHyperlink then return C_TooltipInfo_GetHyperlink(link) end
	if not GameTooltip or not GameTooltip.SetHyperlink then return nil end
	GameTooltip:SetHyperlink(link)
	local lines = {}
	for i = 1, GameTooltip:NumLines() do
		local left = _G["GameTooltipTextLeft" .. i]
		lines[i] = { leftText = left and left:GetText() }
	end
	return { lines = lines }
end
local C_ToyBox_GetToyInfo = C_ToyBox and C_ToyBox.GetToyInfo
local C_TransmogCollection_PlayerHasTransmogByItemInfo = C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogByItemInfo
local C_TransmogSets_GetSetInfo = C_TransmogSets and C_TransmogSets.GetSetInfo
local C_Transmog_GetAllSetAppearancesByID = C_Transmog and C_Transmog.GetAllSetAppearancesByID

local Enum_ItemClass = _G.Enum and _G.Enum.ItemClass or {}
local Enum_InventoryType = _G.Enum and _G.Enum.InventoryType or {}
local Enum_ItemClass_Battlepet = Enum_ItemClass.Battlepet
local BUYBACK_ITEMS_PER_PAGE = BUYBACK_ITEMS_PER_PAGE
local COLLECTED = COLLECTED
local ITEM_SPELL_KNOWN = ITEM_SPELL_KNOWN or ""
local ITEM_PET_KNOWN = ITEM_PET_KNOWN or ""
local PET_SEARCH_PATTERN = strmatch(ITEM_PET_KNOWN, "[^%(（]+") or ITEM_PET_KNOWN
local MAX_GUILDBANK_SLOTS_PER_TAB = 98
local NUM_SLOTS_PER_GUILDBANK_GROUP = 14

local knowables = {
	[Enum_ItemClass.Consumable or -1] = true,
	[Enum_ItemClass.Weapon or -2] = true,
	[Enum_ItemClass.Armor or -3] = true,
	[Enum_ItemClass.ItemEnhancement or -4] = true,
	[Enum_ItemClass.Recipe or -5] = true,
	[Enum_ItemClass.Miscellaneous or -6] = true,
	[Enum_ItemClass.Battlepet or -7] = true,
}

local transmogInventoryTypes = {
	[Enum_InventoryType.IndexBodyType or -1] = true,
	[Enum_InventoryType.IndexTabardType or -2] = true,
}

local knowns = {}

local function IsPetCollected(speciesID)
	if not speciesID then return false end
	if C_PetJournal_GetNumCollectedInfo then
		local num = C_PetJournal_GetNumCollectedInfo(speciesID)
		return num and num > 0
	end
	return false
end

local function IsTransmogCollected(itemID)
	if not C_Item_IsCosmeticItem(itemID) then
		local inventoryType = GetItemInventoryType(itemID)
		if not transmogInventoryTypes[inventoryType] then
			return false
		end
	end

	return C_TransmogCollection_PlayerHasTransmogByItemInfo and C_TransmogCollection_PlayerHasTransmogByItemInfo(itemID) or false
end

local function IsTransmogSetCollected(itemID)
	if not C_Item_GetItemLearnTransmogSet or not C_TransmogSets_GetSetInfo or not C_Transmog_GetAllSetAppearancesByID or not C_TransmogCollection_PlayerHasTransmogByItemInfo then return false end
	local setID = C_Item_GetItemLearnTransmogSet(itemID)
	if not setID then
		return false
	end

	local info = C_TransmogSets_GetSetInfo(setID)
	if not info then
		return false
	end

	if info.collected then
		return true
	end

	local items = C_Transmog_GetAllSetAppearancesByID(setID)
	if not items then
		return false
	end

	return not ContainsIf(items, function(item)
		return not C_TransmogCollection_PlayerHasTransmogByItemInfo(item.itemID)
	end)
end

local function IsMountCollected(itemID)
	if C_MountJournal_IsMountItem and not C_MountJournal_IsMountItem(itemID) then return false end
	if not C_MountJournal_GetMountFromItem or not C_MountJournal_GetMountInfoByID then return false end
	local mountID = C_MountJournal_GetMountFromItem(itemID)
	if not mountID then return false end
	return select(11, C_MountJournal_GetMountInfoByID(mountID)) or false
end

local function IsToyCollected(itemID)
	if not PlayerHasToy then return false end
	if C_ToyBox_GetToyInfo and not C_ToyBox_GetToyInfo(itemID) then return false end
	return PlayerHasToy(itemID) and true or false
end

local function IsHeirloomCollected(itemID)
	return C_Heirloom_IsItemHeirloom and C_Heirloom_PlayerHasHeirloom and C_Heirloom_IsItemHeirloom(itemID) and C_Heirloom_PlayerHasHeirloom(itemID) or false
end

local function IsPetItemCollected(itemID)
	if C_PetJournal_IsPetItem and not C_PetJournal_IsPetItem(itemID) then return false end
	if not C_PetJournal_GetPetInfoByItemID then return false end
	local speciesID = select(13, C_PetJournal_GetPetInfoByItemID(itemID))
	return speciesID and IsPetCollected(speciesID)
end

local function IsKnown(link, index)
	if not link then
		return
	end

	local linkType, linkID = strmatch(link, "|H(%a+):(%d+)")
	linkID = tonumber(linkID)

	if linkType == "battlepet" then
		return IsPetCollected(linkID)
	elseif linkType == "item" then
		local classID = select(6, C_Item_GetItemInfoInstant(link))
		if classID == Enum_ItemClass_Battlepet and index then
			local tab = GetCurrentGuildBankTab() --[[@as number]]
			local data = GetGuildBankTooltipData(tab, index)
			if data then
				return data.battlePetSpeciesID and IsPetCollected(data.battlePetSpeciesID)
			end
		else
			if knowns[link] then
				return true
			end

			if not knowables[classID] then
				return
			end

			if
				IsMountCollected(linkID)
				or IsToyCollected(linkID)
				or IsPetItemCollected(linkID)
				or IsHeirloomCollected(linkID)
				or IsTransmogCollected(linkID)
				or IsTransmogSetCollected(linkID)
			then
				knowns[link] = true
				return true
			end

			-- Final check via tooltip parsing
			local data = GetHyperlinkTooltipData(link)
			if data then
				for _, line in ipairs(data.lines) do
					local text = line.leftText
					if text then
						if
							strfind(text, COLLECTED, 1, true)
							or strfind(text, ITEM_SPELL_KNOWN, 1, true)
							or strmatch(text, PET_SEARCH_PATTERN)
						then
							knowns[link] = true
							return true
						end
					end
				end
			end
		end
	end
end

local texCache = {}

function AK:UpdateMerchantItemButton(button, _, _, _, skip)
	if skip or not button:IsShown() then
		return
	end

	local tex = texCache[button]
	local index = button:GetID()
	local info = C_MerchantFrame_GetItemInfo and C_MerchantFrame_GetItemInfo(index)
	if not info then
		local _, _, _, _, _, isUsable, numAvailable = GetMerchantItemInfo(index)
		info = { isUsable = isUsable, numAvailable = numAvailable }
	end
	if info and info.isUsable and IsKnown(GetMerchantItemLink(index)) then
		if self.db.mode == "MONOCHROME" then
			tex:SetDesaturated(true)
		else
			local r, g, b = self.db.color.r, self.db.color.g, self.db.color.b
			if info.numAvailable == 0 then
				r, g, b = r * 0.5, g * 0.5, b * 0.5
			end
			-- 3.3.5a has no SetItemButtonTextureVertexColor button method; the global is the native API.
			SetItemButtonTextureVertexColor(button, 0.9 * r, 0.9 * g, 0.9 * b)
		end
	else
		tex:SetDesaturated(false)
	end
end

function AK:Merchant()
	if not self.db.enable then
		return
	end

	local numItems = GetMerchantNumItems()
	for i = 1, _G.MERCHANT_ITEMS_PER_PAGE do
		local index = (_G.MerchantFrame.page - 1) * _G.MERCHANT_ITEMS_PER_PAGE + i
		if index > numItems then
			return
		end

		local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
		local itemButtonTex = _G["MerchantItem" .. i .. "ItemButtonIconTexture"]
		if itemButton and itemButtonTex and not self:IsHooked(itemButton, "SetItemButtonTextureVertexColor") then
			texCache[itemButton] = itemButtonTex
			-- The button method is retail-only; on 3.3.5a only the global exists, so the hook is skipped.
			if itemButton.SetItemButtonTextureVertexColor then
				self:SecureHook(itemButton, "SetItemButtonTextureVertexColor", "UpdateMerchantItemButton")
			end
			self:UpdateMerchantItemButton(itemButton)
		end
	end
end

function AK:Buyback()
	if not self.db.enable then
		return
	end

	local numItems = GetNumBuybackItems()
	for index = 1, BUYBACK_ITEMS_PER_PAGE do
		if index > numItems then
			return
		end

		local button = _G["MerchantItem" .. index .. "ItemButton"]
		if button and button:IsShown() then
			local isUsable = select(6, GetBuybackItemInfo(index))
			if isUsable and IsKnown(GetBuybackItemLink(index)) then
				if self.db.mode == "MONOCHROME" then
					_G["MerchantItem" .. index .. "ItemButtonIconTexture"]:SetDesaturated(true)
				else
					local r, g, b = self.db.color.r, self.db.color.g, self.db.color.b
					SetItemButtonTextureVertexColor(button, 0.9 * r, 0.9 * g, 0.9 * b)
				end
			else
				_G["MerchantItem" .. index .. "ItemButtonIconTexture"]:SetDesaturated(false)
			end
		end
	end
end

function AK:GuildBank(frame)
	if not self.db.enable then
		return
	end

	if frame.mode ~= "bank" then
		return
	end

	local tab = GetCurrentGuildBankTab() --[[@as number]]
	for i = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
		local index = mod(i, NUM_SLOTS_PER_GUILDBANK_GROUP)
		if index == 0 then
			index = NUM_SLOTS_PER_GUILDBANK_GROUP
		end

		local column = ceil((i - 0.5) / NUM_SLOTS_PER_GUILDBANK_GROUP)
		local button = frame.Columns[column].Buttons[index]
		if button and button:IsShown() then
			local texture, _, locked = GetGuildBankItemInfo(tab, i)
			if texture and not locked then
				if IsKnown(GetGuildBankItemLink(tab, i), i) then
					if self.db.mode == "MONOCHROME" then
						SetItemButtonDesaturated(button, true)
					else
						local r, g, b = self.db.color.r, self.db.color.g, self.db.color.b
						SetItemButtonTextureVertexColor(button, r, g, b)
					end
				else
					SetItemButtonTextureVertexColor(button, 1, 1, 1)
					SetItemButtonDesaturated(button, false)
				end
			end
		end
	end
end

function AK:AuctionHouse(frame)
	if not self.db.enable then
		return
	end

	for i = 1, frame.ScrollTarget:GetNumChildren() do
		local child = select(i, frame.ScrollTarget:GetChildren())
		if child.cells then
			local button = child.cells[2]
			local itemKey = button and button.rowData and button.rowData.itemKey
			if itemKey and itemKey.itemID then
				local itemLink
				if itemKey.itemID == 82800 then
					itemLink = format("|Hbattlepet:%d::::::|h[Dummy]|h", itemKey.battlePetSpeciesID)
				else
					itemLink = format("|Hitem:%d", itemKey.itemID)
				end

				if itemLink and IsKnown(itemLink) then
					if self.db.mode == "MONOCHROME" then
						button.Icon:SetDesaturated(true)
					else
						local r, g, b = self.db.color.r, self.db.color.g, self.db.color.b
						child.SelectedHighlight:Show()
						child.SelectedHighlight:SetVertexColor(r, g, b)
						child.SelectedHighlight:SetAlpha(0.25)
						button.Icon:SetVertexColor(r, g, b)
						button.IconBorder:SetVertexColor(r, g, b)
						button.Icon:SetDesaturated(false)
					end
				else
					child.SelectedHighlight:SetVertexColor(1, 1, 1)
					button.Icon:SetVertexColor(1, 1, 1)
					button.IconBorder:SetVertexColor(1, 1, 1)
					button.Icon:SetDesaturated(false)
				end
			end
		end
	end
end

do
	local numHooked = 0
	function AK:ADDON_LOADED(event, addOnName)
		if addOnName == "Blizzard_AuctionHouseUI" then
			local scrollBox = _G.AuctionHouseFrame and _G.AuctionHouseFrame.BrowseResultsFrame and _G.AuctionHouseFrame.BrowseResultsFrame.ItemList and _G.AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox
			if scrollBox and scrollBox.Update then
				self:SecureHook(scrollBox, "Update", "AuctionHouse")
				numHooked = numHooked + 1
			end
		elseif addOnName == "Blizzard_GuildBankUI" then
			-- The 3.3.5a fork may expose GuildBankFrame without the retail Update method.
			if _G.GuildBankFrame and _G.GuildBankFrame.Update then
				self:SecureHook(_G.GuildBankFrame, "Update", "GuildBank")
				numHooked = numHooked + 1
			end
		end

		if numHooked == 2 then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end

function AK:Initialize()
	if C_AddOns_IsAddOnLoaded("AlreadyKnown") then
		self.StopRunning = "AlreadyKnown"
		return
	end

	if not E.db.WT.item.alreadyKnown.enable then
		return
	end

	self.db = E.db.WT.item.alreadyKnown
	self.initialized = true
	self:SecureHook("MerchantFrame_UpdateMerchantInfo", "Merchant")
	self:SecureHook("MerchantFrame_UpdateBuybackInfo", "Buyback")
	self:RegisterEvent("ADDON_LOADED")
end

function AK:ToggleSetting()
	if C_AddOns_IsAddOnLoaded("AlreadyKnown") then
		self.StopRunning = "AlreadyKnown"
		return
	end

	self.db = E.db.WT.item.alreadyKnown

	if self.db.enable and not self.initialized then
		self:Initialize()
	end
end

AK.ProfileUpdate = AK.ToggleSetting

W:RegisterModule(AK:GetName())
