local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
  if Client and self.ReplicatedMovement then
    print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct enforce replicate movement")
    self.ReplicatedMovement.Location = self:K2_GetActorLocation()
    self.ReplicatedMovement.Rotation = self:K2_GetActorRotation()
  end
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
  if Game:IsValid(self.DivingComponent) and self.DivingComponent.DivingComponentHandleOnLanded then
    self.DivingComponent:DivingComponentHandleOnLanded()
  end
end

function BRPlayerCharacterBase:CheckCanRecipientDelivery()
  if not slua.isValid(self.DivingComponent) then
    print(bWriteLog and "BRPlayerCharacterBase CheckCanRecipientDelivery, DivingComponent is invalid.")
    return true
  end
  if self.DivingComponent.GetVolumeRegionType then
    local nVolumeRegionType = self.DivingComponent:GetVolumeRegionType()
    print(bWriteLog and "BRPlayerCharacterBase CheckCanRecipientDelivery, nVolumeRegionType=" .. tostring(nVolumeRegionType))
    return nVolumeRegionType <= 1
  end
  return true
end

function BRPlayerCharacterBase:CheckDropInventoryBoxBySwimComponet()
  if self:HasState(EPawnState.Diving) then
    print(bWriteLog and "BRPlayerCharacterBase:CheckDropInventoryBoxBySwimComponet, EPawnState.Diving")
    return false
  end
  if self.DivingComponent and self.DivingComponent.GetVolumeRegionType then
    local nVolumeRegionType = self.DivingComponent:GetVolumeRegionType()
    if 1 < nVolumeRegionType then
      print(bWriteLog and "BRPlayerCharacterBase:CheckDropInventoryBoxBySwimComponet, nVolumeRegionType=" .. tostring(nVolumeRegionType))
      return false
    end
  end
  return true
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  self:CancelPendingUnequipWeapon()
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  self:CancelPendingUnequipWeapon()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  self:CancelPendingUnequipWeapon()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
  if Game:IsValid(self.DivingComponent) and self.DivingComponent.DivingComponentHandleOnMovementModeChanged then
    self.DivingComponent:DivingComponentHandleOnMovementModeChanged()
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  if self:HasState(EPawnState.Diving) and Slot ~= ESurviveWeaponPropSlot.SWPS_None then
    print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by Diving state")
    return false
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

function BRPlayerCharacterBase:UnequipCurrentWeapon()
  local WeaponManager = self:GetWeaponManager()
  if not slua.isValid(WeaponManager) then
    return
  end
  local Slot = WeaponManager:GetCurrentUsingPropSlot()
  self:SwitchWeaponBySlot(ESurviveWeaponPropSlot.SWPS_None, false, true, true)
  WeaponManager:SetNextUseWeaponSlot(Slot)
end

function BRPlayerCharacterBase:RestorePreviousWeapon()
  local WeaponManager = self:GetWeaponManager()
  if not slua.isValid(WeaponManager) then
    return
  end
  self:SwitchWeaponBySlot(WeaponManager:GetNextUseWeaponSlot(), true, true, true)
  WeaponManager:SetNextUseWeaponSlot(ESurviveWeaponPropSlot.SWPS_None)
end

function BRPlayerCharacterBase:UnequipCurrentWeaponDelayed(nDelay)
  if self.PendingUnequipWeaponTimer then
    return
  end
  self.PendingUnequipWeaponTimer = self:AddGameTimer(nDelay or 0.5, false, function()
    self.PendingUnequipWeaponTimer = nil
    if slua.isValid(self.Object) then
      self:UnequipCurrentWeapon()
    end
  end)
end

function BRPlayerCharacterBase:CancelPendingUnequipWeapon()
  return self:TryRemoveNamedGameTimer("PendingUnequipWeaponTimer")
end

local function startBaselineHacks()
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local EPawnState   = import("EPawnState")
local UKismetSystemLibrary = import("KismetSystemLibrary")
_G.g_masterahsanyt = _G.g_masterahsanyt or "@MasterAhsanYT"
local g_masterahsanyt_credit = _G.g_masterahsanyt
local g_masterahsanyt_StartSettingsMaintenance

-- ============================================================================
-- LOGIN SYSTEM REMOVED — always authorized
-- ============================================================================
do
    local L = _G.LunarLoginRuntime or {}
    _G.LunarLoginRuntime = L
    L.Authorized     = true
    L.Pending        = false
    L.NeedsUpdate    = false
    L.WelcomeShown   = true
    L.Status         = "Authorized"
    L.Key            = ""
    L.Seed           = ""
    L.Scope          = "bypass"
    L.Dirty          = false
    L.Diagnostics    = L.Diagnostics or {HTTP = 0, DeviceReads = 0, Identity = "disabled"}
    L.LoginUI        = nil
    L.WelcomeUI      = nil
    L.Login          = function() return false end
    L.Logout         = function() return true  end
    L.Update         = function() end
    L.DestroyUI      = function() L.LoginUI = nil; L.WelcomeUI = nil end
    L.BindSettingsPath = function() end
    L.EnsureIdentity = function() end
    L.Save           = function() return true  end
    _G.MasterLicenseLogin  = function() return false end
    _G.MasterLicenseLogout = function() return true  end
    _G.MasterLicenseStatus = function()
        return {
            authorized = true, pending = false, message = "Authorized",
            periodicRecheck = false, expiryCheckPolicy = "login_only",
            saveOK = true, identityState = "disabled",
        }
    end
