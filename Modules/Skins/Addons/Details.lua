local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local S = W.Modules.Skins ---@type Skins
local LSM = E.Libs.LSM

local _G = _G
local next = next
local pairs = pairs

local skinnedWindows = {}
local skinnedRows = {}

---Style a single Details row: status bar texture and name/value fonts.
---@param row table|nil The Details row frame
local function SkinBar(row)
	if not row or skinnedRows[row] then
		return
	end
	skinnedRows[row] = true

	local barDB = S.db.details.bar
	local statusBar = row.statusbar
	if statusBar then
		local texture = statusBar:GetStatusBarTexture()
		if texture then
			texture:SetTexture(LSM:Fetch("statusbar", barDB.texture))
			texture:SetAlpha(barDB.alpha)
		end
	end

	F.SetFontWithDB(row.texto_esquerdo, barDB.font.name)
	F.SetFontWithDB(row.texto_direita, barDB.font.value)
end

---Style one Details window (base frame, header and existing rows).
---@param instance table|nil The Details window instance
local function SkinWindow(instance)
	if not instance or not instance.baseframe or skinnedWindows[instance] then
		return
	end
	skinnedWindows[instance] = true

	local baseframe = instance.baseframe

	-- ElvUI Toolkit is mixed into every frame type, so Details windows can
	-- use the standard backdrop + shadow pipeline directly.
	if not baseframe.backdrop and baseframe.SetTemplate then
		baseframe:SetTemplate("Transparent")
	end
	S:CreateBackdropShadow(baseframe)

	-- Replace the default "ball" header artwork with a clean look
	local cabecalho = baseframe.cabecalho
	if cabecalho then
		for _, key in next, { "top_bg", "ball", "ball_r", "emenda", "ball_point" } do
			local tex = cabecalho[key]
			if tex and tex.SetTexture then
				tex:SetTexture(nil)
			end
		end

		local closeButton = cabecalho.fechar
		if closeButton and not closeButton.__windSkin then
			S:Proxy("HandleCloseButton", closeButton)
			closeButton.__windSkin = true
		end
	end

	-- Style the rows that already exist
	local barras = instance.barras
	if barras then
		for i = 1, #barras do
			SkinBar(barras[i])
		end
	end
end

---Skin every open Details window (idempotent; skinned windows are skipped).
local function SkinAllWindows()
	local Details = _G._detalhes
	if not Details then
		return
	end

	for _, instance in pairs(Details.tabela_instancias or {}) do
		SkinWindow(instance)
	end
end

function S:Details()
	if
		not E.private.WT.skins.enable
		or not E.private.WT.skins.addons.details
		or not S.db.details.enable
	then
		return
	end

	local Details = _G._detalhes
	if not Details then
		return
	end

	self:DisableAddOnSkin("Details")

	-- New / reactivated windows: re-skin everything (guarded, cheap)
	if Details.CriarInstancia and not self:IsHooked(Details, "CriarInstancia") then
		self:SecureHook(Details, "CriarInstancia", SkinAllWindows)
	end

	-- New rows are created by gump:CriaNovaBarra
	if Details.gump and Details.gump.CriaNovaBarra and not self:IsHooked(Details.gump, "CriaNovaBarra") then
		self:SecureHook(Details.gump, "CriaNovaBarra", function(_, instance, index)
			SkinBar(instance and instance.barras and instance.barras[index])
		end)
	end

	SkinAllWindows()
end

S:AddCallbackForAddon("Details")
