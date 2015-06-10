include("Scripts/Characters/BasePlayer.lua")
include("Scripts/Core/NKUtils.lua")
include("Scripts/UI/SurvivalUIView.lua")
include("Scripts/Core/SurvivalInventoryManager.lua")
include("Scripts/Mixins/ClientCraftingMixin.lua")
include("Scripts/Mixins/SurvivalPlacementInput.lua")
include("Scripts/Mixins/ChatCommandsInput.lua")
include("Scripts/Core/NKTerrain.lua")

LocalPlayer = BasePlayer.Subclass("LocalPlayer")

--[[										]]--
--[[	 Static variables (do not tweak!)	]]--
--[[										]]--
-- Camera mode enumeration
LocalPlayer.ECameraMode 			=
{
	First 	= 0,
	Third 	= 1,
	Free  	= 2
}

-- Visibility override mode enumeration
LocalPlayer.EVisibilitySettings		=
{
	Hands 	= 0,
	Body 	= 1,
	All		= 2
}

NKRegisterEvent("ServerEvent_RequestCrafting",
	{
		at = "vec3",
	}
)

NKRegisterEvent("ClientEvent_ToggleInventory",
	{
		down = "bool"
	}
)

-- Gameobject to use when in first-person mode.
LocalPlayer.FirstPersonObjectName						= "Player Hand"
LocalPlayer.EquippedItemRendersLast						= false -- We start in first person.

-- The vertical axis amount the camera sinks by when crouching.
LocalPlayer.CrouchingCameraHeightModifier 				= -1.6

-- Visibility settings
LocalPlayer.m_baseVisibilitySettings 					= {}
LocalPlayer.m_baseVisibilitySettings.m_hands			= false
LocalPlayer.m_baseVisibilitySettings.m_body				= false
LocalPlayer.m_overrideVisibilitySettings 				= {}
LocalPlayer.m_overrideVisibilitySettings.m_hands		= false
LocalPlayer.m_overrideVisibilitySettings.m_body			= false
LocalPlayer.m_overrideVisibilitySettings.m_handsActive	= false
LocalPlayer.m_overrideVisibilitySettings.m_bodyActive	= false

-- Speed Constants
LocalPlayer.NormalMoveSpeed 		= 5.5 	-- Walk speed of the player
LocalPlayer.SprintMoveSpeed			= 11.0 	-- Sprint speed of the player
LocalPlayer.SneakMoveSpeed			= 2.75	-- Sneak speed of the player
LocalPlayer.SneakFastMoveSpeed		= 4.675	-- Sneak fast speed of the player
LocalPlayer.FlyMoveSpeed			= 13.0	-- Flying and Wisp speed


function LocalPlayer:Constructor( args )
	self.m_doubleTapTimer = 0.0

	self.m_minimumFall 				= 10.0
	self.m_maximumFall 				= 30.0
	self.m_fallthreshold 			= -15.0
	self.m_isFalling 				= false
	self.m_cameraControl			= true
	self.m_jumpCooldown				= 0.0

	self.m_primaryActionEnabled		= true
	self.m_secondaryActionEnabled 	= true

	self.m_primaryActionEngaged		= false
	self.m_secondaryActionEngaged 	= false

	self.m_isHoldingCrouch			= false
	self.m_isRunning 				= false
	self.m_runPreventFlag			= false

	self.m_prevHitObj 				= nil

	-- The unmodified camera height, disregarding any crouching modifiers
	self.m_baseCameraHeight			= self.GrowthState.Child.CameraOffset -- Default to child height and we'll update it later after loading our experience value
	self.m_cameraHeight 			= self.m_baseCameraHeight

	self:Mixin(ClientCraftingMixin, args)
	self:Mixin(SurvivalPlacementInput, args)
	self:Mixin(ChatCommandsInput, args)
end


function LocalPlayer:PostLoad()
	-- Create the hands
	local hands = Eternus.GameObjectSystem:NKCreateGameObject(self.FirstPersonObjectName, true)
	if hands then
		self.m_fpsHands = hands:NKGetInstance()
	end

	-- Call super postload after hand creation because the super also triggers the morph target changes
	LocalPlayer.__super.PostLoad(self)

	self:SetCameraMode(LocalPlayer.ECameraMode.First)

	self.m_diedSignal:Add(function()
		self:DropEverything()
	end)
end

