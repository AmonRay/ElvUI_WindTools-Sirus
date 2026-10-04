local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local M = W.Modules.Misc ---@class Misc

local _G = _G

function M:HideTalkingHeadFrame(frame)
	if frame and E.db.WT.misc.disableTalkingHead then
		frame:Hide()
	end
end

function M:HookTalkingHeadPlayCurrent()
	self:SecureHook(_G.TalkingHeadFrame, "PlayCurrent", "HideTalkingHeadFrame")
	self:SecureHook(_G.TalkingHeadFrame, "Reset", "HideTalkingHeadFrame")
end

function M:DisableTalkingHead()
	if _G.TalkingHeadFrame then
		self:HookTalkingHeadPlayCurrent()
		return
	end

	-- Talking heads are a BfA-era feature: this client has neither
	-- TalkingHeadFrame nor TalkingHead_LoadUI, and SecureHook on a missing
	-- global target is an error, so the feature stays a no-op there.
	if type(_G.TalkingHead_LoadUI) == "function" then
		self:SecureHook("TalkingHead_LoadUI", "HookTalkingHeadPlayCurrent")
	else
		W.Compatibility:Report("TalkingHead", L["This client has no talking head frame, so there is nothing to hide."])
	end
end

M:AddCallback("DisableTalkingHead")
