local W, F, E = unpack((select(2, ...))) ---@type WindTools, Functions, table
local S = W.Modules.Skins ---@class Skins

S:SecureHook(_G.LibStub--[[@as table]], "NewLibrary", "LibStub_NewLibrary")
for libName in pairs(_G.LibStub.libs) do
	local lib, minor = _G.LibStub(libName, true)
	if lib and S.libraryHandlers[libName] then
		S.libraryHandledMinors[libName] = minor
		for _, func in next, S.libraryHandlers[libName] do
			if
				not xpcall(function()
					return func(S, lib)
				end, F.Developer.ThrowError)
			then
				if type(S.Log) == "function" then
					S:Log("debug", format("Failed to skin library %s", libName, minor))
				end
			end
		end
	end
end
