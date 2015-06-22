
include("Scripts/UI/UFIView.lua")

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

-------------------------------------------------------------------------------
function UFI:LocalPlayerReady(player)
	self.m_UFIView = UFIView.new("SurvivalLayoutUFI.layout", player)
	
	player.m_toggleInventorySignal:Add(function(show)
		self.m_UFIView:ToggleInventory(show)
	end)
end


EntityFramework:RegisterModScript(UFI)
