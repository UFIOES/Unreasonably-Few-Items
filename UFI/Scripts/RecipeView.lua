
include("Scripts/UI/View.lua")
--include("Scripts/RecipeItemView.lua")

local Windows = nil
local UISystem = nil

-- get an Schematic with invalid name
local nullSchematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName("_NULL_null_000")

if Eternus.IsClient then -- These are not used in a dedicated server environment
	Windows	= EternusEngine.UI.Windows
	UISystem = EternusEngine.UI.System
end


-------------------------------------------------------------------------------

if RecipeView == nil then
	RecipeView = View.Subclass("RecipeView")
end

RecipeView.ALPHA_VISIBLE = "tl:FFFFFFFF tr:FFFFFFFF bl:FFFFFFFF br:FFFFFFFF"
RecipeView.ALPHA_INVISIBLE = "tl:00FFFFFF tr:00FFFFFF bl:00FFFFFF br:00FFFFFF"

-------------------------------------------------------------------------------

function RecipeView:PostLoad(layout, controller)

	self.recipeScrollpane = CEGUI.toScrollablePane(self:GetChild("Recipes"))
	self.recipeScrollpane:setShowHorzScrollbar(false)

	self.recipeContext = InputMappingContext.new("Recipies")

	self.recipeContext:NKSetInputPropagation(false)

	self.recipeContext:NKRegisterNamedCommand("Return to Menu", self, "ToggleInterface", KEY_ONCE)

	self.recipeContext:NKRegisterNamedCommand("Toggle Recipe Interface", self, "ToggleInterface", KEY_ONCE)

	self.searchbox = CEGUI.toEditbox(self:GetChild("Searchbox"))

	self.searchContext = InputMappingContext.new("Searchbox")

	self.searchContext:NKSetInputPropagation(false)

	self.searchContext:NKRegisterNamedCommand("Return to Menu", self, "OnSearchboxExit", KEY_ONCE)

	self.cheatModeButton = CEGUI.toToggleButton(self:GetChild("CheatMode"))

	self.discoveryModeButton = CEGUI.toToggleButton(self:GetChild("DiscoveryMode"))

	self.cheatMode = false

	self.descoveryMode = true

	self.searching = false

	self.cheatModeButton:subscribeEvent("SelectStateChanged", function(args)
		if self.m_active then
			self.cheatMode = not self.cheatMode
		end
	end)

	self.discoveryModeButton:subscribeEvent("SelectStateChanged", function(args)
		if self.m_active then
			self.descoveryMode = not self.descoveryMode
			self:OnTextChanged()
		end
	end)

	self.searchbox:subscribeEvent("MouseClick", function(args)
		if self.m_active then
			self:OnSearchboxClicked()
		end
	end)

	self.searchbox:subscribeEvent("TextChanged", function(args)
		if self.m_active then
			self:OnTextChanged()
		end
	end)

	self.searchbox:subscribeEvent("Deactivated", function(args)
		if self.m_active then
			self:OnSearchboxDeactivated()
		end
	end)

	self.searchbox:subscribeEvent("TextAccepted", function(args)
		if self.m_active then
			self:OnSearchboxExit()
		end
	end)

	self.recipesList = Windows:createWindow("VerticalLayoutContainer")

	self.recipesList:setProperty("DistributeCapturedInputs", "true")
	self.recipesList:setProperty("MouseInputPropagationEnabled", "true")

	self.recipeScrollpane:addChild(self.recipesList)

	self.m_controller = controller

	self.layout = layout

	self.m_tooltip = CEGUI.toTooltip(Windows:createWindow("TUGLook/Tooltip"))
	self.m_active = false
	self.m_currentWindow = nil

	EternusEngine.UI.Layers.Gameplay:addChild(self.m_tooltip)

	self:LoadRecipes()

	self:LayoutAllRecipes()

end

