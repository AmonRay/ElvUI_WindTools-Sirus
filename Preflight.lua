-- WindTools preflight compatibility for libraries loaded before Initialize.lua.
-- Do not create or mutate Blizzard C_* namespaces: libraries are feature-gated instead.
-- Probe methods, not namespaces: Sirus defines partial C_* tables in Lua.
--
-- This file also installs the legacy *global function* shims that the modified
-- 3.3.5a client is missing. It is deliberately loaded first (see the .toc) so the
-- bundled libraries (LibKeystone, LibOpenRaid, LibRangeCheck) and every module
-- resolve them, regardless of whether another addon already shipped its own
-- compat layer. Every shim is guarded with `type(x) ~= "function"`, so on a
-- client that already provides the global nothing is replaced.
--
-- The set below mirrors the proven 3.3.5a compat surface (same identifiers that
-- MRT/Compat335 and Questie-335 install) restricted to what WindTools calls.
local _G = _G
local type, select, pcall, tostring, tonumber = type, select, pcall, tostring, tonumber

local function has(namespace, method)
	local api = _G[namespace]
	return type(api) == "table" and (not method or type(api[method]) == "function")
end

---Installs a global function only when the client does not provide it.
---@param name string global identifier
---@param fn function implementation
-- Names installed here, so capability probes (Core/CompatibilityLayer.lua) can
-- tell a native API from a WindTools stand-in: several shims below are inert
-- stubs (MuteSoundFile, UnitGetTotalAbsorbs, ...) and must not make a feature
-- look available.
local shimmed = {}
local function shim(name, fn)
	if type(_G[name]) ~= "function" then
		_G[name] = fn
		shimmed[name] = true
	end
end

-- ---------------------------------------------------------------------------
-- Table / string helpers
-- ---------------------------------------------------------------------------

shim("wipe", function(t)
	if type(t) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
	end
	return t
end)
if type(table.wipe) ~= "function" then
	table.wipe = _G.wipe
end

shim("CopyTable", function(src, deep)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		if deep and type(v) == "table" then
			dst[k] = _G.CopyTable(v, true)
		else
			dst[k] = v
		end
	end
	return dst
end)

shim("strtrim", function(s)
	if type(s) ~= "string" then
		return s
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end)
if type(string.trim) ~= "function" then
	string.trim = _G.strtrim
end

-- Wrath ships a native strsplit, but it ignores the maxSplits argument that the
-- retail/modern callers in this addon (and ElvUI) expect. Re-implement only when
-- the third argument is not honoured.
do
	local native = _G.strsplit
	local supportsMaxSplits = false
	if type(native) == "function" then
		local ok, count = pcall(function()
			return select("#", native(":", "a:b:c:d", 2))
		end)
		supportsMaxSplits = ok and count == 2
	end
	if not supportsMaxSplits then
		_G.strsplit = function(delim, str, maxSplits)
			if type(delim) ~= "string" or delim == "" or type(str) ~= "string" then
				return str
			end
			maxSplits = tonumber(maxSplits)
			if maxSplits and maxSplits <= 0 then
				maxSplits = nil
			end
			if maxSplits == 1 then
				return str
			end
			local results, count, lastPos = {}, 0, 1
			local pattern = "(.-)" .. delim:gsub("%p", "%%%0")
			while true do
				local _, e, cap = str:find(pattern, lastPos)
				if not _ then
					break
				end
				count = count + 1
				results[count] = cap
				lastPos = e + 1
				if maxSplits and count >= maxSplits - 1 then
					break
				end
			end
			count = count + 1
			results[count] = str:sub(lastPos)
			return unpack(results, 1, count)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Units / names
-- ---------------------------------------------------------------------------

-- `UnitNameUnmodified` and `UnitFullName` are later client additions; the Wrath
-- equivalents are UnitName plus the realm suffix rules.
shim("UnitNameUnmodified", function(unit)
	return _G.UnitName(unit)
end)
shim("UnitFullName", function(unit)
	local name, realm = _G.UnitName(unit)
	if realm and realm ~= "" then
		return name, realm
	end
	return name, (type(_G.GetRealmName) == "function" and _G.GetRealmName()) or nil
end)

