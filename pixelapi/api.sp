
void SendReplay(const char[] url, char[] path, any data)
{
    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
    SteamWorks_SetHTTPRequestContextValue(request, data);
    SteamWorks_SetHTTPRequestUserAgentInfo(request, PIXEL_USERAGENT); // not sure what ill use this for but here it is
    SteamWorks_SetHTTPCallbacks(request, .fCompleted=HTTP_OnRequestCompleted, .fData=HTTP_OnDataReceived);
    SteamWorks_SetHTTPRequestRawPostBodyFromFile(request, "application/octet-stream", path);
    SteamWorks_SendHTTPRequest(request);
}

public int HTTP_OnRequestCompleted(Handle request, bool failure, bool requestSuccess, EHTTPStatusCode statusCode, any data)
{
    if (failure || !requestSuccess) {
        delete request;
        DataPack dp = data;
        OnApiReplayFailed_Fallback(dp);
        return;
    }
}

public int HTTP_OnDataReceived(Handle request, bool failure, int offset, int bytesReceived, any data)
{
    if (failure || bytesReceived < 4) {
        delete request;
        DataPack dp = data;
        OnApiReplayFailed_Fallback(dp);
        return;
    }

    SteamWorks_GetHTTPResponseBodyCallback(request, HTTP_OnData, data);
    delete request;
}

public int HTTP_OnData(const char[] body, any data)
{
    JSON_Object jBody = json_decode(body);
    DataPack dp = data;
    bool success = jBody.GetBool("success");

    if (!success) {
        // failure
        OnApiReplayFailed_Fallback(dp);
        return;
    }
    int replayId = jBody.GetInt("id");
    // success
    dp.Reset();
    int client = dp.ReadCell();
    PrintToConsole(client, "[PixelAPI] Replay saved. ID: %i", replayId);

    json_cleanup(jBody);
    delete dp;
}

void OnApiReplayFailed_Fallback(DataPack dp)
{
    dp.Reset();
    int client = dp.ReadCell();
    char hash[41];
    dp.ReadString(hash, sizeof(hash));

    PrintToConsole(client, "[PixelAPI] Failed to submit. Contact %s with the following: [Map: %s, Hash: %s]", PLUGIN_AUTHOR, gC_CurrentMap, hash);

    delete dp;
}