function LocalPlayer:Spawn()
	-- Call the super class function.
	LocalPlayer.__super.Spawn(self)
	if self.m_fpsHands then
		self.m_fpsHands.object:NKPlaceInWorld(false, true)
	end

	-- Grab the keybind mappings that the world is using and register commands
	local keybinds = Eternus.World:NKGetKeybinds()
	keybinds:NKRegisterNamedCommand("Move Forward"			, self, "MoveForward"	, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Move Backward"			, self, "MoveBackward"	, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Strafe Left"			, self, "StrafeLeft"	, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Strafe Right"			, self, "StrafeRight"	, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Jump"					, self, "Jump"			, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Crouch"				, self, "Crouch"		, KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Craft"					, self, "BeginCraft"	, KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Pick Up/Use"			, self, "PrimaryAction", 0.67)
	keybinds:NKRegisterNamedCommand("Place/Interact"		, self, "SecondaryAction", 1.0)
	keybinds:NKRegisterNamedCommand("Inventory"				, self, "ToggleInventory", 1.0)
	keybinds:NKRegisterNamedCommand("Select Terrain Tool"	, self, "SwapHandSlot1",  0.67)
	keybinds:NKRegisterNamedCommand("Select Selection Tool"	, self, "SwapHandSlot2",  0.67)
	keybinds:NKRegisterNamedCommand("Select Move Tool"		, self, "SwapHandSlot3",  0.67)
	keybinds:NKRegisterNamedCommand("Select Rotate Tool"	, self, "SwapHandSlot4",  0.67)
	keybinds:NKRegisterNamedCommand("Put Away Hand Item"	, self, "PutAwayHandItem",  0.67)
	keybinds:NKRegisterNamedCommand("Select Next Block Size", self, "SelectNextBlockBrush", KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Select Prev Block Size", self, "SelectPrevBlockBrush", KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Toggle Stance"			, self, "ToggleHoldStance", KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Toggle UI"				, self, "ToggleUI", KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Show Players"			, self, "ShowPlayers", KEY_FLOOD)
	keybinds:NKRegisterNamedCommand("Toggle Camera Mode"	, self, "ToggleCameraMode", KEY_ONCE)
	keybinds:NKRegisterNamedCommand("Return to Menu"		, self, "GoToMenu", KEY_ONCE)

	self.m_inventoryContext = InputMappingContext.new("Inventory")
	self.m_inventoryContext:NKRegisterNamedCommand("Inventory", self, "ToggleInventory", KEY_ONCE)
	self.m_inventoryContext:NKRegisterNamedCommand("Return to Menu", self, "ToggleInventory", KEY_ONCE)

	self.m_spawnedSignal:Fire()
end

-------------------------------------------------------------------------------
function LocalPlayer:SetupUI()

	-- This UI is for the Survival Local Player
	self.m_survivalUI = SurvivalUIView.new("SurvivalLayoutUFI.layout", self, self)
	self.m_survivalUI.m_containerViews["Backpack"]:Hide()
	self.m_survivalUI.m_containerViews["Equipment"]:Hide()
	self.m_survivalUI.m_containerViews["Chest"]:Hide()
	self.m_survivalUI.m_containerViews["AdditionalBackpack"]:Hide()

	self.m_survivalUI.m_containerViews["RecipeView"]:Hide()

	self.m_healthChangedEvent:Add(function()
		self.m_survivalUI:SetHealthProgress(self.m_health/self.MaxHealth)
	end)
	self.m_staminaChangedEvent:Add(function()
		self.m_survivalUI:SetStaminaProgress(self.m_stamina/self.MaxStamina)
	end)

	local playerEnergy = self:GetStat("Energy")
	playerEnergy:SubscribeToValueChangeSignal(function(old, new)
		self.m_survivalUI:SetEnergyProgress(playerEnergy:Value()/playerEnergy:Max())
	end)

	playerEnergy:SubscribeToMaxChangeSignal(function(old, new)
		self.m_survivalUI:SetEnergyProgress(playerEnergy:Value()/playerEnergy:Max())
	end)

	self.m_spawnedSignal:Add(function()
		self.m_survivalUI:SetHealthProgress(self.m_health/self.MaxHealth)
		self.m_survivalUI:SetStaminaProgress(self.m_stamina/self.MaxStamina)
		self.m_survivalUI:SetEnergyProgress(self.m_energy:Value()/self.m_energy:Max())
		self.m_survivalUI:SetEncumbranceProgress(self.m_encumbrance/self.MaxEncumbrance)
		self.m_survivalUI:FadeAlpha(self.m_survivalUI.m_rootWindow, 0.0, 1.0, 0.5)
		self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_crosshair, 0.0, 1.0, 0.5)

		for i, view in pairs(self.m_survivalUI.m_containerViews) do
			self.m_survivalUI:FadeAlpha(view.m_rootWindow, 0.0, 1.0, 0.5)
		end
	end)

	self.m_diedSignal:Add(function()
		self.m_survivalUI:FadeAlpha(self.m_survivalUI.m_rootWindow, 1.0, 0.0, 0.5)
		self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_crosshair, 1.0, 0.0, 0.5)

		for i, view in pairs(self.m_survivalUI.m_containerViews) do
			self.m_survivalUI:FadeAlpha(view.m_rootWindow, 1.0, 0.0, 0.5)
		end

	end)

	self.m_encumbranceChangedEvent:Add(function()
		self.m_survivalUI:SetEncumbranceProgress(self.m_totalEncumbrance/self.m_maxEncumbrance)
	end)

	self.m_craftingStartSignal:Add(function(itemName)
		self.m_survivalUI:FadeAlpha(self.m_survivalUI.m_craftingProgressBar, 0.0, 1.0, 0.5)
		self.m_survivalUI:SetCraftingProgress(0.0)
		self.m_survivalUI:SetCraftingText("Crafting ... " .. itemName)
		self.m_survivalUI.m_craftingProgressBar:activate()
		-- Change the crafting bar to blue, in case the last craft set it to red when it failed
		if self.m_survivalUI.m_craftingProgressBar:getProperty("ProgressImage") ~= "TUGGame/HealthBarLitBlue" then
			self.m_survivalUI.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitBlue")
		end
	end)

	self.m_craftingProgressSignal:Add(function(value)
		self.m_survivalUI:SetCraftingProgress(value)
	end)

	self.m_craftingInterruptSignal:Add(function()
		self.m_survivalUI.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitRed")
	end)

	self.m_craftingStopSignal:Add(function(failed)
		self.m_survivalUI:SetCraftingProgress(1.0)
		if failed then
			-- Our crafting failed, change the color of the bar to red and indicate a failure
			self.m_survivalUI.m_craftingProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitRed")
		end
		self.m_survivalUI:FadeAlpha(self.m_survivalUI.m_craftingProgressBar, 1.0, 0.0, 0.5)
	end)

	-- This UI is for the Base Local Player
	self.m_gameModeUI = TUGGameModeUIView.new("TUGGameModeLayout.layout")
	self.m_gameModeUI:RegisterScoreboard(gScoreboard)

	self.m_targetAcquiredSignal:Add(function(hitObj)

		if hitObj and hitObj:NKGetInstance() then

			if self.m_gameModeUI.m_targetProgressBar:getProperty("ProgressImage") ~= "TUGGame/HealthBarLitGreen" then
				self.m_gameModeUI.m_targetProgressBar:setProperty("ProgressImage", "TUGGame/HealthBarLitGreen")
			end

			self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_targetProgressBar, 0.0, 1.0, 0.5)

			local stackCount = nil

			if hitObj:NKGetInstance().GetMaxStackSize then
				stackCount = hitObj:NKGetInstance():GetMaxStackSize()
			end

			if stackCount and stackCount > 1 then
				self.m_gameModeUI:SetTargetText(hitObj:NKGetInstance():GetDisplayName() .. " x " .. tostring(hitObj:NKGetInstance():GetStackSize()))
			else
				self.m_gameModeUI:SetTargetText(hitObj:NKGetInstance():GetDisplayName())
			end
		end
	end)

	self.m_targetLostSignal:Add(function()

		self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_targetProgressBar, 1.0, 0.0, 0.5)
	end)

	self.m_targetHealthChangedSignal:Add(function(hitObj)

		if hitObj and hitObj:NKGetInstance() then
			-- Safety Check if the object exists
			if hitObj:NKGetInstance():InstanceOf(HasHitPoints) then
					-- If it has HitPoints
					self.m_gameModeUI:SetTargetProgress(hitObj:NKGetInstance():GetHitPoints()/hitObj:NKGetInstance():GetMaxHitPoints())
			elseif hitObj:NKGetInstance():InstanceOf(BasePlayer) then
				-- If it is a Player
				self.m_gameModeUI:SetTargetProgress(hitObj:NKGetInstance().m_health/hitObj:NKGetInstance().MaxHealth)
			else
				self.m_gameModeUI:SetTargetProgress(1.0)
			end
		end
	end)

	EternusEngine.UI.Layers.Gameplay:show()
	EternusEngine.UI.Layers.Gameplay:activate()
end

-------------------------------------------------------------------------------
function LocalPlayer:ToggleUI( down )

	if not down then
		return
	end

	-- Hide all UI when toggled
	-- Gets the current state of the mouse so it can restore it when you show the UI again
	if EternusEngine.UI.Layers.Gameplay:isVisible() then
		EternusEngine.UI.Layers.Gameplay:hide()
		NKPrint("Checking IsMouseHidden : " .. tostring(Eternus.InputSystem:NKIsMouseHidden()) .. "\n")
		if Eternus.InputSystem:NKIsMouseHidden() then
			Eternus.InputSystem:NKHideMouse()
			self.m_restoreMouse = false
		else
			self.m_restoreMouse = true
		end
	else
		EternusEngine.UI.Layers.Gameplay:show()
		if self.m_restoreMouse then
			Eternus.InputSystem:NKShowMouse()
		end
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:ShowPlayers( down )

	if not down then
		-- Turn off the players window
		self.m_gameModeUI.m_playersWindow:setVisible(false)
		self.m_gameModeUI.m_crosshair:setVisible(true)
		return
	end

	-- Turn on the players Window
	if not self.m_gameModeUI.m_playersWindow:isVisible() then
		self.m_gameModeUI.m_playersWindow:setVisible(true)
		self.m_gameModeUI.m_playersWindow:activate()
		self.m_gameModeUI.m_crosshair:setVisible(false)
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:ToggleCameraMode( down )
	-- Wait for keyup
	if down then
		return
	end

	if self:HasDied() then
		return
	end

	-- Swap the m_activeCamera
	if Eternus.GameState.m_activeCamera ~= Eternus.GameState.m_fpcamera then
		Eternus.GameState.m_activeCamera = Eternus.GameState.m_fpcamera
		self:SetCameraMode(LocalPlayer.ECameraMode.First)
	else
		Eternus.GameState.m_activeCamera = Eternus.GameState.m_tpcamera
		self:SetCameraMode(LocalPlayer.ECameraMode.Third)
	end

	-- Inform the backing TUGGameMode
	NKSetActiveCamera(Eternus.GameState.m_activeCamera)