shim("Ambiguate", function(name, mode)
	if type(name) ~= "string" then
		return name
	end
	if mode == "full" then
		return name
	end
	local stripped = name:match("^([^%-]+)")
	return stripped and stripped ~= "" and stripped or name
end)

-- Group state. Modern clients expose these; 3.3.5a only knows the party/raid
-- member counters, so the shims translate.
shim("GetNumSubgroupMembers", function()
	return (_G.GetNumPartyMembers and _G.GetNumPartyMembers()) or 0
end)
shim("GetNumGroupMembers", function()
	local raid = (_G.GetNumRaidMembers and _G.GetNumRaidMembers()) or 0
	if raid > 0 then
		return raid
	end
	return (_G.GetNumPartyMembers and _G.GetNumPartyMembers()) or 0
end)
shim("IsInRaid", function()
	return ((_G.GetNumRaidMembers and _G.GetNumRaidMembers()) or 0) > 0
end)
shim("IsInGroup", function(category)
	if category == 2 then -- LE_PARTY_CATEGORY_INSTANCE
		return false
	end
	return ((_G.GetNumRaidMembers and _G.GetNumRaidMembers()) or 0) > 0
		or ((_G.GetNumPartyMembers and _G.GetNumPartyMembers()) or 0) > 0
end)
shim("UnitIsGroupLeader", function(unit)
	if type(unit) ~= "string" or unit == "" then
		return false
	end
	local raidCount = (_G.GetNumRaidMembers and _G.GetNumRaidMembers()) or 0
	if raidCount > 0 then
		local targetName = _G.UnitName(unit)
		if not targetName then
			return false
		end
		for i = 1, raidCount do
			local name, rank = _G.GetRaidRosterInfo(i)
			if name == targetName then
				return (rank or 0) >= 2
			end
		end
		return false
	end
	if unit == "player" then
		return (type(_G.IsPartyLeader) == "function" and _G.IsPartyLeader()) and true or false
	end
	return (type(_G.UnitIsPartyLeader) == "function" and _G.UnitIsPartyLeader(unit)) and true or false
end)
shim("UnitIsGroupAssistant", function(unit)
	local raidCount = (_G.GetNumRaidMembers and _G.GetNumRaidMembers()) or 0
	if raidCount == 0 or type(unit) ~= "string" or unit == "" then
		return false
	end
	local targetName = _G.UnitName(unit)
	if not targetName then
		return false
	end
	for i = 1, raidCount do
		local name, rank = _G.GetRaidRosterInfo(i)
		if name == targetName then
			return (rank or 0) == 1
		end
	end
	return false
end)

-- Absorb units: absent on 3.3.5a, report 0 so unit-frame tags keep rendering.
shim("UnitGetTotalAbsorbs", function()
	return 0
end)
shim("UnitGetTotalHealAbsorbs", function()
	return 0
end)
shim("UnitSpellHaste", function(unit)
	if unit == "player" and type(_G.GetCombatRatingBonus) == "function" then
		return _G.GetCombatRatingBonus(20) or 0
	end
	return 0
end)

-- `UnitHealthPercent` / `UnitPowerPercent` are later additions that return a
-- curve-scaled fraction. The callers in this addon (UnitFrames tags) always
-- format the result as a percentage, and CurveConstants does not exist here, so
-- the shims return the 0-100 scale directly.
shim("UnitHealthPercent", function(unit)
	local current = _G.UnitHealth(unit)
	local maximum = _G.UnitHealthMax(unit)
	if not maximum or maximum <= 0 then
		return 0
	end
	return (current / maximum) * 100
end)
shim("UnitPowerPercent", function(unit, powerType)
	local current = _G.UnitPower(unit, powerType)
	local maximum = _G.UnitPowerMax(unit, powerType)
	if not maximum or maximum <= 0 then
		return 0
	end
	return (current / maximum) * 100
end)