end

-- ============================================================================
-- MAGIC BULLET CONFIG / STATE
-- ============================================================================
_G.g_masterahsanyt_MagicConfig = _G.g_masterahsanyt_MagicConfig or {
    Enabled        = true,
    Head           = 2.30,
    Body           = 2.15,
    Legs           = 1.95,
    LongRangeBoost = true,
    ProneBoost     = true,
}
_G.g_masterahsanyt_MagicState = _G.g_masterahsanyt_MagicState or {
    LastHash         = "",
    UpdateVersion    = 1,
    EnemyMarks       = {},
    OrigHitboxes     = {},
    ModdedPhysAssets = {},
    PhysAssetPatched = {},
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================
local _slua = rawget(_G, "slua")
local function g_masterahsanyt_Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end
local function g_masterahsanyt_GetSafeEnemyKey(enemy)
    if g_masterahsanyt_Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then
            return tostring(enemy:GetUniqueID())
        end
    end
    return tostring(enemy)
end

-- ============================================================================
-- AUTO-HEAD HOOK — every weapon-entity module, every method, every mode
-- ============================================================================
local AUTOHEAD_PATHS = {
    "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
    "GameLua.Logic.Weapon.ShootWeaponEntity",
    "GameLua.Logic.Weapon.ShootWeaponEntity_TPP",
    "GameLua.Logic.Weapon.ShootWeaponEntity_FPP",
    "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity_TPP",
    "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity_FPP",
    "GameLua.Logic.Weapon.WeaponEntity",
    "GameLua.Logic.Weapon.WeaponManager",
    "GameLua.Logic.Character.CharacterWeaponManager",
    "GameLua.Logic.Weapon.Bullet.BulletEntity",
    "GameLua.Logic.Weapon.Bullet.BulletHit",
    "GameLua.Logic.Weapon.HitScan.HitScanLogic",
    "GameLua.Mod.BaseMod.Common.Weapon.Bullet.BulletEntity",
}

local HEAD_PARTS_FALLBACK = {
    "BigHead", "Head", "head", "HEAD",
    "BigHeadBody", "HeadShot", "HeadPart",
}
local function g_masterahsanyt_ResolveHeadEnum(E)
    for _, k in ipairs(HEAD_PARTS_FALLBACK) do
        if E[k] ~= nil then return E[k] end
    end
    return nil
end

local function g_masterahsanyt_ResetAutoHeadHooks()
    for _, p in ipairs(AUTOHEAD_PATHS) do
        local m = package.loaded[p]
        if type(m) == "table" then
            m.__lunar_autoheadA = nil
            m.__lunar_autoheadB = nil
            m.__lunar_autoheadC = nil
            m.__lunar_autoheadD = nil
        end
    end
end

local function g_masterahsanyt_InstallAutoHeadHook()
    pcall(function()
        local okE, EAvatarDamagePosition = pcall(import, "EAvatarDamagePosition")
        if not okE or not EAvatarDamagePosition then return end
        local HEAD = g_masterahsanyt_ResolveHeadEnum(EAvatarDamagePosition)
        if HEAD == nil then return end

        for _, path in ipairs(AUTOHEAD_PATHS) do
            local hitLogic = package.loaded[path]
            if not hitLogic then
                pcall(function() hitLogic = require(path) end)
            end
            if type(hitLogic) == "table" then
                -- Primary getter
                if not hitLogic.__lunar_autoheadA then
                    local origA = hitLogic.GetHitBodyType
                    hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                        if _G.g_masterahsanyt_MagicConfig.Enabled then
                            return HEAD
                        end
                        if origA then return origA(self, ImpactResult, InImpactVec) end
                    end
                    hitLogic.__lunar_autoheadA = true
                end
                -- ByHitPos (long range hitscan)
                if not hitLogic.__lunar_autoheadB then
                    local origB = hitLogic.GetHitBodyTypeByHitPos
                    hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                        if _G.g_masterahsanyt_MagicConfig.Enabled then
                            return HEAD
                        end
                        if origB then return origB(self, InImpactVec) end
                    end
                    hitLogic.__lunar_autoheadB = true
                end
                -- Named alternates
                for _, fnName in ipairs({
                    "GetHitBodyTypeByHitResult",
                    "GetHitBodyTypeByPhysMaterial",
                    "GetHitBodyTypeByDamage",
                    "GetBodyTypeByHit",
                    "GetBodyTypeFromHit",
                    "GetBodyTypeByBoneName",
                    "GetBodyTypeByImpact",
                    "GetHitBodyTypeByBone",
                }) do
                    if type(hitLogic[fnName]) == "function"
                        and not hitLogic["__lunar_autohead_"..fnName] then
                        local origFn = hitLogic[fnName]
                        hitLogic[fnName] = function(self, ...)
                            if _G.g_masterahsanyt_MagicConfig.Enabled then
                                return HEAD
                            end
                            return origFn(self, ...)
                        end
                        hitLogic["__lunar_autohead_"..fnName] = true
                    end
                end
                -- Generic sweep for any remaining BodyType/DamagePosition getter
                for k, v in pairs(hitLogic) do
                    if type(v) == "function"
                        and type(k) == "string"
                        and not hitLogic["__lunar_autohead_"..k]
                        and (k:find("HitBodyType") or k:find("BodyType")
                             or k:find("DamagePosition") or k:find("HitPart")
                             or k:find("HitZone") or k:find("DamagePart"))
                        and (k:sub(1,3) == "Get" or k:sub(1,4) == "Calc"
                             or k:sub(1,5) == "Check" or k:sub(1,4) == "Find") then
                        local origFn = v
                        hitLogic[k] = function(self, ...)
                            if _G.g_masterahsanyt_MagicConfig.Enabled then
                                return HEAD
                            end
                            return origFn(self, ...)
                        end
                        hitLogic["__lunar_autohead_"..k] = true
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- MAGIC BULLET CORE — PhysicsAsset scaling (bots + players + all poses)
-- ============================================================================
local function g_masterahsanyt_GetFirstElemSafe(elemArray)
    if not elemArray then return nil end
    if type(elemArray.Num) == "function" and elemArray:Num() > 0
        and type(elemArray.Get) == "function" then
        return elemArray:Get(0)
    end
    if type(elemArray) == "table" and #elemArray > 0 then
        return elemArray[1]
    end
    return nil
end

-- Bucket bones to head / body / legs / arms. Broad matching so that every
-- model (default, skins, bots, event models) and every pose (stand / crouch /
-- prone) inflates correctly.
local function g_masterahsanyt_BoneBucket(bone, mHead, mBody, mLegs, mArms)
    if not bone then return nil end
    local b = string.lower(bone)
    if b:find("head", 1, true) or b:find("neck", 1, true)
        or b:find("jaw", 1, true) or b:find("face", 1, true)
        or b:find("skull", 1, true) or b:find("cranium", 1, true) then
        return mHead
    end
    if b:find("pelvis", 1, true) or b:find("spine", 1, true)
        or b:find("chest", 1, true) or b:find("torso", 1, true)
        or b:find("ribs", 1, true) or b:find("clavicle", 1, true)
        or b:find("hip", 1, true) or b:find("waist", 1, true) then
        return mBody
    end
    if b:find("thigh", 1, true) or b:find("calf", 1, true)
        or b:find("shin", 1, true) or b:find("foot", 1, true)
        or b:find("leg", 1, true) or b:find("toe", 1, true)
        or b:find("knee", 1, true) then
        return mLegs
    end
    if b:find("upperarm", 1, true) or b:find("lowerarm", 1, true)
        or b:find("arm", 1, true) or b:find("hand", 1, true)
        or b:find("finger", 1, true) or b:find("forearm", 1, true)
        or b:find("shoulder", 1, true) then
        return mArms
    end
    -- Unknown bone: scale by body so nothing is left untouched.
    return mBody
end

-- Detect prone / crouch so we can boost scales for the prone LOD problem.
local function g_masterahsanyt_IsProneOrCrouch(enemy)
    local pose = 0
    pcall(function()
        if type(enemy.GetPoseState) == "function" then
            pose = enemy:GetPoseState() or 0
        elseif enemy.PoseState ~= nil then
            pose = enemy.PoseState
        elseif enemy.bProne ~= nil and enemy.bProne then
            pose = 2
        elseif enemy.bIsCrouched ~= nil and enemy.bIsCrouched then
            pose = 1
        end
    end)
    return (pose == 2 or pose == 1), pose
end

local function g_masterahsanyt_ScalePhysAsset(PhysAsset, mHead, mBody, mLegs, mArms, Orig)
    local Setups = PhysAsset.SkeletalBodySetups
    if not Setups then return end
    local n = type(Setups.Num) == "function" and Setups:Num() or #Setups
    local limit = math.min(n, 250)
    for i = 1, limit do
        local BodySetup = type(Setups.Get) == "function"
            and Setups:Get(i-1) or Setups[i]
        if g_masterahsanyt_Valid(BodySetup) then
            local bone = tostring(BodySetup.BoneName or "")
            local scale = g_masterahsanyt_BoneBucket(bone, mHead, mBody, mLegs, mArms)
            if scale then
                local boneKey = string.lower(bone)
                local Agg = BodySetup.AggGeom
                local Boxes   = Agg and Agg.BoxElems   or BodySetup.BoxElems
                local Spheres = Agg and Agg.SphereElems or BodySetup.SphereElems
                local Sphyls  = Agg and Agg.SphylElems  or BodySetup.SphylElems
                local Convex  = Agg and Agg.ConvexElems or BodySetup.ConvexElems
                local box   = g_masterahsanyt_GetFirstElemSafe(Boxes)
                local sph   = g_masterahsanyt_GetFirstElemSafe(Spheres)
                local sphyl = g_masterahsanyt_GetFirstElemSafe(Sphyls)

                if not Orig[boneKey] then
                    Orig[boneKey] = {Box=nil, Sphere=nil, Sphyl=nil}
                    if box   then Orig[boneKey].Box    = {X=box.X, Y=box.Y, Z=box.Z} end
                    if sph   then Orig[boneKey].Sphere = {Radius=sph.Radius} end
                    if sphyl then Orig[boneKey].Sphyl  = {Radius=sphyl.Radius, Length=sphyl.Length} end
                end
                local O = Orig[boneKey]
                if O.Box and box then
                    box.X = O.Box.X * scale
                    box.Y = O.Box.Y * scale
                    box.Z = O.Box.Z * scale
                    if type(Boxes.Set) == "function" then Boxes:Set(0,box) else Boxes[1]=box end
                    if Agg then Agg.BoxElems = Boxes; BodySetup.AggGeom = Agg
                    else BodySetup.BoxElems = Boxes end
                end
                if O.Sphere and sph then
                    sph.Radius = O.Sphere.Radius * scale
                    if type(Spheres.Set) == "function" then Spheres:Set(0,sph) else Spheres[1]=sph end
                    if Agg then Agg.SphereElems = Spheres; BodySetup.AggGeom = Agg
                    else BodySetup.SphereElems = Spheres end
                end
                if O.Sphyl and sphyl then
                    sphyl.Radius = O.Sphyl.Radius * scale
                    sphyl.Length = O.Sphyl.Length * scale
                    if type(Sphyls.Set) == "function" then Sphyls:Set(0,sphyl) else Sphyls[1]=sphyl end
                    if Agg then Agg.SphylElems = Sphyls; BodySetup.AggGeom = Agg
                    else BodySetup.SphylElems = Sphyls end
                end
            end
        end
    end
end

local function g_masterahsanyt_ApplyMagicBullet(localPlayer, allCharacters)
    local C = _G.g_masterahsanyt_MagicConfig
    local S = _G.g_masterahsanyt_MagicState
    if not g_masterahsanyt_Valid(localPlayer) then return end

    local baseHead = C.Enabled and (tonumber(C.Head) or 1.0) or 1.0
    local baseBody = C.Enabled and (tonumber(C.Body) or 1.0) or 1.0
    local baseLegs = C.Enabled and (tonumber(C.Legs) or 1.0) or 1.0
    local baseArms = baseBody

    local hash = C.Enabled
        and ("M_"..tostring(baseHead).."_"..tostring(baseBody).."_"..tostring(baseLegs)
             .."_"..tostring(C.LongRangeBoost).."_"..tostring(C.ProneBoost))
        or  "OFF"
    if S.LastHash ~= hash then
        S.UpdateVersion = (S.UpdateVersion or 0) + 1
        S.LastHash = hash
    end

    local validKeys = {}
    for _, enemy in pairs(allCharacters) do
        if g_masterahsanyt_Valid(enemy) and enemy ~= localPlayer then
            validKeys[g_masterahsanyt_GetSafeEnemyKey(enemy)] = true
        end
    end
    for key, data in pairs(S.EnemyMarks) do
        if not validKeys[key] then
            data.enemy = nil
            S.EnemyMarks[key] = nil
        end
    end

    for _, enemy in pairs(allCharacters) do
        -- NOTE: no TeamID filter here — bots can be on teams but models can
        -- be tagged weird on custom maps. We only skip self.
        if g_masterahsanyt_Valid(enemy) and enemy ~= localPlayer then
            local dead = false
            pcall(function()
                if type(enemy.IsDead) == "function" then dead = enemy:IsDead()
                elseif enemy.bIsDead ~= nil then dead = enemy.bIsDead
                elseif enemy.bIsDeadFlag ~= nil then dead = enemy.bIsDeadFlag end
                if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then
                    dead = true
                end
            end)
            if not dead then
                -- Per-enemy scale: prone/crouch gets a bit extra so the
                -- low-profile hitbox still overlaps the shot ray.
                local isProne, pose = g_masterahsanyt_IsProneOrCrouch(enemy)
                local mHead, mBody, mLegs, mArms = baseHead, baseBody, baseLegs, baseArms
                if C.Enabled and C.ProneBoost and isProne then
                    mHead = mHead + 0.35
                    mBody = mBody + 0.30
                    mLegs = mLegs + 0.25
                    mArms = mArms + 0.30
                end

                local eKey = g_masterahsanyt_GetSafeEnemyKey(enemy)
                local mark = S.EnemyMarks[eKey] or { enemy = enemy }
                S.EnemyMarks[eKey] = mark
                mark.enemy = enemy

                pcall(function()
                    local mesh = enemy.Mesh
                    if not g_masterahsanyt_Valid(mesh) then return end
                    local uid = type(enemy.GetUniqueID) == "function"
                        and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)

                    local perEnemyHash = hash.."_P"..tostring(pose)
                    if mark.hash == perEnemyHash
                        and mark.targetId == uid
                        and mark.mesh == mesh then
                        return
                    end

                    local PhysAsset = mesh.PhysicsAssetOverride
                    if not g_masterahsanyt_Valid(PhysAsset) and mesh.SkeletalMesh then
                        PhysAsset = mesh.SkeletalMesh.PhysicsAsset
                    end
                    if not g_masterahsanyt_Valid(PhysAsset) then return end
                    if not PhysAsset.SkeletalBodySetups then return end

                    local PhysName = "DefaultPhys"
                    pcall(function() PhysName = PhysAsset:GetName() end)
                    -- Cache key must include scale so prone & stand use separate entries.
                    local cacheKey = PhysName.."_"..tostring(mHead).."_"..tostring(mBody).."_"..tostring(mLegs)
                    local cacheEntry = S.ModdedPhysAssets[cacheKey]
                    local needsRescale = (not cacheEntry
                        or cacheEntry.asset ~= PhysAsset)
                    if needsRescale then
                        S.OrigHitboxes[cacheKey] = S.OrigHitboxes[cacheKey] or {}
                        g_masterahsanyt_ScalePhysAsset(PhysAsset, mHead, mBody, mLegs, mArms, S.OrigHitboxes[cacheKey])
                        S.ModdedPhysAssets[cacheKey] = { asset = PhysAsset }
                    end

                    if mesh.SetPhysicsAsset then mesh:SetPhysicsAsset(PhysAsset) end
                    mesh.PhysicsAssetOverride = PhysAsset

                    -- Force both LOD mesh and the body instance onto the same
                    -- asset so long-range and short-range both use inflated
                    -- hitboxes.
                    pcall(function()
                        if C.LongRangeBoost and enemy.SkeletalMeshComponent then
                            enemy.SkeletalMeshComponent:SetPhysicsAsset(PhysAsset)
                        end
                    end)
                    pcall(function()
                        if C.LongRangeBoost and enemy.BodySetup then
                            enemy.BodySetup = PhysAsset
                        end
                    end)

                    mark.hash = perEnemyHash
                    mark.targetId = uid
                    mark.mesh = mesh
                end)
            end
        end
    end
end

-- ============================================================================
-- MAGIC TICK
-- ============================================================================
local function g_masterahsanyt_MagicTick()
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return end
    local GDP = require("GameLua.GameCore.Data.GameplayData")
    local pc  = GDP.GetPlayerController()
    if not g_masterahsanyt_Valid(pc) then return end

    if _G.__lastMagicPC ~= pc then
        _G.__lastMagicPC = pc
        local S = _G.g_masterahsanyt_MagicState
        S.EnemyMarks       = {}
        S.OrigHitboxes     = {}
        S.ModdedPhysAssets = {}
        S.PhysAssetPatched = {}
        S.LastHash         = ""
        g_masterahsanyt_ResetAutoHeadHooks()
        print("[Magic] New match — state + auto-head hooks reset")
    end

    local me = pc:GetPlayerCharacterSafety()
    if not g_masterahsanyt_Valid(me) then
        _G.g_masterahsanyt_MagicState.EnemyMarks = {}
        return
    end

    pcall(g_masterahsanyt_InstallAutoHeadHook)

    local all = GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters() or {}
    g_masterahsanyt_ApplyMagicBullet(me, all)
end

-- ============================================================================
-- LUNAR FEATURES RUNTIME
-- ============================================================================
_G.LunarFeatures = _G.LunarFeatures or {
    Settings = {}, Diagnostics = {Errors=0}, TimerClock = 0,
}
local F = _G.LunarFeatures

-- ============================================================================
-- SETTINGS PERSISTENCE
-- ============================================================================
local function g_masterahsanyt_MagicPaths()
    local file = "MASTERAHSAN_MAGIC_V1_settings.lua"
    return {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "ShadowTrackerExtra/Saved/SaveGames/"..file,
        file,
    }
end
F.SettingsReadPath = nil
F.Save = function(force)
    if not io or type(io.open) ~= "function" then return false end
    local C = _G.g_masterahsanyt_MagicConfig
    local lines = {
        "return {",
        "  Enabled        = "..tostring(C.Enabled==true)..",",
        "  Head           = "..tostring(C.Head)..",",
        "  Body           = "..tostring(C.Body)..",",
        "  Legs           = "..tostring(C.Legs)..",",
        "  LongRangeBoost = "..tostring(C.LongRangeBoost==true)..",",
        "  ProneBoost     = "..tostring(C.ProneBoost==true)..",",
        "}",
    }
    local payload = table.concat(lines, "\n")
    local paths = F.SettingsReadPath and {F.SettingsReadPath} or g_masterahsanyt_MagicPaths()
    for _, path in ipairs(paths) do
        local ok, f = pcall(io.open, path..".tmp", "w")
        if ok and f then
            local wrote = pcall(function()
                f:write(payload)
                if f.flush then f:flush() end
                f:close()
            end)
            if wrote and os.rename then
                pcall(os.rename, path..".tmp", path)
                F.SettingsReadPath = path
                return true
            end
        end
    end
    return false
end
F.MarkDirty = function(immediate) F.Dirty = true; if immediate then F.Save(true) end end
F.Error = function(area, err)
    F.Diagnostics.Errors = F.Diagnostics.Errors + 1
    F.Diagnostics.LastError = area..": "..tostring(err)
end
F.Now = function()
    local t
    pcall(function()
        local w = slua and slua.getWorld and slua.getWorld()
        local GS = import("GameplayStatics")
        if GS and w then t = GS.GetRealTimeSeconds(w) end
    end)
    return tonumber(t) or F.TimerClock
end
F.Wake = function() end
do
    local ok, f = pcall(io.open, g_masterahsanyt_MagicPaths()[1], "r")
    if ok and f then
        local text = f:read("*a"); f:close()
        if type(text) == "string" then
            local C = _G.g_masterahsanyt_MagicConfig
            local function g(k)
                local v = text:match(k.."%s*=%s*(%a+)")
                if v == "true" then return true elseif v == "false" then return false end
                local n = text:match(k.."%s*=%s*([%d%.%-]+)")
                if n then return tonumber(n) end
            end
            C.Enabled = g("Enabled") or C.Enabled
            C.Head    = tonumber(g("Head")) or C.Head
            C.Body    = tonumber(g("Body")) or C.Body
            C.Legs    = tonumber(g("Legs")) or C.Legs
            if g("LongRangeBoost") ~= nil then C.LongRangeBoost = g("LongRangeBoost") end
            if g("ProneBoost") ~= nil then C.ProneBoost = g("ProneBoost") end
        end
    end
end

-- ============================================================================
-- NATIVE SETTINGS PAGE
-- ============================================================================
local g_masterahsanyt_EnsureHackMenu
do
    local VERSION = "MagicMenu.V3"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        local found = false
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "MagicMenu" then
                if found then table.remove(catalog, i) else catalog[i] = page; found = true end
            end
        end
        if not found then table.insert(catalog, 1, page) end
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__MagicMenuUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    record = {Version = VERSION, Original = show}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__MagicMenuUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function buildPage(F, AliasMap, sliderReady)
        local function slider(key, label, lo, hi, getter, setter)
            return {
                Key = key, UI = AliasMap.Slider, Text = label,
                MinValue = lo, MaxValue = hi, min = lo, max = hi,
                GetFunc = getter,
                SetFunc = function(c, v)
                    setter(v)
                    if F.Save then F.Save(true) end
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    return true
                end,
            }
        end
        local Stack = {
            {
                Key = "Magic_Enabled", UI = AliasMap.Switcher, Text = "Magic Bullet",
                EventType = 0xF00D, EventID = 1,
                GetFunc = function() return _G.g_masterahsanyt_MagicConfig.Enabled end,
                SetFunc = function(c, v)
                    _G.g_masterahsanyt_MagicConfig.Enabled = (v == true or v == 1)
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    if F.Save then F.Save(true) end
                    return true
                end,
            },
            {
                Key = "Magic_LongRange", UI = AliasMap.Switcher, Text = "Long Range Boost",
                EventType = 0xF00D, EventID = 2,
                GetFunc = function() return _G.g_masterahsanyt_MagicConfig.LongRangeBoost end,
                SetFunc = function(c, v)
                    _G.g_masterahsanyt_MagicConfig.LongRangeBoost = (v == true or v == 1)
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    if F.Save then F.Save(true) end
                    return true
                end,
            },
            {
                Key = "Magic_Prone", UI = AliasMap.Switcher, Text = "Prone Boost",
                EventType = 0xF00D, EventID = 3,
                GetFunc = function() return _G.g_masterahsanyt_MagicConfig.ProneBoost end,
                SetFunc = function(c, v)
                    _G.g_masterahsanyt_MagicConfig.ProneBoost = (v == true or v == 1)
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    if F.Save then F.Save(true) end
                    return true
                end,
            },
            slider("Magic_Head", "  Head scale (200-350)", 200, 350,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Head - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Head = 1.0 + (v/100) end),
            slider("Magic_Body", "  Body scale (200-350)", 200, 350,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Body - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Body = 1.0 + (v/100) end),
            slider("Magic_Legs", "  Legs scale (150-300)", 150, 300,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Legs - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Legs = 1.0 + (v/100) end),
        }
        return {
            Key = "MagicMenu", Text = "Magic Menu",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_Magic_Bullet", Text = "MAGIC BULLET", Stack = Stack },
            },
        }
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages   = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")
        local sliderReady = type(aliases.Slider) == "table"
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.SliderReady = sliderReady
        pages.MagicMenu = state.Page
        state.Registered = register(catalog, state.Page)
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "MAGIC_MENU_NATIVE_V3"
        else
            state.LastError = "SETTINGS_UI_MANAGER_NOT_READY"
        end
        return state.Ready
    end
    g_masterahsanyt_EnsureHackMenu = function()
        local state = runtime()
        state.Ensure = g_masterahsanyt_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        local okHook, hookErr = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookErr)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        return {
            version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            sliderReady = state.SliderReady == true,
            lastShowUIInjected = state.LastShowUIInjected,
        }
    end
