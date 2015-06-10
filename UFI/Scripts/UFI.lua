
include("Scripts/Core/Common.lua")

-------------------------------------------------------------------------------
if UFI == nil then
	UFI = EternusEngine.ModScriptClass.Subclass("UFI")
end

-------------------------------------------------------------------------------
function UFI:Constructor(  )

end

 -------------------------------------------------------------------------------
 -- Called once from C++ at engine initialization time
function UFI:Initialize()

end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters
function UFI:Enter()
end

-------------------------------------------------------------------------------
-- Called from C++ when the game leaves it current mode
function UFI:Leave()
end


-------------------------------------------------------------------------------
-- Called from C++ every update tick
function UFI:Process(dt)
end


EntityFramework:RegisterModScript(UFI)
