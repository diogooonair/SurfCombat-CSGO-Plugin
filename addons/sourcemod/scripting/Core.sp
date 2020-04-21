#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "DiogoOnAir"
#define PLUGIN_VERSION "1.00"
#define m_flNextSecondaryAttack FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack")

#include <sourcemod>
#include <sdktools>
#include <colorvariables>
#include <cstrike>
#include <sdkhooks>
#include <smlib>

#pragma tabsize 0

Database g_DBSQL = null;

/* Convars */
ConVar g_EnableVipmenu = null;
ConVar g_hPluginPrefix = null;
ConVar g_MinimumPlayers;
ConVar g_TopLimit;
ConVar g_KnifeDuelPlayerSpeed;
ConVar g_KnifeDuelGravity;
ConVar g_SafeBuyZone;

/* Chars */
char g_PluginPrefix[64];
char g_szMenuPrefix[64];
char g_PlayerRank[64];
/* Bools */

bool g_UsedMenu[MAXPLAYERS + 1];
bool g_RankTag[MAXPLAYERS + 1];
bool g_ImALegend[MAXPLAYERS + 1];
bool g_LegendSound[MAXPLAYERS + 1];
bool g_BedSound[MAXPLAYERS + 1];
bool g_Thanos[MAXPLAYERS + 1];
bool g_DeadPool[MAXPLAYERS + 1];
bool g_BatMan[MAXPLAYERS + 1];
bool g_WonLegendary[MAXPLAYERS + 1];
bool InNoscope = false;
bool InDecoyDuel = false;

/* Int */

int g_PKills[MAXPLAYERS + 1] = 0;
int g_PDeaths[MAXPLAYERS + 1] = 0;
int g_PShots[MAXPLAYERS + 1] = 0;
int g_PHits[MAXPLAYERS + 1] = 0;
int g_PHS[MAXPLAYERS + 1] = 0;
int g_PAssists[MAXPLAYERS + 1] = 0;
int g_PlayTime[MAXPLAYERS + 1] = 0;
int g_BonusCase[MAXPLAYERS + 1];
int g_CurrentRank[MAXPLAYERS + 1];
int vote1 = 0;
int vote2 = 0;
int vote3 = 0;
int vote4 = 0;
int vote5 = 0;

float teleloc[3];

public Plugin myinfo = 
{
	name = "SurfCombat Gamemode",
	author = PLUGIN_AUTHOR,
	description = "Surf Combat",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	ConnectToDatabase();
	/* Commands */
	RegAdminCmd("sm_vipmenu", Cmd_VipMenu, ADMFLAG_GENERIC, "[SurfCombat]Opens the VipMenu");
	RegConsoleCmd("sm_tagtog", Cmd_TagTog, "[SurfCombat]Switch the player tag");
	RegConsoleCmd("sm_legend", LegendMenu, "[SurfCombat]Legend Customizations Menu");
	RegConsoleCmd("sm_rankbonus", RankBonus, "[SurfCombat]Legend Customizations Menu");
	RegConsoleCmd("sm_bonusmodel", BonusModel, "[SurfCombat]Command for client to open menu with top kills x players.");
	RegConsoleCmd("sm_stats", Cmd_Stats, "[SurfCombat]Command for client to open menu with his stats.");
	RegConsoleCmd("sm_top", Cmd_Top, "[SurfCombat]Command for client to open menu with top kills x players.");
	/* Convars */
	g_hPluginPrefix = CreateConVar("sc_chat_prefix", "{lime}SurfCombat {default}|", "Determines the prefix used for chat messages", FCVAR_NOTIFY);
	g_EnableVipmenu = CreateConVar("sc_vipmenu_enabled", "1", "Enable VipMenu 1 - yes, 0 - no", FCVAR_NOTIFY);
	g_MinimumPlayers = CreateConVar("sc_rank_min", "4", "Minimum players to start record player stats");
	g_TopLimit = CreateConVar("sc_rank_toplimit", "10", "How much people will display on top menu");
	g_SafeBuyZone = CreateConVar("sc_zones_safe", "1", "The players cannot be killed in the buy zone? 1 - yes 2 - no");
	g_KnifeDuelPlayerSpeed = CreateConVar("sc_duel_knifespeed", "1.4", "Define players speed when they are in a speed knife duel");
	g_KnifeDuelGravity = CreateConVar("sc_duel_knifegravity", "0.2", "Define the players gravity when they are in a low gravity knife duel");
	/* Hooks */
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("item_pickup", Event_OnItemPickUp);
	
	AddNormalSoundHook(SoundHook);
	
	AutoExecConfig(true, "SurfCombat");
	LoadTranslations("surfcombat_phrases.txt");
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnConfigsExecuted()
{
	GetConVarString(g_hPluginPrefix, g_PluginPrefix, sizeof(g_PluginPrefix));
	GetConVarString(g_hPluginPrefix, g_szMenuPrefix, sizeof(g_szMenuPrefix));
	CRemoveColors(g_szMenuPrefix, sizeof(g_szMenuPrefix));
}
/*====================================
=              Hooks              =
====================================*/

public Action Event_OnItemPickUp(Handle hEvent, const char[] szName, bool dontBroadcast)
{
	char temp[32];
	GetEventString(hEvent, "item", temp, sizeof(temp));
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(StrEqual(temp, "weapon_c4", false)) //Find the bomb carrier
	{
		char iWeaponIndex = GetPlayerWeaponSlot(iClient, 4);
		RemovePlayerItem(iClient, iWeaponIndex); //Remove the bomb
	}
	return Plugin_Continue;
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags) 
{
	if(StrContains(sound, "player/damage", false) >= 0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void OnMapStart()
{
    PrecacheModel("models/player/custom_player/kuristaja/deadpool/deadpool.mdl", true);
    PrecacheModel("models/player/custom_player/kuristaja/deadpool/deadpool_arms.mdl", true);
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool.phy");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool_arms.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool_arms.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/deadpool/deadpool_arms.vvd");
    PrecacheModel("models/player/custom_player/kaesar2018/thanos/thanos.mdl", true);
    PrecacheModel("models/player/custom_player/kaesar2018/thanos/thanos_arms.mdl", true);
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.phy");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.dx90.vtx");
    PrecacheModel("models/player/custom_player/kuristaja/ak/batman/batmanv2.mdl", true);
    PrecacheModel("models/player/custom_player/kuristaja/ak/batman/batman_arms.mdl", true);
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batman_arms.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batman_arms.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batman_arms.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batmanv2.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batmanv2.phy");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batmanv2.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kuristaja/ak/batman/batmanv2.mdl");
    PrecacheSound("sound/surfcombat/bedtime.mp3"); 
    AddFileToDownloadsTable("sound/surfcombat/bedtime.mp3");
    PrecacheSound("sound/surfcombat/Imlegend.mp3"); 
    AddFileToDownloadsTable("sound/surfcombat/Imlegend.mp3");
    
    ServerCommand("sv_accelerate 10");
	ServerCommand("sv_airaccelerate 800");
	ServerCommand("mp_roundtime 5");
}

