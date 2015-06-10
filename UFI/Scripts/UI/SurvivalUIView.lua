include("Scripts/Core/Common.lua")
include("Scripts/UI/View.lua")
include("Scripts/UI/EquipmentView.lua")
include("Scripts/UI/ItemContainerView.lua")
include("Scripts/RecipeView.lua")

-------------------------------------------------------------------------------
if SurvivalUIView == nil then
	SurvivalUIView = View.Subclass("SurvivalUIView")
end

-------------------------------------------------------------------------------
-- Player and inventory will be the same, need to remove one. --I need to load my view here. UFIOES--
function SurvivalUIView:PostLoad( layout, survival, player )

	self.m_survival = survival
	self.m_player = player

	self.m_player.m_containerAddedSignal:Add(function(container)
		self:AttachViewToModel(container)
	end)

	self.m_player.m_containerRemovedSignal:Add(function(container)
		self:DetachViewFromModel(container)
	end)

	self.m_healthBar = self:GetChild("HealthBar")
	self.m_healthText = self:GetChild("HealthText", self.m_healthBar)
	self.m_healthBar = CEGUI.toProgressBar(self.m_healthBar)
	self:SetHealthProgress(self.m_player.m_health/self.m_player.MaxHealth)

	self.m_staminaBar = self:GetChild("StaminaBar")
	self.m_staminaText = self:GetChild("StaminaText", self.m_staminaBar)
	self.m_staminaBar = CEGUI.toProgressBar(self.m_staminaBar)
	self:SetStaminaProgress(self.m_player.m_stamina/self.m_player.MaxStamina)

	self.m_energyBar = self:GetChild("EnergyBar")
	self.m_energyText = self:GetChild("EnergyText", self.m_energyBar)
	self.m_energyBar = CEGUI.toProgressBar(self.m_energyBar)
	self:SetEnergyProgress(self.m_player:GetStat("Energy"):Value()/self.m_player:GetStat("Energy"):Max())

	self.m_craftingProgressBar = self:GetChild("CraftingBar")
	self.m_craftingProgressText = self:GetChild("CraftingText", self.m_craftingProgressBar)
	self.m_craftingProgressBar = CEGUI.toProgressBar(self.m_craftingProgressBar)

	self.m_backpackContainer = self:GetChild("Backpack")
	self.m_handContainer = self:GetChild("Handslot")
	self.m_beltContainer = self:GetChild("Beltbar")
	self.m_equipmentContainer = self:GetChild("Equipment")
	self.m_chestContainer = self:GetChild("Chest")
	self.m_additionalBackpack = self:GetChild("AdditionalBackpack")

	self.recipeView = self:GetChild("RecipeView")

	self.m_containerViews = { }

	self.m_containerViews["HandSlot"] = ItemContainerView.new(self.m_handContainer, self.m_player, self.m_player.m_inventoryContainers[1])
	self.m_containerViews["BeltBar"] = ItemContainerView.new(self.m_beltContainer, self.m_player, self.m_player.m_inventoryContainers[2])
	self.m_containerViews["Backpack"] = ItemContainerView.new(self.m_backpackContainer, self.m_player, self.m_player.m_inventoryContainers[3])
	self.m_containerViews["Equipment"] = EquipmentView.new(self.m_equipmentContainer, self.m_player, self.m_player.m_inventoryContainers[4])
	self.m_containerViews["Chest"] = ItemContainerView.new(self.m_chestContainer, self.m_player)
	self.m_containerViews["AdditionalBackpack"] = ItemContainerView.new(self.m_additionalBackpack, self.m_player)

	self.m_containerViews["RecipeView"] = RecipeView.new(self.recipeView, self.m_player)

end

-------------------------------------------------------------------------------
function SurvivalUIView:SetHealthProgress( value )

	self.m_healthBar:setProgress(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetStaminaProgress( value )

	self.m_staminaBar:setProgress(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetEnergyProgress( value )

	self.m_energyBar:setProgress(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetEncumbranceProgress( value )

	--self.m_backpackView.m_encumbranceBar:setProgress(value)
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
function SurvivalUIView:SetCraftingProgress( value )

	self.m_craftingProgressBar:setProgress(value)
end

-------------------------------------------------------------------------------
function SurvivalUIView:SetCraftingText( value )

	self.m_craftingProgressText:setText(value)
end