end

-------------------------------------------------------------------------------
function LocalPlayer:GoToMenu( down )
	if down then
		return
	end

	NKSwitchGameStateToMenu()
end

-------------------------------------------------------------------------------
function LocalPlayer:SelectNextBlockBrush(down)

	if not down then
		return
	end

	self.CurrentBlockBrushIdx = self.CurrentBlockBrushIdx - 1;
	if self.CurrentBlockBrushIdx < 1 then
		self.CurrentBlockBrushIdx = #self.BlockBrush;
	end

	self.CurrentBlockBrush = self.BlockBrush[self.CurrentBlockBrushIdx];

	self:RaiseServerEvent("ServerEvent_SetBlockBrush", {brushIdx = self.CurrentBlockBrushIdx})

end

-------------------------------------------------------------------------------
function LocalPlayer:SelectPrevBlockBrush(down)

	if not down then
		return
	end

	self.CurrentBlockBrushIdx = self.CurrentBlockBrushIdx + 1;
	if self.CurrentBlockBrushIdx > #self.BlockBrush then
		self.CurrentBlockBrushIdx = 1;
	end

	self.CurrentBlockBrush = self.BlockBrush[self.CurrentBlockBrushIdx];

	self:RaiseServerEvent("ServerEvent_SetBlockBrush", {brushIdx = self.CurrentBlockBrushIdx})

end

-------------------------------------------------------------------------------
function LocalPlayer:OnContactCreated(data)
	if self.m_isFalling then
		self.m_isFalling = false

		local diff = data.thisBody.position - self.m_initialFallLoc
		local distance = diff:NKLength()
		self.m_initialFallLoc = data.thisBody.position

		--NKPrint("In-Air Distance: " .. tostring(distance) .. "\n")
		self.m_triggerHurtEffects = true
		if distance > self.m_minimumFall then

			local falldamage = ((distance - self.m_minimumFall) / self.m_maximumFall) * self.MaxHealth
			--self:RaiseServerEvent("ServerEvent_TakeDamage", { damage = falldamage })
			--NKPrint("Damage: " .. tostring(falldamage) .. "\n")
		end
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:Update( dt )
	if self:NKGetCharacterController():NKGetState() == CharacterController.eInAirState and self:NKGetCharacterController():NKGetLinearVelocity():y() <= self.m_fallthreshold then
		if not self.m_isFalling then
			self.m_initialFallLoc = self:NKGetPosition()
			--NKPrint("Going to take fall damage!\n")
		end
		self.m_isFalling = true
	else
		self.m_isFalling = false
	end


	-- Sync the players transform with the physics capsule.
	self:NKGetCharacterController():Step(dt)

	local cc = self:NKGetCharacterController()
	self.m_speed = cc:NKGetLinearVelocity():NKLength()
	self.m_moveDir = self:GetMovementDirection()
	self.m_onGround = cc:NKGetState() == CharacterController.eOnGroundState

	self:_UpdateState()

	LocalPlayer.__super.Update(self, dt)

	self.m_doubleTapTimer = self.m_doubleTapTimer + dt

	if self.m_jumpCooldown > 0.0 then
		self.m_jumpCooldown = self.m_jumpCooldown - dt
	end

	self:UpdateMovementSpeed()
	self:UpdateHands()
	self:UpdateHitObject()

end

-------------------------------------------------------------------------------
-- Called once a frame to update the players internal state variable (self.m_state).
function LocalPlayer:_UpdateState()

	local prevState = self.m_state
	local prevJumping = self.m_jumping

	-- Are we crouching?
	local isCrouching = self:IsCrouching()

	-- Are we moving?
	local isMoving = self:NKGetCharacterController():NKIsMoving()

	-- Are we on the ground?
	local onGround = self:NKGetCharacterController():NKOnGround()

	-- Update the state.
	if self:IsFlying() then
		self.m_state = BasePlayer.EState.eFlying
	elseif isMoving and onGround then
		-- Get the run key status (why is this by exact keycode and not a rebindable action?).
		local shiftHeld = Eternus.InputSystem:NKIsDown(VK_SHIFT)

		-- Are we trying to run?
		local isRunning = (not self.m_runPreventFlag) and self.m_stamina > 0.0 and shiftHeld

		if isCrouching and isRunning then
			self.m_state = BasePlayer.EState.eSneakRun
		elseif isCrouching then
			self.m_state = BasePlayer.EState.eSneak
		elseif isRunning then
			self.m_state = BasePlayer.EState.eRunning
		else
			self.m_state = BasePlayer.EState.eWalking
		end
	elseif not isMoving then
		if isCrouching then
			self.m_state = BasePlayer.EState.eCrouch
		else
			self.m_state = BasePlayer.EState.eIdle
		end
	end

	if self:NKGetCharacterController():NKGetJumpFlag() then
		self:SetJumpFlag(true)
	elseif self.m_jumping and onGround then
		self:SetJumpFlag(false)
	end
end

-------------------------------------------------------------------------------
-- Called once a frame to update the first person hands position and orientation.
function LocalPlayer:UpdateHands()
	-- Don;'t bother unless we are in first person- the only state when hands are visible.
	if self.m_camMode ~= LocalPlayer.ECameraMode.First or not self.m_fpsHands then
		return
	end

	-- Update the hand's position based on the active camera.
	self.m_fpsHands.object:NKSetPosition(Eternus.GameState.m_activeCamera:NKGetLocation(true) + vec3.new(0.0, 0.0, 0.0), false)

	-- Update the hand's orientation.
	self.m_fpsHands.object:NKSetOrientation(Eternus.GameState.m_activeCamera:NKGetOrientation())
end

-------------------------------------------------------------------------------
function LocalPlayer:UpdateHitObject()
	local eyePosition = self:NKGetPosition() + vec3.new(0.0, self.m_cameraHeight, 0.0)
	local lookDirection = Eternus.GameState.m_activeCamera:ForwardVector()
	local rayTraceHit = NKPhysics.RayCastCollect(eyePosition, lookDirection, self:GetMaxReachDistance(), {self, self.m_equippedItem})
	local hitObj = nil

	if rayTraceHit then
		hitObj = rayTraceHit.gameobject
	end

	if hitObj then
		-- If we hit something,
		if self.m_prevHitObj == nil then
			-- If our previous hit object was nil, fire m_targetAcquiredEvent
			self.m_targetAcquiredSignal:Fire(hitObj)
			-- Fire a m_targetHealthChangedSignal
			self.m_targetHealthChangedSignal:Fire(hitObj)
		else
			if self.m_prevHitObj ~= hitObj then
				-- If our previous hit object was not the same as our current hit object, fire m_targetAcquiredEvent
				self.m_targetAcquiredSignal:Fire(hitObj)

				-- Disable the highlighting of the previous object
				if self.m_prevHitObj:NKGetInstance() then
					self.m_prevHitObj:NKGetInstance():SetHighlightedRender(false)
				end
			end
		end
		-- Fire a m_targetHealthChangedSignal
		self.m_targetHealthChangedSignal:Fire(hitObj)

		-- Always enable highlighting of whatever object was hit
		if hitObj:NKGetInstance() then
			hitObj:NKGetInstance():SetHighlightedRender(true)
		end
	else
		-- If we hit nothing,
		if self.m_prevHitObj then
			-- If our previous hit object was not nil
			-- Set our previous hit object to nil, fire m_targetLostSignal
			self.m_targetLostSignal:Fire()

			-- Disable the highlighting of whatever object was being targeted
			if self.m_prevHitObj:NKGetInstance() then
				self.m_prevHitObj:NKGetInstance():SetHighlightedRender(false)
			end
		end

		if rayTraceHit then
			local handObj = self.m_equippedItem

			if handObj then
				local handObjInstance = handObj:NKGetInstance()
				if handObjInstance then
					if handObjInstance.m_showVoxelSelectionBox then
						--EternusEngine.Debugging.Breakpoint()
						NKTerrain:RenderVoxelSelectionBox(rayTraceHit.contact, rayTraceHit.normal, Eternus.GameState.m_activeCamera:NKGetLocation(), self.CurrentBlockBrush, handObjInstance:GetModificationType())
					end
				end
			end
		end
	end

	-- Assign our previous hit object to the object we traced this frame
	self.m_prevHitObj = hitObj