public Action PreThink(int client)
{
	if(IsPlayerAlive(client))
	{
		int  weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(!IsValidEdict(weapon))
			return Plugin_Continue;

		char item[64];
		GetEdictClassname(weapon, item, sizeof(item)); 
		if(InNoscope && StrEqual(item, "weapon_awp"))
		{
			SetEntDataFloat(weapon, m_flNextSecondaryAttack, GetGameTime() + 9999.9); //Disable Scope
		}
	}
	return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
    {
    	if(!IsClientInGame(i))
    		return;
    		
        int VipMenuActive = GetConVarInt(g_EnableVipmenu);
        if(VipMenuActive == 1)
        {
        	g_UsedMenu[i] = false;
    		int flags = GetUserFlagBits(i);
	    	if(flags & ADMFLAG_RESERVATION) 
	    	{
	    		ClientCommand(i, "sm_vipmenu");
        	}
        }
    }
    vote1 = 0;
    vote2 = 0;
    vote3 = 0;
    vote4 = 0;
    vote5 = 0;
    InNoscope = false;
    InDecoyDuel = false;
    
    int iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "hostage_entity")) != -1) //Find the hostages themselves and destroy them
	{
		AcceptEntityInput(iEnt, "kill");
	}
}

public void Event_RoundEnd(Event e, const char[] name, bool dontBroadcast)
{
	
	if (g_DBSQL == null)
	{
		return;
	}
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			UpdatePlayer(i, GetClientTime(i));
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
 	if (g_DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < g_MinimumPlayers.IntValue)
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool headshot = GetEventBool(event, "headshot");
	int assister = GetClientOfUserId(GetEventInt(event, "assister"));
	
	if (!IsValidClient(client) || !IsValidClient(attacker))
	{
		return;
	}
	
	if (attacker == client)
	{
		return;
	}
	
	if(g_LegendSound[attacker])
	{
		EmitSoundToAll("sound/surfcombat/Imlegend.mp3");
    }
    else if(g_BedSound[attacker])
    {
    	EmitSoundToAll("sound/surfcombat/bedtime.mp3");
    }
	
	//Player Stats//
	g_PKills[attacker]++;
	g_PDeaths[client]++;
	if (headshot)
		g_PHS[attacker]++;
	
	if (assister)
		g_PAssists[assister]++;
		
    if(AliveTPlayers() == 1 && AliveCTPlayers() == 1)
	{
	  for (int i = 0; i <= MaxClients; i++)
	  {
	  	ShowDuelMenu(i);
	  }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_RankTag[client])
	{
		GetPlayerRank(client);
		CS_SetClientClanTag(client, g_PlayerRank);
    }
    else if(!g_RankTag[client])
	{
		if (GetUserFlagBits(client) & ADMFLAG_ROOT) 
    	{ 
       		 CS_SetClientClanTag(client, "Owner |"); 
   		}
   		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM5)
		{ 
				CS_SetClientClanTag(client, "Head Admin |"); 
		}
   		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM3)
		{ 
			CS_SetClientClanTag(client, "Admin |"); 
		}
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM4)
		{ 
				CS_SetClientClanTag(client, "Mod |"); 
		}
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM6)
		{ 
				CS_SetClientClanTag(client, "Helper |"); 
		}
		else if (GetUserFlagBits(client) & ADMFLAG_RESERVATION)
		{ 
				CS_SetClientClanTag(client, "VIP |"); 
		}	
        else
        { 
				CS_SetClientClanTag(client, "Player |"); 
		}	        
    }
    if(g_DeadPool[client])
    {
    	SetEntityModel(client, "models/player/custom_player/kuristaja/deadpool/deadpool.mdl");  
    	SetEntPropString (client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/deadpool/deadpool_arms.mdl");  
    }
    else if(g_Thanos[client])
    {
    	SetEntityModel(client, "models/player/custom_player/kaesar2018/thanos/thanos.mdl");  
    	SetEntPropString (client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kaesar2018/thanos/thanos_arms.mdl");  
    }
    else if(g_BatMan[client])
    {
    	SetEntityModel(client, "models/player/custom_player/kuristaja/ak/batman/batmanv2.mdl");  
    	SetEntPropString (client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/ak/batman/batman_arms.mdl");  
    }
}
public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	if (g_DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < g_MinimumPlayers.IntValue)
	{
		return;
	}
	
	char FiredWeapon[32];
	GetEventString(event, "weapon", FiredWeapon, sizeof(FiredWeapon));
	
	if (StrEqual(FiredWeapon, "decoy"))
	{
		if(InDecoyDuel)
		{
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			GivePlayerItem(client, "weapon_decoy");
	    }
    }
    
	if (StrEqual(FiredWeapon, "hegrenade") || StrEqual(FiredWeapon, "flashbang") || StrEqual(FiredWeapon, "smokegrenade") || StrEqual(FiredWeapon, "molotov") || StrEqual(FiredWeapon, "incgrenade") || StrEqual(FiredWeapon, "decoy"))
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client))
	{
		return;
	}
	
	//Player Stats//
	g_PShots[client]++;
}