-------------------------------------------------------------------------------
--[[recipe data
	self.m_components 				= args.Components
	self.m_unconsumedComponents 	= args["Unconsumed Components"]
	self.m_craftingTool 			= args["Crafting Tool"]
	self.m_craftingStations 		= args["Crafting Stations"]
	self.m_craftingStationsOptional = args["Crafting Stations Optional"]
	self.m_failedResults 			= args["Failed Results"]
	self.m_results 					= args.Results
	self.m_unconsumedDamage 		= args.unconsumedDamage or DefaultRecipe.DefaultUnconsumedDamage
	self.m_energyCost 				= args.energyCost or DefaultRecipe.DefaultEnergyCost
]]
-------------------------------------------------------------------------------
function RecipeView:SpawnComponents(recipe)

	if (recipe["m_components"]) then

		for category, parts in pairs(recipe["m_components"]) do

			if recipe:InstanceOf(ModularRecipe) then

				local component = parts["default"]

				if component == "Long Shaft" then
					component = "Wood Shaft"
				elseif component == "Crystal Shard" then
					component = "Blue Crystal Shard"
				elseif component == "Spear" then
					component = "Wood Spear"
				elseif component == "Wood Log" then
					component = "Wood Log Pine"
				elseif component == "Dark Green Clump" then
					component = "Dark Green Grass Clump"
				elseif component == "Light Green Clump" then
					component = "Light Green Grass Clump"
				elseif component == "Tan Clump" then
					component = "Tan Grass Clump"
				elseif component == "Sat Green Clump" then --??? no such grass?
					component = "Light Green Grass Clump"
				end

				if type(component) == "string" and component ~= "Long Shaft" and component ~= "Crystal Shard" and component ~= "Spear" then

					self:spawnItem(component, 1)

				end

			else

				for component, n in pairs(parts) do

					if component == "Long Shaft" then
						component = "Wood Shaft"
					elseif component == "Crystal Shard" then
						component = "Blue Crystal Shard"
					elseif component == "Spear" then
						component = "Wood Spear"
					elseif component == "Wood Log" then
						component = "Wood Log Pine"
					elseif component == "Dark Green Clump" then
						component = "Dark Green Grass Clump"
					elseif component == "Light Green Clump" then
						component = "Light Green Grass Clump"
					elseif component == "Tan Clump" then
						component = "Tan Grass Clump"
					elseif component == "Sat Green Clump" then --??? no such grass?
						component = "Light Green Grass Clump"
					end

					if type(component) == "string" and component ~= "Long Shaft" and component ~= "Crystal Shard" and component ~= "Spear" then

						self:spawnItem(component, n)

						break

					end

				end

			end

		end

	end

end
-------------------------------------------------------------------------------
function RecipeView:spawnItem(name, count)

	local spawnLocation = Eternus.GameState.m_activeCamera:NKGetLocation() + (Eternus.GameState.m_activeCamera:ForwardVector():mul_scalar(3.0))

	-- Forward the command to player
	self.m_controller:SpawnCommand(name, count, spawnLocation)

	Eternus.CommandService:NKAddLocalText("Attempting to spawn " .. tostring(count) .. " of object " .. name .. "\n")

end
-------------------------------------------------------------------------------
function RecipeView:ToggleInterface()

	self:setVisible(false)
	self.layout:setVisible(false)

end
-------------------------------------------------------------------------------
function RecipeView:setVisible(show)

	self.m_active = show

	if show then

		Eternus.InputSystem:NKPushInputContext(self.recipeContext)

		self.m_controller.m_gameModeUI.m_crosshair:hide()

		Eternus.InputSystem:NKShowMouse()
		Eternus.InputSystem:NKCenterMouse()

		self.m_controller.m_inventoryToggleable = false

	else

		if self.m_currentWindow then
			self.m_currentWindow:setProperty("HighlightImageColours", RecipeView.ALPHA_INVISIBLE)
			self.m_tooltip:hide()
			self.m_currentWindow = nil
		end

		Eternus.InputSystem:NKRemoveInputContext(self.recipeContext)

		self.m_controller.m_gameModeUI.m_crosshair:show()

		Eternus.InputSystem:NKHideMouse()

		self.m_controller.m_inventoryToggleable = true

	end

