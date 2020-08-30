
#define REPLAY_MAGIC_NUMBER 0x676F6B7A
#define REPLAY_FORMAT_VERSION 0x01
#define TICK_DATA_BLOCKSIZE 7

static bool recording[MAXPLAYERS+1];
static bool recordingPaused[MAXPLAYERS+1];
static ArrayList recordedTickData[MAXPLAYERS+1];

void PrepareClient(int client)
{
    if (recordedTickData[client] == INVALID_HANDLE)
        recordedTickData[client] = new ArrayList(TICK_DATA_BLOCKSIZE, 0);
    else
        recordedTickData[client].Clear();
}

void StartRecording(int client)
{
    if (IsFakeClient(client)) return;

    StopRecording(client);
    recording[client] = true;
    ResumeRecording(client);
}

void StopRecording(int client)
{
    recording[client] = false;
    recordedTickData[client].Clear();
}

void PauseRecording(int client)
{
    recordingPaused[client] = true;
}

void ResumeRecording(int client)
{
    recordingPaused[client] = false;
}

void SaveRecording(int client, int steamId32, int course, int mode, int style, float time, int teleports)
{
    if (!recording[client]) return;

    int tickCount = recordedTickData[client].Length;
    char steamid2[24], ip[16] = "127.0.0.1", alias[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, steamid2, sizeof(steamid2));
    // GetClientIP(client, ip, sizeof(ip));
    GetClientName(client, alias, sizeof(alias));

    char fileIdentity[128];
    FormatEx(fileIdentity, sizeof(fileIdentity), "%s%i%i%i%i%i%i\0", gC_CurrentMap,steamId32,course,mode,style,view_as<int>(time),teleports);
    char fileHash[41];
    SHA1String(fileIdentity, sizeof(fileIdentity), fileHash, true);

    // save to file
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), 
        "%s/%s/%s.replay", 
        FALLBACK_DIRECTORY, gC_CurrentMap, fileHash);
    if (FileExists(path))
    {
        DeleteFile(path);
    }

    File file = OpenFile(path, "wb");
    if (file == null)
    {
        PrintToConsole(client, "[PixelAPI] Unable to save replay");
        LogError("Unable to open file: %s", path);
        return;
    }

    file.WriteInt32(REPLAY_MAGIC_NUMBER);
    file.WriteInt8(REPLAY_FORMAT_VERSION);
    file.WriteInt8(strlen(GOKZ_VERSION));
    file.WriteString(GOKZ_VERSION, false);
    file.WriteInt8(strlen(gC_CurrentMap));
    file.WriteString(gC_CurrentMap, false);
    file.WriteInt32(course);
    file.WriteInt32(mode);
    file.WriteInt32(style);
    file.WriteInt32(view_as<int>(time));
    file.WriteInt32(teleports);
    file.WriteInt32(GetSteamAccountID(client));
    file.WriteInt8(strlen(steamid2));
    file.WriteString(steamid2, false);
    file.WriteInt8(strlen(ip));
    file.WriteString(ip, false);
    file.WriteInt8(strlen(alias));
    file.WriteString(alias, false);
    file.WriteInt32(tickCount);

    any tickData[TICK_DATA_BLOCKSIZE];
    for (int i = 0; i < tickCount; i++)
    {
        recordedTickData[client].GetArray(i, tickData, TICK_DATA_BLOCKSIZE);
        file.Write(tickData, TICK_DATA_BLOCKSIZE, 4);
    }
    file.Close();

    recordedTickData[client].Clear();
    recording[client] = false;

    DataPack data = new DataPack();
    data.WriteCell(client);
    data.WriteString(fileHash);

    char url[1024] = API_BASE_URL ... REPLAY_ENDPOINT;

    SendReplay(url, path, data);
}

void OnPlayerRunCmd_Recording(int client, int buttons)
{
    if (IsFakeClient(client)) return;

    if (!recording[client]) return;

    if (gB_GOKZ)
        if (recordingPaused[client]) return;

    // a little more work than GOKZ
    if (gB_KZTimer)
        if (IsPaused(client)) return;

    int tick = GetArraySize(recordedTickData[client]);
    recordedTickData[client].Resize(tick + 1);

    float origin[3], angles[3];
    Movement_GetOrigin(client, origin);
    Movement_GetEyeAngles(client, angles);
    int flags = GetEntityFlags(client);

    recordedTickData[client].Set(tick, origin[0], 0);
    recordedTickData[client].Set(tick, origin[1], 1);
    recordedTickData[client].Set(tick, origin[2], 2);
    recordedTickData[client].Set(tick, angles[0], 3);
    recordedTickData[client].Set(tick, angles[1], 4);
    // Don't bother tracking eye angle roll (angles[2]) - not used
    recordedTickData[client].Set(tick, buttons, 5);
    recordedTickData[client].Set(tick, flags, 6);
}

bool IsPaused(int client) 
{
	// MOVETYPE_NONE occurs when paused, or challenged
	return GetEntityMoveType(client) == MOVETYPE_NONE;
}