end

-------------------------------------------------------------------------------
function LocalPlayer:GetActiveModel()
	if self.m_fpsHands and self.m_camMode == LocalPlayer.ECameraMode.First then
		return self.m_fpsHands.object
	elseif self.m_3pobject then
		return self.m_3pobject.object
	else
		return self.object
	end
end

-------------------------------------------------------------------------------
-- Returns true if this character is currently in a state where he should play a step sound.
-- Overridden from BasePlayer.
function LocalPlayer:ShouldPlayStepSounds()
	local cc = self:NKGetCharacterController()
	return self.m_camMode ~= LocalPlayer.ECameraMode.Free and cc:NKIsMoving() and cc:NKOnGround() and LocalPlayer.__super.ShouldPlayStepSounds(self)
end

-------------------------------------------------------------------------------
-- Provides different step sounds based on the aterial underfoot. This is currently done only for LocalPlayers.
-- Overridden from BasePlayer.
function LocalPlayer:GetCurrentStepSound()

	--check the voxel below us
	local input =
	{
		traceType = 1,
		distance = 5.0,
		position = self:NKGetWorldPosition() + vec3.new(0.0,1.0,0.0),
	 	direction = vec3.new(0.0, -1.0, 0.0),
	 	targetType = EternusEngine.EPhysicsTraceType.eVoxel,
	}

	local gps = Eternus.PhysicsWorld:NKGetPlayerGPS()
	if not gps then
		NKError("Physics has no player GPS!")
		return
	end

	local matId = gps:NKGetMaterialUnderPlayer()
	local matObj = Eternus.GameObjectSystem:NKGetPlaceableMaterialByID(matId)
	if matObj then
		local p = matObj:NKGetPlaceableMaterial()
		if p and p:NKGetStepSound() ~= "" then
			return p:NKGetStepSound()
		end
	end

	return self.DefaultStepSound
end

-------------------------------------------------------------------------------
-- Called once a frame to update the players current movement speed.
function LocalPlayer:UpdateMovementSpeed()
	-- Are we crouching?
	local isCrouching = self:IsCrouching()

	-- Get the run key status (why is this by exact keycode and not a rebindable action?).
	local shiftHeld = Eternus.InputSystem:NKIsDown(VK_SHIFT)

	-- Are we trying to run?
	self.m_isRunning = (not self.m_runPreventFlag) and self.m_stamina > 0.0 and shiftHeld

	-- Update the speed.
	local speed = LocalPlayer.NormalMoveSpeed
	if self:IsDead() then
		speed = LocalPlayer.FlyMoveSpeed
	elseif isCrouching and self.m_isRunning then
		speed = LocalPlayer.SneakFastMoveSpeed
	elseif isCrouching then
		speed = LocalPlayer.SneakMoveSpeed
	elseif self.m_isRunning then
		speed = LocalPlayer.SprintMoveSpeed
	elseif self:IsFlying() then
		speed = LocalPlayer.FlyMoveSpeed
	end

	--speed = speed * self.m_speedMultiplier
	local mul = 1.0
	local statMul = self:GetStat("SpeedMultiplier")
	if statMul then
		mul = statMul:Value()
	end
	speed = speed * mul

	-- Force the run key to be released for at least a frame after stamina bottoms out.
	if not shiftHeld then
		self.m_runPreventFlag = false
	end

	-- Add in any runspeed modifiers.
	local speedMod = 1.0
	--if self.m_equippedItem and self.m_equippedItem:NKGetEquipable() ~= nil then
		--speedMod = self.m_equippedItem:NKGetEquipable():NKGetMoveSpeedModifier()
	--end

	-- Actually set the move speed.
	self:NKGetCharacterController():NKSetMaxSpeed(speed * speedMod)
end

function LocalPlayer:IsRunning()
	return self.m_isRunning
end

function LocalPlayer:MoveForward(down)
	if down then
		if not self.m_dying and not self.m_movementLocked then
			self:NKGetCharacterController():MoveForward()
			--Eternus.GameState:InterruptCrafting()
		end
	end
end

function LocalPlayer:MoveBackward(down)
	if down then
		if not self.m_dying and not self.m_movementLocked then
			self:NKGetCharacterController():MoveBackward()
			--Eternus.GameState:InterruptCrafting()
		end
	end
end

function LocalPlayer:StrafeLeft(down)
	if down then
		if not self.m_dying and not self.m_movementLocked then
			self:NKGetCharacterController():MoveLeft()
			--Eternus.GameState:InterruptCrafting()
		end
	end
end

function LocalPlayer:StrafeRight(down)
	if down then
		if not self.m_dying and not self.m_movementLocked then
			self:NKGetCharacterController():MoveRight()
			--Eternus.GameState:InterruptCrafting()
		end
	end
end

function LocalPlayer:Jump(down)
	if down then
		if self.m_dying or self.m_movementLocked then
			return
		end

		if self:IsCrouching() then
			self:SetCrouching(false)
		end

		local doubleTap = (self.m_doubleTapTimer < 0.30)

		if not self.m_jumpHeld then
			self.m_doubleTapTimer = 0.0
			self.m_jumpHeld = true
		else
			--jump is already held
			doubleTap = false --Never double tap if we got here from a repeat.
		end

		if EternusEngine.Debugging.Enabled then
			if self:IsFlying() then
				if doubleTap then
					self:SetFlying(false)
				else
					self:NKGetCharacterController():MoveUp()
				end
			else
				if doubleTap then
					self:SetFlying(true)
				elseif not self.m_dying and self.m_jumpCooldown <= 0.0 then
					self:NKGetCharacterController():Jump()
					self.m_jumpCooldown = 0.1
				end
			end
		else
			if self:IsFlying() then
				self:NKGetCharacterController():MoveUp()
			else
				if not self.m_dying and self.m_jumpCooldown <= 0.0 then
					self:NKGetCharacterController():Jump()
					self.m_jumpCooldown = 0.1
				end
			end
		end

	else
		self.m_jumpHeld = false
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:Crouch(down)
	if down then
		if self:IsFlying() then
			self:NKGetCharacterController():MoveDown()
		elseif not self.m_isHoldingCrouch then
			if not self:IsCrouching() then
				self:SetCrouching(true)
			else
				self:SetCrouching(false)
			end
		end
		self.m_isHoldingCrouch = true
	else
		self.m_isHoldingCrouch = false
	end
end

function LocalPlayer:SetCrouching(to)
	self.__super.SetCrouching(self, to)

	if to then
		self.m_cameraHeight = self.m_baseCameraHeight + self.CrouchingCameraHeightModifier
	else
		self.m_cameraHeight = self.m_baseCameraHeight
	end
end
-- Visibility control.

