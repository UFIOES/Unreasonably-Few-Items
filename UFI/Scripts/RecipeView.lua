
include("Scripts/UI/View.lua")
include("Scripts/UI/RecipeItemView.lua")
include("Scripts/objects/Equipable.lua")
include("Scripts/UI/TechTreeView.lua")

local Windows = nil
local UISystem = nil
local Animations = nil

if Eternus.IsClient then -- These are not used in a dedicated server environment
	Windows	= EternusEngine.UI.Windows
	UISystem = EternusEngine.UI.System
	Animations = EternusEngine.UI.Animations
end


-------------------------------------------------------------------------------

if RecipeView == nil then
	RecipeView = View.Subclass("RecipeView")
end

RecipeView.ALPHA_VISIBLE = "tl:FFFFFFFF tr:FFFFFFFF bl:FFFFFFFF br:FFFFFFFF"
RecipeView.ALPHA_INVISIBLE = "tl:00FFFFFF tr:00FFFFFF bl:00FFFFFF br:00FFFFFF"

-------------------------------------------------------------------------------

function RecipeView:PostLoad(layout, controller)

	self.recipeScrollpane = CEGUI.toScrollablePane(self:GetChild("RecipesFrame"):getChild("Recipes"))
	self.recipeScrollpane:setShowHorzScrollbar(false)

	self.recipeContext = InputMappingContext.new("Recipies")

	self.recipeContext:NKSetInputPropagation(false)

	self.recipeContext:NKRegisterNamedCommand("Return to Menu", self, "ToggleInterface", KEY_ONCE)

	self.recipeContext:NKRegisterNamedCommand("Toggle Recipe Interface", self, "ToggleInterface", KEY_ONCE)

	self.searchbox = CEGUI.toEditbox(self:GetChild("RecipesFrame"):getChild("Searchbox"))

	self.searchContext = InputMappingContext.new("Searchbox")

	self.searchContext:NKSetInputPropagation(false)

	self.searchContext:NKRegisterNamedCommand("Return to Menu", self, "OnSearchboxExit", KEY_ONCE)

	self.cheatModeButton = CEGUI.toToggleButton(self:GetChild("OptionsFrame"):getChild("CheatMode"))

	self.discoveryModeButton = CEGUI.toToggleButton(self:GetChild("OptionsFrame"):getChild("DiscoveryMode"))

	self.mouseCycleModeButton = CEGUI.toToggleButton(self:GetChild("OptionsFrame"):getChild("MouseCycleMode"))

	self.cheatMode = false

	self.descoveryMode = true

	self.mouseCycleMode = true

	self.searching = false

	self.iconUpdateTime = 0

--[[
	EternusEngine.UI.Layers.Gameplay:subscribeEvent("CaptureLost", function(args)
		if self.active then
			self:ToggleInterface()
		end
	end)
]]

	self.cheatModeButton:subscribeEvent("SelectStateChanged", function(args)
		if self.active then
			self.cheatMode = not self.cheatMode
		end
	end)

	self.discoveryModeButton:subscribeEvent("SelectStateChanged", function(args)
		if self.active then
			self.descoveryMode = not self.descoveryMode
			self:OnTextChanged()
		end
	end)

	self.mouseCycleModeButton:subscribeEvent("SelectStateChanged", function(args)
		if self.active then
			self.mouseCycleMode = not self.mouseCycleMode
		end
	end)

	self.searchbox:subscribeEvent("MouseClick", function(args)
		if self.active then
			self:OnSearchboxClicked()
		end
	end)

	self.searchbox:subscribeEvent("TextChanged", function(args)
		if self.active then
			self:OnTextChanged()
		end
	end)

	self.searchbox:subscribeEvent("Deactivated", function(args)
		if self.active then
			self:OnSearchboxDeactivated()
		end
	end)

	self.searchbox:subscribeEvent("TextAccepted", function(args)
		if self.active then
			self:OnSearchboxExit()
		end
	end)

	self.recipesList = Windows:createWindow("VerticalLayoutContainer")

	self.recipesList:setProperty("DistributeCapturedInputs", "true")
	self.recipesList:setProperty("MouseInputPropagationEnabled", "false")

	self.recipeScrollpane:addChild(self.recipesList)

	self.controller = controller

	self.layout = layout

	self.tooltip = CEGUI.toTooltip(Windows:createWindow("TUGLook/Tooltip"))
	self.active = false
	self.currentWindow = nil

	EternusEngine.UI.Layers.Gameplay:addChild(self.tooltip)

	if not Animations:getAnimation("moveRight") then

		self.moveRight = {}

		self.moveRight.animation = Animations:createAnimation("moveRight")

		self.moveRight.animation:setDuration(0.125)

		self.moveRight.animation:setReplayMode(CEGUI.Animation.RM_Once)

		self.moveRight.affector = self.moveRight.animation:createAffector("Position", "UVector2")

		self.moveRight.affector:setApplicationMethod(CEGUI.Affector.AM_Relative)

		self.moveRight.affector:createKeyFrame(0, "{{0, 0}, {0, 0}}")

		self.moveRight.affector:createKeyFrame(0.125, "{{0, 8}, {0, 0}}", CEGUI.KeyFrame.P_QuadraticAccelerating)

		self.moveLeft = {}

		self.moveLeft.animation = Animations:createAnimation("moveLeft")

		self.moveLeft.animation:setDuration(0.125)

		self.moveLeft.animation:setReplayMode(CEGUI.Animation.RM_Once)

		self.moveLeft.affector = self.moveLeft.animation:createAffector("Position", "UVector2")

		self.moveLeft.affector:setApplicationMethod(CEGUI.Affector.AM_Relative)

		self.moveLeft.affector:createKeyFrame(0, "{{0, 0}, {0, 0}}")

		self.moveLeft.affector:createKeyFrame(0.125, "{{0, -8}, {0, 0}}", CEGUI.KeyFrame.P_QuadraticDecelerating)

	else

		self.moveRight = {}

		self.moveRight.animation = Animations:getAnimation("moveRight")

		self.moveLeft = {}

		self.moveLeft.animation = Animations:getAnimation("moveLeft")

	end

	self.tabs = {}

	self:AddTab("All")

	self:AddTab("Tools")

	self:AddTab("Repair")

	self:AddTab("Decor")

	self:AddTab("Misc")

	self:LoadRecipes()

	self:LayoutAllRecipes()

