local PlayerHome = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Interfaces = require("utility/interfaces")

local SpawnYOffset = 20

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}
    global.playerHome.teams = global.playerHome.teams or {}
    --[[
        [id] = {
            id = string team of either "north" or "south".
            spawnPosition = position of this team's spawn.
            playerIds = table of the player ids who have joined this team.
            playerNames = table of player names who will join this team on first connect.
            teleporterEntity = entity of the teleporter.
            otherTeam = ref to the other teams global object.
        }
    ]]
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {}
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "PlayerHome.OnPlayerSpawn", PlayerHome.OnPlayerSpawn)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
end

PlayerHome.OnStartup = function()
    Utils.DisableIntroMessage()

    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.divider.dividerMiddleYPos - SpawnYOffset)
        PlayerHome.CreateTeam("south", global.divider.dividerMiddleYPos + SpawnYOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["east"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["west"]
    end
end

local function on_entity_damaged(event)
	if event.force == event.entity.force then
	    -- allow friendly fire to own team
	    return false
	end

	local from_player_match = false
	local to_player_match = false

	for force_name, _ in pairs(global.playerHome.teams) do
	    if event.force.name == force_name then
		from_player_match = true
	    end
	    if event.entity.force.name == force_name then
		to_player_match = true
	    end
	end

	if not from_player_match or not to_player_match then
	    return false
	end

	-- damage is cross player force. Null out
        event.entity.health = event.entity.health + event.final_damage_amount

        return true
end

script.on_event(defines.events.on_entity_damaged, on_entity_damaged)

PlayerHome.CreateTeam = function(teamId, spawnYPos)
    local team = {
        id = teamId,
        spawnPosition = {x = 0, y = spawnYPos},
        playerIds = {},
        playerNames = {}
    }

    local force = game.create_force(teamId)
    local enemy_force = game.create_force(teamId.."_enemy")

    -- Don't auto target other forces
    for other_force_name, _ in pairs(global.playerHome.teams) do
	other_force = game.forces[other_force_name]
	other_enemy_force = game.forces[other_force_name.."_enemy"]

	force.set_cease_fire(other_force, true)
	force.set_cease_fire(other_enemy_force, true)
	enemy_force.set_cease_fire(other_force, true)
	enemy_force.set_cease_fire(other_enemy_force, true)
    end

    global.playerHome.teams[teamId] = team
end

PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end
    -- Check if player is on the named list.
    local team
    for _, teamToCheck in pairs(global.playerHome.teams) do
        if teamToCheck.playerNames[player.name] ~= nil then
            team = teamToCheck
            break
        end
    end
    -- If player isn't named give them a random team.
    if team == nil then
        local teamNames = Utils.TableKeyToArray(global.playerHome.teams)
        team = global.playerHome.teams[teamNames[math.random(1, 2)]]
        PlayerHome.AddPlayerNameToTeam(player.name, team)
        game.print("Player '" .. player.name .. "' isn't set on a team, so added to the '" .. team.id .. "' randomly")
    end
    --Record the player ID to the team, rather than relying on names.
    team.playerIds[player.index] = player
    global.playerHome.playerIdToTeam[player.index] = team

    player.force = game.forces[team.id]
    PlayerHome.OnPlayerSpawn(event)
end

PlayerHome.OnPlayerSpawn = function(event)
    local player = game.get_player(event.player_index)
    local team = global.playerHome.playerIdToTeam[player.index]
    local targetPos, surface = team.spawnPosition, player.surface

    local foundPos = surface.find_non_colliding_position("character", targetPos, 0, 0.2)
    if foundPos == nil then
        Logging.LogPrint("ERROR: no position found for player '" .. player.name .. "' near '" .. Logging.PositionToString(targetPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
    local teleported = player.teleport(foundPos, surface)
    if teleported ~= true then
        Logging.LogPrint("ERROR: teleport failed for player '" .. player.name .. "' to '" .. Logging.PositionToString(foundPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
end

return PlayerHome