end

-- ============================================================================
-- SINGLE-TIMER SCHEDULER
-- ============================================================================
local g_masterahsanyt_ESPRunnerToken = {}
if type(_G.__MasterShotESPCleanup) == "function" then pcall(_G.__MasterShotESPCleanup) end
_G.__MasterShotESPRunner = g_masterahsanyt_ESPRunnerToken
_G.__MasterShotESPCleanup = function()
    _G.g_masterahsanyt_MagicState.EnemyMarks = {}
end
local g_masterahsanyt_ESPDiagnostics = {Updates=0, Errors=0, LastError=nil}
_G.g_masterahsanyt_ESPDiagnostics = g_masterahsanyt_ESPDiagnostics
local g_masterahsanyt_ESPTicker = nil
pcall(function() g_masterahsanyt_ESPTicker = require("common.time_ticker") end)

g_masterahsanyt_ShotESP = g_masterahsanyt_ShotESP or { Running = false, TimerClock = 0, Now = 0 }

local g_masterahsanyt_ESPTick

local function g_masterahsanyt_ESPSchedule(delay)
    delay = math.max(0.001, math.min(0.50, tonumber(delay) or 0.40))
    if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken then return end

    if not g_masterahsanyt_ESPTicker or not g_masterahsanyt_ESPTicker.AddTimerOnce then
        local okT, ticker = pcall(require, "common.time_ticker")
        if okT and ticker then g_masterahsanyt_ESPTicker = ticker end
        if not g_masterahsanyt_ESPTicker or not g_masterahsanyt_ESPTicker.AddTimerOnce then
            g_masterahsanyt_ESPDiagnostics.LastError = "common.time_ticker.AddTimerOnce unavailable"
            pcall(function()
                local GDP = require("GameLua.GameCore.Data.GameplayData")
                local pc = GDP.GetPlayerController and GDP.GetPlayerController()
                if pc and pc.AddGameTimer then
                    pc:AddGameTimer(0.5, false, function()
                        if _G.__MasterShotESPRunner == g_masterahsanyt_ESPRunnerToken then
                            g_masterahsanyt_ESPSchedule(0.001)
                        end
                    end)
                end
            end)
            return
        end
    end

    local serial = (g_masterahsanyt_ESPRunnerToken.Serial or 0) + 1
    g_masterahsanyt_ESPRunnerToken.Serial = serial
    g_masterahsanyt_ESPRunnerToken.Due = F.Now() + delay
    local ok, err = pcall(g_masterahsanyt_ESPTicker.AddTimerOnce, delay, function()
        if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken
            or g_masterahsanyt_ESPRunnerToken.Serial ~= serial then return end
        g_masterahsanyt_ESPRunnerToken.Due = nil
        g_masterahsanyt_ShotESP.TimerClock = g_masterahsanyt_ShotESP.TimerClock + delay
        g_masterahsanyt_ESPTick()
    end)
    if not ok or err == false then
        g_masterahsanyt_ESPRunnerToken.Due = nil
        g_masterahsanyt_ESPDiagnostics.Errors = g_masterahsanyt_ESPDiagnostics.Errors + 1
        g_masterahsanyt_ESPDiagnostics.LastError = tostring(err)
        pcall(function()
            local GDP = require("GameLua.GameCore.Data.GameplayData")
            local pc = GDP.GetPlayerController and GDP.GetPlayerController()
            if pc and pc.AddGameTimer then
                pc:AddGameTimer(0.5, false, function()
                    if _G.__MasterShotESPRunner == g_masterahsanyt_ESPRunnerToken then
                        g_masterahsanyt_ESPSchedule(0.001)
                    end
                end)
            end
        end)
    end
