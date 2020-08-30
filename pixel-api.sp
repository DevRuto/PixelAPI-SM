#define API_BASE_URL "http://localhost:5000"
#define REPLAY_ENDPOINT "/api/replay"
#define PIXEL_USERAGENT "pixelapi/sm-plugin:1.0"

#define FALLBACK_DIRECTORY "data/pixel-fallback-replays"

#define PLUGIN_AUTHOR "Ruto"
#define PLUGIN_VERSION "1.0"

// sourcemod
#include <sourcemod>
#include <sdktools>
#include <cstrike>

// third party
#include <SteamWorks>
#include <sha1>
#include <json>

// kz
#undef REQUIRE_PLUGIN
#include <gokz/core>
#include <gokz/localdb>
#include <kztimer>
#define REQUIRE_PLUGIN

#define DEBUG
#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 10000000

// vars
bool gB_GOKZ = false;
bool gB_KZTimer = false;
char gC_CurrentMap[64];
char gC_Plugin[10];

#include "pixelapi/api.sp"
#include "pixelapi/recorder.sp"

public Plugin myinfo =
{
    name = "PixelAPI KZ Replays",
    author = PLUGIN_AUTHOR,
    description = "Sends recording of runs to Pixel API",
    version = PLUGIN_VERSION,
    url = "https://github.com/DevRuto/PixelAPI"
}

public void OnPluginStart()
{
    if (GetEngineVersion() != Engine_CSGO)
        SetFailState("This plugin is for CSGO only.");
}

public void OnAllPluginsLoaded()
{
    gB_GOKZ = LibraryExists("gokz-localdb");
    gB_KZTimer = LibraryExists("KZTimer");

    if (!gB_GOKZ && !gB_KZTimer)
        SetFailState("GOKZ or KZTimer is required for this plugin!");

    if (gB_KZTimer)
        gC_Plugin = "kztimer";
    else
        gC_Plugin = "gokz";
}

public void OnLibraryAdded(const char[] name)
{
    gB_KZTimer = StrEqual(name, "KZTimer");
    gB_GOKZ = StrEqual(name, "gokz-localdb");

    if (gB_KZTimer)
        gC_Plugin = "kztimer";
    else
        gC_Plugin = "gokz";
}

public void OnLibraryRemoved(const char[] name)
{
    gB_KZTimer = !StrEqual(name, "KZTimer");
    gB_GOKZ = !StrEqual(name, "gokz-localdb");

    if (!gB_GOKZ && !gB_KZTimer)
        SetFailState("GOKZ or KZTimer is required for this plugin!");

    if (gB_KZTimer)
        gC_Plugin = "kztimer";
    else
        gC_Plugin = "gokz";
}

public void OnMapStart()
{
    GetCurrentMap(gC_CurrentMap, sizeof(gC_CurrentMap));
    GetMapDisplayName(gC_CurrentMap, gC_CurrentMap, sizeof(gC_CurrentMap));
    String_ToLower(gC_CurrentMap, gC_CurrentMap, sizeof(gC_CurrentMap));

    CreateReplaysDirectory(gC_CurrentMap);
}

public void OnClientPutInServer(int client)
{
    PrepareClient(client);
}

public Action OnPlayerRunCmd(int client, int &buttons,  int &impulse, float vels[3],  float angles2[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) 
{
    OnPlayerRunCmd_Recording(client, buttons);
}

/* KZTIMER events */

public int KZTimer_TimerStarted(int client)
{
    StartRecording(client);
}

public int KZTimer_TimerStoppedValid(int client, int teleports, int rank, float time) 
{
    StopRecording(client);
}

public int KZTimer_TimerStopped(int client, int teleports, float time, int record) 
{
    PrintToServer("start save");
    SaveRecording(client, GetSteamAccountID(client), 0, 2, 0, time, teleports);
    StopRecording(client);
}

/* GOKZ Events */

public void GOKZ_OnTimerStart_Post(int client, int course)
{
    StartRecording(client);
}

public void GOKZ_OnTimerStopped(int client)
{
    StopRecording(client);
}

public void GOKZ_OnPause_Post(int client)
{
    PauseRecording(client);
}

public void GOKZ_OnResume_Post(int client)
{
    ResumeRecording(client);
}

public void GOKZ_DB_OnTimeInserted(int client, int steamID, int mapID, int course, int mode, int style, int runtimeMS, int teleports)
{
    SaveRecording(client, steamID, course, mode, style, runtimeMS/1000.0, teleports);
    StopRecording(client);
}

// helper - gokz-replays

static void CreateReplaysDirectory(const char[] map)
{
	char path[PLATFORM_MAX_PATH];
	
	// Create parent replay directory
	BuildPath(Path_SM, path, sizeof(path), FALLBACK_DIRECTORY);
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);
	}
	
	// Create map's replay directory
	BuildPath(Path_SM, path, sizeof(path), "%s/%s", FALLBACK_DIRECTORY, map);
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);
	}
}