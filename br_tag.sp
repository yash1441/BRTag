#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <clientprefs>

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.2"
#define PLUGIN_URL "yash1441@yahoo.com"

Handle WinCountCookie;
char SavedWins[MAXPLAYERS + 1][4];

public Plugin myinfo = 
{
	name = "BattleRoyale Tag", 
	author = PLUGIN_AUTHOR, 
	description = "Give players Tags according to their BattleRoyale wins.", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	CreateConVar("sm_br_tag_version", PLUGIN_VERSION, "BattleRoyale Tag Version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	WinCountCookie = RegClientCookie("BRWinCount", "Cookie for counting wins in BR.", CookieAccess_Protected);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
			continue;
		OnClientCookiesCached(i);
	}
}

public void OnClientSettingsChanged(int client)
{
	if (IsValidClient(client))
	{
		CalculateTag(client);
	}
}

public Action OnClientCommand(int client, int args)
{
	if (IsValidClient(client))
	{
		CalculateTag(client);
	}
}

public void OnClientCookiesCached(int client)
{
	GetClientCookie(client, WinCountCookie, SavedWins[client], sizeof(SavedWins[]));
	if (StrEqual(SavedWins[client], ""))
		strcopy(SavedWins[client], sizeof(SavedWins[]), "0");
}

public void CalculateTag(int client)
{
	char NewTag[40];
	Format(NewTag, sizeof(NewTag), "[%i Wins]", StringToInt(SavedWins[client]));
	SetTag(client, NewTag);
}

public void SetTag(int client, const char[] tag)
{
	char CurrentTag[40];
	CS_GetClientClanTag(client, CurrentTag, sizeof(CurrentTag));
	if (!StrEqual(tag, CurrentTag))
		CS_SetClientClanTag(client, tag);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			CalculateTag(i);
		}
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int count = 0;
	int client;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			client = i;
			count++;
		}
	}
	
	if (count == 1)
	{
		int cookievalue;
		cookievalue = StringToInt(SavedWins[client]);
		cookievalue++;
		IntToString(cookievalue, SavedWins[client], sizeof(SavedWins[]));
		SetClientCookie(client, WinCountCookie, SavedWins[client]);
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 