--Modes.Survival.Survival.lua
--Game Mode definitions and state for Proving Grounds mode
include("Scripts/Modes/TUGGameMode.lua")
include("Scripts/Characters/LocalPlayer.lua")
include("Scripts/UI/SurvivalUIView.lua")

local NKPhysics = include("Scripts/Core/NKPhysics.lua")

include("Scripts/Core/NKTerrain.lua")


-------------------------------------------------------------------------------
Survival = TUGGameMode.Subclass("Survival")

Survival.MAX_RAYCAST_DISTANCE = 6.0
Survival.TETHER_DISTANCE = 6.0

-------------------------------------------------------------------------------
function Survival:Initialize( )
	Survival.__super.Initialize(self)

	self.MAX_RAYCAST_DISTANCE = Survival.MAX_RAYCAST_DISTANCE
	self.TETHER_DISTANCE = Survival.TETHER_DISTANCE

	-- This is being done as a temporary measure to help clear up the ambigious
	--	states being set by the Engine Core.
	--  [11/24/2014 Anthony]
	EternusEngine.GameMode = self
	self:InitStats()
end

-------------------------------------------------------------------------------
-- This is called before creating a new gamestate script when you create a new game
function Survival:Cleanup( )
	Survival.__super.Cleanup(self)
end

-------------------------------------------------------------------------------
function Survival:Enter( )
	Survival.__super.Enter(self)

	if self.player and not self.player.m_showInventory then
		Eternus.InputSystem:NKGrabMouseInput()
	end
end

-------------------------------------------------------------------------------
function Survival:Leave( )
	Survival.__super.Leave(self)
	Eternus.InputSystem:NKReleaseMouseInput()
end

-------------------------------------------------------------------------------
function Survival:AppFocusGained( )
	Survival.__super.AppFocusGained(self)

	Eternus.InputSystem:NKFlushAllInputStatesNow()

	if self.player and not self.player.m_showInventory and self:IsStateActive() then
		Eternus.InputSystem:NKGrabMouseInput()
	end
end

-------------------------------------------------------------------------------
function Survival:AppFocusLost( )
	Survival.__super.AppFocusLost(self)

	Eternus.InputSystem:NKReleaseMouseInput()
end

 -------------------------------------------------------------------------------
-- Register input for Survival mode.
function Survival:SetupInputSystem( )
	-- Call super function.
	Survival.__super.SetupInputSystem(self)
	Eternus.CommandService:NKRegisterChatCommand("physics", "Command_Physics")
	Eternus.CommandService:NKRegisterChatCommand("pickup", "Command_Pickup")
	Eternus.CommandService:NKRegisterChatCommand("giveItem", "Command_GiveItem")
	Eternus.CommandService:NKRegisterChatCommand("setstrength", "Command_SetStrength")
	Eternus.CommandService:NKRegisterChatCommand("setmass", "Command_SetMass")
	Eternus.CommandService:NKRegisterChatCommand("raytest", "Command_RayTest")
	Eternus.CommandService:NKRegisterChatCommand("giveexp", "Command_GiveExperience")
end

-------------------------------------------------------------------------------
function Survival:Command_Physics( userInput, args )
	NKPhysics.RunCommand(userInput, args)
end

-------------------------------------------------------------------------------
function Survival:Command_Pickup( userInput, args )
	if args[1] then --Have a name.
		local objName = args[1]
		local objCount = 1
		if args[2] then
			objCount = tonumber(args[2])
			if not objCount then
				NKPrint("Attempting to spawn object " .. objName .. " with invalid count: " .. args[2])
				return
			end
		end

		self.player:RaiseServerEvent("Server_Pickup", { name = objName, count = objCount })
	end
end

-------------------------------------------------------------------------------
-- Single fire of a given ray trace. See NKPhysics.lua
function Survival:Command_RayTest( userInput, args )
	NKPhysics.RayTest(self.m_activeCamera:NKGetLocation(), self.m_activeCamera:ForwardVector(), {self.player}, userInput, args)
end

-------------------------------------------------------------------------------
-- Set the strength of the player. How much force a player can "push" onto an object
function Survival:Command_SetStrength( userInput, args )
	NKPrint("Setting player strength from: " .. self.player:NKGetCharacterController():NKGetStrength() .. " -> " .. args[1])
	self.player:NKGetCharacterController():NKSetStrength(args[1])
end

