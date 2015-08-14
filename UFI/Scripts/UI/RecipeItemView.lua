include("Scripts/Core/Class.lua")
include("Scripts/UI/EquipmentView.lua")
include("Scripts/UI/ItemContainerView.lua")
--include("Scripts/RecipeView.lua")

-------------------------------------------------------------------------------
if RecipeItemView == nil then
	RecipeItemView = Class.Subclass("RecipeItemView")
end

if Eternus.IsClient then -- These are not used in a dedicated server environment
	Windows	= EternusEngine.UI.Windows
	UISystem = EternusEngine.UI.System
end

-- get an Schematic with invalid name
local nullSchematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName("_NULL_null_000")

-------------------------------------------------------------------------------
function RecipeItemView:Constructor(recipeView, recipe)
--[[
	for k, v in pairs(recipe) do

		NKPrint(k)

	end
]]
	self.recipeView = recipeView

	self.invslots = {}

	self.name = ""

	self.data = Windows:createWindow("HorizontalLayoutContainer")

	self.data:setProperty("DistributeCapturedInputs", "true")
	self.data:setProperty("MouseInputPropagationEnabled", "true")

	self.data:setSize(CEGUI.USize(CEGUI.UDim(1,0), CEGUI.UDim(1,0)))

	self:AddCraftButton(recipe, self.data)

	if recipe["m_results"] then

		for result, n in pairs(recipe["m_results"]) do

			if type(result) == "string" then

				self.name = result

				--NKPrint("Recipe: " .. result .. "\n")

				local frame = Windows:createWindow("TUGLook/Frame")

				frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

				frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

				self:SlotHelper(frame, result, n, recipe)

				self.data:addChild(frame)

			end

		end

	end

	if recipe["m_validTools"] then

		local frame = Windows:createWindow("TUGLook/Frame")

		frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

		frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		local tools = {}

		for tool in pairs(recipe["m_validTools"]) do

			if type(tool) == "string" then

				table.insert(tools, tool)

			end

		end

		self:SlotHelper(frame, tools)

		self.data:addChild(frame)

	end

	local label = Windows:createWindow("TUGLook/Frame")

	label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

	label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

	self.data:addChild(label)

	if recipe["m_craftingStations"] then
--[[
		local interchangeables = Windows:createWindow("HorizontalLayoutContainer")

		interchangeables:setProperty("DistributeCapturedInputs", "true")
		interchangeables:setProperty("MouseInputPropagationEnabled", "true")

		local num = 0.0

		local frame = Windows:createWindow("TUGLook/Frame")

		for station in pairs(recipe["m_craftingStations"]) do

			num = num + 1

		end
]]
		local frame = Windows:createWindow("TUGLook/Frame")

		frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

		frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		local stations = {}

		for station in pairs(recipe["m_craftingStations"]) do

			if type(station) == "string" then

				--NKPrint("Station: " .. station)

				table.insert(stations, station)

			end

		end

		self:SlotHelper(frame, stations)

		self.data:addChild(frame)