-- ---------------------------------------------------------------------------
-- Class info
-- ---------------------------------------------------------------------------

-- `GetClassInfo` is the modern replacement for GetClassInfo/UnitClass lookups and
-- is absent here (ElvUI only has a file-local copy). Returns the same tuple as
-- retail: localizedName, classFile, classID.
do
	local classIDToToken = {
		[1] = "WARRIOR",
		[2] = "PALADIN",
		[3] = "HUNTER",
		[4] = "ROGUE",
		[5] = "PRIEST",
		[6] = "DEATHKNIGHT",
		[7] = "SHAMAN",
		[8] = "MAGE",
		[9] = "WARLOCK",
		[11] = "DRUID",
	}
	local localized
	local function buildLocalized()
		if localized then
			return localized
		end
		localized = {}
		if type(_G.FillLocalizedClassList) == "function" then
			pcall(_G.FillLocalizedClassList, localized)
		end
		if type(_G.LOCALIZED_CLASS_NAMES_MALE) == "table" then
			for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
				if localized[k] == nil then
					localized[k] = v
				end
			end
		end
		return localized
	end
	shim("GetClassInfo", function(classID)
		local token = classIDToToken[classID]
		if not token then
			return nil
		end
		local name = buildLocalized()[token] or token
		return name, token, classID
	end)
end

-- ---------------------------------------------------------------------------
-- Secure calling
-- ---------------------------------------------------------------------------

-- `securecallfunction` lives in the shared XML layer on retail clients; without
-- it every library that dispatches callbacks through it (LibKeystone) breaks.
shim("securecallfunction", function(func, ...)
	if type(func) ~= "function" then
		return
	end
	local ok, result = pcall(func, ...)
	if ok then
		return result
	end
	local handler = type(_G.geterrorhandler) == "function" and _G.geterrorhandler()
	if handler then
		handler(result)
	end
end)

-- ---------------------------------------------------------------------------
-- Mixin framework
-- ---------------------------------------------------------------------------

-- The client ships GenerateClosure (SharedXML/FunctionUtil.lua) but not the
-- nils-safe GenerateFlatClosure variant that WindTools' move mode uses.
shim("GenerateFlatClosure", function(f, ...)
	local numArgs = select("#", ...)
	local args = { ... }
	return function()
		return f(unpack(args, 1, numArgs))
	end
end)

shim("Mixin", function(object, ...)
	for i = 1, select("#", ...) do
		local m = select(i, ...)
		if type(m) == "table" then
			for k, v in pairs(m) do
				object[k] = v
			end
		end
	end
	return object
end)
shim("CreateFromMixins", function(...)
	return _G.Mixin({}, ...)
end)
shim("CreateAndInitFromMixin", function(mixin, ...)
	local object = _G.CreateFromMixins(mixin)
	if type(object.OnLoad) == "function" then
		object:OnLoad(...)
	end
	return object
end)

