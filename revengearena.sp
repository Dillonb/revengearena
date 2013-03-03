#include <sourcemod>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <tf2>
#define REQUIRE_EXTENSIONS

public Plugin:myinfo =
{
    name = "Revenge Arena",
    author = "Dillon B.",
    description = "A revenge dodgeball-like modification of Arena mode.",
    version = "1.0.0.0",
    url = ""
}

new killedby[MAXPLAYERS + 1]; //Stores a list of who killed which player
new Handle:revengearena_enabled = INVALID_HANDLE;

//Game:
// 0 : unknown
// 1 : Team Fortress 2
// 2 : Counter-Strike Source
// 3 : Counter-Strike Global Offensive
new gametype = 0;
new bool:supportedMap = false;
public OnPluginStart()
{

    decl String:GameType[50];
    GetGameFolderName(GameType, sizeof(GameType))
    
    if (StrEqual(GameType, "tf", false))
    {
        gametype = 1;
    }
    if(StrEqual(GameType, "cstrike"))
    {
        gametype = 2;
    }
    if (StrEqual(GameType, "csgo"))
    {
        gametype = 3;
    }

    
    // 0 - disabled
    // 1 - enabled on supported maps
    // 2 - forced enabled on all maps
    revengearena_enabled = CreateConVar("revengearena_enabled", "0");
    ResetKilledbyList();
    
    HookEvent("player_death", Event_PlayerDeath);
    
    //For maximum compatibility, hook everything
    if (StrEqual(GameType, "tf"))
    {
        HookEvent("arena_round_start", Event_RoundStart);
    }
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("game_init", Event_RoundStart);
    HookEvent("game_start", Event_RoundStart);
    HookEvent("round_start", Event_RoundStart);
}

//Checks whether revengearena should be enabled.
//Takes into account the map type and the setting of revengearena_enabled.
bool:IsRevengeArenaEnabled()
{
    //if (supportedMap && revengearena_enabled)
    if (revengearena_enabled)
    {
        // PrintToServer("RevengeArena is ENABLED.");
        return true;
    }
    // PrintToServer("RevengeArena is DISABLED.");
    return false;
}
public refreshMapSupportedStatus()
{
    if (gametype == 2 || gametype == 3)
    {
        supportedMap = true;
    }
    if (gametype == 1)
    {
        decl String:MapName[6];
        GetCurrentMap(MapName, sizeof(MapName));
        if (StrEqual(MapName, "arena_", false))
        {
            supportedMap = true;
        }

    }

}
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsRevengeArenaEnabled())
    {
        return;
    }
    refreshMapSupportedStatus();
    ResetKilledbyList();
}

public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsRevengeArenaEnabled())
    {
        return;
    }
    //Treat disconnects like the player was killed.
    new userid = GetEventInt(event, "userid");
    new player = GetClientOfUserId(userid);
    RespawnAllByKiller(player);

}
//Refresh the entire killedby array to fix issues between games.
ResetKilledbyList()
{
    for (new i = 0; i <= MAXPLAYERS; i++)
    {
        killedby[i] = -1;
    }
}

//Respawns all players killed by id
RespawnAllByKiller(id)
{
    decl String:killerName[33];
    GetClientName(id, killerName, 33);
    for (new i = 0; i < MAXPLAYERS; i++)
    {
        if (killedby[i] == id)
        {
            decl String:playerName[33];
            GetClientName(i, playerName, 33);
            PrintToChatAll("%s is back in the game!", playerName);
            PrintCenterText(i, "With %s's death, you are back in the game!", killerName);
            killedby[i] = -1;
            RespawnPlayer(i);
        }
    }
}

//Game-agnostic respawn method
RespawnPlayer(id)
{
    if (gametype == 1)
    {
        TF2_RespawnPlayer(id);
    }
    if (gametype == 2)
    {
        CS_RespawnPlayer(id);
    }
    if (gametype == 3)
    {
        CS_RespawnPlayer(id);
    }
}

//Process a player's death - respawn all they have killed
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!IsRevengeArenaEnabled())
    {
        return;
    }
    //Handle dead ringer in TF2
    if (gametype == 1)
    {
        new death_flags = GetEventInt(event, "death_flags");
        if (death_flags & 32)
        {
            return;
        }
    }
    new victim_id = GetEventInt(event, "userid");
    new attacker_id = GetEventInt(event, "attacker");
    new victim = GetClientOfUserId(victim_id);
    new killer = GetClientOfUserId(attacker_id);
    
    //decl String:victimName[33]
    decl String:killerName[33];
    
    //GetClientName(victim, victimName, 33)
    GetClientName(killer, killerName, 33);
    
    if (victim == killer || killer == 0)
    {
        killedby[victim] = -1;
        RespawnAllByKiller(victim);
        PrintCenterText(victim, "Suicide is never the answer.");
        return //Committing suicide will NOT make you revive
    }
    PrintCenterText(victim, "You were killed by %s", killerName);
    //PrintCenterText(killer, "You killed %s.", victimName)
    RespawnAllByKiller(victim); //Respawn all players killed by the victim
    killedby[victim] = killer;
}
