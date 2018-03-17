--
--Local variables : Please do not touch theses variables
--

if(config.useCopWhitelist == true) then
	isCop = false
else
	isCop = true
end
local isInService = false
local rank = "unknown"
local checkpoints = {}
local policeHeli = nil
local handCuffed = false
local isAlreadyDead = false
local allServiceCops = {}
local blipsCops = {}
local drag = false
local officerDrag = -1

anyMenuOpen = {
	menuName = "",
	isActive = false
}

--It isn't recommanded to use this array directly, please just use it in order to retrieve quickly the key code your are searching
--[[
local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}]]

local clockInStation = {
  {x=850.156677246094, y=-1283.92004394531, z=28.0047378540039}, -- La Mesa
  {x=457.956909179688, y=-992.72314453125, z=30.6895866394043}, -- Mission Row
  {x=1856.91320800781, y=3689.50073242188, z=34.2670783996582}, -- Sandy Shore
  {x=-450.063201904297, y=6016.5751953125, z=31.7163734436035} -- Paleto Bay
}

local garageStation = {
	{x=1897.475966796875, y=-3720.15681152344, z=33.0386586761475},  -- La Mesa
	{x=1897.475966796875, y=-3720.15681152344, z=33.0386586761475},  -- Mission Row
	{x=1897.475966796875, y=-3720.15681152344, z=33.0386586761475}, -- Sandy Shore
	{x=1897.475966796875, y=-3720.15681152344, z=33.0386586761475} -- Paleto Bay
}

local heliStation = {
	{x=1897.475966796875, y=-3720.15681152344, z=33.0386586761475} -- Mission Row
}

local armoryStation = {
	{x=452.119966796875, y=-980.061966796875, z=30.690966796875} -- Mission Row
}

--
--Events handlers
--

if(config.useCopWhitelist == true) then
	AddEventHandler("playerSpawned", function()
		TriggerServerEvent("police:checkIsCop")
	end)
end

if(config.useCopWhitelist == true) then
	RegisterNetEvent('police:receiveIsCop')
	AddEventHandler('police:receiveIsCop', function(result)
		if(result == "unknown") then
			if(config.useCopWhitelist == true) then
				isCop = false
			end
		else
			isCop = true
			rank = result
		end
	end)
end

if(config.useCopWhitelist == true) then
	RegisterNetEvent('police:nowCop')
	AddEventHandler('police:nowCop', function()
		isCop = true
	end)
end

if(config.useCopWhitelist == true) then
	RegisterNetEvent('police:noLongerCop')
	AddEventHandler('police:noLongerCop', function()
		if(config.useCopWhitelist == true) then
			isCop = false
		end
		isInService = false
		
		if(config.enableOutfits == true) then
			RemoveAllPedWeapons(GetPlayerPed(-1))
			TriggerServerEvent("skin_customization:SpawnPlayer")
		else
			local model = GetHashKey("a_m_y_mexthug_01")

			RequestModel(model)
			while not HasModelLoaded(model) do
				RequestModel(model)
				Citizen.Wait(0)
			end
		 
			SetPlayerModel(PlayerId(), model)
			SetModelAsNoLongerNeeded(model)
			RemoveAllPedWeapons(GetPlayerPed(-1))
		end
		
		if(policeHeli ~= nil) then
			SetEntityAsMissionEntity(policeHeli, true, true)
			Citizen.InvokeNative(0xEA386986E786A54F, Citizen.PointerValueIntInitialized(policeHeli))
			policeHeli = nil
		end
		
		ServiceOff()
	end)
end

RegisterNetEvent('police:getArrested')
AddEventHandler('police:getArrested', function()
	handCuffed = not handCuffed
	if(handCuffed) then
		TriggerEvent("police:notify",  "CHAR_ANDREAS", 1, txt[config.lang]["title_notification"], false, txt[config.lang]["now_cuffed"])
	else
		TriggerEvent("police:notify",  "CHAR_ANDREAS", 1, txt[config.lang]["title_notification"], false, txt[config.lang]["now_uncuffed"])
		drag = false
	end
end)