if type(_G.ColorMixin) ~= "table" then
	local ColorMixin = {}
	function ColorMixin:OnLoad(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
	end
	function ColorMixin:GetRGB()
		return self.r, self.g, self.b
	end
	function ColorMixin:GetRGBA()
		return self.r, self.g, self.b, self.a
	end
	function ColorMixin:GetRGBAsBytes()
		return (self.r or 0) * 255, (self.g or 0) * 255, (self.b or 0) * 255
	end
	function ColorMixin:GetRGBAAsBytes()
		return (self.r or 0) * 255, (self.g or 0) * 255, (self.b or 0) * 255, (self.a or 1) * 255
	end
	function ColorMixin:SetRGBA(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
	end
	function ColorMixin:SetRGB(r, g, b)
		self:SetRGBA(r, g, b, nil)
	end
	function ColorMixin:IsEqualTo(other)
		return type(other) == "table"
			and self.r == other.r and self.g == other.g
			and self.b == other.b and self.a == other.a
	end
	function ColorMixin:GenerateHexColor()
		return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
	end
	function ColorMixin:GenerateHexColorMarkup()
		return "|c" .. self:GenerateHexColor()
	end
	function ColorMixin:WrapTextInColorCode(text)
		return ("|c%s%s|r"):format(self:GenerateHexColor(), text or "")
	end
	_G.ColorMixin = ColorMixin
end

shim("CreateColor", function(r, g, b, a)
	local c = _G.CreateFromMixins(_G.ColorMixin)
	c:OnLoad(r, g, b, a)
	return c
end)
shim("CreateColorFromBytes", function(r, g, b, a)
	return _G.CreateColor((r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 0) / 255)
end)
shim("WrapTextInColorCode", function(text, hex)
	return ("|c%s%s|r"):format(hex or "ffffffff", text or "")
end)

-- ---------------------------------------------------------------------------
-- Object / frame pools
-- ---------------------------------------------------------------------------

-- The pool framework is retail-only. Modules that build pools (AchievementTracker)
-- need it; the mixin contract matches the modern implementation.
if type(_G.ObjectPoolMixin) ~= "table" then
	local ObjectPoolMixin = {}
	function ObjectPoolMixin:OnLoad(creationFunc, resetterFunc)
		self.creationFunc = creationFunc
		self.resetterFunc = resetterFunc
		self.activeObjects = {}
		self.inactiveObjects = {}
		self.numActiveObjects = 0
	end
	function ObjectPoolMixin:Acquire()
		local n = #self.inactiveObjects
		if n > 0 then
			local obj = self.inactiveObjects[n]
			self.inactiveObjects[n] = nil
			self.activeObjects[obj] = true
			self.numActiveObjects = self.numActiveObjects + 1
			return obj, false
		end
		local newObj = self.creationFunc(self)
		if self.resetterFunc and not self.disallowResetIfNew then
			self.resetterFunc(self, newObj)
		end
		self.activeObjects[newObj] = true
		self.numActiveObjects = self.numActiveObjects + 1
		return newObj, true
	end
	function ObjectPoolMixin:Release(obj)
		if not self.activeObjects[obj] then
			return false
		end
		self.inactiveObjects[#self.inactiveObjects + 1] = obj
		self.activeObjects[obj] = nil
		self.numActiveObjects = self.numActiveObjects - 1
		if self.resetterFunc then
			self.resetterFunc(self, obj)
		end
		return true
	end
	function ObjectPoolMixin:ReleaseAll()
		for obj in pairs(self.activeObjects) do
			self:Release(obj)
		end
	end
	function ObjectPoolMixin:SetResetDisallowedIfNew(disallowed)
		self.disallowResetIfNew = disallowed
	end
	function ObjectPoolMixin:EnumerateActive()
		return pairs(self.activeObjects)
	end
	function ObjectPoolMixin:GetNextActive(current)
		return next(self.activeObjects, current)
	end
	function ObjectPoolMixin:GetNextInactive(current)
		return next(self.inactiveObjects, current)
	end
	function ObjectPoolMixin:IsActive(obj)
		return self.activeObjects[obj] ~= nil
	end
	function ObjectPoolMixin:GetNumActive()
		return self.numActiveObjects
	end
	function ObjectPoolMixin:EnumerateInactive()
		return ipairs(self.inactiveObjects)
	end
	_G.ObjectPoolMixin = ObjectPoolMixin
end

shim("CreateObjectPool", function(creationFunc, resetterFunc)
	local pool = _G.CreateFromMixins(_G.ObjectPoolMixin)
	pool:OnLoad(creationFunc, resetterFunc)
	return pool
end)

shim("FramePool_Hide", function(_, frame)
	if frame and frame.Hide then
		frame:Hide()
	end
end)
shim("FramePool_HideAndClearAnchors", function(_, frame)
	if frame and frame.Hide then
		frame:Hide()
	end
	if frame and frame.ClearAllPoints then
		frame:ClearAllPoints()
	end
end)
shim("TexturePool_Hide", function(_, texture)
	if texture and texture.Hide then
		texture:Hide()
	end
end)
shim("TexturePool_HideAndClearAnchors", function(_, texture)
	if texture and texture.Hide then
		texture:Hide()
	end
	if texture and texture.ClearAllPoints then
		texture:ClearAllPoints()
	end
end)

if type(_G.FramePoolMixin) ~= "table" then
	local FramePoolMixin = _G.CreateFromMixins(_G.ObjectPoolMixin)
	local function FramePoolFactory(framePool)
		return CreateFrame(framePool.frameType, nil, framePool.parent, framePool.frameTemplate)
	end
	function FramePoolMixin:OnLoad(frameType, parent, frameTemplate, resetterFunc, _, frameInitFunc)
		local creationFunc = FramePoolFactory
		if type(frameInitFunc) == "function" then
			creationFunc = function(framePool)
				local frame = CreateFrame(framePool.frameType, nil, framePool.parent, framePool.frameTemplate)
				frameInitFunc(frame)
				return frame
			end
		end
		_G.ObjectPoolMixin.OnLoad(self, creationFunc, resetterFunc)
		self.frameType = frameType
		self.parent = parent
		self.frameTemplate = frameTemplate
	end
	function FramePoolMixin:GetTemplate()
		return self.frameTemplate
	end
	_G.FramePoolMixin = FramePoolMixin
end

shim("CreateFramePool", function(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
	local pool = _G.CreateFromMixins(_G.FramePoolMixin)
	pool:OnLoad(frameType, parent, frameTemplate, resetterFunc or _G.FramePool_HideAndClearAnchors, forbidden, frameInitFunc)
	return pool
end)

if type(_G.TexturePoolMixin) ~= "table" then
	local TexturePoolMixin = _G.CreateFromMixins(_G.ObjectPoolMixin)
	local function TexturePoolFactory(texturePool)
		return texturePool.parent:CreateTexture(nil, texturePool.layer, texturePool.textureTemplate, texturePool.subLayer)
	end
	function TexturePoolMixin:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
		_G.ObjectPoolMixin.OnLoad(self, TexturePoolFactory, resetterFunc)
		self.parent = parent
		self.layer = layer
		self.subLayer = subLayer
		self.textureTemplate = textureTemplate
	end
	_G.TexturePoolMixin = TexturePoolMixin
end

shim("CreateTexturePool", function(parent, layer, subLayer, textureTemplate, resetterFunc)
	local pool = _G.CreateFromMixins(_G.TexturePoolMixin)
	pool:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc or _G.TexturePool_HideAndClearAnchors)
	return pool
end)

-- ---------------------------------------------------------------------------
-- Number formatting
-- ---------------------------------------------------------------------------

shim("FormatLargeNumber", function(amount)
	local sep = _G.LARGE_NUMBER_SEPERATOR or ","
	local s = tostring(amount or 0)
	local sign, digits = s:match("^(%-?)(%d+)$")
	if not digits then
		return s
	end
	local out = digits:reverse():gsub("(%d%d%d)", "%1" .. sep)
	out = out:reverse()
	if out:sub(1, #sep) == sep then
		out = out:sub(#sep + 1)
	end
	return sign .. out
end)
shim("BreakUpLargeNumbers", function(amount)
	return _G.FormatLargeNumber(amount)
end)

-- ---------------------------------------------------------------------------
-- Quest helpers
-- ---------------------------------------------------------------------------

-- `GetItemInfoFromHyperlink` is a C_Item helper here; the Wrath way to get the
-- item id out of a link is the item: pattern. Only the id is consumed by the
-- callers in this addon.
shim("GetItemInfoFromHyperlink", function(hyperlink)
	if type(hyperlink) ~= "string" then
		return nil
	end
	return tonumber(hyperlink:match("item:(%d+)"))
end)

-- Area-trigger quests (quests that auto-open from a world object) do not exist on
-- 3.3.5a; QuestIsFromAreaTrigger is only used to bypass the trivial-quest check,
-- so "not an area trigger" is the correct degradation.
shim("QuestIsFromAreaTrigger", function()
	return false
end)

-- The auto-accept acknowledgement step only exists to suppress the retail
-- "quest auto-accepted" popup. Wrath accepts through the normal AcceptQuest
-- flow, so there is nothing to acknowledge.
shim("AcknowledgeAutoAcceptQuest", function() end)

-- `GetActiveQuestID` is a C_GossipInfo helper and this client ships neither the
-- namespace nor a quest id inside its gossip list: the Wrath equivalent
-- GetGossipActiveQuests returns only title/level/isTrivial/isComplete. Report nil
-- rather than guessing an id, because guessing would auto-select the wrong quest;
-- every caller in this addon guards the result and skips the per-quest filter.
shim("GetActiveQuestID", function()
	return nil
end)

-- ---------------------------------------------------------------------------
-- Sound kit
-- ---------------------------------------------------------------------------

-- This client ships SOUNDKIT but only with a subset of the retail keys. The ones
-- WindTools plays are added when missing (same approach as MRT/Compat335).
-- Per-sound-file muting arrived long after 3.3.5a; the client only knows the
-- master/music/ambience/effects channels. Callers use these to silence a sound
-- for the duration of a UI window, so a no-op is the correct degradation.
shim("MuteSoundFile", function() end)
shim("UnmuteSoundFile", function() end)

if type(_G.SOUNDKIT) ~= "table" then
	_G.SOUNDKIT = {}
end
if _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON == nil then
	_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn"
end
if _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF == nil then
	_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff"
end
if _G.SOUNDKIT.IG_CHARACTER_INFO_OPEN == nil then
	_G.SOUNDKIT.IG_CHARACTER_INFO_OPEN = "igCharacterInfoOpen"
end
if _G.SOUNDKIT.IG_CHARACTER_INFO_TAB == nil then
	_G.SOUNDKIT.IG_CHARACTER_INFO_TAB = "igCharacterInfoTab"
end

-- ---------------------------------------------------------------------------
-- Widget method shims
-- ---------------------------------------------------------------------------
-- The modified client documents retail widget methods it does not actually
-- implement (Slider:SetObeyStepOnDrag is in APIDocumentation but absent from
-- the Slider widget), and implements others with the legacy signature
-- (Texture:SetGradient takes the classic 6-number form, not retail ColorMixin
-- objects). A missing method hard-fails the Construct() of any module that
-- calls it and can leave half-built frames behind. Each shim installs only
-- where the method is genuinely absent; the SetGradient adapter keeps the
-- client's native numeric implementation and only translates retail-style
-- ColorMixin arguments into it.

local frameMethods, textureMethods
do
	local okFrame, probeFrame = pcall(CreateFrame, "Frame")
	if okFrame and type(probeFrame) == "table" then
		local mt = getmetatable(probeFrame)
		frameMethods = mt and mt.__index
		local okTex, tex = pcall(probeFrame.CreateTexture, probeFrame)
		if okTex and type(tex) == "table" then
			local texMt = getmetatable(tex)
			textureMethods = texMt and texMt.__index
		end
	end
end

local function ensureWidgetMethod(methods, name, impl)
	if methods and type(methods[name]) ~= "function" then
		methods[name] = impl
		return true
	end
	return false
end

if textureMethods then
	-- Retail form: SetGradient(orientation, colorMixin1, colorMixin2).
	-- Client form: SetGradient(orientation, r1, g1, b1, r2, g2, b2).
	-- The native numeric implementation is kept untouched and ColorMixin
	-- arguments are translated into it; if the native method were absent,
	-- degrade to SetGradientAlpha or a flat color so gradient styling never
	-- hard-fails a Construct.
	local nativeSetGradient = textureMethods.SetGradient
	local nativeSetGradientAlpha = textureMethods.SetGradientAlpha
	local function colorToParts(color)
		if type(color) == "table" and type(color.r) == "number" then
			return color.r, color.g, color.b, color.a or 1
		end
		return nil
	end
	textureMethods.SetGradient = function(self, orientation, first, second, ...)
		local r1, g1, b1, a1 = colorToParts(first)
		local r2, g2, b2, a2 = colorToParts(second)
		if r1 and r2 then
			-- SetGradientAlpha keeps the ColorMixin alpha; plain SetGradient drops it.
			if type(nativeSetGradientAlpha) == "function" then
				return nativeSetGradientAlpha(self, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
			elseif type(nativeSetGradient) == "function" then
				return nativeSetGradient(self, orientation, r1, g1, b1, r2, g2, b2)
			end
			return self:SetVertexColor(r1, g1, b1)
		end
		if type(nativeSetGradient) == "function" then
			return nativeSetGradient(self, orientation, first, second, ...)
		end
	end
	ensureWidgetMethod(textureMethods, "SetRotation", function() end)
	-- 3.3.5a has no SetColorTexture; SetTexture(r, g, b, a) draws the same
	-- solid color there.
	ensureWidgetMethod(textureMethods, "SetColorTexture", function(self, r, g, b, a)
		return self:SetTexture(r, g, b, a or 1)
	end)
end

if frameMethods then
	ensureWidgetMethod(frameMethods, "SetClipsChildren", function() end)
	ensureWidgetMethod(frameMethods, "SetFading", function() end)
end

-- Sliders may carry their own method table that does not chain to Frame's.
do
	local okSlider, probeSlider = pcall(CreateFrame, "Slider")
	if okSlider and type(probeSlider) == "table" then
		local mt = getmetatable(probeSlider)
		local sliderMethods = mt and mt.__index
		if sliderMethods ~= frameMethods then
			ensureWidgetMethod(sliderMethods, "SetObeyStepOnDrag", function() end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Optional libraries
-- ---------------------------------------------------------------------------

-- LibOpenRaid is a retail library. WindTools bundles it for the retail client,
-- but its data model (retail talent tabs, spellbook, PlayerInfo rating and the
-- retail keystone APIs) is not verified on the modified client, so it is not
-- started there. This switch is resolved once, before Libraries\Load_Libraries.xml
-- runs, and can be overridden by setting the global before WindTools loads.
if type(_G.WindTools_OpenRaidEnabled) ~= "boolean" then
	local interfaceVersion = type(_G.GetBuildInfo) == "function" and tonumber(select(4, _G.GetBuildInfo())) or 0
	_G.WindTools_OpenRaidEnabled = interfaceVersion >= 100000
end

-- ---------------------------------------------------------------------------
-- Debug helper
-- ---------------------------------------------------------------------------

shim("DebugPrint", function(...)
	if not _G.WindTools_VERBOSE_DEBUG then
		return
	end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	print("|cff80ff80[WindTools]|r " .. table.concat(parts, " "))
end)

_G.WindToolsPreflight = {
	HasTimerAPI = has("C_Timer", "NewTicker"),
	HasContainerAPI = has("C_Container", "GetContainerNumSlots"),
	HasItemAPI = has("C_Item", "GetItemInfo"),
	HasSpellAPI = has("C_Spell", "GetSpellInfo"),
	HasMapAPI = has("C_Map", "GetBestMapForUnit"),
	HasQuestAPI = has("C_QuestLog", "GetInfo"),
	HasTooltipAPI = has("TooltipDataProcessor", "AddTooltipPostCall"),
	HasChallengeAPI = has("C_ChallengeMode", "GetMapUIInfo"),
	HasMythicPlusAPI = has("C_MythicPlus", "GetOwnedKeystoneLevel"),
	HasModernCinematicAPI = type(_G.EventRegistry) == "table" and type(_G.MovieFrame_PlayMovie) == "function" and type(_G.Enum) == "table" and type(_G.Enum.CinematicType) == "table",
	HasSpellActivationOverlay = type(_G.SpellActivationOverlayFrame) == "table" and type(_G.SpellActivationOverlayFrame.ShowOverlay) == "function",
	OpenRaid = _G.WindTools_OpenRaidEnabled,
	Shimmed = shimmed,
}