-------------------------------------------------------------------------------
-- Set the mass of the player. How much force, due to gravity, gets applied "downwards" onto an object
function Survival:Command_SetMass( userInput, args )
	NKPrint("Setting player mass from: " .. self.player:NKGetCharacterController():NKGetMass() .. " -> " .. args[1])
	self.player:NKGetCharacterController():NKSetMass(args[1])
end

-------------------------------------------------------------------------------
-- Give a player experience by name.
-- Usage /giveexperience [player name] [amount]
function Survival:Command_GiveExperience( userInput, args )
	if args[1] then
		local amount = args[1]
		if self.player then
			self.player:RaiseServerEvent("ServerEvent_GiveExperience", { amount = amount })
		end
	end
end

-------------------------------------------------------------------------------
function Survival:SetupUI( )

	self.player:SetupUI(SurvivalUIView, "SurvivalLayoutUFI.layout")
end

-------------------------------------------------------------------------------
function Survival:CreatePlayer( )
	--Survival.__super.CreatePlayer(self)
	local gameobject = Eternus.GameObjectSystem:NKCreateGameObject("Survival Player Controller", true)
	self.player = gameobject:NKGetInstance()
	if not self.player then
		out:NKPrintToChannel(DebugOutput.eDebugChannelLua, DebugOutput.ePriorityError, "Unable to create Player Controller!")
		return
	end
	self.controller = CharacterController.new(self.player.object)
	self.player.object:NKSetController(self.controller)
	self.player.m_controller = self.controller
	self.player:Initialize(self)

end

-------------------------------------------------------------------------------
-- args is a table of all the arguemnts passed in.
function Survival:TargetInfoCommand( args )

	local hitObj = Eternus.PhysicsWorld:NKGetWorldTracedObject()
	if not hitObj.gameobject then
		return true
	end
	self:ObjectDataToChatWindow(hitObj.gameobject)

	return true
end


-------------------------------------------------------------------------------
function Survival:ObjectDataToChatWindow( obj )

	local miscUI = NKGetDeprecatedUIContainer():NKGetMiscellaneousUI()

	local str = "Display Name: " .. obj:NKGetDisplayName()
	miscUI:NKChatWindow_AddText(str)

	str = "Real Name: " .. obj:NKGetName()
	miscUI:NKChatWindow_AddText(str)

	local pos = obj:NKGetPosition()
	str = "Position: " .. tostring(pos:x()) .. ", " .. tostring(pos:y()) .. ", " .. tostring(pos:z())
	miscUI:NKChatWindow_AddText(str)

	local rot = obj:NKGetOrientation()
	str = "Rotation: " .. tostring(rot:w()) .. ", " .. tostring(rot:x()) .. ", " .. tostring(rot:y()) .. ", " .. tostring(rot:z())
	miscUI:NKChatWindow_AddText(str)

	local bounds = obj:NKGetBounds()
	str = "Bounding Radius: " .. tostring(bounds:NKGetRadius())
	miscUI:NKChatWindow_AddText(str)

	local children = obj:NKGetChildren()
	if table.getn(children) ~= 0 then
		miscUI:NKChatWindow_AddText("** Child Objects **")
		for i = 1, table.getn(children) do
			self:ObjectDataToChatWindow(children[i])
		end
	end
end

-------------------------------------------------------------------------------
function Survival:Process( dt )

	-- Call the super class version
	Survival.__super.Process(self, dt)

	NKPhysics.Update(dt)
	RDU.NKUpdateCamera(self.m_activeCamera:NKGetLocation(), self.m_activeCamera:NKGetLocation() + self.m_activeCamera:ForwardVector(), vec3(0.0, 1.0, 0.0), 0.05, 50000.0, 60.0, "RDU Camera")
end

-------------------------------------------------------------------------------
function Survival:HandleMouse ( mouseDelta )
	-- Ask the player if he has control over the camera direction
	if self.player:HasCameraControl() then
		return true
	else
		return false
	end
end

