include("Scripts/UI/View.lua")
include("Scripts/UI/EquipmentView.lua")
include("Scripts/UI/ItemContainerView.lua")
include("Scripts/RecipeView")

-------------------------------------------------------------------------------
if SurvivalUIView == nil then
	SurvivalUIView = View.Subclass("SurvivalUIView")
end

-------------------------------------------------------------------------------
-- Player and inventory will be the same, need to remove one.
function SurvivalUIView:Constructor( layout, model )

	self.m_model = model --this means the player... WHY??? UFIOES.

	self.m_chatBackground = self:GetChild("ChatBackground")

	self.m_healthBar = self:GetChild("HealthBar")
	self.m_healthText = self:GetChild("HealthText", self.m_healthBar)
	self.m_healthBar = CEGUI.toProgressBar(self.m_healthBar)

	self.m_staminaBar = self:GetChild("StaminaBar")
	self.m_staminaText = self:GetChild("StaminaText", self.m_staminaBar)
	self.m_staminaBar = CEGUI.toProgressBar(self.m_staminaBar)

	self.m_energyBar = self:GetChild("EnergyBar")
	self.m_energyText = self:GetChild("EnergyText", self.m_energyBar)
	self.m_energyBar = CEGUI.toProgressBar(self.m_energyBar)

	self.m_craftingProgressBar = self:GetChild("CraftingBar")
	self.m_craftingProgressText = self:GetChild("CraftingText", self.m_craftingProgressBar)
	self.m_craftingProgressBar = CEGUI.toProgressBar(self.m_craftingProgressBar)

	self.m_playerBackpack = self:GetChild("PlayerBackpack")
	self.m_backpackContainer = self:GetChild("Backpack", self.m_playerBackpack)
	self.m_handContainer = self:GetChild("Handslot")
	self.m_beltContainer = self:GetChild("Beltbar")
	self.m_equipmentContainer = self:GetChild("Equipment", self.m_playerBackpack)
	self.m_chestContainer = self:GetChild("Chest", self.m_playerBackpack)
	self.m_additionalBackpack = self:GetChild("AdditionalBackpack", self.m_playerBackpack)


	self.recipeView = self:GetChild("RecipeView")


	-- Setup our container Views
	self.m_containerViews = { }
	self.m_containerViews["HandSlot"] = ItemContainerView.new(self.m_handContainer, self.m_model)
	self.m_containerViews["BeltBar"] = ItemContainerView.new(self.m_beltContainer, self.m_model)
	self.m_containerViews["Backpack"] = ItemContainerView.new(self.m_backpackContainer, self.m_model)
	self.m_containerViews["Equipment"] = EquipmentView.new(self.m_equipmentContainer, self.m_model)
	self.m_containerViews["Chest"] = ItemContainerView.new(self.m_chestContainer, self.m_model)
	self.m_containerViews["AdditionalBackpack"] = ItemContainerView.new(self.m_additionalBackpack, self.m_model)


	self.m_containerViews["RecipeView"] = RecipeView.new(self.recipeView, self.m_model)


	self.m_containerViews["HandSlot"]:AttachToModel(self.m_model.m_inventoryContainers[1])
	self.m_containerViews["BeltBar"]:AttachToModel(self.m_model.m_inventoryContainers[2])
	self.m_containerViews["Backpack"]:AttachToModel(self.m_model.m_inventoryContainers[3])
	self.m_containerViews["Equipment"]:AttachToModel(self.m_model.m_inventoryContainers[4])


	-- Create the callbacks for when the model changes
	self.m_containerAddedCallback =	NKUtils.CreateDelegate(self, "AttachViewToModel")
	self.m_containerRemovedCallback = NKUtils.CreateDelegate(self, "DetachViewFromModel")

	self.m_hitPointsChangedCallback = NKUtils.CreateDelegate(self, "SetHealthProgress")
	self.m_staminaChangedCallback = NKUtils.CreateDelegate(self, "SetStaminaProgress")
	self.m_energyChangedCallback = NKUtils.CreateDelegate(self, "SetEnergyProgress")
	self.m_maxEnergyChangedCallback = NKUtils.CreateDelegate(self, "SetEnergyProgress")
	self.m_encumbranceChangedCallback = NKUtils.CreateDelegate(self, "SetEncumbranceProgress")

	self.m_spawnedCallback = NKUtils.CreateDelegate(self, "Spawned")
	self.m_diedCallback = NKUtils.CreateDelegate(self, "Died")

	self.m_craftingStartCallback = function(itemName)
		self:CraftingStart(itemName)
	end

	self.m_craftingProgressCallback = function(value)
		self:SetCraftingProgress(value)
	end

	self.m_craftingInterruptCallback = function()
		self:CraftingInterrupted()
	end

	self.m_craftingStoppedCallback = function(failed)
		self:CraftingStopped(failed)
	end

	-- Hide these containers by default
	self.m_playerBackpack:hide()
	self.m_containerViews["Chest"]:Hide()
	self.m_containerViews["AdditionalBackpack"]:Hide()


	self.m_containerViews["RecipeView"]:Hide()


	self:SetHealthProgress()
	self:SetStaminaProgress()
	self:SetEnergyProgress()

	if Eternus.GlobalRules.ProcessPlayerHitPoints == 0 then
		self.m_healthBar:hide()
	end

	if Eternus.GlobalRules.ProcessPlayerStamina == 0 then
		self.m_staminaBar:hide()
	end

	if Eternus.GlobalRules.ProcessPlayerEnergy == 0 then
		self.m_energyBar:hide()
	end

	self:AttachToModel()
