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
function UFIView:Constructor(layout, model)

	self.showing = false

	self.m_player = model

	self.recipeView = self:GetChild("RecipeView")
	self.recipeView:setVisible(false)
	self.m_recipeView = RecipeView.new(self.recipeView, self.m_player)
end

-------------------------------------------------------------------------------
function UFIView:ShowInterface(down)

	if down then

		self.recipeView:setVisible(true)

		self.m_recipeView:setVisible(true)

	end

end