public void Event_PlayerHurt(Event e, const char[] name, bool dontBroadcast)
{
	if (g_DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < g_MinimumPlayers.IntValue)
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	
	if (!IsValidClient(client) || !IsValidClient(attacker))
	{
		return;
	}
	
	int g_ClientTeam = GetClientTeam(client);
	int g_AttackerTeam = GetClientTeam(attacker);
	
	if (g_ClientTeam != g_AttackerTeam)
	{
		//Player Stats//
		g_PHits[attacker]++;
	}
}

public void OnClientPutInServer(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (g_DBSQL == null)
	{
		return;
	}
	
	// Player Stuff
	g_PKills[client] = 0;
	g_PDeaths[client] = 0;
	g_PShots[client] = 0;
	g_PHits[client] = 0;
	g_PHS[client] = 0;
	g_PAssists[client] = 0;
	g_PlayTime[client] = 0;
	g_BonusCase[client] = 0;
	g_UsedMenu[client] = false;
	g_RankTag[client] = true;
	g_LegendSound[client] = false;
	g_ImALegend[client] = false;
	g_BedSound[client] = false;
	g_Thanos[client] = false;
	g_DeadPool[client] = false;
	g_BatMan[client] = false;
 	g_WonLegendary[client] = false;
	
	SDKHook(client, SDKHook_PreThink, PreThink);
	if(g_SafeBuyZone.IntValue == 1)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
	
	char g_PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, g_PlayerName, MAX_NAME_LENGTH);
	
	char g_SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, g_SteamID64, 32))
	{
		KickClient(client, "Verification problem , please reconnect.");
		return;
	}
	
	//escaping name , dynamic array;
	int iLength = ((strlen(g_PlayerName) * 2) + 1);
	char[] g_EscapedName = new char[iLength];
	g_DBSQL.Escape(g_PlayerName, g_EscapedName, iLength);
	
	char g_ClientIP[64];
	GetClientIP(client, g_ClientIP, 64);
	
	char g_Query[512];
	FormatEx(g_Query, 512, "INSERT INTO `players` (`steamid`, `name`, `ip`, `lastconn`) VALUES ('%s', '%s', '%s', UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE `name` = '%s', `ip` = '%s', `lastconn` = CURRENT_TIMESTAMP();", g_SteamID64, g_EscapedName, g_ClientIP, g_EscapedName, g_ClientIP);
	g_DBSQL.Query(SQL_InsertPlayer_Callback, g_Query, GetClientSerial(client), DBPrio_Normal);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (g_DBSQL == null)
	{
		return;
	}
	
	UpdatePlayer(client, GetClientTime(client));
}

public Action OnTakeDamage(victim, &attacker, &inflictor, float &damage, &damagetype)
{
	if(damagetype & DMG_FALL)
	{
		return Plugin_Handled;
	}
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
        if (GetEntProp(victim, Prop_Send, "m_bInBuyZone")) {
            return Plugin_Handled;
        }
        if (GetEntProp(attacker, Prop_Send, "m_bInBuyZone")) {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}  

/*====================================
=           TagTog           =
====================================*/

public Action Cmd_TagTog(int client, int args)
{
	if(g_RankTag[client])
	{
		g_RankTag[client] = false;
		CPrintToChat(client, "%t", "YouHaveDisabledTheRankTag", g_PluginPrefix);
    }
    else if(!g_RankTag[client])
    {
    	g_RankTag[client] = true;
    	CPrintToChat(client, "%t", "YouHaveEnabledTheRankTag", g_PluginPrefix);
    }
}

/*====================================
=           Rank Commands            =
====================================*/
public Action Cmd_Top(int client, int args)
{
    char g_Query[512];
	
	FormatEx(g_Query, 512, "SELECT steamid, name, kills FROM `players` WHERE kills != 0 ORDER BY kills DESC LIMIT %d;", g_TopLimit.IntValue);
	g_DBSQL.Query(SQL_SelectTop_Callback, g_Query, GetClientSerial(client), DBPrio_Normal);
	
	
	return Plugin_Handled;
}

public Action Cmd_Stats(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	char gB_SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, gB_SteamID64, 32))
	{
		return Plugin_Handled;
	}
	
	OpenStatsMenu(client, client);
	
	return Plugin_Handled;
}