end

-------------------------------------------------------------------------------
function SurvivalUIView:Initialize()

end

-------------------------------------------------------------------------------
function SurvivalUIView:AttachToModel( )

	self.m_model.m_containerAddedSignal:Add(self.m_containerAddedCallback)
	self.m_model.m_containerRemovedSignal:Add(self.m_containerRemovedCallback)

	self.m_model.m_hitPointsChangedSignal:Add(self.m_hitPointsChangedCallback)
	self.m_model.m_staminaChangedEvent:Add(self.m_staminaChangedCallback)

	self.m_model:GetStat("Energy"):SubscribeToValueChangeSignal(self.m_energyChangedCallback)
	self.m_model:GetStat("Energy"):SubscribeToMaxChangeSignal(self.m_maxEnergyChangedCallback)

	self.m_model.m_encumbranceChangedEvent:Add(self.m_encumbranceChangedCallback)

	self.m_model.m_spawnedSignal:Add(self.m_spawnedCallback)
	self.m_model.m_diedSignal:Add(self.m_diedCallback)

	self.m_model.m_craftingStartSignal:Add(self.m_craftingStartCallback)
	self.m_model.m_craftingProgressSignal:Add(self.m_craftingProgressCallback)
	self.m_model.m_craftingInterruptSignal:Add(self.m_craftingInterruptCallback)
	self.m_model.m_craftingStopSignal:Add(self.m_craftingStoppedCallback)
end

-------------------------------------------------------------------------------
function SurvivalUIView:DetachFromModel( )

	self.m_model.m_containerAddedSignal:Remove(self.m_containerAddedCallback)
	self.m_model.m_containerRemovedSignal:Remove(self.m_containerRemovedCallback)

	self.m_model.m_hitPointsChangedSignal:Remove(self.m_hitPointsChangedCallback)
	self.m_model.m_staminaChangedEvent:Remove(self.m_staminaChangedCallback)

	self.m_model:GetStat("Energy"):UnsubscribeToValueChangeSignal(self.m_energyChangedCallback)
	self.m_model:GetStat("Energy"):UnsubscribeToMaxChangeSignal(self.m_maxEnergyChangedCallback)

	self.m_model.m_encumbranceChangedEvent:Remove(self.m_encumbranceChangedCallback)

	self.m_model.m_spawnedSignal:Remove(self.m_spawnedCallback)
	self.m_model.m_diedSignal:Remove(self.m_diedCallback)

	self.m_model.m_craftingStartSignal:Remove(self.m_craftingStartCallback)
	self.m_model.m_craftingProgressSignal:Remove(self.m_craftingProgressCallback)
	self.m_model.m_craftingInterruptSignal:Remove(self.m_craftingInterruptCallback)
	self.m_model.m_craftingStopSignal:Remove(self.m_craftingStoppedCallback)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetHealthProgress( )

	self.m_healthBar:setProgress(self.m_model:GetHitPoints()/self.m_model:GetMaxHitPoints())
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetStaminaProgress( )

	self.m_staminaBar:setProgress(self.m_model.m_stamina/self.m_model.MaxStamina)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetEnergyProgress( )

	self.m_energyBar:setProgress(self.m_model:GetStat("Energy"):Value()/self.m_model:GetStat("Energy"):Max())
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetEncumbranceProgress( )

	--self.m_backpackView.m_encumbranceBar:setProgress(self.m_model.m_totalEncumbrance/self.m_model.m_maxEncumbrance)
