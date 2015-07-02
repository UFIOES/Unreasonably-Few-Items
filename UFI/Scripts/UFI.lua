
include("Scripts/UI/UFIView.lua")
include("Scripts/Recipes/DefaultRecipe.lua")
include("Scripts/Recipes/ModularRecipe.lua")
include("Scripts/Characters/BasePlayer.lua")

-------------------------------------------------------------------------------
if UFI == nil then
	UFI = EternusEngine.ModScriptClass.Subclass("UFI")
end

BasePlayer.OnSuccessfulCraft = function (self, craftedObj)
	self:RaiseGameAction("Craft", craftedObj)
	if UFI.instance.UFIView.RecipeView.descoveryMode then UFI.instance:OnSuccessfulCraft(craftedObj) end
end

ModularRecipe.SpawnResultItem = function (self, craftAction, objName, spawnpos )
	-- Flip key/value in craftAction.removals to meet when ModularTool expects
	local removals = {}
	for object, slot in pairs(craftAction.removals) do
		removals[slot] = object
	end

	local obj = Eternus.GameObjectSystem:NKCreateNetworkedGameObject(objName, true, true, {CraftComponents = removals})
	if obj then

		obj:NKSetPosition(spawnpos)

		if obj:NKGetPlaceable() then
			local rot = quat.new(0.0,0.0,1.0,0.0)
			if craftAction.station then
				rot  = craftAction.stationObj:NKGetOrientation()
			end
			obj:NKSetOrientation(rot)
			obj:NKGetInstance():OnCraftComplete()
			obj:NKPlaceInWorld(false, false)
		end
	end

	return obj

end

UFI.RegisterScriptEvent("ServerEvent_CraftRecipe",
	{
		at = "vec3",
		recipe = "string",
		player = "gameobject",
	}
)

UFI.RegisterScriptEvent("ClientEvent_CraftingResponce",
	{
		success = "boolean",
		responce = "string[]",
	}
)