void OpenStatsMenu(int client, int displayto)
{
	Menu menu = new Menu(Stats_MenuHandler);
	menu.SetTitle("%s Stats:", g_szMenuPrefix);
	
	char gH_Kills[128], gH_Deaths[128], gH_Shots[128], gH_Hits[128], gH_HS[128], gH_Assists[128], gH_PlayTime[258], gH_PlayTime2[128];
	int g_Seconds = RoundToZero(GetClientTime(client));
	int CurrentTime = g_Seconds + g_PlayTime[client];
	SecondsToTime(CurrentTime, gH_PlayTime2);
	
	int g_Accuracy = 0;
	if (g_PHits[client] != 0 && g_PShots[client] != 0)
	{
		g_Accuracy = (100 * g_PHits[client] + g_PShots[client] / 2) / g_PShots[client];
	}
	
	int g_HSP = 0;
	if (g_PHits[client] != 0 && g_PHS[client] != 0)
	{
		g_HSP = (100 * g_PHits[client] + g_PHS[client] / 2) / g_PHS[client];
	}
	
	FormatEx(gH_Kills, 128, "Your total kills : %d", g_PKills[client]);
	FormatEx(gH_Deaths, 128, "Your total deaths : %d", g_PDeaths[client]);
	FormatEx(gH_Shots, 128, "Your total shots : %d", g_PShots[client]);
	FormatEx(gH_Hits, 128, "Your total hits : %d (Accuracy : %d%%%)", g_PHits[client], g_Accuracy);
	FormatEx(gH_HS, 128, "Your total headshots : %d (HS Percent : %d%%%)", g_PHS[client], g_HSP);
	FormatEx(gH_Assists, 128, "Your total assists : %d", g_PAssists[client]);
	FormatEx(gH_PlayTime, 128, "Play time : %s", gH_PlayTime2);
	
	menu.AddItem("", gH_Kills, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_Deaths, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_Shots, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_Hits, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_HS, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_Assists, ITEMDRAW_DISABLED);
	menu.AddItem("", gH_PlayTime, ITEMDRAW_DISABLED);
	
	menu.ExitButton = true;
	menu.Display(displayto, 30);
}

public int Stats_MenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

/*====================================
=           VipMenu                  =
====================================*/

public Action Cmd_VipMenu(int client, int args)  
{
  if(g_EnableVipmenu.IntValue == 1)
  {
  	 if(GetClientTeam(client) == 1)
  	 {
			CPrintToChat(client, "%t", "YouReSpectator", g_PluginPrefix);
			return Plugin_Handled;
 	 }
  	 if(g_UsedMenu[client])
  	 {
			CPrintToChat(client, "%t", "YouHaveAlreadyUseTheMenu", g_PluginPrefix);
			return Plugin_Handled;
  	 }
  	 else
  	 {
	 	if(IsValidClient(client) && IsPlayerAlive(client))
   	 	{
	   		   	g_UsedMenu[client] = true;
		 	  	Menu menu = new Menu(VipMenuS);
	
				menu.SetTitle("%s Vip Menu", g_szMenuPrefix);
				menu.AddItem("AKDeag", "AK47 + Deagle");
				menu.AddItem("M4Deag", "M4A4 + Deagle");
				menu.AddItem("M4ADeag", "M4A1-S + Deagle");
				menu.AddItem("AWDeag", "AWP + Deagle");
				menu.ExitButton = false;
				menu.Display(client, MENU_TIME_FOREVER);
  	    }
     }
  }
  return Plugin_Handled; 
}

public int VipMenuS(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));

		    if (StrEqual(info, "AKDeag"))
			{
				CPrintToChat(client, "%t", "YouChoosedAKD", g_PluginPrefix);
                GivePlayerItem(client, "weapon_ak47");
                GivePlayerItem(client, "weapon_deagle");
			}
			else if (StrEqual(info, "M4Deag"))
			{
				CPrintToChat(client, "%t", "YouChoosedM4D", g_PluginPrefix);
				GivePlayerItem(client, "weapon_m4a4");
                GivePlayerItem(client, "weapon_deagle");
			}
			else if (StrEqual(info, "M4ADeag"))
			{
				 CPrintToChat(client, "%t", "YouChoosedM4AD", g_PluginPrefix);
                 GivePlayerItem(client, "weapon_m4a1_silencer");
                 GivePlayerItem(client, "weapon_deagle");
			}
			else if (StrEqual(info, "AWDeag"))
			{
				 CPrintToChat(client, "%t", "YouChoosedAKD", g_PluginPrefix);
                 GivePlayerItem(client, "weapon_awp");
                 GivePlayerItem(client, "weapon_deagle");
			}
		}

		case MenuAction_End:{delete menu;}
	}

	return 0;
}

/*====================================
=        RankBonus                 =
====================================*/