end
-------------------------------------------------------------------------------
function RecipeView:OnMouseEnterDragContainer(invSlot)
	-- Enable the selection highlight
	if invSlot then
		invSlot:setProperty("HighlightImageColours", RecipeView.ALPHA_VISIBLE)
		self.m_tooltip:show()
		self.m_currentWindow = invSlot
	end
end
-------------------------------------------------------------------------------
function RecipeView:OnMouseExitDragContainer(invSlot)
	-- Disable the selection highlight
	if invSlot then
		invSlot:setProperty("HighlightImageColours", RecipeView.ALPHA_INVISIBLE)
		self.m_tooltip:hide()
		self.m_currentWindow = nil
	end

end
-------------------------------------------------------------------------------
function RecipeView:OnTextChanged()

	self.text = self.searchbox:getText()

	if self.text == "" then
		self.text = nil
		self:LayoutAllRecipes()
		return
	end
--[[
	self.recipeScrollpane:destroyChild(self.recipesList)

	self.recipesList = Windows:createWindow("VerticalLayoutContainer")

	self.recipesList:setProperty("DistributeCapturedInputs", "true")
	self.recipesList:setProperty("MouseInputPropagationEnabled", "true")

	self.recipeScrollpane:addChild(self.recipesList)

	self:LoadRecipes()
]]

	for i, recipe in pairs(self.recipes) do

		self.recipesList:removeChild(recipe.data)

		if not UFI.instance.discoveredRecipes then

			if string.find(string.lower(recipe.name), string.lower(self.text)) then

				self.recipesList:addChild(recipe.data)

				CEGUI.toHorizontalLayoutContainer(recipe.data):layout()

			end

		elseif (UFI.instance.discoveredRecipes[recipe.name] or not self.descoveryMode) and string.find(string.lower(recipe.name), string.lower(self.text)) then

			self.recipesList:addChild(recipe.data)

			CEGUI.toHorizontalLayoutContainer(recipe.data):layout()

		end

	end

	CEGUI.toVerticalLayoutContainer(self.recipesList):layout()

end
-------------------------------------------------------------------------------
function RecipeView:OnSearchboxClicked()

	if not self.searching then

		Eternus.InputSystem:NKPushInputContext(self.searchContext)

		self.searching = true

	end

end
-------------------------------------------------------------------------------
function RecipeView:OnSearchboxExit()

	self.searchbox:deactivate()

end
-------------------------------------------------------------------------------
function RecipeView:OnSearchboxDeactivated()

	Eternus.InputSystem:NKRemoveInputContext(self.searchContext)

	self.searching = false

end
-------------------------------------------------------------------------------
function RecipeView:LayoutAllRecipes()

	for i, recipe in pairs(self.recipes) do

		self.recipesList:removeChild(recipe.data)

		if not UFI.instance.discoveredRecipes then

			self.recipesList:addChild(recipe.data)

			CEGUI.toHorizontalLayoutContainer(recipe.data):layout()

		elseif UFI.instance.discoveredRecipes[recipe.name] or not self.descoveryMode then

			self.recipesList:addChild(recipe.data)

			CEGUI.toHorizontalLayoutContainer(recipe.data):layout()

		end

	end

	CEGUI.toVerticalLayoutContainer(self.recipesList):layout()

end

