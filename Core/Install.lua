local W, F, E, L, V, P, G = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable, PrivateDB, ProfileDB, GlobalDB

local type = type
local pairs = pairs

-- WindTools registers its defaults into the ElvUI default trees (V/P/G), and
-- ElvUI materializes the live DBs (E.db.WT / E.private.WT) from them at
-- PLAYER_LOGIN. Modules read their `enable` flags from E.db.WT (profile) and
-- E.private.WT (private), so the installer writes those live trees.

local Install = W.Install or {}

local function SetInstallComplete()
	if not E.private.WT then E.private.WT = {} end
	if not E.private.WT.core then E.private.WT.core = {} end
	E.private.WT.core.installComplete = true
end

local function ForEachEnableFlag(db, func)
	if type(db) ~= "table" then return end
	for k, v in pairs(db) do
		if k == "enable" and type(v) == "boolean" then
			func(db, k)
		elseif type(v) == "table" then
			ForEachEnableFlag(v, func)
		end
	end
end

---@param mode "recommended"|"all"|"minimal"
local function ApplyPreset(mode)
	if mode == "recommended" then
		-- The defaults filled by Settings/*.lua are the recommended ones.
		E:UpdateAll()
		return
	end

	local value = mode == "all"
	local function setter(t, k)
		t[k] = value
	end

	ForEachEnableFlag(E.db.WT, setter)
	ForEachEnableFlag(E.private.WT, setter)

	if mode == "minimal" and E.private.WT.skins then
		E.private.WT.skins.enable = true
	end

	E:UpdateAll()
end

local PI

local function GetPI()
	if not PI then
		PI = E:GetModule("PluginInstaller")
	end
	return PI
end

local function PageWelcome()
	local f = _G.PluginInstallFrame
	f.SubTitle:SetText(L["Welcome to WindTools!"])
	f.Desc1:SetText(L["WindTools adds a lot of quality-of-life features to ElvUI: skins, tooltips, quest and map enhancements, social tools and much more."])
	f.Desc2:SetText(L["This installer will help you configure the most important options. You can change everything later in the WindTools settings."])
	f.Desc3:SetText(L["You can open the settings with /ec -> WindTools at any time."])

	f.Option1:Show()
	f.Option1:SetText(L["Begin Installation"])
	f.Option1:SetScript("OnClick", function()
		GetPI():NextPage()
	end)

	f.Option2:Show()
	f.Option2:SetText(L["Skip"])
	f.Option2:SetScript("OnClick", function()
		SetInstallComplete()
		GetPI():CloseInstall()
	end)
end

local function PagePresets()
	local f = _G.PluginInstallFrame
	f.SubTitle:SetText(L["Installation Options"])
	f.Desc1:SetText(L["Choose how WindTools should be configured. Every option can be changed later."])

	f.Option1:Show()
	f.Option1:SetText(L["Recommended"])
	f.Option1:SetScript("OnClick", function()
		ApplyPreset("recommended")
		GetPI():NextPage()
	end)

	f.Option2:Show()
	f.Option2:SetText(L["Enable All Modules"])
	f.Option2:SetScript("OnClick", function()
		ApplyPreset("all")
		GetPI():NextPage()
	end)

	f.Option3:Show()
	f.Option3:SetText(L["Minimal"])
	f.Option3:SetScript("OnClick", function()
		ApplyPreset("minimal")
		GetPI():NextPage()
	end)
end

local function PageComplete()
	local f = _G.PluginInstallFrame
	f.SubTitle:SetText(L["Installation Complete"])
	f.Desc1:SetText(L["WindTools has been configured. Thank you for choosing WindTools!"])

	f.Option1:Show()
	f.Option1:SetText(L["Open WindTools Options"])
	f.Option1:SetScript("OnClick", function()
		SetInstallComplete()
		GetPI():CloseInstall()
		E:ToggleOptions("WindTools")
	end)

	f.Option2:Show()
	f.Option2:SetText(L["Finish"])
	f.Option2:SetScript("OnClick", function()
		SetInstallComplete()
		GetPI():CloseInstall()
	end)
end

Install.Addon = {
	Title = "WindTools",
	Name = "WindTools",
	Pages = { PageWelcome, PagePresets, PageComplete },
}

-- Runs from W:PLAYER_ENTERING_WORLD (initial login). Waits until ElvUI finished
-- its own install so the native PluginInstaller queue is not blocked by
-- E.private.install_complete.
function Install:CheckInstall()
	if E.private.WT and E.private.WT.core and E.private.WT.core.installComplete then return end
	if Install.Queued then return end

	if not E.private.install_complete then
		E:Delay(5, self.CheckInstall, self)
		return
	end

	local elvInstall = _G.ElvUIInstallFrame
	if elvInstall and elvInstall:IsShown() then
		E:Delay(5, self.CheckInstall, self)
		return
	end

	local pi = GetPI()
	if not pi or not pi.Queue then return end

	local pluginFrame = _G.PluginInstallFrame
	if pluginFrame and pluginFrame:IsShown() then
		E:Delay(5, self.CheckInstall, self)
		return
	end

	Install.Queued = true
	pi:Queue(Install.Addon)
end

W.Install = Install