-------------------------------------------------------------------------------
function Survival:VoxelsModifiedCallback( voxels, modificationType, modifyingPlayer, userdata1 )

	local count = 0
	local firstVoxel = nil

	local objToModify = nil
	if userdata1 ~= nil then
		objToModify = Eternus.World:NKGetGameObjectByNetId(userdata1)
	end

	local modifiedVoxelsData = {}

	if objToModify then
		local objScript = objToModify:NKGetInstance()
		if objScript.VoxelsModifiedCallback then
			objScript:VoxelsModifiedCallback(voxels, modificationType, modifyingPlayer, userdata1)
			return
		end
	end

	for key,voxel in pairs(voxels) do
		count = count + 1

		if voxel then

			local pos 		= voxel:NKGetPosition()
			local prevMat 	= voxel:NKGetPreviousMaterial()
			local newMat 	= voxel:NKGetNewMaterial()

			if firstVoxel ~= nil then
				firstVoxel = prevMat
			end

			-- Get the material Schematic
			local schem = Eternus.GameObjectSystem:NKFindObjectSchematicByMat(prevMat)

			if schem then
				local voxelName = schem:NKGetObjectRep()
				if modifiedVoxelsData[voxelName] == nil then
					modifiedVoxelsData[voxelName] = {}
					modifiedVoxelsData[voxelName].pos = pos
					modifiedVoxelsData[voxelName].prevMat = prevMat
					modifiedVoxelsData[voxelName].newMat = newMat
					modifiedVoxelsData[voxelName].count = 1
					modifiedVoxelsData[voxelName].schem = schem
					modifiedVoxelsData[voxelName].voxel = voxel
				else
					modifiedVoxelsData[voxelName].count = modifiedVoxelsData[voxelName].count + 1
				end
			end
		end
	end

	for key, value in pairs(modifiedVoxelsData) do

		if modificationType ~= NKTerrain.EVoxelOperations.ePlace then
			self:PlayMiningEmitter(value.voxel, value.pos, value.prevMat, value.newMat, value.schem, modifyingPlayer)
		end

		if modificationType == NKTerrain.EVoxelOperations.eRemove then
			self:ChunkDrops(value.voxel,value.pos,value.prevMat,value.newMat,value.schem, modifyingPlayer, value.count)
		end

	end

	if objToModify then
		local objScript = objToModify:NKGetInstance()
		if objScript:InstanceOf(PlaceableMaterial) then
			modifyingPlayer:NKGetPawn():NKGetInstance():RemoveHandItem(count)
		else
			objScript:ModifyHitPoints(-(count * 0.5))
		end
	end

end


-------------------------------------------------------------------------------
function Survival:PlayMiningEmitter( voxel, pos, prevMat, newMat, schem, player )

	local emitterName = "Combat Hit HP Emitter"
	local altEmitterName = ""

	if not player then
		return
	end

	local pawn = player:NKGetPawn()

	if not pawn then
		return
	end

	if schem then
		local name = schem:NKGetMiningEmitterName()
		if name ~= "" then
			emitterName = name
		end
		altEmitterName = schem:NKGetMiningEmitterAltName()
	end

	pawn:NKGetInstance():RaiseClientEvent("ClientEvent_PlayMiningEmitter", { position = pos, name = emitterName})

	--Eternus.ParticleSystem:NKPlayWorldEmitter(pos, emitterName);

	-- 	Play the alternate emitter as well.  This is used for materials that have double emitters
	-- 	(like gold, would play the rock emitter and the gold emitter at the same location)
	if altEmitterName ~= "" then
		pawn:NKGetInstance():RaiseClientEvent("ClientEvent_PlayMiningEmitter", { position = pos, name = altEmitterName})
		--Eternus.ParticleSystem:NKPlayWorldEmitter(pos, altEmitterName)
	end
end

---------------------------------------------------------------------------------
function Survival:ChunkDrops( voxel, pos, prevMat, newMat, schem, modifyingPlayer,count )
	if not Eternus.IsServer then
		return
	end

	local bestPM = -1
	local bestQaulity = -1

	--find the material schematic

	if not schem then
		return
	end

	local pmObj = nil
	local objName = schem:NKGetObjectRep()
	if objName == "" then
		return
	end

	-- First off, attempt to give the digging player the object.
	local newObj = Eternus.GameObjectSystem:NKCreateNetworkedGameObject(objName, true, true)
	newObj:NKGetInstance():SetStackSize(count)
	local wasPickedUp = false
	if modifyingPlayer then
		local player = modifyingPlayer:NKGetPawn()
		if player then
			local pawnInst = player:NKGetInstance()
			wasPickedUp = pawnInst:PickupVoxelDrops(newObj)
		else
			NKError("Player attempting to dig has no pawn set.")
		end

	end

	--temporarily spawn objects only
	if not wasPickedUp then
		local gameobjects = Eternus.GameObjectSystem:NKGetGameObjectsInRadius(pos, 5.0, "all", true )
		local gameobjectNames = {}
		for key, value in pairs(gameobjects) do
			gameobjectNames[key] = value:NKGetName()
		end
		local objFound = false
		local tempObj = nil

		for key,obj in pairs(gameobjects) do

			if objFound == false then
				tempObj = obj
				if tempObj:NKGetName() == objName then

					local script = tempObj:NKGetInstance()
					if script ~= nil then

						script:ModifyStackSize(count)

						objFound = true
						newObj:NKDeleteMe()
					end
				end
			end
		end



		if objFound == false then
			pmObj = newObj

			if pmObj == nil then
				return
			end

			pmObj:NKGetInstance():SetStackSize(count)

			pmObj:NKSetShouldRender(true, true)
			pmObj:NKSetPosition(vec3.new(pos:x(), pos:y() + 1.0, pos:z()), false)
			pmObj:NKPlaceInWorld(false, false)

			local physics = pmObj:NKGetPhysics()

			if physics ~= nil then

				-- Launch
				physics:NKActivate()

				--add some random movement
				local destination = vec3.new(math.random(-5.0, 5.0), 2.0, math.random(-5.0, 5.0))
				local angularVelocity = vec3.new(math.random(-5.0,5.0), math.random(0.0,5.0), math.random(-5.0,5.0))
				physics:NKSetLinearVelocity(destination)
				physics:NKSetAngularVelocity(angularVelocity)
			end

		end
	end

    --Produce the non voxel clump drops for the voxel
	for i=1,count do NKProduceDropsFromSchematic(schem, pos) end


	--Check best quality PM
	--Play Removal Sound