--[[
		frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70 * num), CEGUI.UDim(0, 70)))

		frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		frame:addChild(interchangeables)

		self.data:addChild(frame)

		CEGUI.toHorizontalLayoutContainer(interchangeables):layout()
]]
	else

		local invItemContainer = Windows:createWindow("DefaultWindow")
		invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))
		invItemContainer:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		self.data:addChild(invItemContainer)

	end

	if recipe["m_craftingTool"] and UFI.instance:FindTools(recipe["m_craftingTool"]["category"], recipe["m_craftingTool"]["tier"]) then

		local frame = Windows:createWindow("TUGLook/Frame")

		local frame = Windows:createWindow("TUGLook/Frame")

		frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

		frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		self:SlotHelper(frame, UFI.instance:FindTools(recipe["m_craftingTool"]["category"], recipe["m_craftingTool"]["tier"]))

		self.data:addChild(frame)

	else

		local invItemContainer = Windows:createWindow("DefaultWindow")
		invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))
		invItemContainer:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		self.data:addChild(invItemContainer)

	end

	local label = Windows:createWindow("TUGLook/Frame")

	label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

	label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

	self.data:addChild(label)

	if recipe["m_unconsumedComponents"] then

		for category, parts in pairs(recipe["m_unconsumedComponents"]) do

			local frame = Windows:createWindow("TUGLook/Frame")

			frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

			frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			local components = {}

			local counts = {}

			for component, n in pairs(parts) do

				if type(component) == "string" then

					local filtered = UFI.instance:FilterGenerics(component)

					if type(filtered) == "table" then

						for i, object in pairs(filtered) do

							table.insert(components, object)

							table.insert(counts, n)

						end

					else

						table.insert(components, filtered)

						table.insert(counts, n)

					end

				end

			end

			self:SlotHelper(frame, components, counts)

			self.data:addChild(frame)

		end

		local label = Windows:createWindow("TUGLook/Frame")

		label:setSize(CEGUI.USize(CEGUI.UDim(0, 8), CEGUI.UDim(0, 70)))

		label:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		self.data:addChild(label)

	end

	if (recipe["m_components"]) then

		for category, parts in pairs(recipe["m_components"]) do
--[[
			local interchangeables = Windows:createWindow("HorizontalLayoutContainer")

			interchangeables:setProperty("DistributeCapturedInputs", "true")
			interchangeables:setProperty("MouseInputPropagationEnabled", "true")

			local num = 0

			local frame = Windows:createWindow("TUGLook/Frame")

			if recipe:InstanceOf(ModularRecipe) then

				num = 1

				local component = parts["default"]

				if type(component) == "string" then

					self:SlotHelper(interchangeables, UFI.instance:FilterGenerics(component), n)

				end

			else

				for component, n in pairs(parts) do

					num = num + 1

				end

				for component, n in pairs(parts) do

					if type(component) == "string" then

						self:SlotHelper(interchangeables, UFI.instance:FilterGenerics(component), n)

					end

				end

			end

			frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70 * num), CEGUI.UDim(0, 70)))

			frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			frame:addChild(interchangeables)

			self.data:addChild(frame)

			CEGUI.toHorizontalLayoutContainer(interchangeables):layout()
]]

			local frame = Windows:createWindow("TUGLook/Frame")

			frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

			frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

			local components = {}

			local counts = {}

			if recipe:InstanceOf(ModularRecipe) then

				local component = parts["default"]

				if type(component) == "string" then

					local filtered = UFI.instance:FilterGenerics(component)

					if type(filtered) == "table" then

						for i, object in pairs(filtered) do

							table.insert(components, object)

							table.insert(counts, n)

						end

					else

						table.insert(components, filtered)

						table.insert(counts, n)

					end

				end

			else

				for component, n in pairs(parts) do

					if type(component) == "string" then

						local filtered = UFI.instance:FilterGenerics(component)

						if type(filtered) == "table" then

							for i, object in pairs(filtered) do

								table.insert(components, object)

								table.insert(counts, n)

							end

						else

							table.insert(components, filtered)

							table.insert(counts, n)

						end

					end

				end

			end

			self:SlotHelper(frame, components, counts)

			self.data:addChild(frame)

		end

	end

	if recipe["m_validTools"] then

		local frame = Windows:createWindow("TUGLook/Frame")

		frame:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

		frame:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

		local tools = {}

		for tool in pairs(recipe["m_validTools"]) do

			if type(tool) == "string" then

				table.insert(tools, tool)

			end

		end

		self:SlotHelper(frame, tools)

		self.data:addChild(frame)

	end

	CEGUI.toHorizontalLayoutContainer(self.data):layout()