-------------------------------------------------------------------------------
-- Sets visibility settings for the hands and body based on the given cam mode.
-- Automatically updates those objects ShouldRender flags.
function LocalPlayer:SetVisibilityForCamMode( camMode )
	if camMode == LocalPlayer.ECameraMode.First then
		self.m_baseVisibilitySettings.m_hands = true
		self.m_baseVisibilitySettings.m_body = false

	elseif camMode == LocalPlayer.ECameraMode.Third then
		self.m_baseVisibilitySettings.m_hands = false
		self.m_baseVisibilitySettings.m_body = true

	elseif camMode == LocalPlayer.ECameraMode.Free then
		self.m_baseVisibilitySettings.m_hands = false
		self.m_baseVisibilitySettings.m_body = true

	end

	self:UpdateVisibility()
end

-------------------------------------------------------------------------------
-- Sets override settings for hands and/or body visibility
-- Parameters:
-- part - The body part to be affected.  Should be one of LocalPlayer.EVisibilitySettings
-- activationFlag - Whether to turn the override on or off
-- visibilityFlag - Whether the model should render or not when the override is set.
function LocalPlayer:SetVisibilityOverride( part, activationFlag, visibilityFlag )
	if part == LocalPlayer.EVisibilitySettings.Hands then
		self.m_overrideVisibilitySettings.m_handsActive = activationFlag
		self.m_overrideVisibilitySettings.m_hands = visibilityFlag

	elseif part == LocalPlayer.EVisibilitySettings.Body then
		self.m_overrideVisibilitySettings.m_bodyActive = activationFlag
		self.m_overrideVisibilitySettings.m_body = visibilityFlag

	elseif part == LocalPlayer.EvisibilitySettings.All then
		self.m_overrideVisibilitySettings.m_handsActive = activationFlag
		self.m_overrideVisibilitySettings.m_hands = visibilityFlag

		self.m_overrideVisibilitySettings.m_bodyActive = activationFlag
		self.m_overrideVisibilitySettings.m_body = visibilityFlag

	end

	self:UpdateVisibility()
end

-------------------------------------------------------------------------------
-- Updates the visibility of the body and hands objects based on current
-- visibility settings.
function LocalPlayer:UpdateVisibility()
	local handsOR = self.m_overrideVisibilitySettings.m_handsActive
	local baseHands = self.m_baseVisibilitySettings.m_hands
	local overHands = self.m_overrideVisibilitySettings.m_hands
	local handsVisibility = (not handsOR and baseHands) or (handsOR and overHands)

	local bodyOR = self.m_overrideVisibilitySettings.m_bodyActive
	local baseBody = self.m_baseVisibilitySettings.m_body
	local overBody = self.m_overrideVisibilitySettings.m_body
	local bodyVisibility = (not bodyOR and baseBody) or (bodyOR and overBody)


	if self.m_fpsHands then
		self.m_fpsHands:NKSetShouldRender(handsVisibility, true)
	end

	if self.m_3pobject then
		self.m_3pobject:NKSetShouldRender(bodyVisibility, true)
	end
end

-------------------------------------------------------------------------------
-- Set the camera mode used by the player.
function LocalPlayer:SetCameraMode(mode)
	-- Save the current cam mode.
	self.m_camMode = mode

	-- In first person we show the hands and hide the seed. In third the opposite.
	if mode == LocalPlayer.ECameraMode.First and self.m_fpsHands then
		self.EquippedItemRendersLast = true
		if self:NKGetCharacterController() then
			self:NKGetCharacterController():NKSetAlignWithCamera(true)
		end
		if self.m_equippedItem then
			self.m_equippedItem:NKGetGraphics():NKSetShouldRenderLast(true)
			self.m_fpsHands:NKAddChildObject(self.m_equippedItem)
		end
	else
		self.EquippedItemRendersLast = false
		if self:NKGetCharacterController() then
			self:NKGetCharacterController():NKSetAlignWithCamera(false)
		end
		if self.m_equippedItem then
			self.m_equippedItem:NKGetGraphics():NKSetShouldRenderLast(false)
			self.m_3pobject:NKAddChildObject(self.m_equippedItem)
		end
	end

	self:SetVisibilityForCamMode(mode)
end

-------------------------------------------------------------------------------
-- Called when the player initates death.
-- Overridden from BasePlayer.
function LocalPlayer:Die(source)
	self:SetOverlayAlpha(0.85)
	self:PlayOverlayFlash(0.85, 0.0, 4.0, BasePlayer.HurtColor)
	if self.m_showInventory then
		self:ToggleInventory(false)
	end


	local sound = Eternus.SoundSystem:NKGetAmbientSound("Death")
	if sound then
		sound:NKPlayAmbient(false)
	end

	self:SetCameraMode(LocalPlayer.ECameraMode.Third)
	Eternus.GameState:SyncCameraModeToPlayer()

	self:PlayDeathNotice(0.0, 1.0, 1.5)

	LocalPlayer.__super.Die(self, source)
end

-------------------------------------------------------------------------------
-- Overridden from BasePlayer to add the additional OnSwingAnimation callback.
function LocalPlayer:_SetThirdPersonGameObject( gameObjectName )
	LocalPlayer.__super._SetThirdPersonGameObject(self, gameObjectName)

	-- Setup the swing callback.
	if self.m_torsoAnimationSlot then
		self.m_gfx:NKRegisterAnimationEvent("OnSwing", LuaAnimationCallbackListener.new(self, "OnSwingAnimation"))
		self.m_gfx:NKRegisterAnimationEvent("OnPickup", LuaAnimationCallbackListener.new(self, "OnPickupAnimation"))
		self.m_gfx:NKRegisterAnimationEvent("OnThrow", LuaAnimationCallbackListener.new(self, "OnThrowAnimation"))
		self.m_gfx:NKRegisterAnimationEvent("OnShoot", LuaAnimationCallbackListener.new(self, "OnShootAnimation"))
		self.m_gfx:NKRegisterAnimationEvent("TransitionToDefault", LuaAnimationCallbackListener.new(self, "TransitionToDefault"))
		self.m_gfx:NKRegisterAnimationEvent("OnConsume", LuaAnimationCallbackListener.new(self, "OnConsume"))
	end
end

-------------------------------------------------------------------------------
-- Swap the 3P model (m_3pobject) out from a seedling to a wisp.
-- Sets m_inDeathForm to true.
function LocalPlayer:SetModelWisp()
	-- Call the base player version.
	LocalPlayer.__super.SetModelWisp(self)

	-- Create a wisp and destroy the seed.
	if self:InstanceOf(LocalPlayer) then -- Belongs in LocalPlayer via virtual function.
		self:NKSetPosition(self:NKGetPosition() + vec3.new(0.0, 3.0, 0.0))
	end

	self:PlayDeathNotice(1.0, 0.0, 5.0)

	-- Enable fly mode.
	self:NKGetCharacterController():EnableFlying()
	self:SetFlying(true)
	self:SetBaseCameraHeight( 0.0 )
end

-------------------------------------------------------------------------------
function LocalPlayer:SetModelSeedling( experience )
	LocalPlayer.__super.SetModelSeedling(self, experience)
	--self.m_cameraHeight = 3.2
	self:SetCameraMode(LocalPlayer.ECameraMode.First)
	Eternus.GameState:SyncCameraModeToPlayer()
	self:NKSetOrientation(quat.new(0.0, 0.0, 1.0, 0.0))
	self.m_respawning = true
	self:SetFlying(false)

	if self:NKGetCharacterController() then
		self:NKGetCharacterController():DisableFlying() --Make sure we're not in fly mode! We should be if we came from a wisp.
		self:NKGetCharacterController():NKSetPhi(0.0)
		self:NKGetCharacterController():NKSetTheta(0.0)
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:PlayTorsoAnimationOneShot( s_animationName, f_transitionInTime, f_transitionOutTime, loop, restart )
	-- Call super function (which plays it on the third person model)
	LocalPlayer.__super.PlayTorsoAnimationOneShot(self, s_animationName, f_transitionInTime, f_transitionOutTime, loop, restart)
	--Now tell the hands to do it.
	if self.m_fpsHands and self.m_fpsHands.PlayAnimationOneShot then
		self.m_fpsHands:PlayAnimationOneShot(s_animationName, f_transitionInTime, f_transitionOutTime, loop, restart)
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:ClearTorsoAnimation()
	-- Call super function (which plays it on the third person model)
	LocalPlayer.__super.ClearTorsoAnimation(self)
	--Now tell the hands to do it.
	self.m_fpsHands:ClearTorsoAnimation()