end

--Step 1
-------------------------------------------------------------------------------
function Survival:Server_GetPawnClassName( clientConnection )
	if clientConnection:NKIsLocalPlayer() then
		return "Local Player"
	else
		return "Network Player"
	end
end

--Step 2
-------------------------------------------------------------------------------
function Survival:Client_LocalPawnReady( conn )

	Survival.__super.Client_LocalPawnReady(self, conn)

	self.player = conn:NKGetPawn():NKGetInstance()
end

--Step 3
-------------------------------------------------------------------------------
function Survival:Server_EnterWorld( clientConnection )
	Survival.__super.Server_EnterWorld(self, clientConnection)
end

--Step 4
-------------------------------------------------------------------------------
function Survival:Client_EnterWorld( conn )
	Survival.__super.Client_EnterWorld(self, conn)
end

--Step 5
-------------------------------------------------------------------------------
function Survival:Server_LeaveWorld( clientConnection )
	Survival.__super.Server_LeaveWorld(self, clientConnection)
end

-------------------------------------------------------------------------------
function Survival:InitStats()
	-- Define an action namespace
	EternusEngine.Statistics.DefineGameAction("Craft")
	EternusEngine.Statistics.DefineGameAction("Consume")
	-- EternusEngine.Statistics.DefineGameAction("Defeat")
	-- EternusEngine.Statistics.DefineGameAction("Destroy")
	-- EternusEngine.Statistics.DefineGameAction("Skin")

	-- EternusEngine.Statistics.DefineGameAction("Farm")
	-- EternusEngine.Statistics.DefineGameAction("Repair")
	-- EternusEngine.Statistics.DefineGameAction("Deconstruct")
	-- EternusEngine.Statistics.DefineGameAction("Move")
	-- EternusEngine.Statistics.DefineGameAction("Collecting")

	-- Craft Namespace
	EternusEngine.Statistics.AddDataModel("Craft", "Crafted", include("Scripts/DataModels/CraftModel.lua"))

	-- -- Consume Namespace
	EternusEngine.Statistics.AddDataModel("Consume", "Consumed", include("Scripts/DataModels/ConsumeModel.lua"))

	-- -- Defeat Namespace
	-- EternusEngine.Statistics.AddDataModel("Defeat", "Defeated", include("Scripts/DataModels/DefeatModel.lua"))

	-- -- Destroy Namespace
	-- EternusEngine.Statistics.AddDataModel("Destroy", "Destroyed", include("Scripts/DataModels/DestroyModel.lua"))

	-- -- Skin Namespace
	-- EternusEngine.Statistics.AddDataModel("Skin", "Skinned", include("Scripts/DataModels/SkinModel.lua"))

	-- Farm Namespace
	-- EternusEngine.Statistics.AddDataModel("Farm", "Farmed", include("Scripts/DataModels/FarmModel.lua"))

	-- Repair Namespace
	-- EternusEngine.Statistics.AddDataModel("Repair", "Repaired", include("Scripts/DataModels/RepairModel.lua"))

	-- Deconstruct Namespace
	-- EternusEngine.Statistics.AddDataModel("Deconstruct", "Deconstructed", include("Scripts/DataModels/DeconstructModel.lua"))
end

EntityFramework:RegisterGameState(Survival)