end

function RecipeView:Update(dt)

	self.iconUpdateTime = self.iconUpdateTime + dt

	if self.iconUpdateTime > 1 then

		for i, recipe in pairs(self.recipes) do

			recipe:Update()

			CEGUI.toHorizontalLayoutContainer(recipe.data):layout()

		end

		CEGUI.toVerticalLayoutContainer(self.recipesList):layout()

		self.iconUpdateTime = 0

	end

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

				if type(component) == "string" then

					local items = UFI.instance:FilterGenerics(component)

					if type(items) == "table" then
						self:spawnItem(items[1], 1)
					else
						self:spawnItem(items, 1)
					end

				end

			else

				for component, n in pairs(parts) do

						if type(component) == "string" then

						local items = UFI.instance:FilterGenerics(component)

						if type(items) == "table" then
							self:spawnItem(items[1], n)
						else
							self:spawnItem(items, n)
						end

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
	self.controller:SpawnCommand(name, count, spawnLocation)

	Eternus.CommandService:NKAddLocalText("Attempting to spawn " .. tostring(count) .. " of object " .. name .. "\n")

end
-------------------------------------------------------------------------------
function RecipeView:ToggleInterface()

	self:setVisible(false)
	self.layout:setVisible(false)

end
-------------------------------------------------------------------------------
function RecipeView:setVisible(show)

	self.active = show

	if show then

		Eternus.InputSystem:NKPushInputContext(self.recipeContext)

		self.controller.m_gameModeUI.m_crosshair:hide()

		Eternus.InputSystem:NKShowMouse()
		Eternus.InputSystem:NKCenterMouse()

		self.controller.m_inventoryToggleable = false

	else

		if self.currentWindow then
			self.currentWindow:setProperty("HighlightImageColours", RecipeView.ALPHA_INVISIBLE)
			self.tooltip:hide()
			self.currentWindow = nil
		end

		Eternus.InputSystem:NKRemoveInputContext(self.recipeContext)

		self.controller.m_gameModeUI.m_crosshair:show()

		Eternus.InputSystem:NKHideMouse()

		self.controller.m_inventoryToggleable = true

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

function RecipeView:AddTab(group)

	--local name = group:ClassName()

	table.insert(self.tabs, group)--TechTreeView.new(group)

	local tabBacker = Windows:createWindow("TUGLook/TabBacker")

	local tabButton = Windows:createWindow("TUGLook/ImageButton")

	tabButton:setArea(CEGUI.UDim(0, 0), CEGUI.UDim(0, 0), CEGUI.UDim(1, 0), CEGUI.UDim(1, 0))

	tabBacker:setArea(CEGUI.UDim(0, 0), CEGUI.UDim(0, 64 * (table.getn(self.tabs) - 1)), CEGUI.UDim(0, 64), CEGUI.UDim(0, 64))

	tabBacker:setProperty("Rotation", "w:0.707107 x:0 y:0 z:-0.707107")

	tabBacker:addChild(tabButton)

	self.layout:addChild(tabBacker)

	local animRight = Animations:instantiateAnimation(self.moveRight.animation)

	animRight:setTargetWindow(tabBacker)

	local animLeft = Animations:instantiateAnimation(self.moveLeft.animation)

	animLeft:setTargetWindow(tabBacker)

	tabButton:subscribeEvent("MouseEntersSurface", function(args)

		if self.active then

			animLeft:stop()

			tabBacker:setXPosition(CEGUI.UDim(0, 0))

			animRight:start()

		end

	end)

	tabButton:subscribeEvent("MouseLeavesSurface", function(args)

		if self.active then

			animRight:stop()

			tabBacker:setXPosition(CEGUI.UDim(0, 8))

			animLeft:start()

		end

	end)

	tabButton:subscribeEvent("MouseClick", function(args)

		if self.active then

			--switch tab

		end

	end)

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

				table.insert(recipesSorted, recipe)

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

	--local dataTypes = {}

	for j, recipe in pairs(recipesSorted) do
--[[
		for m_type, data in pairs(recipe) do

			dataTypes[m_type] = 1

		end
]]
		table.insert(self.recipes, RecipeItemView.new(self, recipe))

	end
--[[
	for m_type, one in pairs(dataTypes) do

		NKPrint(m_type)

	end
]]
end