public Action RankBonus(int client, int args)
{
    if(g_BonusCase[client] > 0)
   	{
   		g_BonusCase[client] -= 1;
   		int randomNumber = GetRandomInt(0,100);	
		PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| <font color='#15fb00'>%i</font> ||</font></b></u></big>", g_szMenuPrefix, randomNumber);
		if(randomNumber < 20)
		{
			g_PKills[client] += 1;
			PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| You have won<font color='#15fb00'>1/font> Points ||</font></b></u></big>", g_szMenuPrefix);
	    }
	    else if(20 < randomNumber < 40)
	    {
	    	g_PKills[client] += 2;
	    	PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| You have won<font color='#15fb00'>2/font> Points ||</font></b></u></big>", g_szMenuPrefix);
	    }
	    else if(40 < randomNumber < 60)
	    {
	    	g_PKills[client] += 3;
	    	PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| You have won<font color='#15fb00'>3/font> Points ||</font></b></u></big>", g_szMenuPrefix);
	    }
	    else if(80 < randomNumber < 98)
	    {
	    	g_PKills[client] += 5;
	    	PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| You have won<font color='#15fb00'>5/font> Points ||</font></b></u></big>", g_szMenuPrefix);
	    }
	    else if(randomNumber > 98)
	    {
	        g_WonLegendary[client] = true;
	    	PrintCenterText(client, "<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| You have won<font color='#15fb00'>an Legendary Player Model/font> Do !bonusmodel to activate||</font></b></u></big>", g_szMenuPrefix);
	    }
   	}
   	else
   	{
   		CPrintToChat(client, "%t", "YouDontHaveCases", g_PluginPrefix);
    }
}

public Action BonusModel(int client, int args)
{
	if(g_WonLegendary[client])
	{
		if(g_BatMan[client])
		{
			g_BatMan[client] = false;
			CPrintToChat(client, "%t", "YouHaveDisabledTheBatman", g_PluginPrefix);
	    }
	    else if(!g_BatMan[client])
		{
			g_BatMan[client] = true;
			CPrintToChat(client, "%t", "YouHaveEnabledTheBatman", g_PluginPrefix);
	    }
    }
    else
    {
    	CPrintToChat(client, "%t", "YouDontHaveWonLegend", g_PluginPrefix);
    }
}
/*====================================
=        Legend Menu                 =
====================================*/

public Action LegendMenu(int client, int args)
{
     if(IsValidClient(client) && IsPlayerAlive(client) && g_ImALegend[client])
     {
        Menu menu = new Menu(LegendMenuHandle);

		menu.SetTitle("%s Legend Menu", g_szMenuPrefix);
		menu.AddItem("KS", "Kill Sounds");
		menu.AddItem("M", "Models");
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	 }
	 else
	 {
	 	CPrintToChat(client, "%t", "YouAreNotLegend", g_PluginPrefix);
	 }
}

public int LegendMenuHandle(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));

		    if (StrEqual(info, "KS"))
			{
				Menu aa = new Menu(LegendMenuSoundHandle);

				aa.SetTitle("%s Legend Menu", g_szMenuPrefix);
				aa.AddItem("KS", "Im a fucking legend");
				aa.AddItem("M", "It s fucking bed time");
				aa.ExitButton = false;
				aa.Display(client, MENU_TIME_FOREVER);
			}
			else if (StrEqual(info, "M"))
			{
				Menu aa = new Menu(LegendMenuModelsHandle);

				aa.SetTitle("%s Legend Menu", g_szMenuPrefix);
				aa.AddItem("KS", "DeadPool");
				aa.AddItem("M", "Thanos");
				aa.ExitButton = false;
				aa.Display(client, MENU_TIME_FOREVER);
			}
		}

		case MenuAction_End:{delete menu;}
	}

	return 0;
}

public int LegendMenuSoundHandle(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));

		    if (StrEqual(info, "KS"))
			{
				g_BedSound[client] = false;
				g_LegendSound[client] = true;
				CPrintToChat(client, "%t", "YouHaveEnabledTheSound", g_PluginPrefix);
			}
			else if (StrEqual(info, "M"))
			{
				g_LegendSound[client] = false;
				g_BedSound[client] = true;
				CPrintToChat(client, "%t", "YouHaveEnabledTheSound", g_PluginPrefix);
				
			}
		}
		case MenuAction_End:{delete menu;}
	}

	return 0;
}

public int LegendMenuModelsHandle(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));

		    if (StrEqual(info, "KS"))
			{
				g_Thanos[client] = false;
				g_DeadPool[client] = true;
				g_BatMan[client] = false;
				CPrintToChat(client, "%t", "YouHaveEnabledTheModel", g_PluginPrefix);
			}
			else if (StrEqual(info, "M"))
			{
				g_DeadPool[client] = false;
				g_Thanos[client] = true;
				g_BatMan[client] = false;
				CPrintToChat(client, "%t", "YouHaveEnabledTheModel", g_PluginPrefix);
			}
		}
		case MenuAction_End:{delete menu;}
	}

	return 0;
}

/*====================================
=           Duel                    =
====================================*/

public void ShowDuelMenu(int client)
{
     if(IsValidClient(client) && IsPlayerAlive(client))
     {
        Menu menu = new Menu(DuelMenu);

		menu.SetTitle("%s Duel", g_szMenuPrefix);
		menu.AddItem("AN", "AWP NoScope");
		menu.AddItem("KLG", "Low Gravity + Knife");
		menu.AddItem("SK", "Speed + Knife");
		menu.AddItem("D1HP", "Decoy + 1 HP");
		menu.AddItem("ND", "No Duel");
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	 }
}