end

-------------------------------------------------------------------------------
function SurvivalUIView:Spawned()

	self:SetHealthProgress()
	self:SetStaminaProgress()
	self:SetEnergyProgress()
	self:SetEncumbranceProgress()
	self:FadeAlpha(self.m_rootWindow, 0.0, 1.0, 0.5)

	for i, view in pairs(self.m_containerViews) do
		self:FadeAlpha(view.m_rootWindow, 0.0, 1.0, 0.5)
	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:Died()

	self:FadeAlpha(self.m_rootWindow, 1.0, 0.0, 0.5)

	for i, view in pairs(self.m_containerViews) do
		self:FadeAlpha(view.m_rootWindow, 1.0, 0.0, 0.5)
	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:AttachViewToModel( newModel )

	if self.m_containerViews[newModel:GetID()] then
		self.m_containerViews[newModel:GetID()]:AttachToModel(newModel)
	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:DetachViewFromModel( oldModel )

	if self.m_containerViews[oldModel:GetID()] then
		self.m_containerViews[oldModel:GetID()]:DetachFromModel()
		self.m_containerViews[oldModel:GetID()]:Hide()
	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:CraftingStart( itemName )
	self:FadeAlpha(self.m_craftingProgressBar, 0.0, 1.0, 0.5)
	self:SetCraftingProgress(0.0)
	self:SetCraftingText("Crafting ... " .. itemName)
	self.m_craftingProgressBar:activate()
	-- Change the crafting bar to blue, in case the last craft set it to red when it failed
	if self.m_craftingProgressBar:getProperty("ProgressImage") ~= "TUGGame/HealthBarLitBlue" then
		self.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitBlue")
	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetCraftingProgress( value )

	self.m_craftingProgressBar:setProgress(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:CraftingInterrupted( )

	self.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitRed")
end

-------------------------------------------------------------------------------
function SurvivalUIView:CraftingStopped( failed )

	self:SetCraftingProgress(1.0)
	if failed then
		-- Our crafting failed, change the color of the bar to red and indicate a failure
		self.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitRed")
	end
	self:FadeAlpha(self.m_craftingProgressBar, 1.0, 0.0, 0.5)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetCraftingText( value )

	self.m_craftingProgressText:setText(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:ToggleInventory( show )

	if show then
		self.m_playerBackpack:show()

		self.m_containerViews["RecipeView"]:Show()

		if self.m_containerViews["Chest"]:GetModel() then
			self.m_containerViews["Chest"]:Show()
		elseif self.m_containerViews["AdditionalBackpack"]:GetModel() then
			self.m_containerViews["AdditionalBackpack"]:Show()
		end
	else
		self.m_playerBackpack:hide()

		self.m_containerViews["RecipeView"]:Hide()

	end
end

-------------------------------------------------------------------------------
function SurvivalUIView:ToggleChatWindow( show )

	if show then
		self:FadeAlpha(self.m_chatBackground, 0, 1, 0.2)
	else
		self:FadeAlpha(self.m_chatBackground, 1, 0, 0.2)
	end
end
