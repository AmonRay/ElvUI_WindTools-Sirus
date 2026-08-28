local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local T = W.Modules.Tooltips
local LibStub = LibStub

local _G = _G
local format = format
local next = next
local select = select
local strsplit = strsplit
local tonumber = tonumber

local C_QuestLog_GetInfo = C_QuestLog and C_QuestLog.GetInfo
local C_QuestLog_GetLogIndexForQuestID = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
local TooltipDataProcessor_AddTooltipPostCall = _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall
local LegacyGetQuestLogTitle = GetQuestLogTitle
local LegacyTooltip = _G.GameTooltip

local accuracy

local function AddObjectiveProgress(tt, data)
	if not tt or not tt.NumLines or tt:NumLines() == 0 then
		return
	end

	local npcID = data and data.guid and E:NotSecretValue(data.guid) and select(6, strsplit("-", data.guid))

	if not npcID or npcID == "" then
		return
	end

	npcID = tonumber(npcID)

	local OP = LibStub("LibObjectiveProgress", true) or E.Libs.ObjectiveProgressWT
	if not OP or type(OP.GetNPCWeightByCurrentQuests) ~= "function" then
		return
	end
	local weightsTable = OP:GetNPCWeightByCurrentQuests(npcID)
	if not weightsTable then
		return
	end

	for questID, npcWeight in next, weightsTable do
		local logIndex = questID and C_QuestLog_GetLogIndexForQuestID and C_QuestLog_GetLogIndexForQuestID(questID)
		local info = logIndex and C_QuestLog_GetInfo and C_QuestLog_GetInfo(logIndex)
		local title = info and info.title
		if not title and LegacyGetQuestLogTitle then
			for index = 1, GetNumQuestLogEntries() do
				local legacyTitle, _, _, _, isHeader, _, _, _, legacyQuestID = LegacyGetQuestLogTitle(index)
				if not isHeader and legacyQuestID == questID then
					title = legacyTitle
					break
				end
			end
		end
		if title then
			for i = 1, tt:NumLines() do
				local text = _G["GameTooltipTextLeft" .. i]
				local textStr = text and text:GetText()
				if E:NotSecretValue(textStr) and textStr and textStr == title then
					text:SetText(textStr .. format(" + %s%%", E:Round(npcWeight, accuracy)))
				end
			end
		end
	end
end

function T:ObjectiveProgress()
	if not LegacyTooltip then
		return
	end
	if not E.private.WT.tooltips.objectiveProgress.enable then
		return
	end
	if not TooltipDataProcessor_AddTooltipPostCall then
		return
	end
	local Enum_TooltipDataType_Unit = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Unit
	if not Enum_TooltipDataType_Unit then
		return
	end
	accuracy = E.private.WT.tooltips.objectiveProgress.accuracy

	TooltipDataProcessor_AddTooltipPostCall(Enum_TooltipDataType_Unit, AddObjectiveProgress)
end

if T.AddCallback then
	T:AddCallback("ObjectiveProgress")
elseif not T.__windtoolsCoreMissingWarned then
	T.__windtoolsCoreMissingWarned = true
	F.Developer.ThrowError(
		"Tooltips ObjectiveProgress was skipped: Modules/Tooltips/Core.lua did not load (T:AddCallback is missing), so tooltip callbacks were not registered. Reinstall ElvUI_WindTools with a complete copy of all files, then /reload."
	)
end
