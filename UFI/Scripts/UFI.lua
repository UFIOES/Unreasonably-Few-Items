
include("Scripts/UI/UFIView.lua")
include("Scripts/Recipes/DefaultRecipe.lua")

-------------------------------------------------------------------------------
if UFI == nil then
	UFI = EternusEngine.ModScriptClass.Subclass("UFI")
end

UFI.RegisterScriptEvent("ServerEvent_CraftRecipe",
	{
		at = "vec3",
		recipe = "string",
		player = "gameobject",
	}
)

UFI.RegisterScriptEvent("ClientEvent_CraftingGood",
	{
	}
)

function UFI:ServerEvent_CraftRecipe(args)

	local recipe = nil

	for i = Eternus.CraftingSystem.m_highestPriority, 0, -1 do
		if Eternus.CraftingSystem.m_recipes[i] then
			local r = Eternus.CraftingSystem.m_recipes[i][args.recipe]
			if r then

				recipe = r

			end
		end
	end

	local player = args.player:NKGetInstance()

	player.m_currentCraftingLocation = args.at

	local areaObjects = player:GetCraftableObjectsNearPosition()

	Eternus.CraftingSystem:RemoveInvalidObjects(areaObjects)

	local craftAction = recipe:GenerateCraftAction(areaObjects, player)

	if craftAction then

		player:StartCrafting(recipe:GenerateCraftAction(areaObjects, player))

		self:RaiseClientEvent("ClientEvent_CraftingGood", {})

	else

	end

end

function UFI:ClientEvent_CraftingGood(args)

	self.UFIView.m_recipeView:ToggleInterface()

end

-------------------------------------------------------------------------------
function UFI:Constructor()
	UFI.instance = self
end

 -------------------------------------------------------------------------------
 -- Called once from C++ at engine initialization time
function UFI:Initialize()

end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters
function UFI:Enter()
	self.UFIView.m_player.m_defaultInputContext:NKRegisterNamedCommand("Toggle Recipe Interface", self.UFIView, "ShowInterface", KEY_ONCE)

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

	self.UFIView = UFIView.new("SurvivalLayoutUFI.layout", player)

end




EntityFramework:RegisterModScript(UFI)
