-- WindTools preflight compatibility for libraries loaded before Initialize.lua.
-- Do not create or mutate Blizzard C_* namespaces: libraries are feature-gated instead.
local _G = _G
local function has(namespace, method)
	local api = _G[namespace]
	return type(api) == "table" and (not method or type(api[method]) == "function")
end

_G.WindToolsPreflight = {
	HasTimerAPI = has("C_Timer", "NewTicker"),
	HasContainerAPI = has("C_Container"),
	HasItemAPI = has("C_Item"),
	HasSpellAPI = has("C_Spell"),
	HasMapAPI = has("C_Map", "GetBestMapForUnit"),
	HasQuestAPI = has("C_QuestLog", "GetInfo"),
	HasTooltipAPI = has("TooltipDataProcessor", "AddTooltipPostCall"),
	HasChallengeAPI = has("C_ChallengeMode"),
	HasMythicPlusAPI = has("C_MythicPlus"),
	HasModernCinematicAPI = type(_G.EventRegistry) == "table" and type(_G.MovieFrame_PlayMovie) == "function" and type(_G.Enum) == "table" and type(_G.Enum.CinematicType) == "table",
	HasSpellActivationOverlay = type(_G.SpellActivationOverlayFrame) == "table" and type(_G.SpellActivationOverlayFrame.ShowOverlay) == "function",
}
