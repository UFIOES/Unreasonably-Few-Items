include("Scripts/UI/View.lua")
include("Scripts/UI/EquipmentView.lua")
include("Scripts/UI/ItemContainerView.lua")

-------------------------------------------------------------------------------
if TechTreeView == nil then
	TechTreeView = View.Subclass("TechTreeView")
end


-------------------------------------------------------------------------------
-- Player and inventory will be the same, need to remove one.
function TechTreeView:Constructor(group)



end
