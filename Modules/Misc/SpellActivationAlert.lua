local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable

local SA = W:NewModule("SpellActivationAlert") ---@class SpellActivationAlert : AceModule

local _G = _G
local pairs = pairs
local tonumber = tonumber

local C_CVar_GetCVar = W.Compatibility.GetCVar
local Enum_ScreenLocationType = _G.Enum and _G.Enum.ScreenLocationType or {}
local SCREEN_TOP = Enum_ScreenLocationType.Top
local SCREEN_BOTTOM = Enum_ScreenLocationType.Bottom
local SCREEN_LEFT = Enum_ScreenLocationType.Left
local SCREEN_LEFT_OUTSIDE = Enum_ScreenLocationType.LeftOutside
local SCREEN_RIGHT = Enum_ScreenLocationType.Right
local SCREEN_RIGHT_OUTSIDE = Enum_ScreenLocationType.RightOutside

function SA:Update()
	if not self.db or not _G.SpellActivationOverlayFrame then
		return
	end

	local scale = self.db.enable and self.db.scale or 1		_G.SpellActivationOverlayFrame:SetScale(scale)

	local opacityCVar = C_CVar_GetCVar("spellActivationOverlayOpacity")
	local opacity = opacityCVar and tonumber(opacityCVar)
	if opacity then
		_G.SpellActivationOverlayFrame:SetAlpha(opacity)
	end
end

---@type table<Enum.ScreenLocationType, {spellID: number, textureID: number}>
local previewData = {}
local positions = {
	{ SCREEN_TOP, 449488 },
	{ SCREEN_BOTTOM, 449487 },
	{ SCREEN_LEFT, 450929 },
	{ SCREEN_LEFT_OUTSIDE, 449490 },
	{ SCREEN_RIGHT, 449490 },
	{ SCREEN_RIGHT_OUTSIDE, 450929 },
}
for _, entry in ipairs(positions) do
	if entry[1] ~= nil then
		previewData[entry[1]] = { spellID = 123986, textureID = entry[2] }
	end
end

function SA:Preview()
	if not _G.SpellActivationOverlayFrame then
		return
	end

	for position, data in pairs(previewData) do
		_G.SpellActivationOverlayFrame:ShowOverlay(data.spellID, data.textureID, position, 1, 255, 255, 255)
	end

	self.previewID = (self.previewID or 0) + 1
	local previewID = self.previewID
	E:Delay(3, function()
		if previewID == self.previewID then
			_G.SpellActivationOverlayFrame:HideAllOverlays()
		end
	end)
end

function SA:Initialize()
	self.db = E.db.WT.misc.spellActivationAlert

	if not self.db.enable then
		return
	end

	F.TaskManager:AfterLogin(self.Update, self)
end

SA.ProfileUpdate = SA.Update

W:RegisterModule(SA:GetName())
