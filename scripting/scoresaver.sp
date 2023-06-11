#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <dhooks>

#define PL_NAME "ScoreSaver"
#define PL_DESC "Saves scores when players disconnect"
#define PL_VERSION "1.0.0"

public Plugin myinfo =
{
    name = PL_NAME,
    author = "Fraeven & Rowedahelicon",
    description = PL_DESC,
    version = PL_VERSION,
    url = "https://scg.wtf"
}

Handle g_Cvar_Teamplay = INVALID_HANDLE;
static Address CTFGameStats;
static Handle SDKIncrementStat;

StringMap sm_SavedScores;

enum Game
{
    GAME_UNKNOWN = 0,
    GAME_TF,
    GAME_OF
};

Game game;

enum TFStatType_t
{
    TFSTAT_UNDEFINED = 0,
    TFSTAT_SHOTS_HIT,
    TFSTAT_SHOTS_FIRED,
    TFSTAT_KILLS
};

public void OnPluginStart()
{
    Handle gamedata = LoadGameConfigFile("scoresaver.games");

    CreateDetour(gamedata, "CTFGameStats::ResetRoundStats", _, DHook_ResetRoundStats);

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFGameStats::IncrementStat");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    SDKIncrementStat = EndPrepSDKCall();
    if (!SDKIncrementStat)
    {
        LogError("[Gamedata] Could not find CTFGameStats::IncrementStat");
    }

    g_Cvar_Teamplay = FindConVar("mp_teamplay");

    sm_SavedScores = new StringMap();

    HookEvent("player_team", Event_PlayerTeam);

    char gameName[30];
    GetGameFolderName(gameName, sizeof(gameName));

    if (StrEqual(gameName, "tf", false))
    {
        game = GAME_TF;
    }
    else if (StrEqual(gameName, "open_fortress", false))
    {
        game = GAME_OF;
    }
    else
    {
        game = GAME_UNKNOWN;
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = event.GetInt("team");

    if (!IsValidClient(client) || team <= 1)
    {
        return;
    }

    char steamId[16];
    Format(steamId, sizeof(steamId), "%d", GetSteamAccountID(client));

    char strScore[5];
    bool found = sm_SavedScores.GetString(steamId, strScore, sizeof(strScore));
    if (!found)
    {
        return;
    }

    int score = StringToInt(strScore);
    SetScore(client, score);

    sm_SavedScores.Remove(steamId);
}

public void OnClientDisconnect(int client)
{
    if (IsFakeClient(client))
    {
        return;
    }

    char steamId[16];
    Format(steamId, sizeof(steamId), "%d", GetSteamAccountID(client));

    int score = GetScore(client);

    char strScore[5];
    Format(strScore, sizeof(strScore), "%d", score);

    sm_SavedScores.SetString(steamId, strScore, true);
}

public void OnMapEnd()
{
    sm_SavedScores.Clear();
}

stock bool IsValidClient(int client)
{
    if (!client || client > MaxClients || client < 1)
    {
        return false;
    }

    if (!IsClientInGame(client))
    {
        return false;
    }

    return true;
}

public bool IsTeamplay()
{
    return GetConVarBool(g_Cvar_Teamplay);
}

public int GetScore(int client)
{
    // Use frags for Open Fortress DM
    if (game == GAME_OF && !IsTeamplay())
    {
        return GetFrags(client);
    }

    return GetPlayerResourceTotalScore(client);
}

public int GetPlayerResourceTotalScore(int client)
{
    int playerSourceEnt = GetPlayerResourceEntity();
    return GetEntProp(playerSourceEnt, Prop_Send, "m_iTotalScore", _, client);
}

public SetScore(int client, int score)
{
    // Use frags for Open Fortress DM
    if (game == GAME_OF && !IsTeamplay())
    {
        SetFrags(client, score);
        return;
    }

    SDKCall_IncrementStat(client, TFSTAT_KILLS, score);
}

// Get player's frags
public GetFrags(int client)
{
    return GetClientFrags(client);
}

// Set player's frags
public SetFrags(int client, int frags)
{
    SetEntProp(client, Prop_Data, "m_iFrags", frags);
}

void SDKCall_IncrementStat(int client, TFStatType_t stat, int amount)
{
    if (SDKIncrementStat)
    {
        Address address = DHook_GetGameStats();
        if (address != Address_Null)
        {
            SDKCall(SDKIncrementStat, address, client, stat, amount);
        }
    }
}

static void CreateDetour(Handle gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
    DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
    if (detour)
    {
        if (preCallback != INVALID_FUNCTION && !detour.Enable(Hook_Pre, preCallback))
        {
            LogError("[Gamedata] Failed to enable pre detour: %s", name);
        }

        if (postCallback != INVALID_FUNCTION && !detour.Enable(Hook_Post, postCallback))
        {
            LogError("[Gamedata] Failed to enable post detour: %s", name);
        }

        delete detour;
    }
    else
    {
        LogError("[Gamedata] Could not find %s", name);
    }
}

Address DHook_GetGameStats()
{
    return CTFGameStats;
}

public MRESReturn DHook_ResetRoundStats(Address address)
{
    CTFGameStats = address;
    sm_SavedScores.Clear();
    return MRES_Ignored;
}
