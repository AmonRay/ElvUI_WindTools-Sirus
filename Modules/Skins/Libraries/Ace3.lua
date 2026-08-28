local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins

local pairs = pairs

function S:AceGUI(lib)
	if not lib or type(lib) ~= "table" then
		return
	end
	if not self:IsHooked(lib, "RegisterWidgetType") then
		self:SecureHook(lib, "RegisterWidgetType", "HandleAceGUIWidget")
	end
	for name, constructor in pairs(lib.WidgetRegistry) do
		self:HandleAceGUIWidget(lib, name, constructor)
	end
end

function S:AceConfigDialog(lib)
	if not lib or type(lib) ~= "table" then
		return
	end
	F.WaitFor(function()
		return E.private.WT and E.private.WT.skins and E.private.WT.skins.libraries
	end, function()
		if E.private.WT.skins and E.private.WT.skins.libraries.ace3 then
			self:CreateShadow(lib.popup)
			E:GetModule("Tooltip"):SetStyle(lib.tooltip)
		end
	end)
end

function S:Ace3_Frame(widget)
	if widget and widget.frame then
		self:CreateShadow(widget.frame)
	end
end

-- AceGUI TabGroup tabs render WITHOUT visible labels on this client: the tab
-- FontString ends up with no usable font via the default font objects
-- (GameFontNormalSmall / GameFontDisableSmall — the client's SharedFontStyles
-- defines GameFont* as retail-style virtual templates), while the SELECTED
-- tab's font (GameFontHighlightSmall) renders fine. Force the proven-working
-- font object and an explicit white text color on every tab state so inactive
-- tab labels are visible too.
function S:Ace3_TabGroup(widget)
	if not widget or widget.WT_TabGroupHooked then
		return
	end
	widget.WT_TabGroupHooked = true

	local createTab = widget.CreateTab
	widget.CreateTab = function(self, id)
		local tab = createTab(self, id)
		if tab then
			local font = _G.GameFontHighlightSmall
			if font then
				tab:SetNormalFontObject(font)
				tab:SetHighlightFontObject(font)
				tab:SetDisabledFontObject(font)
			end
			if tab.Text then
				tab.Text:SetTextColor(1, 1, 1)
			end
		end
		return tab
	end
end

function S:Ace3_DropdownPullout(widget)
	if self.db.libraries.ace3Dropdown then
		widget.frame:SetTemplate("Transparent")
	end
	if widget and widget.frame then
		self:CreateShadow(widget.frame)
	end
end

S:AddCallbackForLibrary("AceGUI-3.0", "AceGUI")
S:AddCallbackForLibrary("AceConfigDialog-3.0", "AceConfigDialog")
S:AddCallbackForLibrary("AceConfigDialog-3.0-ElvUI", "AceConfigDialog")
S:AddCallbackForAceGUIWidget("Frame", "Ace3_Frame", function(db)
	return db.libraries.ace3 and db.shadow
end)
S:AddCallbackForAceGUIWidget("Window", "Ace3_Frame", function(db)
	return db.libraries.ace3 and db.shadow
end)
S:AddCallbackForAceGUIWidget("Dropdown-Pullout", "Ace3_DropdownPullout", function(db)
	return db.libraries.ace3 and (db.libraries.ace3Dropdown or db.shadow)
end)
S:AddCallbackForAceGUIWidget("TabGroup", "Ace3_TabGroup", function()
	return true -- invisible tab labels are a functional bug, not an aesthetic skin
end)