--Inspired from emergency for request system (by Jyben : https://forum.fivem.net/t/release-job-save-people-be-a-hero-paramedic-emergency-coma-ko/19773)
local lockAskingFine = false
RegisterNetEvent('police:payFines')
AddEventHandler('police:payFines', function(amount, sender)
	Citizen.CreateThread(function()
		
		if(lockAskingFine ~= true) then
			lockAskingFine = true
			local notifReceivedAt = GetGameTimer()
			Notification(txt[config.lang]["info_fine_request_before_amount"]..amount..txt[config.lang]["info_fine_request_after_amount"])
			while(true) do
				Wait(0)
				
				if (GetTimeDifference(GetGameTimer(), notifReceivedAt) > 15000) then
					TriggerServerEvent('police:finesETA', sender, 2)
					Notification(txt[config.lang]["request_fine_expired"])
					lockAskingFine = false
					break
				end
				
				if IsControlPressed(1, 246) then
					if(config.useModifiedBanking == true) then
						TriggerServerEvent('bank:withdrawAmende', amount)
					else
						TriggerServerEvent('bank:withdraw', amount)
					end
					Notification(txt[config.lang]["pay_fine_success_before_amount"]..amount..txt[config.lang]["pay_fine_success_after_amount"])
					TriggerServerEvent('police:finesETA', sender, 0)
					lockAskingFine = false
					break
				end
				
				if IsControlPressed(1, 45) then
					TriggerServerEvent('police:finesETA', sender, 3)
					lockAskingFine = false
					break
				end
			end
		else
			TriggerServerEvent('police:finesETA', sender, 1)
		end
	end)
end)

-- Copy/paste from fs_freeroam (by FiveM-Script : https://forum.fivem.net/t/alpha-fs-freeroam-0-1-4-fivem-scripts/14097)
RegisterNetEvent("police:notify")
AddEventHandler("police:notify", function(icon, type, sender, title, text)
    Citizen.CreateThread(function()
		Wait(1)
		SetNotificationTextEntry("STRING");
		AddTextComponentString(text);
		SetNotificationMessage(icon, icon, true, type, sender, title, text);
		DrawNotification(false, true);
    end)
end)

if(config.useVDKInventory == true) then
	RegisterNetEvent('police:dropIllegalItem')
	AddEventHandler('police:dropIllegalItem', function(id)
		TriggerEvent("player:looseItem", tonumber(id), exports.vdk_inventory:getQuantity(id))
	end)
end

--Piece of code given by Thefoxeur54
RegisterNetEvent('police:unseatme')
AddEventHandler('police:unseatme', function(t)
	local ped = GetPlayerPed(t)        
	ClearPedTasksImmediately(ped)
	plyPos = GetEntityCoords(GetPlayerPed(-1),  true)
	local xnew = plyPos.x+2
	local ynew = plyPos.y+2
   
	SetEntityCoords(GetPlayerPed(-1), xnew, ynew, plyPos.z)
end)

RegisterNetEvent('police:toggleDrag')
AddEventHandler('police:toggleDrag', function(t)
	if(handCuffed) then
		drag = not drag
		officerDrag = t
	end
end)

RegisterNetEvent('police:forcedEnteringVeh')
AddEventHandler('police:forcedEnteringVeh', function(veh)
	if(handCuffed) then
		local pos = GetEntityCoords(GetPlayerPed(-1))
		local entityWorld = GetOffsetFromEntityInWorldCoords(GetPlayerPed(-1), 0.0, 20.0, 0.0)

		local rayHandle = CastRayPointToPoint(pos.x, pos.y, pos.z, entityWorld.x, entityWorld.y, entityWorld.z, 10, GetPlayerPed(-1), 0)
		local _, _, _, _, vehicleHandle = GetRaycastResult(rayHandle)

		if vehicleHandle ~= nil then
			SetPedIntoVehicle(GetPlayerPed(-1), vehicleHandle, 1)
		end
	end
end)

RegisterNetEvent('police:removeWeapons')
AddEventHandler('police:removeWeapons', function()
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
end)

if(config.enableOtherCopsBlips == true) then
	RegisterNetEvent('police:resultAllCopsInService')
	AddEventHandler('police:resultAllCopsInService', function(array)
		allServiceCops = array
		enableCopBlips()
	end)
end

if(config.useModifiedEmergency == true) then
	RegisterNetEvent('es_em:cl_ResPlayer')
	AddEventHandler('es_em:cl_ResPlayer', function()
		if(isCop and isInService) then
			ServiceOff()
		end
		
		if(handCuffed == true) then
			handCuffed = false
		end
	end)
end

--
--Functions
--

function Notification(msg)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(msg)
	DrawNotification(0,1)
end

function drawNotification(text)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(text)
	DrawNotification(false, false)
end

--From Player Blips and Above Head Display (by Scammer : https://forum.fivem.net/t/release-scammers-script-collection-09-03-17/3313)
function enableCopBlips()

	for k, existingBlip in pairs(blipsCops) do
        RemoveBlip(existingBlip)
    end
	blipsCops = {}
	
	local localIdCops = {}
	for id = 0, 64 do
		if(NetworkIsPlayerActive(id) and GetPlayerPed(id) ~= GetPlayerPed(-1)) then
			for i,c in pairs(allServiceCops) do
				if(i == GetPlayerServerId(id)) then
					localIdCops[id] = c
					break
				end
			end
		end
	end
	
	for id, c in pairs(localIdCops) do
		local ped = GetPlayerPed(id)
		local blip = GetBlipFromEntity(ped)
		
		if not DoesBlipExist( blip ) then

			blip = AddBlipForEntity( ped )
			SetBlipSprite( blip, 1 )
			Citizen.InvokeNative( 0x5FBCA48327B914DF, blip, true )
			HideNumberOnBlip( blip )
			SetBlipNameToPlayerName( blip, id )
			
			SetBlipScale( blip,  0.85 )
			SetBlipAlpha( blip, 255 )
			
			table.insert(blipsCops, blip)
		else
			
			blipSprite = GetBlipSprite( blip )
			
			HideNumberOnBlip( blip )
			if blipSprite ~= 1 then
				SetBlipSprite( blip, 1 )
				Citizen.InvokeNative( 0x5FBCA48327B914DF, blip, true )
			end
			
			SetBlipNameToPlayerName( blip, id )
			SetBlipScale( blip,  0.85 )
			SetBlipAlpha( blip, 255 )
			
			table.insert(blipsCops, blip)
		end
	end
end

function GetPlayers()
    local players = {}

    for i = 0, 31 do
        if NetworkIsPlayerActive(i) then
            table.insert(players, i)
        end
    end

    return players
end

function GetClosestPlayer()
	local players = GetPlayers()
	local closestDistance = -1
	local closestPlayer = -1
	local ply = GetPlayerPed(-1)
	local plyCoords = GetEntityCoords(ply, 0)
	
	for index,value in ipairs(players) do
		local target = GetPlayerPed(value)
		if(target ~= ply) then
			local targetCoords = GetEntityCoords(GetPlayerPed(value), 0)
			local distance = Vdist(targetCoords["x"], targetCoords["y"], targetCoords["z"], plyCoords["x"], plyCoords["y"], plyCoords["z"])
			if(closestDistance == -1 or closestDistance > distance) then
				closestPlayer = value
				closestDistance = distance
			end
		end
	end
	
	return closestPlayer, closestDistance
end

function drawTxt(text,font,centre,x,y,scale,r,g,b,a)
	SetTextFont(font)
	SetTextProportional(0)
	SetTextScale(scale, scale)
	SetTextColour(r, g, b, a)
	SetTextDropShadow(0, 0, 0, 0,255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(centre)
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(x , y)
end

function isNearTakeService()
	local distance = 10000
	local pos = {}
	for i = 1, #clockInStation do
		local coords = GetEntityCoords(GetPlayerPed(-1), 0)
		local currentDistance = Vdist(clockInStation[i].x, clockInStation[i].y, clockInStation[i].z, coords.x, coords.y, coords.z)
		if(currentDistance < distance) then
			distance = currentDistance
			pos = clockInStation[i]
		end
	end
	
	if anyMenuOpen.menuName == "cloackroom" and anyMenuOpen.isActive and distance > 3 then
		CloseMenu()
	end
	if(distance < 30) then
		DrawMarker(1, pos.x, pos.y, pos.z-1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 155, 255, 200, 0, 0, 2, 0, 0, 0, 0)
	end
	if(distance < 2) then
		return true
	end
end

function isNearStationGarage()
	local distance = 10000
	local pos = {}
	for i = 1, #garageStation do
		local coords = GetEntityCoords(GetPlayerPed(-1), 0)
		local currentDistance = Vdist(garageStation[i].x, garageStation[i].y, garageStation[i].z, coords.x, coords.y, coords.z)
		if(currentDistance < distance) then
			distance = currentDistance
			pos = garageStation[i]
		end
	end
	
	if anyMenuOpen.menuName == "garage" and anyMenuOpen.isActive and distance > 5 then
		CloseMenu()
	end
	if(distance < 30) then
		DrawMarker(1, pos.x, pos.y, pos.z-1, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 0, 155, 255, 200, 0, 0, 2, 0, 0, 0, 0)
	end
	if(distance < 2) then
		return true
	end
end

function isNearHelicopterStation()
	local distance = 10000
	local pos = {}
	for i = 1, #heliStation do
		local coords = GetEntityCoords(GetPlayerPed(-1), 0)
		local currentDistance = Vdist(heliStation[i].x, heliStation[i].y, heliStation[i].z, coords.x, coords.y, coords.z)
		if(currentDistance < distance) then
			distance = currentDistance
			pos = heliStation[i]
		end
	end
	
	if(distance < 30) then
		DrawMarker(1, pos.x, pos.y, pos.z-1, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 1.0, 0, 155, 255, 200, 0, 0, 2, 0, 0, 0, 0)
	end
	if(distance < 2) then
		return true
	end
end

function isNearArmory()
	local distance = 10000
	local pos = {}
	for i = 1, #armoryStation do
		local coords = GetEntityCoords(GetPlayerPed(-1), 0)
		local currentDistance = Vdist(armoryStation[i].x, armoryStation[i].y, armoryStation[i].z, coords.x, coords.y, coords.z)
		if(currentDistance < distance) then
			distance = currentDistance
			pos = armoryStation[i]
		end
	end
	
	if (anyMenuOpen.menuName == "armory" or anyMenuOpen.menuName == "armory-weapon_list") and anyMenuOpen.isActive and distance > 2 then
		CloseMenu()
	end
	if(distance < 30) then
		DrawMarker(1, pos.x, pos.y, pos.z-1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 155, 255, 200, 0, 0, 2, 0, 0, 0, 0)
	end
	if(distance < 2) then
		return true
	end
end

function ServiceOn()
	isInService = true
	if(config.useJobSystem == true) then
		TriggerServerEvent("jobssystem:jobs", config.job.officer_on_duty_job_id)
	end
	TriggerServerEvent("police:takeService")
end

function ServiceOff()
	isInService = false
	if(config.useJobSystem == true) then
		TriggerServerEvent("jobssystem:jobs", config.job.officer_not_on_duty_job_id)
	end
	TriggerServerEvent("police:breakService")
	
	if(config.enableOtherCopsBlips == true) then
		allServiceCops = {}
		
		for k, existingBlip in pairs(blipsCops) do
			RemoveBlip(existingBlip)
		end
		blipsCops = {}
	end
end

function DisplayHelpText(str)
	SetTextComponentFormat("STRING")
	AddTextComponentString(str)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

function CloseMenu()
	SendNUIMessage({
		action = "close"
	})
	
	anyMenuOpen.menuName = ""
	anyMenuOpen.isActive = false
end

RegisterNUICallback('sendAction', function(data, cb)
	_G[data.action]()
    cb('ok')
end)

--
--Threads
--

local alreadyDead = false

Citizen.CreateThread(function()

	--Embedded NeverWanted script // Non loop part
	if(config.enableNeverWanted == true) then
		SetPoliceIgnorePlayer(PlayerId(), true)
		SetDispatchCopsForPlayer(PlayerId(), false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 1, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 2, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 3, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 5, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 8, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 9, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 10, false)
		Citizen.InvokeNative(0xDC0F817884CDD856, 11, false)
	end
	
	for _, item in pairs(clockInStation) do
      item.blip = AddBlipForCoord(item.x, item.y, item.z)
      SetBlipSprite(item.blip, 60)
      SetBlipAsShortRange(item.blip, true)
      BeginTextCommandSetBlipName("STRING")
      AddTextComponentString(txt[config.lang]["police_station"])
      EndTextCommandSetBlipName(item.blip)
    end
	
    while true do
        Citizen.Wait(10)
		
		DisablePlayerVehicleRewards(PlayerId())
		
		--Embedded NeverWanted script // Loop part
		if(config.enableNeverWanted == true) then
			SetPlayerWantedLevel(PlayerId(), 0, false)
			SetPlayerWantedLevelNow(PlayerId(), false)
			ClearAreaOfCops()
		end
		
		if(anyMenuOpen.isActive) then
			DisableControlAction(1, 21)
			DisableControlAction(1, 140)
			DisableControlAction(1, 141)
			DisableControlAction(1, 142)
			SetDisableAmbientMeleeMove(GetPlayerPed(-1), true)
			if (IsControlJustPressed(1,172)) then
				SendNUIMessage({
					action = "keyup"
				})
			elseif (IsControlJustPressed(1,173)) then
				SendNUIMessage({
					action = "keydown"
				})
			elseif (IsControlJustPressed(1,176)) then
				SendNUIMessage({
					action = "keyenter"
				})
			elseif (IsControlJustPressed(1,177)) then
				if(anyMenuOpen.menuName == "policemenu" or anyMenuOpen.menuName == "armory" or anyMenuOpen.menuName == "cloackroom" or anyMenuOpen.menuName == "garage") then
					CloseMenu()
				elseif(anyMenuOpen.menuName == "armory-weapon_list") then
					BackArmory()
				else
					BackMenuPolice()
				end
			end
		else
			EnableControlAction(1, 21)
			EnableControlAction(1, 140)
			EnableControlAction(1, 141)
			EnableControlAction(1, 142)
		end
		
		--Control death events
		if(config.useModifiedEmergency == false) then
			if(IsPlayerDead(PlayerId())) then
				if(alreadyDead == false) then
					if(isInService) then
						ServiceOn()
					end
					handCuffed = false
					drag = false
					alreadyDead = true
				end
			else
				alreadyDead = false
			end
		end
		
		if (handCuffed == true) then
			RequestAnimDict('mp_arresting')

			while not HasAnimDictLoaded('mp_arresting') do
				Citizen.Wait(0)
			end

			local myPed = PlayerPedId(-1)
			local animation = 'idle'
			local flags = 16
			
			while(IsPedBeingStunned(myPed, 0)) do
				ClearPedTasksImmediately(myPed)
			end
			TaskPlayAnim(myPed, 'mp_arresting', animation, 8.0, -8, -1, flags, 0, 0, 0, 0)
		end
		
		--Piece of code from Drag command (by Frazzle, Valk, Michael_Sanelli, NYKILLA1127 : https://forum.fivem.net/t/release-drag-command/22174)
		if drag then
			local ped = GetPlayerPed(GetPlayerFromServerId(officerDrag))
			local myped = GetPlayerPed(-1)
			AttachEntityToEntity(myped, ped, 4103, 11816, 0.48, 0.00, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
		else
			DetachEntity(GetPlayerPed(-1), true, false)		
		end
		
        if(isCop) then
			if(isNearTakeService()) then
			
				DisplayHelpText(txt[config.lang]["help_text_open_cloackroom"],0,1,0.5,0.8,0.6,255,255,255,255) -- ~g~E~s~
				if IsControlJustPressed(1,51) then
					OpenCloackroom()
				end
			end
			
			if(isInService) then
			
				--Open Garage menu
				if(isNearStationGarage()) then
					if(policevehicle ~= nil) then
						DisplayHelpText(txt[config.lang]["help_text_put_car_into_garage"],0,1,0.5,0.8,0.6,255,255,255,255)
					else
						DisplayHelpText(txt[config.lang]["help_text_get_car_out_garage"],0,1,0.5,0.8,0.6,255,255,255,255)
					end
					
					if IsControlJustPressed(1,51) then
						if(policevehicle ~= nil) then
							--Destroy police vehicle
							Citizen.InvokeNative(0xEA386986E786A54F, Citizen.PointerValueIntInitialized(policevehicle))
							policevehicle = nil
						else
							OpenGarage()
						end
					end
				end
				
				--Open Garage menu
				if(isNearArmory()) then
					
					DisplayHelpText(txt[config.lang]["help_text_open_armory"],0,1,0.5,0.8,0.6,255,255,255,255)
					
					if IsControlJustPressed(1,51) then
						OpenArmory()
					end
				end
				
				--Open/Close Menu police
				if (IsControlJustPressed(1,166)) then
					TogglePoliceMenu()
				end
				
				--Control helicopter spawning
				if isNearHelicopterStation() then
					if(policeHeli ~= nil) then
						DisplayHelpText(txt[config.lang]["help_text_put_heli_into_garage"],0,1,0.5,0.8,0.6,255,255,255,255)
					else
						DisplayHelpText(txt[config.lang]["help_text_get_heli_out_garage"],0,1,0.5,0.8,0.6,255,255,255,255)
					end
					
					if IsControlJustPressed(1,51)  then
						if(policeHeli ~= nil) then
							Citizen.InvokeNative(0xEA386986E786A54F, Citizen.PointerValueIntInitialized(policeHeli))
							policeHeli = nil
						else
							local heli = GetHashKey("polmav")
							local ply = GetPlayerPed(-1)
							local plyCoords = GetEntityCoords(ply, 0)
							
							RequestModel(heli)
							while not HasModelLoaded(heli) do
									Citizen.Wait(0)
							end
							
							policeHeli = CreateVehicle(heli, plyCoords["x"], plyCoords["y"], plyCoords["z"], 90.0, true, false)
							SetVehicleHasBeenOwnedByPlayer(policevehicle,true)
							local netid = NetworkGetNetworkIdFromEntity(policeHeli)
							SetNetworkIdCanMigrate(netid, true)
							NetworkRegisterEntityAsNetworked(VehToNet(policeHeli))
							SetVehicleLivery(policeHeli, 0)
							TaskWarpPedIntoVehicle(ply, policeHeli, -1)
							SetEntityAsMissionEntity(policeHeli, true, true)
						end
					end
				end
			end
		end
    end
end)