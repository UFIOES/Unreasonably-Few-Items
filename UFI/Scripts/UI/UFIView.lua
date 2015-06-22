include("Scripts/UI/View.lua")
include("Scripts/UI/EquipmentView.lua")
include("Scripts/UI/ItemContainerView.lua")
include("Scripts/RecipeView.lua")

-------------------------------------------------------------------------------
if UFIView == nil then
	UFIView = View.Subclass("UFIView")
end

-------------------------------------------------------------------------------
-- Player and inventory will be the same, need to remove one.
function UFIView:Constructor( layout, model )
	self.m_player = model
	
	self.recipeView = self:GetChild("RecipeView")
	self.recipeView:setVisible(false)
	self.m_recipeView = RecipeView.new(self.recipeView, self.m_player)
end

-------------------------------------------------------------------------------
function UFIView:ToggleInventory(show)
	self.recipeView:setVisible(show)
end