function UFI:ServerEvent_CraftRecipe(args)

	local responce = {}

	local success = false

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

		success = true

		player:StartCrafting(recipe:GenerateCraftAction(areaObjects, player))

	else

		local hasEverything = true

		local hasSomethingInCategory = false

		local lastCategory = nil

		self:CrawlRecipe(recipe, function(kind, object, requiredAmount, category)

			if kind == "tool" then

				local containerFrom = nil
				local indexFrom = nil
				local containerTo = SurvivalInventoryController.Containers.eHandSlot
				local indexTo = 1

				for i, container in pairs(player.m_inventoryContainers) do

					if i > 1 then

						for j, item in pairs(container:GetItemList()) do

							if item:GetItem():NKGetInstance():GetCategory() == object and item:GetItem():NKGetInstance():GetTier() >= requiredAmount then

								indexFrom = j
								containerFrom = i

								break

							end

						end

					end

				end

				if not indexFrom then

					--NKPrint("Do Not Have Everything: " .. object)

					table.insert(responce, "You need a tier " .. tostring(requiredAmount) .. " " .. object)

					hasEverything = false

				end

			elseif category then

				if not lastCategory then

					lastCategory = category

					hasSomethingInCategory = false

					local quantity = tostring(requiredAmount) .. " of "

					if requiredAmount == 1 then

						quantity = "a "

					end

					table.insert(responce, "You need " .. quantity .. object)

				elseif lastCategory and lastCategory == category and hasSomethingInCategory then

					return

				elseif lastCategory and lastCategory ~= category then

					if not hasSomethingInCategory then

						hasEverything = false

					end

					lastCategory = category

					hasSomethingInCategory = false

					local quantity = tostring(requiredAmount) .. " of "

					if requiredAmount == 1 then

						quantity = "a "

					end

					table.insert(responce, "You need " .. quantity .. object)

				else

					local append = responce[table.getn(responce)]

					table.remove(responce)

					local quantity = tostring(requiredAmount) .. " of "

					if requiredAmount == 1 then

						quantity = "a "

					end

					table.insert(responce, append .. " or " .. quantity .. object)

				end

				local count = 0

				for key,value in pairs(areaObjects) do
					if ((value:NKGetName() == object or value:NKGetPlaceable():NKGetCraftingArchetype() == object) and value:NKGetParent() == nil) then
						count = count + value:NKGetInstance():GetStackSize()
					end
				end

				--NKPrint("Have: " .. count)

				if count < requiredAmount then

					for i, container in pairs(player.m_inventoryContainers) do

						local indices = { }
						for j, item in pairs(container:GetItemList()) do
							if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
								table.insert(indices, j)
							end
						end

						for j, index in pairs(indices) do

							count = count + container:GetItemAt(index):GetStackSize()

						end

					end

					--NKPrint("Have: " .. count)

					if count < requiredAmount then

						--NKPrint("Do Not Have Everything: " .. object)

					else

						hasSomethingInCategory = true

						table.remove(responce)

					end

				else

					hasSomethingInCategory = true

					table.remove(responce)

				end

			else

				local count = 0

				for key,value in pairs(areaObjects) do
					if ((value:NKGetName() == object or value:NKGetPlaceable():NKGetCraftingArchetype() == object) and value:NKGetParent() == nil) then
						count = count + value:NKGetInstance():GetStackSize()
					end
				end

				--NKPrint("Have: " .. count)

				if count < requiredAmount then

					for i, container in pairs(player.m_inventoryContainers) do

						local indices = { }
						for j, item in pairs(container:GetItemList()) do
							if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
								table.insert(indices, j)
							end
						end

						for j, index in pairs(indices) do

							count = count + container:GetItemAt(index):GetStackSize()

						end

					end

					--NKPrint("Have: " .. count)

					if count < requiredAmount then

						--NKPrint("Do Not Have Everything: " .. object)

						local quantity = tostring(requiredAmount) .. " of "

						if requiredAmount == 1 then

							quantity = "a "

						end

						table.insert(responce, "You need " .. quantity .. object)

						hasEverything = false

					end

				end

			end

		end)

		if lastCategory and not hasSomethingInCategory then

			hasEverything = false

		end

		if hasEverything then

			--NKPrint("Have Everything")

			hasSomethingInCategory = false

			lastCategory = nil

			self:CrawlRecipe(recipe, function(kind, object, requiredAmount)

				if kind == "tool" then

					local containerFrom = nil
					local indexFrom = nil
					local containerTo = SurvivalInventoryController.Containers.eHandSlot
					local indexTo = 1

					for i, container in pairs(player.m_inventoryContainers) do

						if i > 1 then

							for j, item in pairs(container:GetItemList()) do

								if item:GetItem():NKGetInstance():GetCategory() == object and item:GetItem():NKGetInstance():GetTier() >= requiredAmount then

									indexFrom = j
									containerFrom = i

									break

								end

							end

						end

					end

					if indexFrom then

						player:Server_SwapTwoItems({
							containerFrom = containerFrom,
							indexFrom = indexFrom,
							containerTo	= containerTo,
							indexTo = indexTo
						})

					end

				elseif category then

					if not lastCategory then

						lastCategory = category

						hasSomethingInCategory = false

					elseif lastCategory and lastCategory == category and hasSomethingInCategory then

						return

					elseif lastCategory and lastCategory ~= category then

						lastCategory = category

						hasSomethingInCategory = false

					end

					local count = 0

					for key,value in pairs(areaObjects) do
						if ((value:NKGetName() == object or value:NKGetPlaceable():NKGetCraftingArchetype() == object) and value:NKGetParent() == nil) then
							count = count + value:NKGetInstance():GetStackSize()
						end
					end

					if count < requiredAmount then

						for i, container in pairs(player.m_inventoryContainers) do

							local indices = { }
							for j, item in pairs(container:GetItemList()) do
								if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
									table.insert(indices, j)
								end
							end

							for j, index in pairs(indices) do

								count = count + container:GetItemAt(index):GetStackSize()

							end

						end

						if count >= requiredAmount then

							hasSomethingInCategory = true

							for i, container in pairs(player.m_inventoryContainers) do

								local indices = { }
								for j, item in pairs(container:GetItemList()) do
									if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
										table.insert(indices, j)
									end
								end

								for j, index in pairs(indices) do

									if container:GetItemAt(index):GetStackSize() >= requiredAmount - count then

										--NKPrint("Dropping: " .. object)

										local objectToDrop = container:GetItemAt(index):CreateItem():NKGetInstance()

										objectToDrop:SetStackSize(requiredAmount - count)

										objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

										player:TryPlace(i, index, requiredAmount - count, Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

										return

									else

										--NKPrint("Dropping: " .. object)

										local objectToDrop = container:GetItemAt(index):GetItem()

										objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

										player:TryPlace(i, index, container:GetItemAt(index):GetStackSize(), Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

										count = count + container:GetItemAt(index):GetStackSize()

									end

								end

							end

						end

					else

						hasSomethingInCategory = true

						for i, container in pairs(player.m_inventoryContainers) do

							local indices = { }
							for j, item in pairs(container:GetItemList()) do
								if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
									table.insert(indices, j)
								end
							end

							for j, index in pairs(indices) do

								if container:GetItemAt(index):GetStackSize() >= requiredAmount - count then

									--NKPrint("Dropping: " .. object)

									local objectToDrop = container:GetItemAt(index):CreateItem():NKGetInstance()

									objectToDrop:SetStackSize(requiredAmount - count)

									objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

									player:TryPlace(i, index, requiredAmount - count, Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

									return

								else

									--NKPrint("Dropping: " .. object)

									local objectToDrop = container:GetItemAt(index):GetItem()

									objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

									player:TryPlace(i, index, container:GetItemAt(index):GetStackSize(), Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

									count = count + container:GetItemAt(index):GetStackSize()

								end

							end

						end

					end

				else

					local count = 0

					for key,value in pairs(areaObjects) do
						if ((value:NKGetName() == object or value:NKGetPlaceable():NKGetCraftingArchetype() == object) and value:NKGetParent() == nil) then
							count = count + value:NKGetInstance():GetStackSize()
						end
					end

					if count < requiredAmount then

						for i, container in pairs(player.m_inventoryContainers) do

							local indices = { }
							for j, item in pairs(container:GetItemList()) do
								if item:GetName() == object or item:GetItem():NKGetPlaceable():NKGetCraftingArchetype() == object then
									table.insert(indices, j)
								end
							end

							for j, index in pairs(indices) do

								if container:GetItemAt(index):GetStackSize() >= requiredAmount - count then

									--NKPrint("Dropping: " .. object)

									local objectToDrop = container:GetItemAt(index):CreateItem():NKGetInstance()

									objectToDrop:SetStackSize(requiredAmount - count)

									objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

									player:TryPlace(i, index, requiredAmount - count, Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

									return

								else

									--NKPrint("Dropping: " .. object)

									local objectToDrop = container:GetItemAt(index):GetItem()

									objectToDrop:NKGetInstance():RaiseNetEvent("ClientEvent_SetShouldRender", {shouldRender = true, propogate = true});

									player:TryPlace(i, index, container:GetItemAt(index):GetStackSize(), Eternus.GameState.m_activeCamera:NKGetLocation(), Eternus.GameState.m_activeCamera:ForwardVector(), nil, objectToDrop:NKGetScale())

									count = count + container:GetItemAt(index):GetStackSize()

								end

							end

						end

					end

				end

			end)

			areaObjects = player:GetCraftableObjectsNearPosition()

			craftAction = recipe:GenerateCraftAction(areaObjects, player)

			if craftAction then

				success = true

				player:StartCrafting(craftAction)

			end

		end

	end

	self:RaiseClientEvent("ClientEvent_CraftingResponce", {success = success, responce = responce})

end

function UFI:CrawlRecipe(recipe, dothis)
--NKPrint("crawl")
	if recipe["m_craftingStations"] then
--NKPrint("m_craftingStations")
		for station in pairs(recipe["m_craftingStations"]) do

			if type(station) == "string" then

				dothis("station", station, 1)

			end

		end

	end

	if recipe["m_craftingTool"] then

		tier = recipe["m_craftingTool"]["tier"]

		tool = recipe["m_craftingTool"]["category"]

		if type(tool) == "string" then

			dothis("tool", tool, tier)

		end

	end

	if recipe["m_unconsumedComponents"] then
--NKPrint("m_unconsumedComponents")
		for category, parts in pairs(recipe["m_unconsumedComponents"]) do

			for component, n in pairs(parts) do

				if type(component) == "string" then

					if n == nil then n = 1 end

					dothis("unconsumed", component, n, category)

				end

			end

		end

	end

	if (recipe["m_components"]) then
--NKPrint("m_components")
		for category, parts in pairs(recipe["m_components"]) do

			if recipe:InstanceOf(ModularRecipe) then

				local component = parts["default"]

				if type(component) == "string" then

					if n == nil then n = 1 end

					dothis("component", component, n, category)

				end

			else

				for component, n in pairs(parts) do

					if type(component) == "string" then

						if n == nil then n = 1 end

						dothis("component", component, n, category)

					end

				end

			end

		end

	end

end

function UFI:ClientEvent_CraftingResponce(args)

	for i, message in pairs(args.responce) do

		Eternus.CommandService:NKAddLocalText(message .. " to craft this.")

	end

	if args.success then self.UFIView.m_recipeView:ToggleInterface() end

end

-------------------------------------------------------------------------------
function UFI:Constructor()
	UFI.instance = self
	self.isKeyBound = false
end

 -------------------------------------------------------------------------------
 -- Called once from C++ at engine initialization time
function UFI:Initialize()
	self.isKeyBound = false
end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters
function UFI:Enter()

	if self.UFIView and not self.isKeyBound then

		self.UFIView.m_player.m_defaultInputContext:NKRegisterNamedCommand("Toggle Recipe Interface", self.UFIView, "ShowInterface", KEY_ONCE)

		self.isKeyBound = true

	end

end

-------------------------------------------------------------------------------
-- Called from C++ when the game leaves it current mode
function UFI:Leave()
end


-------------------------------------------------------------------------------
-- Called from C++ every update tick
function UFI:Process(dt)

	if self.UFIView and self.UFIView.m_player.m_defaultInputContext and not self.isKeyBound then

		self.UFIView.m_player.m_defaultInputContext:NKRegisterNamedCommand("Toggle Recipe Interface", self.UFIView, "ShowInterface", KEY_ONCE)

		self.isKeyBound = true

		if not self.discoveredRecipes then self.discoveredRecipes = {} end

	end

end
-------------------------------------------------------------------------------
function UFI:Save(outData)

	outData.discoveredRecipes = self.discoveredRecipes

end

function UFI:Restore(inData, version)

	if inData.discoveredRecipes then
		self.discoveredRecipes = inData.discoveredRecipes
	else
		self.discoveredRecipes = {}
	end

end
-------------------------------------------------------------------------------
function UFI:LocalPlayerReady(player)

	self.UFIView = UFIView.new("SurvivalLayoutUFI.layout", player)

end
-------------------------------------------------------------------------------
function UFI:OnSuccessfulCraft(craftedObj)

NKPrint("HEY LISTEN!!!")

	if not self.discoveredRecipes[craftedObj:NKGetName()] then

		self.discoveredRecipes[craftedObj:NKGetName()] = true

	end

end

EntityFramework:RegisterModScript(UFI)
