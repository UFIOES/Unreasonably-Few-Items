include("Scripts/Core/Common.lua")
include("Scripts/UI/View.lua")
--include("Scripts/RecipeItemView.lua")

local Windows = nil
local UISystem = nil

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

	self.searchbox = CEGUI.toEditbox(self:GetChild("Searchbox"))

	self.searchContext = InputMappingContext.new("Searchbox")

	self.searchContext:NKSetInputPropagation(false)

	self.searchContext:NKRegisterNamedCommand("Return to Menu", self, "OnSearchboxExit", KEY_ONCE)

	self.searching = false

	self.searchbox:subscribeEvent("MouseClick", function( args )
		if self.m_active then
			self:OnSearchboxClicked()
		end
	end)

	self.searchbox:subscribeEvent("TextChanged", function( args )
		if self.m_active then
			self:OnTextChanged()
		end
	end)

	self.searchbox:subscribeEvent("Deactivated", function( args )
		if self.m_active then
			self:OnSearchboxExit()
		end
	end)

	self.recipesList = Windows:createWindow("VerticalLayoutContainer")

	self.recipesList:setProperty("DistributeCapturedInputs", "true")
	self.recipesList:setProperty("MouseInputPropagationEnabled", "true")

	self.recipeScrollpane:addChild(self.recipesList)

	self.m_controller = controller

	self.m_controller.m_toggleInventorySignal:Add(function()
		self.m_active = not self.m_active
	end)

	self.m_tooltip = CEGUI.toTooltip(Windows:createWindow("TUGLook/Tooltip"))
	self.m_active = false
	self.m_currentWindow = nil

	EternusEngine.UI.Layers.Gameplay:addChild(self.m_tooltip)

	self:LoadRecipes()

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
function RecipeView:OnMouseEnterDragContainer( invSlot )
	-- Enable the selection highlight
	if invSlot then
		invSlot:setProperty("HighlightImageColours", RecipeView.ALPHA_VISIBLE)
		self.m_tooltip:show()
		self.m_currentWindow = invSlot
	end
end
-------------------------------------------------------------------------------
function RecipeView:OnMouseExitDragContainer( invSlot )
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
	end

	self.recipeScrollpane:destroyChild(self.recipesList)

	self.recipesList = Windows:createWindow("VerticalLayoutContainer")

	self.recipesList:setProperty("DistributeCapturedInputs", "true")
	self.recipesList:setProperty("MouseInputPropagationEnabled", "true")

	self.recipeScrollpane:addChild(self.recipesList)

	self:LoadRecipes()

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

	Eternus.InputSystem:NKRemoveInputContext(self.searchContext)

	self.searching = false

end
-------------------------------------------------------------------------------
function RecipeView:LoadRecipes()
	once = true
	local CSys = Eternus.CraftingSystem

	recipesSorted = {}

	local index = 1

	for i = CSys.m_highestPriority, 0, -1 do
		if (CSys.m_recipes[i] ~= nil) then
			for j, recipe in pairs(CSys.m_recipes[i]) do

				if self.text then

					for result, n in pairs(recipe["m_results"]) do

						if type(result) == "string" and string.find(string.lower(result), string.lower(self.text)) then

							recipesSorted[index] = recipe

							index = index + 1

						end

					end

				else

					recipesSorted[index] = recipe

					index = index + 1

				end

			end
		end
	end

	if not self.text then

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

	end

	for j, recipe in pairs(recipesSorted) do

		local data = Windows:createWindow("HorizontalLayoutContainer")

		data:setProperty("DistributeCapturedInputs", "true")
		data:setProperty("MouseInputPropagationEnabled", "true")

		data:setSize(CEGUI.USize(CEGUI.UDim(1,0), CEGUI.UDim(1,0)))

		if (once) then

			for k,l in pairs(recipe) do
				NKPrint(k .. "\n")
			end

			once = false

		end

		for result, n in pairs(recipe["m_results"]) do

			if type(result) == "string" then

				NKPrint("Recipe: " .. result .. "\n")

				local frame = Windows:createWindow("TUGLook/Frame")

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				self:SlotHelper(frame, result, n)

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

					NKPrint("Station: " .. station .. "\n")

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

				NKPrint("Tool: " .. tool .. "\n")

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

					NKPrint(component .. " unconsumed" .. "\n")

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
						NKPrint(" -> " .. component)
					elseif component == "Crystal Shard" then
						component = "Citrine Shard"
						NKPrint(" -> " .. component)
					elseif component == "Spear" then
						component = "Wood Spear"
						NKPrint(" -> " .. component)
					elseif component == "Wood Log" then
						component = "Wood Log Pine"
						NKPrint(" -> " .. component)
					elseif component == "Dark Green Clump" then
						component = "Dark Green Grass Clump"
						NKPrint(" -> " .. component)
					elseif component == "Light Green Clump" then
						component = "Light Green Grass Clump"
						NKPrint(" -> " .. component)
					elseif component == "Tan Clump" then
						component = "Tan Grass Clump"
						NKPrint(" -> " .. component)
					elseif component == "Sat Green Clump" then --??? no such grass?
						component = "Light Green Grass Clump"
						NKPrint(" -> " .. component)
					else
						NKPrint(component .. "\n")
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
							NKPrint(" -> " .. component)
						elseif component == "Crystal Shard" then
							component = "Citrine Shard"
							NKPrint(" -> " .. component)
						elseif component == "Spear" then
							component = "Wood Spear"
							NKPrint(" -> " .. component)
						elseif component == "Wood Log" then
							component = "Wood Log Pine"
							NKPrint(" -> " .. component)
						elseif component == "Dark Green Clump" then
							component = "Dark Green Grass Clump"
							NKPrint(" -> " .. component)
						elseif component == "Light Green Clump" then
							component = "Light Green Grass Clump"
							NKPrint(" -> " .. component)
						elseif component == "Tan Clump" then
							component = "Tan Grass Clump"
							NKPrint(" -> " .. component)
						elseif component == "Sat Green Clump" then --??? no such grass?
							component = "Light Green Grass Clump"
							NKPrint(" -> " .. component)
						else
							NKPrint(component .. "\n")
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

		self.recipesList:addChild(data)

		CEGUI.toHorizontalLayoutContainer(data):layout()

	end

	CEGUI.toVerticalLayoutContainer(self.recipesList):layout()

end

function RecipeView:SlotHelper(parent, item, n)

	local invItemContainer = Windows:createWindow("DefaultWindow")
	invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

	local invSlot = Windows:createWindow("TUGLook/InventorySlot", "InventorySlot")

	invItemContainer:addChild(invSlot)

	parent:addChild(invItemContainer)

	itemSchematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName(item)

	if itemSchematic and itemSchematic:NKGetIconName() then
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

	-- On mouse enter
	invSlot:subscribeEvent("MouseEntersSurface", function( args )
		if self.m_active then
			self:OnMouseEnterDragContainer(invSlot)
		end
	end)

	-- On mouse leave
	invSlot:subscribeEvent("MouseLeavesSurface", function( args )
		if self.m_active then
			self:OnMouseExitDragContainer(invSlot)
		end
	end)

end