end

-------------------------------------------------------------------------------
--  Called once a frame from BasePlayer to update the BlendInfo struct that drives the animated model.
--  Overridden from BasePlayer to handle First Person Hands blending as well.
function LocalPlayer:_UpdateAnimationBlending()
	-- Call the super function.
	LocalPlayer.__super._UpdateAnimationBlending(self)

	if self.m_fpsHands and self.m_fpsHands.u_gfx and self.m_gfx then
		-- Get the BlendInfo struct that was filled by the super call above.
		local blendInfo = self.m_gfx:GetBlendInfo()

		-- Copy the blending infomation from the third to first person model as well.
		local handsBlendInfo = self.m_fpsHands.u_gfx:GetBlendInfo()
		handsBlendInfo:NKCopy(blendInfo)

		-- We are crouching, the hands just play idle (we have no animations for this yet).
		-- Don't have crouching yet, ignore this till we do!
		if self:IsCrouching() then
			handsBlendInfo:NKSetState("PlayerState", BasePlayer.EState.eIdle)
		end
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:IsActionLocked()
	return self.m_actionsLocked or (not self:InDefaultStance() and not self.m_stance == BasePlayer.EStance.eHolding) or self:IsTransitioning()
end

-------------------------------------------------------------------------------
-- Logic should send an event to the server requesting a craft.
-- Server should send back an event telling it what to craft,
-- along with duration information.
function LocalPlayer:BeginCraft(down)
	if not down then
		return
	end

	if self.m_dying or self.m_actionsLocked then
		return
	end

	--NKPrint("Trying to craft.\n")

	local eyePosition = self:NKGetPosition() + vec3(0.0, self.m_cameraHeight, 0.0)
	local lookDirection = Eternus.GameState.m_activeCamera:ForwardVector()
	local result = NKPhysics.RayCastCollect(eyePosition, lookDirection, self:GetMaxReachDistance(), {self})

	if result then
		tracePos = result.contact
	else
		tracePos = eyePosition
		tracePos = tracePos + (lookDirection:mul_scalar(2.5))
	end

	self:RaiseServerEvent("ServerEvent_RequestCrafting", { at = tracePos})
end

-------------------------------------------------------------------------------
function LocalPlayer:SetOverlayAlpha( alpha )
	self.m_gameModeUI.m_backgroundFlash:setAlpha(0.85)
end

-------------------------------------------------------------------------------
function LocalPlayer:PlayOverlayFlash(startAlpha, endAlpha, duration, color)

	self.m_gameModeUI.m_backgroundFlash:setProperty("ImageColours", color)
	self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_backgroundFlash, startAlpha, endAlpha, duration)
end

-------------------------------------------------------------------------------
function LocalPlayer:PlayDeathNotice( startAlpha, endAlpha, duration )

	self.m_gameModeUI:FadeAlpha(self.m_gameModeUI.m_deathNotice, startAlpha, endAlpha, duration)
end

-------------------------------------------------------------------------------
function LocalPlayer:PrimaryAction( down )
	if self:IsDead() or self:HasDied() or self.m_actionsLocked then
		return
	end

	-- no primary action while holding shield
	if self:InHoldingShieldStance() then
		return
	end

	if not down or not self:IsPrimaryActionEnabled() then
		self.m_primaryActionEngaged = false
		return
	end

	if not self.m_primaryActionEngaged then
		self.m_primaryActionEngaged = true
	else

	end

	-- If our inventory is open, CEGUI will handle all the input
	-- This is hacky and should be resolved when we get a new input system
	if self.m_showInventory then
		return
	end
	-- Make sure we can swing first
	if self:CanSwing() then
		--We need to go ahead and do this logic so we can determine if we need can pick something up
		-- as that is a priority over swinging

		-- Order of operations for primary action:
		-- 1. Pick up target.
		-- 2. Use currently held item(hand).
		tempArgs = {}

		local clientCam = Eternus.GameState.m_activeCamera
		tempArgs.positionW = clientCam:NKGetLocation()
		tempArgs.direction = clientCam:ForwardVector()

		tempArgs.player = self
		tempArgs.camManifold = self:CreatePlayerCameraRaycastHit(tempArgs.positionW, tempArgs.direction, self:GetMaxReachDistance())

		--NKPrint("camManifold: " .. EternusEngine.Debugging.Inspect(tempArgs.camManifold) .. "\n\n")

		if tempArgs.camManifold then
			tempArgs.targetObj 		= tempArgs.camManifold.gameobject
			tempArgs.targetPoint 	= tempArgs.camManifold.contact
		else
			tempArgs.targetObj = nil
			tempArgs.targetPoint = tempArgs.positionW + (tempArgs.direction * vec3.new(6.0, 6.0, 6.0))
		end

		if tempArgs.targetObj and tempArgs.targetObj:NKGetInstance().m_isResource and self.m_stance.allowPickup then
			--trigger off the animation to play
			self:RaiseServerEvent("ServerEvent_PlayTorsoAnimOnce", { animName = "Pickup", TimeIN = 0.0, TimeOUT = 0.0, loop = false, restart = true })
		elseif self.m_equippedItem and self.m_equippedItem:NKGetInstance() and self.m_equippedItem:NKGetInstance():InstanceOf(Equipable) then
			--Attempt to swing our weapon
			self:SwingEquippedItem()
		elseif self:InCastingStance( ) then
			self:RaiseServerEvent("ServerEvent_Cast", {})
		else
			--Attempt to punch
			--self:PlayTorsoAnimationOneShot("Place", BasePlayer.m_animationBlendTime, BasePlayer.m_animationBlendTime, false, true)
			self:RaiseServerEvent("ServerEvent_PlayTorsoAnimOnce", { animName = "Punch", TimeIN = 0.0, TimeOUT = 0.0, loop = false, restart = true })
		end
	end
end

-------------------------------------------------------------------------------
function LocalPlayer:SecondaryAction( down )
	if self:IsDead() or self:HasDied() or self.m_actionsLocked then
		return
	end

	if not down or not self:IsSecondaryActionEnabled() then
		self.m_secondaryActionEngaged = false
		return
	end

	if not self.m_secondaryActionEngaged then
		self.m_secondaryActionEngaged = true
	else
	end

	-- Play test safety code (slingshot)
	if self.m_stance.id == BasePlayer.EStance.eSlingshotHolding.id or self.m_stance.id == BasePlayer.EStance.eSlingshotHolding2.id then
		return
	end

	-- Play test safety code (casting)
	if self.m_stance.id == BasePlayer.EStance.eCasting.id or self.m_stance.id == BasePlayer.EStance.eCasting2.id then
		return
	end

	-- Play test safety code
	if self.m_stance.id == BasePlayer.EStance.eHolding.id or self:IsTransitioning() then
		return
	end

	-- Temp bail to fix right clicking stuff out of your inventory.
	if self.m_showInventory then
		return
	end

	--local pos, camPos = self:CalculateDropInfo()
	--self:RaiseServerEvent("ServerEvent_SecondaryAction", { targetObj = Eternus.PhysicsWorld:NKGetWorldTracedGameObject(), targetPoint = pos, originPoint = camPos })

	-- Grab the current client camera and pack the:
	--	origin(vec3) : World Position
	--	direction(vec3) : Normalized direction
	local clientCam = Eternus.GameState.m_activeCamera

	self:RaiseServerEvent("ServerEvent_SecondaryAction", { positionW = clientCam:NKGetLocation(), direction = clientCam:ForwardVector() })