public int DuelMenu(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));

		    if (StrEqual(info, "AN"))
			{
				VoteD1();
			}
			else if (StrEqual(info, "KLG"))
			{
				VoteD2();
			}
			else if (StrEqual(info, "D1HP"))
			{
				VoteD3();
			}
			else if (StrEqual(info, "SK"))
			{
				VoteD4();
			}
			else if (StrEqual(info, "ND"))
			{
				VoteD5();
			}
		}

		case MenuAction_End:{delete menu;}
	}

	return 0;
}

public void VoteD1()
{
	vote1 += 1;
	checkvotes();
}

public void VoteD2()
{
	vote2 += 1;
	checkvotes();
}

public void VoteD3()
{
	vote3 += 1;
	checkvotes();
}

public void VoteD4()
{
	vote4 += 1;
	checkvotes();
}

public void VoteD5()
{
	vote5 += 1;
	checkvotes();
}

public void checkvotes()
{
  	if(vote1 == 2)
	{
		   AWNoscope();
    }
    else if(vote1 == 1)
    {
    	int number = GetRandomInt(1, 2);
    	if (vote2 == 1)
    	{
    		if(number == 1)
    		{
    			AWNoscope();
    	    }
    	    else
    	    {
    	    	KnifeLowGravity();
    	    }
        }
        else if (vote3 == 1)
        {
        	if(number == 1)
    		{
    			AWNoscope();
    	    }
    	    else
    	    {
    	    	Decoy1HP();
    	    }
        }
        else if (vote4 == 1)
        {
        	if(number == 1)
    		{
    			AWNoscope();
    	    }
    	    else
    	    {
    	    	SpeedKnife();
    	    }
        }
        else if (vote5 == 1)
        {
        	NoDuel();
        }
    }
    
    else if(vote2 == 2)
	{
		   KnifeLowGravity();
    }
    else if(vote2 == 1)
    {
    	int number = GetRandomInt(1, 2);
    	if (vote2 == 1)
    	{
    		if(number == 1)
    		{
    			KnifeLowGravity();
    	    }
    	    else
    	    {
    	    	AWNoscope();
    	    }
        }
        else if (vote3 == 1)
        {
        	if(number == 1)
    		{
    			KnifeLowGravity();
    	    }
    	    else
    	    {
    	    	Decoy1HP();
    	    }
        }
        else if (vote4 == 1)
        {
        	if(number == 1)
    		{
    			KnifeLowGravity();
    	    }
    	    else
    	    {
    	    	SpeedKnife();
    	    }
        }
        else if (vote5 == 1)
        {
        	NoDuel();
        }
    }
    else if(vote3 == 2)
	{
		   Decoy1HP();
    }
    else if(vote3 == 1)
    {
    	int number = GetRandomInt(1, 2);
    	if (vote1 == 1)
    	{
    		if(number == 1)
    		{
    			Decoy1HP();
    	    }
    	    else
    	    {
    	    	AWNoscope();
    	    }
        }
        else if (vote2 == 1)
        {
        	if(number == 1)
    		{
    			Decoy1HP();
    	    }
    	    else
    	    {
    	    	KnifeLowGravity();
    	    }
        }
        else if (vote4 == 1)
        {
        	if(number == 1)
    		{
    			Decoy1HP();
    	    }
    	    else
    	    {
    	    	SpeedKnife();
    	    }
        }
        else if (vote5 == 1)
        {
        	NoDuel();
        }
    }
    else if(vote4 == 2)
	{
		   Decoy1HP();
    }
    else if(vote4 == 1)
    {
    	int number = GetRandomInt(1, 2);
    	if (vote1 == 1)
    	{
    		if(number == 1)
    		{
    			SpeedKnife();
    	    }
    	    else
    	    {
    	    	AWNoscope();
    	    }
        }
        else if (vote2 == 1)
        {
        	if(number == 1)
    		{
    			SpeedKnife();
    	    }
    	    else
    	    {
    	    	KnifeLowGravity();
    	    }
        }
        else if (vote3 == 1)
        {
        	if(number == 1)
    		{
    			SpeedKnife();
    	    }
    	    else
    	    {
    	    	Decoy1HP();
    	    }
        }
        else if (vote5 == 1)
        {
        	NoDuel();
        }
    }
    else if (vote5 == 2)
    {
        	NoDuel();
    }
}

public Action TeleportPlayers()
{ 
   for (int i = 0; i <= MaxClients; i++)
	if(IsValidClient(i) && IsPlayerAlive(i))
	{
		float ctvec[3];
		float tvec[3];
		float distance[1];
		if(GetClientTeam(i) == 2)
		{
			GetClientAbsOrigin(i, tvec);
	    }
	    else if(GetClientTeam(i) == 3)
		{
			GetClientAbsOrigin(i, ctvec);
	    }
		distance[0] = GetVectorDistance(ctvec, tvec, true);
		if (distance[0] >= 600000.0)
		{
			teleloc = ctvec;
			CreateTimer(1.0, DoTp);
		}
	}
}

public Action DoTp(Handle timer)
{
  for (int i = 0; i <= MaxClients; i++)
  {
	if(GetClientTeam(i) == 2 && IsValidClient(i) && IsPlayerAlive(i))
	{
		TeleportEntity(i, teleloc, NULL_VECTOR, NULL_VECTOR);
	}
  }
}

public Action AWNoscope()
{ 
 for (int i = 0; i <= MaxClients; i++)
  if(IsValidClient(i) && IsPlayerAlive(i))
  {
    TeleportPlayers();
	InNoscope = true;
    Client_RemoveAllWeapons(i);
    char weapon = GivePlayerItem(i, "weapon_awp");
    SetEntProp(weapon, Prop_Data, "m_iClip1", 1000);
  }
}