end
-------------------------------------------------------------------------------
function RecipeItemView:AddCraftButton(recipe, data)

	local craftButton = Windows:createWindow("TUGLook/Button")

	craftButton:subscribeEvent("MouseClick", function(args)

		if self.recipeView.active then

			if self.recipeView.controller.m_dying or self.recipeView.controller.m_actionLocked then
				return
			end

			local eyePosition = self.recipeView.controller:NKGetPosition() + vec3(0.0, self.recipeView.controller.m_cameraHeight, 0.0)
			local lookDirection = Eternus.GameState.m_activeCamera:ForwardVector()
			local result = NKPhysics.RayCastCollect(eyePosition, lookDirection, self.recipeView.controller:GetMaxReachDistance(), {self.recipeView.controller})

			local tracePos
			if result then
				tracePos = result.point
			else
				tracePos = eyePosition
				tracePos = tracePos + (lookDirection:mul_scalar(2.5))
			end

			UFI.instance:RaiseServerEvent("ServerEvent_CraftRecipe", {at = tracePos, recipe = recipe:GetRecipeName(), player = self.recipeView.controller.object})

		end

	end)

	craftButton:setText("Craft")

	craftButton:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

	craftButton:setMargin(CEGUI.UBox(CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3), CEGUI.UDim(0, 3)))

	data:addChild(craftButton)

end
-------------------------------------------------------------------------------
function RecipeItemView:OnMouseEnterDragContainer(invSlot)
	-- Enable the selection highlight
	if invSlot then
		invSlot:setProperty("HighlightImageColours", RecipeView.ALPHA_VISIBLE)
		self.recipeView.tooltip:show()
		self.recipeView.currentWindow = invSlot
	end
end

function RecipeItemView:OnMouseExitDragContainer(invSlot)
	-- Disable the selection highlight
	if invSlot then
		invSlot:setProperty("HighlightImageColours", RecipeView.ALPHA_INVISIBLE)
		self.recipeView.tooltip:hide()
		self.recipeView.currentWindow = nil
	end