end

-------------------------------------------------------------------------------
function LocalPlayer:ClientEvent_ToggleInventory( args )
	self:ToggleInventory(args.down)
end

-------------------------------------------------------------------------------
function LocalPlayer:ToggleInventory( down )
	if down then
		return
	end

	if self:IsDead() then
		return
	end

	self.m_showInventory = not self.m_showInventory
	self.m_toggleInventorySignal:Fire()

	if self.m_showInventory then
		-- Show the Inventory
		-- Push the inventory input context
		Eternus.InputSystem:NKPushInputContext(self.m_inventoryContext)
		self.m_gameModeUI.m_crosshair:hide()
		self.m_survivalUI.m_containerViews["Backpack"]:Show()
		self.m_survivalUI.m_containerViews["Equipment"]:Show()

		self.m_survivalUI.m_containerViews["RecipeView"]:Show()

		if self.m_survivalUI.m_containerViews["Chest"]:GetModel() then
			self.m_survivalUI.m_containerViews["Chest"]:Show()
		end
		if self.m_survivalUI.m_containerViews["AdditionalBackpack"]:GetModel() then
			self.m_survivalUI.m_containerViews["AdditionalBackpack"]:Show()
		end
		Eternus.InputSystem:NKShowMouse()
		Eternus.InputSystem:NKCenterMouse()
	else
		-- Hide the Inventory
		-- Push the inventory input context
		Eternus.InputSystem:NKRemoveInputContext(self.m_inventoryContext)
		self.m_gameModeUI.m_crosshair:show()
		self.m_survivalUI.m_containerViews["Backpack"]:Hide()
		self.m_survivalUI.m_containerViews["Equipment"]:Hide()

		self.m_survivalUI.m_containerViews["RecipeView"]:Hide()

		self:CloseContainer(self.m_inventoryContainers[5])
		Eternus.InputSystem:NKHideMouse()
	end

	self:SetPlacementMode(false)
end

-------------------------------------------------------------------------------
function LocalPlayer:CalculateDropInfo()

	local cam = Eternus.GameState.m_activeCamera
	local camPos = cam:NKGetLocation()
	local fwd = cam:ForwardVector()
	local pos = Eternus.PhysicsWorld:NKGetWorldTracedObjectPosition()
	if pos == vec3.new(0.0, 0.0, 0.0) then
		pos = camPos + (fwd*vec3.new(6.0, 6.0, 6.0))
	end

	return pos, camPos
end

-- Overridden from BasePlayer.TransitionStance to also transition the first person hands.
function LocalPlayer:TransitionStance( stanceTransition )
	local success = LocalPlayer.__super.TransitionStance(self, stanceTransition)

	if success then
		self.m_fpsHands.m_stanceGraph:NKFinishTransition()
		success = self.m_fpsHands.m_stanceGraph:NKTriggerTransition(stanceTransition.name)
	end
	--[[
		if success then
			NKPrint("FPS Hands Transitioning to '" .. stanceTransition.name .. "'...\n")
		else
			NKPrint("FPS Hands Failed to transition to '" .. stanceTransition.name .. "'...\n")
		end
	else
		NKPrint("Could not transition FPS Hands... \n")
	end
	--]]

	return success
end

-- Overridden from BasePlayer.TransitionShield to also transition the first person hands.
function LocalPlayer:TransitionShield( stanceTransition, targetStance )
	local success = LocalPlayer.__super.TransitionShield(self, stanceTransition, targetStance)

	if (self.m_fpsHands.m_shieldGraph:NKGetActiveTransition() ~= stanceTransition.name) then
		if success then
			self.m_fpsHands.m_shieldGraph:NKFinishTransition()
			success = self.m_fpsHands.m_shieldGraph:NKTriggerTransition(stanceTransition.name)
		end


		if success then
			NKPrint("FPS Shield Transitioning to '" .. stanceTransition.name .. "'...\n")
		else
			NKPrint("FPS Shield Failed to transition to '" .. stanceTransition.name .. "'...\n")
			if targetStance then
				local result = self.m_fpsHands.m_shieldGraph:NKSetStateEx(targetStance.name)

				if result == BlendByGraph.SUCCESS then
					self.m_shieldStance = targetStance
					success = true
				else
					success = false
				end
			end
		end
	end

	return success
end

-------------------------------------------------------------------------------
-- Overridden from BasePlayer.SetStance to also set the state of the first person hands.
function LocalPlayer:SetStance( stance )

	local result = self.m_fpsHands.m_stanceGraph:NKSetStateEx(stance.name)

--[[
	if Eternus.Debugging.Logging then
		if result == BlendByGraph.SUCCESS then
			NKInfo("[LocalPlayer:SetStance] Stance and FPS Hands set to: " .. stance.name .. ".")
		elseif result == BlendByGraph.INVALID then
			NKError("[LocalPlayer:SetStance] Attempting to set invalid stance: " .. stance.name .. ".")
		elseif result == BlendByGraph.NO_CHANGE then
			NKWarn("[LocalPlayer:SetStance] Attempting to set stance (" .. stance.name .. ") when already in that stance.")
		else
			NKError("[LocalPlayer:SetStance] Something went wrong while attempt to set stance: " .. stance.name .. ".")
		end
	end
--]]

	return LocalPlayer.__super.SetStance(self, stance)
end

-------------------------------------------------------------------------------
function LocalPlayer:ToggleHoldStance(down)
	if not down then
		return
	end

	-- Toggle the stance
	if self.m_equippedItem and self.m_equippedItem:NKGetInstance():InstanceOf(RangedWeapon) then
		if self:InDefaultStance() then
			self.m_equippedItem:NKGetInstance():Aim(self)
			--self.m_stance = BasePlayer.EStance.eHolding
		else
			self:TransitionStance(BasePlayer.EStanceTransitions.eCancel)
			--self.m_stance = BasePlayer.EStance.eDefault
		end
	elseif self.m_equippedItem and self.m_equippedItem:NKGetInstance():InstanceOf(ThrowablePotion) then
		if self:InDefaultStance() then
			self:TransitionStance(BasePlayer.EStanceTransitions.eHoldPotion)
			--self.m_stance = BasePlayer.EStance.eHolding
		else
			self:TransitionStance(BasePlayer.EStanceTransitions.eCancel)
			--self.m_stance = BasePlayer.EStance.eDefault
		end
	elseif self.m_equippedItem and self.m_equippedItem:NKGetInstance():InstanceOf(Throwable) then
		if self:InDefaultStance() then
			self:TransitionStance(BasePlayer.EStanceTransitions.eHold)
			--self.m_stance = BasePlayer.EStance.eHolding
		else
			self:TransitionStance(BasePlayer.EStanceTransitions.eCancel)
			--self.m_stance = BasePlayer.EStance.eDefault
		end
	-- check for empty hand
	elseif not self.m_equippedItem then
		self:RaiseServerEvent("ServerEvent_ToggleHoldStance", {})
	end
end