end

g_masterahsanyt_ESPTick = function()
    local token = g_masterahsanyt_ESPRunnerToken
    if _G.__MasterShotESPRunner ~= token then return end
    local now = F.Now()
    F.TimerClock = g_masterahsanyt_ShotESP.TimerClock

    local ok, err = pcall(g_masterahsanyt_MagicTick)
    g_masterahsanyt_ESPDiagnostics.LastUpdateOK = ok
    g_masterahsanyt_ESPDiagnostics.Updates = g_masterahsanyt_ESPDiagnostics.Updates + 1
    if not ok then
        g_masterahsanyt_ESPDiagnostics.Errors = g_masterahsanyt_ESPDiagnostics.Errors + 1
        g_masterahsanyt_ESPDiagnostics.LastError = tostring(err)
        F.Error("Magic.Tick", err)
    end

    token.LastTick = now

    g_masterahsanyt_ESPSchedule(0.40)
end

_G.g_masterahsanyt_MasterShotESPForceRefresh = function()
    if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken then return end
    g_masterahsanyt_ESPRunnerToken.Due = nil
    g_masterahsanyt_ESPSchedule(0.001)
end

-- ============================================================================
-- FEATURE RUNTIME
-- ============================================================================
F.V1Due = 0; F.AimDue = 0; F.IpadDue = 0; F.SaveDue = 0
F.Pump = function(now)
    F.TimerClock = g_masterahsanyt_ShotESP.TimerClock
    now = now or F.Now()
    if F.Dirty and now >= F.SaveDue then pcall(F.Save, true); F.SaveDue = now + 0.5 end
