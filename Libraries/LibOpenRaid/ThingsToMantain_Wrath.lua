-- Wrath compatibility marker for LibOpenRaid.
-- Retail maintenance files are intentionally not executed on the modified 3.3.5 client.
local openRaidLib = LibStub and LibStub:GetLibrary("LibOpenRaid-1.0", true)
if openRaidLib then
	openRaidLib.WindToolsWrath = true
end