public Action KnifeLowGravity()
{ 
 for (int i = 0; i <= MaxClients; i++)
  if(IsValidClient(i) && IsPlayerAlive(i))
  {
    TeleportPlayers();
    Client_RemoveAllWeapons(i);
    GivePlayerItem(i, "weapon_knife");
    SetGravity(i, g_KnifeDuelGravity.FloatValue); 
  }
}

public Action SpeedKnife()
{ 
 for (int i = 0; i <= MaxClients; i++)
  if(IsValidClient(i) && IsPlayerAlive(i))
  {
    TeleportPlayers();
    Client_RemoveAllWeapons(i);
    GivePlayerItem(i, "weapon_knife");
    SetSpeed(i, g_KnifeDuelPlayerSpeed.FloatValue);
  }
}

public Action Decoy1HP()
{ 
 for (int i = 0; i <= MaxClients; i++)
  if(IsValidClient(i) && IsPlayerAlive(i))
  {
    TeleportPlayers();
    InDecoyDuel = true;
    Client_RemoveAllWeapons(i);
    SetEntityHealth(i, 1);
    GivePlayerItem(i, "weapon_decoy");
  }
}

public Action NoDuel()
{ 
    CPrintToChatAll("%t", "DuelCancelled", g_PluginPrefix);
}
/*====================================
=           Sql Functions            =
====================================*/

void UpdatePlayer(int client, float timeonserver)
{
	if (g_DBSQL == null)
	{
		return;
	}
	
	char g_SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, g_SteamID64, 32))
	{
		return;
	}
	
	
	int g_Seconds = RoundToNearest(timeonserver);
	
	char g_Query[512];
	FormatEx(g_Query, 512, "UPDATE `players` SET `kills`= %d,`deaths`= %d,`shots`= %d,`hits`= %d,`headshots`= %d,`assists`= %d, `secsonserver` = secsonserver + %d WHERE `steamid` = '%s';", g_PKills[client], g_PDeaths[client], g_PShots[client], g_PHits[client], g_PHS[client], g_PAssists[client], g_Seconds, g_SteamID64);
	g_DBSQL.Query(SQL_UpdatePlayer_Callback, g_Query, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_UpdatePlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SC] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SC] Cant use client data. Reason: %s", client, error);
		}
		return;
	}
}

public void SQL_SelectTop_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SC] Selecting players error. Reason: %s", error);
		return;
	}
	
	int client = GetClientFromSerial(data);
	if (client == 0)
	{
		LogError("[SC] Client is not valid. Reason: %s", error);
		return;
	}
	
	Menu menu = new Menu(TopHandler);
	menu.SetTitle("%s Top %i", g_szMenuPrefix, g_TopLimit.IntValue);
	
	int gS_Count = 0;
	while (results.FetchRow())
	{
		gS_Count++;
		
		//SteamID
		char[] gS_SteamID = new char[32];
		results.FetchString(0, gS_SteamID, 32);
		
		
		//Player Name
		char[] gS_PlayerName = new char[MAX_NAME_LENGTH];
		results.FetchString(1, gS_PlayerName, MAX_NAME_LENGTH);
		
		//Kills
		int gS_Kills = results.FetchInt(2);
		
		char gS_MenuContent[128];
		Format(gS_MenuContent, 128, "%d - %s (%d kill%s)", gS_Count, gS_PlayerName, gS_Kills, gS_Kills > 1 ? "s":"");
		menu.AddItem(gS_SteamID, gS_MenuContent);
	}
	
	if (!gS_Count)
	{
		menu.AddItem("-1", "No results.");
	}
	
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int TopHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public void SQL_InsertPlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SC] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SC] Cant use client data. Reason: %s", client, error);
		}
		return;
	}
	
	char g_SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, g_SteamID64, 32))
	{
		return;
	}
	
	
	char g_Query[512];
	char g_Query2[512];
	
	FormatEx(g_Query, 512, "SELECT kills, deaths, shots, hits, headshots, assists, secsonserver FROM `players` WHERE `steamid` = '%s'", g_SteamID64);
	g_DBSQL.Query(SQL_SelectPlayer_Callback, g_Query, GetClientSerial(client), DBPrio_Normal);
	
	FormatEx(g_Query2, 512, "UPDATE `players` SET `lastconn`= UNIX_TIMESTAMP() WHERE `steamid` = '%s';", g_SteamID64);
	g_DBSQL.Query(SQL_UpdatePlayer2_Callback, g_Query2, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_SelectPlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SC] Selecting player error. Reason: %s", error);
		return;
	}
	
	int client = GetClientFromSerial(data);
	if (client == 0)
	{
		LogError("[SC] Client is not valid. Reason: %s", error);
		return;
	}
	
	while (results.FetchRow())
	{
		g_PKills[client] = results.FetchInt(0);
		g_PDeaths[client] = results.FetchInt(1);
		g_PShots[client] = results.FetchInt(2);
		g_PHits[client] = results.FetchInt(3);
		g_PHS[client] = results.FetchInt(4);
		g_PAssists[client] = results.FetchInt(5);
		g_PlayTime[client] = results.FetchInt(6);
	}
}

public void SQL_UpdatePlayer2_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SC] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SC] Cant use client data. Reason: %s", client, error);
		}
		return;
	}
}