end
-------------------------------------------------------------------------------
function RecipeItemView:SlotHelper(parent, item, n, recipe)

	local invItemContainer = Windows:createWindow("DefaultWindow")
	invItemContainer:setSize(CEGUI.USize(CEGUI.UDim(0, 70), CEGUI.UDim(0, 70)))

	local invSlot = Windows:createWindow("TUGLook/InventorySlot", "InventorySlot")

	invItemContainer:addChild(invSlot)

	parent:addChild(invItemContainer)

	invSlot:setTooltip(self.recipeView.tooltip)
	invSlot:setProperty("DraggingEnabled", "false")

	if type(item) == "table" then

		invSlot.archetypes = {}

		invSlot.iconIndex = 1

		invSlot.skippedIndexes = 0

		for i, name in pairs(item) do

			local schematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName(name)

			if schematic and schematic~=nullSchematic and schematic:NKGetIconName() and schematic:NKGetIconName() ~= "" then
				table.insert(invSlot.archetypes, {icon = "TUGIcons/" .. schematic:NKGetIconName(), name = name})
			end

		end

		invSlot:setProperty("ItemImage", invSlot.archetypes[invSlot.iconIndex].icon)

		local tooltipMessage = invSlot.archetypes[invSlot.iconIndex].name

		if n and type(n) == "table" then

			invSlot.counts = n

			if invSlot.counts[invSlot.iconIndex] and invSlot.counts[invSlot.iconIndex] > 1 then
				tooltipMessage = tooltipMessage .. " x " .. invSlot.counts[invSlot.iconIndex]
			end

		else

			invSlot.count = n

			if invSlot.count and invSlot.count > 1 then
				tooltipMessage = tooltipMessage .. " x " .. invSlot.count
			end

		end

		invSlot:setTooltipText(tooltipMessage)

		invSlot:subscribeEvent("MouseDoubleClick", function(args)

			if self.recipeView.active and self.recipeView.cheatMode then

				if invSlot.counts then

					if invSlot.counts[invSlot.iconIndex] == nil then invSlot.counts[invSlot.iconIndex] = 1 end

					self.recipeView:spawnItem(invSlot.archetypes[invSlot.iconIndex].name, invSlot.counts[invSlot.iconIndex])

				else

					if invSlot.count == nil then invSlot.count = 1 end

					self.recipeView:spawnItem(invSlot.archetypes[invSlot.iconIndex].name, invSlot.count)

				end

			end
		end)

		if invSlot.counts then

			if invSlot.counts[invSlot.iconIndex] and invSlot.counts[invSlot.iconIndex] > 1 then
				invSlot:setProperty("StackCount", tostring(invSlot.counts[invSlot.iconIndex]))
			else
				invSlot:setProperty("StackCount", "")
			end

		else

			if invSlot.count and invSlot.count > 1 then
				invSlot:setProperty("StackCount", tostring(invSlot.count))
			else
				invSlot:setProperty("StackCount", "")
			end

		end

	else

		local schematic = Eternus.GameObjectSystem:NKFindObjectSchematicByName(item)

		if schematic and schematic~=nullSchematic and schematic:NKGetIconName() and schematic:NKGetIconName() ~= "" then
			invSlot:setProperty("ItemImage", "TUGIcons/" .. schematic:NKGetIconName())
		else
			invSlot:setProperty("ItemImage", "TUGIcons/NoIcon")
		end

		local tooltipMessage = item

		if n and n > 1 then
			tooltipMessage = tooltipMessage .. " x " .. n
		end

		invSlot:setTooltipText(tooltipMessage)-----------------------------------------------------this one is broken!!!

		invSlot:subscribeEvent("MouseDoubleClick", function(args)

			if self.recipeView.active and self.recipeView.cheatMode then

				if n == nil then n = 1 end

				self.recipeView:spawnItem(item, n)

			end
		end)

		if n and n > 1 then
			invSlot:setProperty("StackCount", tostring(n))
		else
			invSlot:setProperty("StackCount", "")
		end

	end

	invSlot:subscribeEvent("MouseEntersSurface", function( args )
		if self.recipeView.active then
			self:OnMouseEnterDragContainer(invSlot)
		end
	end)

	invSlot:subscribeEvent("MouseLeavesSurface", function( args )
		if self.recipeView.active then
			self:OnMouseExitDragContainer(invSlot)
		end
	end)

	if recipe ~= nil then

		invSlot:subscribeEvent("MouseClick", function(args)

			if self.recipeView.active and self.recipeView.cheatMode and Eternus.InputSystem:NKIsDown(EternusKeycodes.LSHIFT) then

				self.recipeView:SpawnComponents(recipe)

			end
		end)

	end

	table.insert(self.invslots, invSlot)

end

-------------------------------------------------------------------------------

function RecipeItemView:Update()

	for i, invSlot in pairs(self.invslots) do

		if invSlot.archetypes then

			if self.recipeView.mouseCycleMode and self.recipeView.currentWindow and self.recipeView.currentWindow == invSlot then

				invSlot.skippedIndexes = invSlot.skippedIndexes + 1

				return

			end

			invSlot.iconIndex = ((invSlot.iconIndex + invSlot.skippedIndexes) % table.getn(invSlot.archetypes)) + 1

			invSlot.skippedIndexes = 0

			invSlot:setProperty("ItemImage", invSlot.archetypes[invSlot.iconIndex].icon)

			local tooltipMessage = invSlot.archetypes[invSlot.iconIndex].name

			if invSlot.counts then

				if invSlot.counts[invSlot.iconIndex] and invSlot.counts[invSlot.iconIndex] > 1 then
					tooltipMessage = tooltipMessage .. " x " .. invSlot.counts[invSlot.iconIndex]
					invSlot:setProperty("StackCount", tostring(invSlot.counts[invSlot.iconIndex]))
				else
					invSlot:setProperty("StackCount", "")
				end

			else

				if invSlot.count and invSlot.count > 1 then
					tooltipMessage = tooltipMessage .. " x " .. invSlot.count
					invSlot:setProperty("StackCount", tostring(invSlot.count))
				else
					invSlot:setProperty("StackCount", "")
				end

			end

			invSlot:setTooltipText(tooltipMessage)

		end

	end

end