-------------------------------------------------------------------------------
-- Test code for throwing an equipped object
-- For now, it's easier to create a new object that
-- is copied from the held item and deleting the item
-- currently being held in the hand
function LocalPlayer:OnThrowAnimation(slot, animation)
	-- Only works if there's an item in the hand
	if not self.m_equippedItem then return end

	-- Play the swing noise (FLAVOR)
	--self:NKGetSound():NKPlayLocalSound("WeaponSwing", false)

	--LocalPlayer.__super.OnThrowAnimation(self, slot, animation)

	--[[
	if Eternus.IsServer then
		NKPrint("(SERVER) Throw Animation Callback...\n")
	elseif Eternus.IsClient then
		NKPrint("(CLIENT) Throw Animation Callback...\n")
	end
	--]]

	--[[
	-- Previous Method
	local obj = Eternus.PhysicsWorld:NKGetWorldTracedGameObject()
	local cam = Eternus.GameState.m_activeCamera
	local camPos = cam:NKGetLocation()
	local fwd = cam:ForwardVector()
	local pos = Eternus.PhysicsWorld:NKGetWorldTracedObjectPosition()
	if (pos == vec3.new(0.0, 0.0, 0.0)) then
		pos = camPos + (fwd*vec3.new(3.0, 3.0, 3.0))
	end

	self:RaiseServerEvent("ServerEvent_PrimaryAction", { targetObj = Eternus.PhysicsWorld:NKGetWorldTracedGameObject(), targetPoint = pos, originPoint = camPos, direction = fwd })
	--]]

	-- New Method

	-- Grab the current client camera and pack the:
	--	positionW(vec3) : World Position
	--	direction(vec3) : Normalized direction
	local clientCam = Eternus.GameState.m_activeCamera

	self:RaiseServerEvent("ServerEvent_PrimaryAction", { positionW = clientCam:NKGetLocation(), direction = clientCam:ForwardVector() })

	--self:PrimaryAction()
end

-------------------------------------------------------------------------------
function LocalPlayer:OnShootAnimation(slot, animation)
	-- Only works if there's an item in the hand
	if not self.m_equippedItem and not self:InCastingStance() then
		return
	end
	local clientCam = Eternus.GameState.m_activeCamera

	self:RaiseServerEvent("ServerEvent_PrimaryAction", { positionW = clientCam:NKGetLocation(), direction = clientCam:ForwardVector() })
end

-------------------------------------------------------------------------------
-- Have the player perform the Place action.
function LocalPlayer:Place()
	-- Play the animation.
	self:PlayTorsoAnimationOneShot("Place", BasePlayer.DefaultAnimationBlendTime, BasePlayer.DefaultAnimationBlendTime, false, true)
end

-------------------------------------------------------------------------------
-- Callback from the animation system when playing upper torso animations (occurs at LocalPlayer.SwingDamageApplyTime).
function LocalPlayer:OnSwingAnimation( animation )
	-- Modify our stamina due to the swing.
	--self:_ModifyStamina(-LocalPlayer.m_staminaDrainSwinging)
	local clientCam = Eternus.GameState.m_activeCamera
	self:RaiseServerEvent("ServerEvent_PrimaryAction", { positionW = clientCam:NKGetLocation(), direction = clientCam:ForwardVector() })
	return false
end

-------------------------------------------------------------------------------
-- Callback from the animation system when playing upper torso animations (occurs at LocalPlayer.SwingDamageApplyTime).
function LocalPlayer:OnPickupAnimation( animation )
	-- Modify our stamina due to the swing.
	--self:_ModifyStamina(-LocalPlayer.m_staminaDrainSwinging)

	local clientCam = Eternus.GameState.m_activeCamera
	self:RaiseServerEvent("ServerEvent_PickupAction", { positionW = clientCam:NKGetLocation(), direction = clientCam:ForwardVector() })
	return false
end

function LocalPlayer:_SetStamina( amount )
	LocalPlayer.__super._SetStamina(self, amount)

	if self.m_stamina <= 0.0 then
		self.m_runPreventFlag = true
	end
end

function LocalPlayer:SharedEvent_TransitionStance( args )
end

function LocalPlayer:SharedEvent_SetStance( args )
end

function LocalPlayer:ClientEvent_TakeDamage( args )
	LocalPlayer.__super.ClientEvent_TakeDamage( self, args )

	self:SetOverlayAlpha(0.85)
	self:PlayOverlayFlash(0.5, 0.0, 1.0, BasePlayer.HurtColor)
end

function LocalPlayer:ClientEvent_NetEventFailure( args )
	self:NetEventFailure(args, "[LocalPlayer] ")
end

function LocalPlayer:ClientEvent_SetStance(args)
	if args.stanceID then
		self:SetStance(BasePlayer.EStance.Lookup[args.stanceID])
	end
end


function LocalPlayer:HandleMouse()
	if not self:HasCameraControl() then return end
end

function LocalPlayer:SetCameraControl(to)
	self.m_cameraControl = to
end

function LocalPlayer:HasCameraControl()
	return self.m_cameraControl
end

function LocalPlayer:SetSecondaryActionEnabled(to)
	self.m_secondaryActionEnabled = to
end

function LocalPlayer:SetPrimaryActionEnabled(to)
	self.m_primaryActionEnabled = to
end

function LocalPlayer:IsSecondaryActionEnabled()
	return self.m_secondaryActionEnabled
end

function LocalPlayer:IsPrimaryActionEnabled()
	return self.m_primaryActionEnabled
end

function LocalPlayer:IsPrimaryActionEngaged()
	return self.m_primaryActionEngaged
end

function LocalPlayer:IsSecondaryActionEngaged()
	return self.m_secondaryActionEngaged
end

function LocalPlayer:HasActionsEngaged()
	return self.m_primaryActionEngaged or self.m_secondaryActionEngaged
end

function LocalPlayer:OnGearEquipped( slotId, gearGameObject, playEffect )
	LocalPlayer.__super.OnGearEquipped(self, slotId, gearGameObject, playEffect)

	if not self.m_fpsHands then return end
	if not gearGameObject:InstanceOf( EquipableGear ) or not gearGameObject:AltersAppearance() then
		self.m_fpsHands:ClearSlotAppearanceRules( slotId )
	else
		self.m_fpsHands:SetSlotAppearanceRules( slotId, gearGameObject:GetAppearanceRules() )
	end
end

function LocalPlayer:OnGearRemoved( slotId )
	LocalPlayer.__super.OnGearRemoved(self, slotId)

	if not self.m_fpsHands then return end
	self.m_fpsHands:ClearSlotAppearanceRules( slotId )
end

function LocalPlayer:_UpdateGearVisuals( obesity, age, hairIdx )
	LocalPlayer.__super._UpdateGearVisuals( self, obesity, age, hairIdx )

	obesity = obesity or self.m_obesity
	age = age or 0.0
	hairIdx = hairIdx or self.m_hairIdx
	if self.m_fpsHands then
		self.m_fpsHands:SetDefaultAppearance(obesity, age, hairIdx)
	end
end

-- Experience asthetics functions that are client side only.
if Eternus.IsClient then
	-------------------------------------------------------------------------------
	-- Overrides BasePlayer._ApplyGrowthState to also apply camera effects for localplayers.
	function LocalPlayer:_ApplyGrowthState( growthState, stateName )
		self.m_fpsHands:SetGrowthState( stateName )
		LocalPlayer.__super._ApplyGrowthState( self, growthState, stateName )
		self:SetBaseCameraHeight( growthState.CameraOffset )
	end
end -- Eternus.IsClient

function LocalPlayer:SetBaseCameraHeight( height )
	self.m_baseCameraHeight = height
	self.m_cameraHeight = height

	if self:IsCrouching() then
		self.m_cameraHeight = height + self.CrouchingCameraHeightModifier
	else
		self.m_cameraHeight = height
	end
end

EntityFramework:RegisterGameObject(LocalPlayer)