function RecipeView:LoadRecipes()
	local once = true
	local CSys = Eternus.CraftingSystem

	local recipesSorted = {}

	self.recipes = {}

	local name = ""

	local index = 1

	for i = CSys.m_highestPriority, 0, -1 do
		if (CSys.m_recipes[i] ~= nil) then
			for j, recipe in pairs(CSys.m_recipes[i]) do

				--[[if self.text then

					for result, n in pairs(recipe["m_results"]) do

						if type(result) == "string" and UFI.instance.discoveredRecipes[result] and string.find(string.lower(result), string.lower(self.text)) then

							recipesSorted[index] = recipe

							index = index + 1

							break

						end

					end

				else]]

					recipesSorted[index] = recipe

					index = index + 1

				--end

			end
		end
	end

	table.sort(recipesSorted, function(a, b)

		for resulta, na in pairs(a["m_results"]) do

			if type(resulta) == "string" then

				for resultb, nb in pairs(b["m_results"]) do

					if type(resultb) == "string" then

						return resulta < resultb

					end

				end

			end

		end

		return false

	end)

	for j, recipe in pairs(recipesSorted) do

		local data = Windows:createWindow("HorizontalLayoutContainer")

		data:setProperty("DistributeCapturedInputs", "true")
		data:setProperty("MouseInputPropagationEnabled", "true")

		data:setSize(CEGUI.USize(CEGUI.UDim(1,0), CEGUI.UDim(1,0)))

		--[[
		if (once) then

			for k,l in pairs(recipe) do
				NKPrint(k .. "\n")
			end

			once = false

		end
		]]

		local craftButton = Windows:createWindow("TUGLook/Button")

		craftButton:subscribeEvent("MouseClick", function(args)

			if self.m_active then

				if self.m_controller.m_dying or self.m_controller.m_actionLocked then
					return
				end

				local eyePosition = self.m_controller:NKGetPosition() + vec3(0.0, self.m_controller.m_cameraHeight, 0.0)
				local lookDirection = Eternus.GameState.m_activeCamera:ForwardVector()
				local result = NKPhysics.RayCastCollect(eyePosition, lookDirection, self.m_controller:GetMaxReachDistance(), {self.m_controller})

				local tracePos
				if result then
					tracePos = result.point
				else
					tracePos = eyePosition
					tracePos = tracePos + (lookDirection:mul_scalar(2.5))
				end

				UFI.instance:RaiseServerEvent("ServerEvent_CraftRecipe", {at = tracePos, recipe = recipe:GetRecipeName(), player = self.m_controller.object})

			end

		end)

		craftButton:setText("Craft")

		craftButton:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

		craftButton:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		data:addChild(craftButton)

		for result, n in pairs(recipe["m_results"]) do

			if type(result) == "string" then

				name = result

				--NKPrint("Recipe: " .. result .. "\n")

				local frame = Windows:createWindow("TUGLook/Frame")

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				self:SlotHelper(frame, result, n, recipe)

				data:addChild(frame)

			end

		end

		local label = Windows:createWindow("TUGLook/Frame")

		label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

		label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		data:addChild(label)

		if recipe["m_craftingStations"] then

			local interchangeables = Windows:createWindow("HorizontalLayoutContainer")

			interchangeables:setProperty("DistributeCapturedInputs", "true")
			interchangeables:setProperty("MouseInputPropagationEnabled", "true")

			local num = 0.0

			local frame = Windows:createWindow("TUGLook/Frame")

			for station in pairs(recipe["m_craftingStations"]) do

				num = num + 1

			end

			for station in pairs(recipe["m_craftingStations"]) do

				if type(station) == "string" then

					--NKPrint("Station: " .. station .. "\n")

					self:SlotHelper(interchangeables, station)

				end

			end

			frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70 * num), CEGUI.UDim(0, 70)))

			frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			frame:addChild(interchangeables)

			data:addChild(frame)

			CEGUI.toHorizontalLayoutContainer(interchangeables):layout()

		else

			local invItemContainer = Windows:createWindow("DefaultWindow")
			invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))
			invItemContainer:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			data:addChild(invItemContainer)

		end

		if recipe["m_craftingTool"] then

			local frame = Windows:createWindow("TUGLook/Frame")

			tier = recipe["m_craftingTool"]["tier"]

			tool = recipe["m_craftingTool"]["category"]

			prefix = {}

			prefix[0] = "Crude"
			prefix[1] = "Crude"
			prefix[2] = "Crude"
			prefix[3] = "Bronze"
			prefix[4] = "Iron"

			--NKPrint("Tier: " .. tier .. "\n")

			if tool == "Knife" then
				tool = prefix[tier] .. " Knife"
			elseif tool == "Hammer" then
				tool = prefix[tier] .. " Hammer"
			elseif tool == "Axe" then
				tool = prefix[tier] .. " Axe"
			elseif tool == "Mallet" then
				tier = math.max(tier, 3)
				tool = "Wooden Mallet"
			elseif tool == "Shears" then
				tier = math.max(tier, 3)
				tool = prefix[tier] .. " Shears"
			end

			if type(tool) == "string" then

				--NKPrint("Tool: " .. tool .. "\n")

				local frame = Windows:createWindow("TUGLook/Frame")

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				self:SlotHelper(frame, tool)

				data:addChild(frame)

			end

		else

			local invItemContainer = Windows:createWindow("DefaultWindow")
			invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))
			invItemContainer:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			data:addChild(invItemContainer)

		end

		local label = Windows:createWindow("TUGLook/Frame")

		label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

		label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		data:addChild(label)

		if recipe["m_unconsumedComponents"] then

			for category, parts in pairs(recipe["m_unconsumedComponents"]) do

				local interchangeables = Windows:createWindow("HorizontalLayoutContainer")

				interchangeables:setProperty("DistributeCapturedInputs", "true")
				interchangeables:setProperty("MouseInputPropagationEnabled", "true")

				local num = 0.0

				local frame = Windows:createWindow("TUGLook/Frame")

				for component, n in pairs(parts) do

					num = num + 1

				end

				for component, n in pairs(parts) do

					--NKPrint(component .. " unconsumed" .. "\n")

					if component == "Crude Rock Head" then
						component = "Round Rock"
					end

					if type(component) == "string" and component ~= "Long Shaft" and component ~= "Crystal Shard" and component ~= "Spear" then

						self:SlotHelper(interchangeables, component, n)

					end

				end

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70 * num), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				frame:addChild(interchangeables)

				data:addChild(frame)

				CEGUI.toHorizontalLayoutContainer(interchangeables):layout()

			end

			local label = Windows:createWindow("TUGLook/Frame")

			label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

			label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			data:addChild(label)

		end

		if (recipe["m_components"]) then

			for category, parts in pairs(recipe["m_components"]) do

				local interchangeables = Windows:createWindow("HorizontalLayoutContainer")

				interchangeables:setProperty("DistributeCapturedInputs", "true")
				interchangeables:setProperty("MouseInputPropagationEnabled", "true")

				local num = 0

				local frame = Windows:createWindow("TUGLook/Frame")

				if recipe:InstanceOf(ModularRecipe) then

					num = 1

					local component = parts["default"]

					if component == "Long Shaft" then
						component = "Wood Shaft"
						--NKPrint(" -> " .. component)
					elseif component == "Crystal Shard" then
						component = "Blue Crystal Shard"
						--NKPrint(" -> " .. component)
					elseif component == "Spear" then
						component = "Wood Spear"
						--NKPrint(" -> " .. component)
					elseif component == "Wood Log" then
						component = "Wood Log Pine"
						--NKPrint(" -> " .. component)
					elseif component == "Dark Green Clump" then
						component = "Dark Green Grass Clump"
						--NKPrint(" -> " .. component)
					elseif component == "Light Green Clump" then
						component = "Light Green Grass Clump"
						--NKPrint(" -> " .. component)
					elseif component == "Tan Clump" then
						component = "Tan Grass Clump"
						--NKPrint(" -> " .. component)
					elseif component == "Sat Green Clump" then --??? no such grass?
						component = "Light Green Grass Clump"
						--NKPrint(" -> " .. component)
					else
						--NKPrint(component .. "\n")
					end

					if type(component) == "string" and component ~= "Long Shaft" and component ~= "Crystal Shard" and component ~= "Spear" then

						self:SlotHelper(interchangeables, component, n)

					end

				else

					for component, n in pairs(parts) do

						num = num + 1

					end

					for component, n in pairs(parts) do

						if component == "Long Shaft" then
							component = "Wood Shaft"
							--NKPrint(" -> " .. component)
						elseif component == "Crystal Shard" then
							component = "Blue Crystal Shard"
							--NKPrint(" -> " .. component)
						elseif component == "Spear" then
							component = "Wood Spear"
							--NKPrint(" -> " .. component)
						elseif component == "Wood Log" then
							component = "Wood Log Pine"
							--NKPrint(" -> " .. component)
						elseif component == "Dark Green Clump" then
							component = "Dark Green Grass Clump"
							--NKPrint(" -> " .. component)
						elseif component == "Light Green Clump" then
							component = "Light Green Grass Clump"
							--NKPrint(" -> " .. component)
						elseif component == "Tan Clump" then
							component = "Tan Grass Clump"
							--NKPrint(" -> " .. component)
						elseif component == "Sat Green Clump" then --??? no such grass?
							component = "Light Green Grass Clump"
							--NKPrint(" -> " .. component)
						else
							--NKPrint(component .. "\n")
						end

						if type(component) == "string" and component ~= "Long Shaft" and component ~= "Crystal Shard" and component ~= "Spear" then

							self:SlotHelper(interchangeables, component, n)

						end

					end

				end

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70 * num), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				frame:addChild(interchangeables)

				data:addChild(frame)

				CEGUI.toHorizontalLayoutContainer(interchangeables):layout()

			end

		end

		table.insert(self.recipes, {data = data, name = name})

		--self.recipesList:addChild(data)

		CEGUI.toHorizontalLayoutContainer(data):layout()

	end

	--CEGUI.toVerticalLayoutContainer(self.recipesList):layout()