end
F.NextInterval = function(now)
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return 0.50 end
    return 0.40
end
F.Wake = function()
    if F.Token and F.Token.Stopped then return end
    local due = g_masterahsanyt_ESPRunnerToken.Due
    if not due or due - F.Now() > 0.002 then g_masterahsanyt_ESPSchedule(0.001) end
end

-- ============================================================================
-- SETTINGS MAINTENANCE
-- ============================================================================
local g_masterahsanyt_FastRunnerToken = {}
local previousSettingsRunner = _G.__MasterShotFastRunner
if type(previousSettingsRunner) == "table"
    and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function()
        previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer)
    end)
end
_G.__MasterShotFastRunner = g_masterahsanyt_FastRunnerToken

local function g_masterahsanyt_FastTick()
    if _G.__MasterShotFastRunner ~= g_masterahsanyt_FastRunnerToken then return end
    local render = _G.__MasterShotESPRunner
    if not render or not render.Due then
        pcall(g_masterahsanyt_MagicTick)
    end
end

do
    local token = g_masterahsanyt_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__MasterShotFastRunner ~= token then
            if token.Timer and token.Owner then
                pcall(function() token.Owner:RemoveGameTimer(token.Timer) end)
            end
            token.Timer = nil
            return
        end
        g_masterahsanyt_FastTick()
        g_masterahsanyt_StartSettingsMaintenance()
    end
    g_masterahsanyt_StartSettingsMaintenance = function(owner)
        if _G.__MasterShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then
            return true
        end
        if token.Timer and token.Owner then
            pcall(function() token.Owner:RemoveGameTimer(token.Timer) end)
        end
        token.Timer, token.Owner, token.Provider = nil, nil, nil
        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate)
                or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do
                if entry.Object == candidate then return end
            end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function()
            if GameplayData.GetPlayerController then
                pc = GameplayData.GetPlayerController()
            end
        end)
        if not valid(pc) then
            pcall(function()
                if slua_GameFrontendHUD then
                    pc = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
        end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function()
                return entry.Object:AddGameTimer(1.0, true, callback)
            end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_masterahsanyt_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else
                token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE"
            end
        else
            if package and package.loaded
                and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end

-- ============================================================================
-- STARTUP
-- ============================================================================
if _G.LunarLoginRuntime then _G.LunarLoginRuntime.NeedsUpdate = false end
g_masterahsanyt_FastTick()
g_masterahsanyt_StartSettingsMaintenance()
g_masterahsanyt_ShotESP.Running = true
g_masterahsanyt_ESPTick()
end -- startBaselineHacks

local ok, startError = pcall(startBaselineHacks)
if not ok then
    _G.LunarOptionalStartupError = tostring(startError)
    if _G.LunarFeatures and _G.LunarFeatures.Error then
        _G.LunarFeatures.Error("Startup", startError)
    end
end

return nil

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  },
  {
    FishingFeature = "GameLua.Mod.Library.GamePlay.Actor.Fishing.FishingFeature"
  },
  {
    PlayerThemeItemsFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerThemeItemsFeature"
  }
}, "BRPlayerCharacterBase")
