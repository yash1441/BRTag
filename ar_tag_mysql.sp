#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <cstrike>

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.6"
#define PLUGIN_URL "yash1441@yahoo.com"

char SavedWins[MAXPLAYERS + 1][4];
Database db;

public Plugin myinfo = 
{
	name = "ArmsRace Tag", 
	author = PLUGIN_AUTHOR, 
	description = "Give players Tags according to their ArmsRace wins.", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	CreateConVar("sm_br_tag_version", PLUGIN_VERSION, "ArmsRace Tag Version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
	RegAdminCmd("sm_setwins", CommandSetWins, ADMFLAG_SLAY);
	
	InitializeDB();
}

public void InitializeDB()
{
	char Error[255];
	db = SQL_Connect("artag", true, Error, sizeof(Error));
	SQL_SetCharset(db, "utf8");
	if (db == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	SQL_TQuery(db, SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS players (steam_id VARCHAR(20) UNIQUE, wins INT(12));");
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

public void OnClientPostAdminCheck(int client)
{
	char steamId[32];
	if (GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
	{
		char buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
		SQL_LockDatabase(db);
		DBResultSet query = SQL_Query(db, buffer);
		SQL_UnlockDatabase(db);
		if (SQL_GetRowCount(query) == 0)
		{
			delete query;
			Format(buffer, sizeof(buffer), "INSERT IGNORE INTO players (steam_id, wins) VALUES ('%s', 0)", steamId);
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			strcopy(SavedWins[client], sizeof(SavedWins[]), "0");
		}
		else
		{
			delete query;
			Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
			SQL_LockDatabase(db);
			query = SQL_Query(db, buffer);
			SQL_UnlockDatabase(db);
			SQL_FetchRow(query);
			int wins = SQL_FetchInt(query, 1);
			delete query;
			IntToString(wins, SavedWins[client], sizeof(SavedWins[]));
		}
	}
	else LogError("Failed to get Steam ID");
}

public void CalculateTag(int client)
{
	char NewTag[40];
	Format(NewTag, sizeof(NewTag), "[%i Wins]", StringToInt(SavedWins[client]));
	CS_SetMVPCount(client, StringToInt(SavedWins[client]));
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

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClient(client))
	{
		char weapon[64];
		GetClientWeapon(client, weapon, sizeof(weapon));
		if (strcmp(weapon, "weapon_knifegg", false) == 0)
		{
			char steamId[32];
			if (GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
			{
				IntToString(StringToInt(SavedWins[client]) + 1, SavedWins[client], sizeof(SavedWins[]));
				char buffer[200];
		 		Format(buffer, sizeof(buffer), "INSERT IGNORE INTO players (steam_id, wins) VALUES ('%s', %d)", steamId, SavedWins[client]);
				SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			}
			else LogError("Failed to get Steam ID");
		}
	}
}

public Action CommandSetWins(int client, int args)
{                           
	char arg1[32], arg2[20];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int wins = StringToInt(arg2);

	if (args != 2)
	{
		ReplyToCommand(client, "sm_setwins <name or #userid> <wins>");
		return Plugin_Continue;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count; bool tn_is_ml;

	if ((target_count = ProcessTargetString(
	arg1,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_TARGET_NONE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Continue;
	}

	for (int i = 0; i < target_count; i++)
	{
		char steamId[32];
		if (GetClientAuthId(target_list[i], AuthId_Steam2, steamId, sizeof(steamId)))
		{
			IntToString(wins, SavedWins[target_list[i]], sizeof(SavedWins[]));
			char buffer[200];
	 		Format(buffer, sizeof(buffer), "INSERT IGNORE INTO players (steam_id, wins) VALUES ('%s', %d)", steamId, SavedWins[client]);
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}
		else LogError("Failed to get Steam ID");
	}

	ShowActivity2(client, "[ArmsRace] ", "Set wins of %s to %i", target_name, wins);
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (!StrEqual(error, ""))
		LogError(error);
}