/*====================================
=        Stocks // Actions           =
====================================*/

public Action GetPlayerRank(int client)
{
	int PlayerRankPoints = g_PKills[client] - g_PDeaths[client];
	if(PlayerRankPoints < 5)
	{
		g_PlayerRank = "Unranked |";
		g_CurrentRank[client] = 0;
    }
    else if(PlayerRankPoints < 10)
    {
    	if(g_CurrentRank[client] != 1)
    	{
    		if(g_CurrentRank[client] !=2)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
    	g_PlayerRank = "Beginner III |";
    	g_CurrentRank[client] = 1;
    }
    else if(PlayerRankPoints < 20)
    {
    	if(g_CurrentRank[client] != 2)
    	{
    		if(g_CurrentRank[client] !=3)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Beginner II |";
   		g_CurrentRank[client] = 2;
    }
    else if(PlayerRankPoints < 30)
    {
    	if(g_CurrentRank[client] != 3)
    	{
    		if(g_CurrentRank[client] !=4)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Beginner I |";
   		g_CurrentRank[client] = 3;
    }
    else if(PlayerRankPoints < 45)
    {
    	if(g_CurrentRank[client] != 4)
    	{
    		if(g_CurrentRank[client] !=5)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Professional III |";
   		g_CurrentRank[client] = 4;
    }
    else if(PlayerRankPoints < 65)
    {
    	if(g_CurrentRank[client] != 5)
    	{
    		if(g_CurrentRank[client] !=6)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Professional II |";
   		g_CurrentRank[client] = 5;
    }
    else if(PlayerRankPoints < 90)
    {
    	if(g_CurrentRank[client] != 6)
    	{
    		if(g_CurrentRank[client] !=7)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Professional I |";
   		g_CurrentRank[client] = 6;
    }
    else if(PlayerRankPoints < 115)
    {
    	if(g_CurrentRank[client] != 7)
    	{
    		if(g_CurrentRank[client] !=8)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Expert III |";
   		g_CurrentRank[client] = 7;
    }
    else if(PlayerRankPoints < 140)
    {
    	if(g_CurrentRank[client] != 8)
    	{
    		if(g_CurrentRank[client] !=9)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Expert II |";
   		g_CurrentRank[client] = 8;
    }
    else if(PlayerRankPoints < 300)
    {
    	if(g_CurrentRank[client] != 9)
    	{
    		if(g_CurrentRank[client] != 10)
    		{
    			g_BonusCase[client] += 1;
    	    }
        }
   		g_PlayerRank = "Expert I |";
   		g_CurrentRank[client] = 9;
   		g_ImALegend[client] = false;
    }
    else if(PlayerRankPoints >= 300)
    {
    	if(g_CurrentRank[client] != 10)
    	{
    		g_BonusCase[client] += 1;
        }
    	g_ImALegend[client] = true;
   		g_PlayerRank = "Legend |";
   		g_CurrentRank[client] = 10;
    }
}

void ConnectToDatabase()
{
	if (g_DBSQL != null)
	{
		delete g_DBSQL;
	}
	
	char g_Error[255];
	if (SQL_CheckConfig("SurfCombat"))
	{
		g_DBSQL = SQL_Connect("SurfCombat", true, g_Error, 255);
		
		if (g_DBSQL == null)
		{
			SetFailState("[SC] Error on start. Reason: %s", g_Error);
		}
	}
	else
	{
		SetFailState("[SC] Cant find `SurfCombat` on database.cfg");
	}
	
	g_DBSQL.SetCharset("utf8");
	
	char g_Query[512];
	FormatEx(g_Query, 512, "CREATE TABLE IF NOT EXISTS `players` (`steamid` VARCHAR(17) NOT NULL, `name` VARCHAR(32), `ip` VARCHAR(64), `kills` INT(11) NOT NULL, `deaths` INT(11) NOT NULL, `shots` INT(11) NOT NULL, `hits` INT(11) NOT NULL, `headshots` INT(11) NOT NULL, `assists` INT(11) NOT NULL, `secsonserver` INT(20) NOT NULL, `lastconn` INT(32) NOT NULL, PRIMARY KEY (`steamid`))");
	if (!SQL_FastQuery(g_DBSQL, g_Query))
	{
		SQL_GetError(g_DBSQL, g_Error, 255);
		LogError("[SC] Cant create table. Error : %s", g_Error);
	}
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

stock int GetPlayersCount()
{
	int count = 0;
	for (int i = 0; i < MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			count++;
		}
	}
	return count;
}

stock int SecondsToTime(int seconds, char[] buffer)
{
	int mins, secs;
	if (seconds >= 60)
	{
		mins = RoundToFloor(float(seconds / 60));
		seconds = seconds % 60;
	}
	secs = RoundToFloor(float(seconds));
	
	if (mins)
		Format(buffer, 70, "%s%d mins, ", buffer, mins);
	
	Format(buffer, 70, "%s%d secs", buffer, secs);
}

public int AliveTPlayers()
{
	int g_Terrorists = 0;
	for (int  i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			g_Terrorists++;
		}
	}
	return g_Terrorists;
}

public int AliveCTPlayers()
{
	int g_CTerrorists = 0;
	for (int  i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
		{
			g_CTerrorists++;
		}
	}
	return g_CTerrorists;
}

public void SetSpeed(int client, float speed)
{
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
}

public void SetGravity(int client, float amount)
{
    SetEntityGravity(client, amount / GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue"));
}