end

function RecipeView:SlotHelper(parent, item, n, recipe)

	local invItemContainer = Windows:createWindow("DefaultWindow")
	invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

	local invSlot = Windows:createWindow("TUGLook/InventorySlot", "InventorySlot")

	invItemContainer:addChild(invSlot)

	parent:addChild(invItemContainer)

	itemSchematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName(item)

	if itemSchematic and itemSchematic~=nullSchematic and itemSchematic:NKGetIconName() then
		invSlot:setProperty("ItemImage", "TUGIcons/" .. itemSchematic:NKGetIconName())
	else
		invSlot:setProperty("ItemImage", "TUGIcons/NoIcon")
	end

	if n and n > 1 then
		invSlot:setProperty("StackCount", tostring(n))
	else
		invSlot:setProperty("StackCount", "")
	end

	invSlot:setTooltip(self.m_tooltip)
	invSlot:setProperty("DraggingEnabled", "false")

	local tooltipMessage = item

	if n and n > 1 then
		tooltipMessage = tooltipMessage .. " x " .. n
	end

	invSlot:setTooltipText(tooltipMessage)

	invSlot:subscribeEvent("MouseEntersSurface", function( args )
		if self.m_active then
			self:OnMouseEnterDragContainer(invSlot)
		end
	end)

	invSlot:subscribeEvent("MouseLeavesSurface", function( args )
		if self.m_active then
			self:OnMouseExitDragContainer(invSlot)
		end
	end)

	if recipe ~= nil then

		invSlot:subscribeEvent("MouseDoubleClick", function(args)

			if self.m_active and self.cheatMode then

				self:SpawnComponents(recipe)

			end
		end)

	else

		invSlot:subscribeEvent("MouseDoubleClick", function(args)

			if self.m_active and self.cheatMode then

				if n == nil then n = 1 end

				self:spawnItem(item, n)

			end
		end)

	end

end
