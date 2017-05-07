#include <sdktools>
#include <autoexecconfig>
#include <multicolors>
#include <vpp_adverts>


/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define PL_VERSION "1.3.5"
#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))
#define PREFIX "[{lightgreen}Advert{default}] "

new g_phraseCount;
new String:g_Phrases[256][192];

new String:gameDir[255];
new String:g_serverIP[16];

new g_serverPort;

/****************************************************************************************************
	ETIQUETTE.
*****************************************************************************************************/
#pragma semicolon 1;

/****************************************************************************************************
	PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
	name = "Multi Advertisement Plugin", 
	author = "Franc1sco franug based on vpp plugin", 
	description = "", 
	version = PL_VERSION, 
	url = "http://steamcommunity.com/id/franug"
}

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
ConVar g_hAdvertUrl = null;
ConVar g_hCvarJoinGame = null;
ConVar g_hCvarAdvertPeriod = null;
ConVar g_hCvarImmunityEnabled = null;
ConVar g_hCvarAdvertTotal = null;
ConVar g_hCvarPhaseAds = null;
ConVar g_hCvarMotdCheck = null;
ConVar g_hCvarSpecAdvertPeriod = null;
ConVar g_hCvarRadioResumation = null;
ConVar g_hCvarMessages = null;
ConVar g_hCvarJoinType = null;
ConVar g_hCvarWaitUntilDead = null;
ConVar g_hCvarDeathAds = null;

Handle g_hFinishedTimer[MAXPLAYERS + 1] = null;
Handle g_hSpecTimer[MAXPLAYERS + 1] = null;
Handle g_hPeriodicTimer[MAXPLAYERS + 1] = null;
Handle g_hOnAdvertStarted = null;
Handle g_hOnAdvertFinished = null;

Menu g_mMenuWarning = null;

ArrayList g_alRadioStations = null;
EngineVersion g_eVersion = Engine_Unknown;

/****************************************************************************************************
	STRINGS.
*****************************************************************************************************/
char g_szGameName[256];

char g_szTestedGames[][] =  {
	"csgo", 
	"csco", 
	"tf", 
	"cstrike", 
	"cure", 
	"brainbread2", 
	"dod", 
	"fof", 
	"nucleardawn", 
	"nmrih"
};

char g_szJoinGames[][] =  {
	"dod", 
	"nucleardawn", 
	"brainbread2", 
	"cstrike"
};

char g_szResumeUrl[MAXPLAYERS + 1][256];

/****************************************************************************************************
	BOOLS.
*****************************************************************************************************/
bool g_bFirstJoin[MAXPLAYERS + 1] = false;
bool g_bAdvertPlaying[MAXPLAYERS + 1] = false;
bool g_bJoinGame = false;
bool g_bProtoBuf = false;
bool g_bPhaseAds = false;
bool g_bPhase = false;
bool g_bGameTested = false;
bool g_bForceJoinGame = false;
bool g_bImmunityEnabled = false;
bool g_bRadioResumation = false;
bool g_bMessages = false;
bool g_bWaitUntilDead = false;
bool g_bAdvertQued[MAXPLAYERS + 1] = false;
bool g_bMotdDisabled[MAXPLAYERS + 1] = false;

/****************************************************************************************************
	INTS.
*****************************************************************************************************/
int g_iAdvertTotal = -1;
int g_iAdvertPlays[MAXPLAYERS + 1] = 0;
int g_iLastAdvertTime[MAXPLAYERS + 1] = 0;
int g_iJoinType = 1;
int g_iMotdOccurence[MAXPLAYERS + 1] = 0;
int g_iDeathAdCount = 0;
int g_iMotdAction = 0;

/****************************************************************************************************
	FLOATS.
*****************************************************************************************************/
float g_fAdvertPeriod;
float g_fSpecAdvertPeriod;

public void OnPluginStart()
{
	GetGameFolderName(gameDir, sizeof(gameDir));

	new Handle:serverIP = FindConVar("hostip");
	new Handle:serverPort = FindConVar("hostport");
	if (serverIP == INVALID_HANDLE || serverPort == INVALID_HANDLE)
		SetFailState("Could not determine server ip and port.");

	new IP = GetConVarInt(serverIP);
	g_serverPort = GetConVarInt(serverPort);
	Format(g_serverIP, sizeof(g_serverIP), "%d.%d.%d.%d", IP >>> 24 & 255, IP >>> 16 & 255, IP >>> 8 & 255, IP & 255);
	UserMsg umVGUIMenu = GetUserMessageId("VGUIMenu");
	
	if (umVGUIMenu == INVALID_MESSAGE_ID) {
		SetFailState("[VPP] The server's engine version doesn't supports VGUI menus.");
	}
	
	HookUserMessage(umVGUIMenu, OnVGUIMenu, true);
	
	g_bProtoBuf = (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
	
	if (GetGameFolderName(g_szGameName, sizeof(g_szGameName)) <= 0) {
		SetFailState("Something went very wrong with this game / engine, thus support is not available.");
	}
	
	g_eVersion = GetEngineVersion();
	
	int iSupportedGames = sizeof(g_szTestedGames);
	int iJoinGames = sizeof(g_szJoinGames);
	
	for (int i = 0; i < iSupportedGames; i++) {
		if (StrEqual(g_szGameName, g_szTestedGames[i])) {
			g_bGameTested = true;
			break;
		}
	}
	
	for (int i = 0; i < iJoinGames; i++) {
		if (StrEqual(g_szGameName, g_szJoinGames[i])) {
			g_bForceJoinGame = true;
			break;
		}
	}
	
	if (!g_bGameTested) {
		LogMessage("This plugin has not been tested on this engine / (game: %s, engine: %d), things may not work correctly.", g_szGameName, g_eVersion);
	}
	
	AutoExecConfig_SetFile("plugin.vpp_adverts");
	
	g_hAdvertUrl = AutoExecConfig_CreateConVar("sm_vpp_url", "", "Put your VPP Advert Link here");
	g_hAdvertUrl.AddChangeHook(OnCvarChanged);
	
	g_hCvarJoinGame = AutoExecConfig_CreateConVar("sm_vpp_onjoin", "1", "Should advertisement be displayed to players on first team join?, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarJoinGame.AddChangeHook(OnCvarChanged);
	
	g_hCvarAdvertPeriod = AutoExecConfig_CreateConVar("sm_vpp_ad_period", "5", "How often the periodic adverts should be played (In Minutes), 0 = Disabled.", _, true, 3.0);
	g_hCvarAdvertPeriod.AddChangeHook(OnCvarChanged);
	
	g_hCvarSpecAdvertPeriod = AutoExecConfig_CreateConVar("sm_vpp_spec_ad_period", "3", "How often should ads be played to spectators (In Minutes), 0 = Disabled.", _, true, 3.0);
	g_hCvarSpecAdvertPeriod.AddChangeHook(OnCvarChanged);
	
	g_hCvarPhaseAds = AutoExecConfig_CreateConVar("sm_vpp_onphase", "1", "Should advertisement be displayed on game phases? (HalfTime, OverTime, MapEnd, WinPanels etc) 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarPhaseAds.AddChangeHook(OnCvarChanged);
	
	g_hCvarDeathAds = AutoExecConfig_CreateConVar("sm_vpp_every_x_deaths", "0", "Play an advert every time somebody dies this many times, 0 = Disabled.", _, true, 0.0);
	g_hCvarDeathAds.AddChangeHook(OnCvarChanged);
	
	g_hCvarAdvertTotal = AutoExecConfig_CreateConVar("sm_vpp_ad_total", "0", "How many adverts should be played in total (excluding join adverts)? 0 = Unlimited, -1 = Disabled.", _, true, -1.0);
	g_hCvarAdvertTotal.AddChangeHook(OnCvarChanged);
	
	g_hCvarImmunityEnabled = AutoExecConfig_CreateConVar("sm_vpp_immunity_enabled", "0", "Prevent displaying ads to users with access to 'advertisement_immunity', 0 = Disabled. (Default: Reservation Flag)", _, true, 0.0, true, 1.0);
	g_hCvarImmunityEnabled.AddChangeHook(OnCvarChanged);
	
	g_hCvarMotdCheck = AutoExecConfig_CreateConVar("sm_vpp_kickmotd", "0", "Action for player with html motd disabled, 0 = Disabled, 1 = Kick Player, 2 = Display notifications.", _, true, 0.0, true, 2.0);
	g_hCvarMotdCheck.AddChangeHook(OnCvarChanged);
	
	g_hCvarRadioResumation = AutoExecConfig_CreateConVar("sm_vpp_radio_resumation", "1", "Resume Radio after advertisement finishes, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarRadioResumation.AddChangeHook(OnCvarChanged);
	
	g_hCvarMessages = AutoExecConfig_CreateConVar("sm_vpp_messages", "1", "Show messages to clients, 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarMessages.AddChangeHook(OnCvarChanged);
	
	g_hCvarJoinType = AutoExecConfig_CreateConVar("sm_vpp_onjoin_type", "1", "2 = Wait for team join, If you have issues with method 1 then set this to method 2, It defaults at 1, in most cases you should leave this at 1.", _, true, 1.0, true, 2.0);
	g_hCvarJoinType.AddChangeHook(OnCvarChanged);
	
	g_hCvarWaitUntilDead = AutoExecConfig_CreateConVar("sm_vpp_wait_until_dead", "0", "Wait until player is dead (Except first join) 0 = Disabled.", _, true, 0.0, true, 1.0);
	g_hCvarWaitUntilDead.AddChangeHook(OnCvarChanged);
	
	RegAdminCmd("sm_vppreload", Command_Reload, ADMFLAG_CONVARS, "Reloads radio stations");
	
	HookEventEx("game_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("game_end", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("round_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("tf_game_over", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("teamplay_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("teamplay_round_win", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("arena_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("announce_phase_end", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("cs_win_panel_match", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("wave_complete", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("dod_game_over", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("dod_win_panel", Phase_Hooks, EventHookMode_Pre);
	HookEventEx("round_start", Event_RoundStart, EventHookMode_Post);
	HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	LoadTranslations("vppadverts.phrases.txt");
	
	UpdateConVars();
	AutoExecConfig_CleanFile(); AutoExecConfig_ExecuteFile();
	LoadRadioStations();
	
	RegServerCmd("sm_vpp_immunity", OldCvarFound, "Outdated cvar, please update your config.");
	RegServerCmd("sm_vpp_ad_grace", OldCvarFound, "Outdated cvar, please update your config.");
	
	LoopValidClients(iClient) {
		OnClientPutInServer(iClient); g_bFirstJoin[iClient] = false;
	}
	
	g_hOnAdvertStarted = CreateGlobalForward("VPP_OnAdvertStarted", ET_Ignore, Param_Cell, Param_String);
	g_hOnAdvertFinished = CreateGlobalForward("VPP_OnAdvertFinished", ET_Ignore, Param_Cell, Param_String);
	
	CreateMotdMenu();
}

public APLRes AskPluginLoad2(Handle hNyself, bool bLate, char[] chError, int iErrMax)
{
	CreateNative("VPP_PlayAdvert", Native_PlayAdvert);
	CreateNative("VPP_IsAdvertPlaying", Native_IsAdvertPlaying);
	
	RegPluginLibrary("VPPAdverts");
	return APLRes_Success;
}

public int Native_IsAdvertPlaying(Handle hPlugin, int iNumParams) {
	int iClient = GetNativeCell(1);
	
	return g_bAdvertPlaying[iClient];
}

public int Native_PlayAdvert(Handle hPlugin, int iNumParams) {
	int iClient = GetNativeCell(1);
	
	if (HasClientFinishedAds(iClient) || g_bAdvertQued[iClient]) {
		return false;
	}
	
	while (QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, true) < view_as<QueryCookie>(0)) {  }
	
	if(!IsClientConnected(iClient)) {
		return false;
	}
	
	return !g_bMotdDisabled[iClient];
}

public Action OldCvarFound(int iArgs)
{
	if (iArgs != 1) {
		return Plugin_Handled;
	}
	
	char szCvarName[64]; GetCmdArg(0, szCvarName, sizeof(szCvarName));
	
	LogError("\n\nHey, it looks like your config is outdated, Please consider having a look at the information below and update your config.\n");
	
	if (StrEqual(szCvarName, "sm_vpp_immunity", false)) {
		LogError("======================[sm_vpp_immunity]======================");
		LogError("sm_vpp_immunity has changed to sm_vpp_immunity_enabled, and the overrides system is now being used.");
		LogError("Users with access to 'advertisement_immunity' are now immune to ads when sm_vpp_immunity_enabled is set to 1.\n");
	} else if (StrEqual(szCvarName, "sm_vpp_ad_grace", false)) {
		LogError("======================[sm_vpp_ad_grace]======================");
		LogError("sm_vpp_ad_grace no longer exists and the cvar is now unused.");
		LogError("You can simply use the other cvars to control when how often ads are played, But a 3 min cooldown between each ad is always enforced.\n");
	}
	
	LogError("After you have acknowledged the above message(s) and updated your config, you may completely remove the cvars to prevent this message displaying again.");
	
	return Plugin_Handled;
}

public void OnCvarChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	if (hConVar == g_hCvarJoinGame) {
		g_bJoinGame = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarPhaseAds) {
		g_bPhaseAds = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarAdvertPeriod) {
		g_fAdvertPeriod = StringToFloat(szNewValue);
		
		if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
			g_fAdvertPeriod = 3.0;
			g_hCvarAdvertPeriod.IntValue = 3;
			
			if (g_fAdvertPeriod > 0.0) {
				LoopValidClients(iClient) {
					OnClientPutInServer(iClient); g_bFirstJoin[iClient] = false;
				}
			}
		}
	} else if (hConVar == g_hCvarAdvertTotal) {
		g_iAdvertTotal = StringToInt(szNewValue);
	} else if (hConVar == g_hCvarImmunityEnabled) {
		g_bImmunityEnabled = view_as<bool>(StringToInt(szNewValue));
		
		if (g_bImmunityEnabled) {
			LoopValidClients(iClient) {
				if (!CheckCommandAccess(iClient, "advertisement_immunity", ADMFLAG_RESERVATION)) {
					continue;
				}
				
				OnClientPutInServer(iClient);
			}
		}
	} else if (hConVar == g_hCvarSpecAdvertPeriod) {
		g_fSpecAdvertPeriod = StringToFloat(szNewValue);
		
		if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
			g_fSpecAdvertPeriod = 3.0;
		}
	} else if (hConVar == g_hCvarRadioResumation) {
		g_bRadioResumation = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarWaitUntilDead) {
		g_bWaitUntilDead = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarMessages) {
		g_bMessages = view_as<bool>(StringToInt(szNewValue));
	} else if (hConVar == g_hCvarJoinType) {
		g_iJoinType = StringToInt(szNewValue);
	} else if (hConVar == g_hCvarDeathAds) {
		g_iDeathAdCount = StringToInt(szNewValue);
	} else if (hConVar == g_hCvarMotdCheck) {
		g_iMotdAction = StringToInt(szNewValue);
	}
}

public void OnConfigsExecuted() {
	UpdateConVars();
}

public void UpdateConVars()
{
	g_bJoinGame = g_hCvarJoinGame.BoolValue;
	g_bPhaseAds = g_hCvarPhaseAds.BoolValue;
	g_bImmunityEnabled = g_hCvarImmunityEnabled.BoolValue;
	g_bRadioResumation = g_hCvarRadioResumation.BoolValue;
	g_bWaitUntilDead = g_hCvarWaitUntilDead.BoolValue;
	g_bMessages = g_hCvarMessages.BoolValue;
	g_iMotdAction = g_hCvarMotdCheck.IntValue;
	g_iJoinType = g_hCvarJoinType.IntValue;
	
	g_fAdvertPeriod = g_hCvarAdvertPeriod.FloatValue;
	g_fSpecAdvertPeriod = g_hCvarSpecAdvertPeriod.FloatValue;
	
	if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
		g_fAdvertPeriod = 3.0;
		g_hCvarAdvertPeriod.IntValue = 3;
	}
	
	if (g_fSpecAdvertPeriod < 3.0 && g_fSpecAdvertPeriod > 0.0) {
		g_fSpecAdvertPeriod = 3.0;
		g_hCvarSpecAdvertPeriod.IntValue = 3;
	}
	
	g_iDeathAdCount = g_hCvarDeathAds.IntValue;
	g_iAdvertTotal = g_hCvarAdvertTotal.IntValue;
}

public Action Command_Reload(int iClient, int iArgs)
{
	CReplyToCommand(iClient, "%s%t", PREFIX, "Radios Loaded", LoadRadioStations());
	return Plugin_Handled;
}

stock int LoadRadioStations()
{
	if (g_alRadioStations != null) {
		g_alRadioStations.Clear();
	} else {
		g_alRadioStations = new ArrayList(256);
	}
	
	LoadThirdPartyRadioStations();
	LoadPresetRadioStations();
	
	int iLoaded = g_alRadioStations.Length;
	
	LogMessage("%t", "Radios Loaded", iLoaded);
	
	return iLoaded;
}

stock void LoadPresetRadioStations()
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/vpp_adverts_radios.txt");
	
	if (!FileExists(szPath)) {
		return;
	}
	
	KeyValues hKv = new KeyValues("Radio Stations");
	
	if (!hKv.ImportFromFile(szPath)) {
		return;
	}
	
	hKv.GotoFirstSubKey();
	
	char szBuffer[256];
	do {
		hKv.GetString("url", szBuffer, sizeof(szBuffer));
		
		TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
		
		if (RadioEntryExists(szBuffer)) {
			continue;
		}
		
		g_alRadioStations.PushString(szBuffer);
		
	} while (hKv.GotoNextKey());
	
	delete hKv;
}

stock void LoadThirdPartyRadioStations()
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/radiovolume.txt");
	
	if (FileExists(szPath)) {
		KeyValues hKv = new KeyValues("Radio Stations");
		
		if (hKv.ImportFromFile(szPath)) {
			hKv.GotoFirstSubKey();
			
			char szBuffer[256];
			do {
				hKv.GetString("Stream URL", szBuffer, sizeof(szBuffer));
				
				TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
				
				if (RadioEntryExists(szBuffer)) {
					continue;
				}
				
				g_alRadioStations.PushString(szBuffer);
				
			} while (hKv.GotoNextKey());
			
			delete hKv;
		}
	}
	
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/vpp_adverts_radios_custom.txt");
	
	if (FileExists(szPath)) {
		KeyValues hKv = new KeyValues("Radio Stations");
		
		if (hKv.ImportFromFile(szPath)) {
			hKv.GotoFirstSubKey();
			
			char szBuffer[256];
			do {
				hKv.GetString("url", szBuffer, sizeof(szBuffer));
				
				TrimString(szBuffer); StripQuotes(szBuffer); ReplaceString(szBuffer, sizeof(szBuffer), ";", "");
				
				if (RadioEntryExists(szBuffer)) {
					continue;
				}
				
				g_alRadioStations.PushString(szBuffer);
				
			} while (hKv.GotoNextKey());
			
			delete hKv;
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	if (g_fAdvertPeriod > 0.0 && g_fAdvertPeriod < 3.0) {
		g_fAdvertPeriod = 3.0;
		g_hCvarAdvertPeriod.IntValue = 3;
	}
	
	if (g_fAdvertPeriod > 0.0) {
		if (g_hPeriodicTimer[iClient] != null) {
			delete g_hPeriodicTimer[iClient];
		}
		
		g_hPeriodicTimer[iClient] = CreateTimer(g_fAdvertPeriod * 60.0, Timer_IntervalAd, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	strcopy(g_szResumeUrl[iClient], 128, "about:blank");
	
	if (!g_bJoinGame) {
		return;
	}
	
	g_bFirstJoin[iClient] = true;
	g_iMotdOccurence[iClient] = 0;
}

public Action OnVGUIMenu(UserMsg umId, Handle hMsg, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	int iClient = iPlayers[0];
	
	if (!IsValidClient(iClient)) {
		return Plugin_Continue;
	}
	
	char szKey[256];
	
	if (g_bProtoBuf) {
		PbReadString(hMsg, "name", szKey, sizeof(szKey));
	} else {
		BfReadString(hMsg, szKey, sizeof(szKey));
	}
	
	if (!StrEqual(szKey, "info")) {
		return Plugin_Continue;
	}
	
	char szTitle[256];
	char szUrl[256];
	
	if (g_bProtoBuf) {
		Handle hSubKey = null;
		
		int iKeyCount = PbGetRepeatedFieldCount(hMsg, "subkeys");
		
		for (int i = 0; i < iKeyCount; i++) {
			hSubKey = PbReadRepeatedMessage(hMsg, "subkeys", i);
			
			PbReadString(hSubKey, "name", szKey, sizeof(szKey));
			
			if (StrEqual(szKey, "title")) {
				PbReadString(hSubKey, "str", szTitle, sizeof(szTitle));
			}
			
			if (StrEqual(szKey, "msg")) {
				PbReadString(hSubKey, "str", szUrl, sizeof(szUrl));
			}
		}
		
	} else {
		int iKeyCount = BfGetNumBytesLeft(hMsg);
		
		for (int i = 0; i < iKeyCount; i++) {
			BfReadString(hMsg, szKey, sizeof(szKey));
			
			if (StrEqual(szKey, "title")) {
				BfReadString(hMsg, szTitle, sizeof(szTitle));
			}
			
			if (StrEqual(szKey, "msg") || StrEqual(szKey, "#L4D_MOTD")) {
				BfReadString(hMsg, szUrl, sizeof(szUrl));
			}
		}
	}
	
	if (StrEqual(szUrl, "http://clanofdoom.co.uk/servers/motd/?id=radio")) {
		return Plugin_Handled;
	}
	
	if (StrEqual(szUrl, "motd")) {
		
		if (g_bProtoBuf) {
			if (g_iMotdOccurence[iClient] == 1) {
				if (g_iJoinType == 2 || AdShouldWait(iClient) || g_bMotdDisabled[iClient]) {
					VPP_PlayAdvert(iClient);
				} else {
					if (!ShowVGUIPanelEx(iClient, "VPP Network Advertisement MOTD", "advert", MOTDPANEL_TYPE_URL, _, true, hMsg)) {
						VPP_PlayAdvert(iClient);
					} else {
						if (g_hFinishedTimer[iClient] == null) {
							g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
						}
						
						RequestFrame(Frame_AdvertStartedForward, GetClientUserId(iClient));
						g_bAdvertPlaying[iClient] = true;
					}
				}
				
				g_bFirstJoin[iClient] = false;
				
				return Plugin_Continue;
			}
		} else {
			switch (g_eVersion) {
				case Engine_Left4Dead, Engine_Left4Dead2, 19: {
					VPP_PlayAdvert(iClient);
					return Plugin_Handled;
				}
				
				default: {
					VPP_PlayAdvert(iClient);
				}
			}
		}
		
		g_iMotdOccurence[iClient]++;
		
		return Plugin_Continue;
	}
	
	bool bRadio = false;
	
	if (g_bRadioResumation) {
		char szBuffer[256];
		
		int iRadioStations = g_alRadioStations.Length;
		
		for (int i = 0; i < iRadioStations; i++) {
			g_alRadioStations.GetString(i, szBuffer, sizeof(szBuffer));
			
			if (StrContains(szUrl, szBuffer, false) != -1) {
				strcopy(g_szResumeUrl[iClient], 128, szUrl);
				bRadio = true;
				break;
			}
		}
	}
	
	if (StrEqual(szTitle, "VPP Network Advertisement MOTD")) {
		if (g_hFinishedTimer[iClient] == null) {
			g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
		}
		
		if (g_bAdvertPlaying[iClient]) {
			return Plugin_Handled;
		}
		
		RequestFrame(Frame_AdvertStartedForward, GetClientUserId(iClient));
		
		g_bAdvertPlaying[iClient] = true;
		
		if (!g_bFirstJoin[iClient]) {
			g_iAdvertPlays[iClient]++;
		}
		
		g_bFirstJoin[iClient] = false;
		
		return Plugin_Continue;
	}
	
	if (g_bAdvertPlaying[iClient]) {
		if (bRadio || (!StrEqual(g_szResumeUrl[iClient], "", false) && !StrEqual(g_szResumeUrl[iClient], "about:blank", false)) && g_bRadioResumation) {
			
			strcopy(g_szResumeUrl[iClient], 128, szUrl);
			
			if (g_hFinishedTimer[iClient] == null) {
				g_hFinishedTimer[iClient] = CreateTimer(60.0, Timer_AdvertFinished, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
			}
			
			RequestFrame(PrintRadioMessage, GetClientUserId(iClient));
		} else {
			
			if (g_bFirstJoin[iClient] || g_iMotdOccurence[iClient] == 1) {
				strcopy(g_szResumeUrl[iClient], 128, szUrl);
			} else {
				RequestFrame(PrintMiscMessage, GetClientUserId(iClient));
			}
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void Frame_AdvertStartedForward(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	Call_StartForward(g_hOnAdvertStarted);
	Call_PushCell(iClient);
	Call_PushString(g_szResumeUrl[iClient]);
	Call_Finish();
}

public void Frame_AdvertFinishedForward(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	Call_StartForward(g_hOnAdvertFinished);
	Call_PushCell(iClient);
	Call_PushString(g_szResumeUrl[iClient]);
	Call_Finish();
}

public void PrintRadioMessage(int iUserId)
{
	if (!g_bMessages) {
		return;
	}
	
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	CPrintToChat(iClient, "%s%t", PREFIX, "Radio Message");
}

public void PrintMiscMessage(int iUserId)
{
	if (!g_bMessages) {
		return;
	}
	
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return;
	}
	
	CPrintToChat(iClient, "%s%t", PREFIX, "Misc Message");
}

public void OnClientDisconnect(int iClient)
{
	g_iAdvertPlays[iClient] = 0;
	g_iLastAdvertTime[iClient] = 0;
	g_bFirstJoin[iClient] = false;
	g_bAdvertPlaying[iClient] = false;
	g_bAdvertQued[iClient] = false;
	g_iMotdOccurence[iClient] = 0;
	
	if (g_hPeriodicTimer[iClient] != null && IsValidHandle(g_hPeriodicTimer[iClient])) {
		delete g_hPeriodicTimer[iClient];
	}
	
	g_hPeriodicTimer[iClient] = null;
	
	if (g_hFinishedTimer[iClient] != null && IsValidHandle(g_hPeriodicTimer[iClient])) {
		delete g_hFinishedTimer[iClient];
	}
	
	g_hFinishedTimer[iClient] = null;
	
	if (g_hSpecTimer[iClient] != null && IsValidHandle(g_hPeriodicTimer[iClient])) {
		delete g_hSpecTimer[iClient];
	}
	
	g_hSpecTimer[iClient] = null;
	
	strcopy(g_szResumeUrl[iClient], 128, "about:blank");
}

public void OnMapEnd() {
	g_bPhase = false;
}

public void OnMapStart() {
	g_phraseCount = BuildPhrases();
	g_bPhase = false;
}

public void Event_RoundStart(Event eEvent, char[] chEvent, bool bDontBroadcast) {
	g_bPhase = false;
}

public void Phase_Hooks(Event eEvent, char[] chEvent, bool bDontBroadcast)
{
	g_bPhase = true;
	
	if (!g_bPhaseAds) {
		return;
	}
	
	bool bShouldAdBeSent = false;
	
	if (StrEqual(g_szGameName, "cure")) {
		bShouldAdBeSent = eEvent.GetInt("wave") % 3 == 0;
	} else {
		bShouldAdBeSent = true;
	}
	
	if (!bShouldAdBeSent) {
		return;
	}
	
	LoopValidClients(iClient) {
		VPP_PlayAdvert(iClient);
	}
}

public Action Event_PlayerTeam(Event eEvent, char[] chEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iTeam = eEvent.GetInt("team");
	bool bDisconnect = eEvent.GetBool("disconnect");
	
	if (bDisconnect || !IsClientConnected(iClient)) {
		return Plugin_Continue;
	}
	
	if (iTeam == 1 && g_fSpecAdvertPeriod > 0.0) {
		VPP_PlayAdvert(iClient);
	} else if (g_hSpecTimer[iClient] != null) {
		delete g_hSpecTimer[iClient];
	}
	
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event evEvent, char[] szEvent, bool bDontBroadcast)
{
	if (CheckGameSpecificConditions()) {
		return;
	}
	
	int iClient = GetClientOfUserId(evEvent.GetInt("userid"));
	int iDeathCount = GetClientDeaths(iClient);
	
	if (g_iDeathAdCount > 0) {
		if (iDeathCount % g_iDeathAdCount == 0) {
			VPP_PlayAdvert(iClient);
		}
	}
}

public Action Timer_IntervalAd(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	VPP_PlayAdvert(iClient);
	
	return Plugin_Continue;
	
}

public Action Timer_PlayAdvert(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		if (iClient > -1 && iClient <= MaxClients) {
			g_hSpecTimer[iClient] = null;
			g_hPeriodicTimer[iClient] = null;
		}
		
		return Plugin_Stop;
	}
	
	if (HasClientFinishedAds(iClient)) {
		if (hTimer == g_hSpecTimer[iClient]) {
			g_hSpecTimer[iClient] = null;
		} else if (hTimer == g_hPeriodicTimer[iClient]) {
			g_hPeriodicTimer[iClient] = null;
		}
		
		return Plugin_Stop;
	}
	
	if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null) {
		if (hTimer == g_hSpecTimer[iClient] || hTimer == g_hPeriodicTimer[iClient]) {
			return Plugin_Continue;
		}
		
		return Plugin_Stop;
	}
	
	if (AdShouldWait(iClient)) {
		g_bAdvertQued[iClient] = hTimer != g_hSpecTimer[iClient] && hTimer != g_hPeriodicTimer[iClient];
		
		if (!g_bAdvertQued[iClient]) {
			VPP_PlayAdvert(iClient);
		}
		
		return Plugin_Continue;
	}
	
	if (IsClientImmune(iClient)) {
		g_hSpecTimer[iClient] = null;
		g_hPeriodicTimer[iClient] = null;
		
		return Plugin_Stop;
	}
	
	ShowVGUIPanelEx(iClient, "VPP Network Advertisement MOTD", "advert", MOTDPANEL_TYPE_URL, _, true);
	
	int iTeam = GetClientTeam(iClient);
	
	if (hTimer == g_hPeriodicTimer[iClient]) {
		return Plugin_Continue;
	} else if (iTeam == 1 && g_fSpecAdvertPeriod > 0.0) {
		if (g_hSpecTimer[iClient] == null) {
			g_hSpecTimer[iClient] = CreateTimer(g_fSpecAdvertPeriod * 60.0, Timer_PlayAdvert, iUserId, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
		
		return Plugin_Continue;
		
	} else if (iTeam != 1 && g_hSpecTimer[iClient] != null && hTimer != g_hSpecTimer[iClient]) {
		delete g_hSpecTimer[iClient];
	}
	
	return Plugin_Stop;
}

stock bool ShowVGUIPanelEx(int iClient, const char[] szTitle, char[] szUrl, int iType = MOTDPANEL_TYPE_URL, int iFlags = 0, bool bShow = true, Handle hMsg = null)
{
	g_bAdvertQued[iClient] = false;
	
	if (AdShouldWait(iClient) || HasClientFinishedAds(iClient) || IsClientImmune(iClient)) {
		return false;
	}
	
	while (QueryClientConVar(iClient, "cl_disablehtmlmotd", Query_MotdPlayAd, false) < view_as<QueryCookie>(0)) {  }
	
	if(!IsClientConnected(iClient)) {
		return false;
	}
	
	if (g_bMotdDisabled[iClient]) {
		return false;
	}
	
	
	
	if (g_bFirstJoin[iClient] && g_bForceJoinGame) {
		FakeClientCommandEx(iClient, "joingame");
	}
	
	KeyValues hKv = CreateKeyValues("data");
	
	hKv.SetString("title", szTitle);
	hKv.SetNum("type", iType);
	
	if(StrEqual(szUrl, "advert", false))
	{
		decl String:steamid[255];
		decl String:name[MAX_NAME_LENGTH];
		decl String:name_encoded[MAX_NAME_LENGTH*2];
		GetClientName(iClient, name, sizeof(name));
		urlencode(name, name_encoded, sizeof(name_encoded));
		GetClientAuthId(iClient, AuthId_Engine, steamid, sizeof(steamid));
		
		new link = GetRandomInt(0,g_phraseCount-1);
	
		Format(szUrl, 256, g_Phrases[link]);
		char temport[24];
		IntToString(g_serverPort, temport, 24);
		ReplaceString(szUrl, 255, "{NAME}", name_encoded, true);
		ReplaceString(szUrl, 255, "{IP}", g_serverIP, true);
		ReplaceString(szUrl, 255, "{PORT}", temport, true);
		ReplaceString(szUrl, 255, "{STEAMID}", steamid, true);
		ReplaceString(szUrl, 255, "{GAME}", gameDir, true);
		
	}
	hKv.SetString("msg", szUrl);
	
	hKv.GotoFirstSubKey(false);
	
	bool bOverride = false;
	
	if (hMsg == null) {
		hKv.SetNum("cmd", 5);
		hMsg = StartMessageOne("VGUIMenu", iClient, iFlags);
	} else {
		bOverride = true;
	}
	
	char szKey[256]; char szValue[256];
	
	if (g_bProtoBuf) {
		if (!bOverride) {
			PbSetString(hMsg, "name", "info");
			PbSetBool(hMsg, "show", bShow);
		}
		
		Handle hSubKey;
		
		do {
			hKv.GetSectionName(szKey, sizeof(szKey));
			hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
			
			hSubKey = PbAddMessage(hMsg, "subkeys");
			
			PbSetString(hSubKey, "name", szKey);
			PbSetString(hSubKey, "str", szValue);
			
		} while (hKv.GotoNextKey(false));
		
	} else {
		BfWriteString(hMsg, "info");
		BfWriteByte(hMsg, bShow);
		
		int iKeyCount = 0;
		
		do {
			iKeyCount++;
		} while (hKv.GotoNextKey(false));
		
		BfWriteByte(hMsg, iKeyCount);
		
		if (iKeyCount > 0) {
			hKv.GoBack(); hKv.GotoFirstSubKey(false);
			do {
				hKv.GetSectionName(szKey, sizeof(szKey));
				hKv.GetString(NULL_STRING, szValue, sizeof(szValue), "");
				
				BfWriteString(hMsg, szKey);
				BfWriteString(hMsg, szValue);
			} while (hKv.GotoNextKey(false));
		}
	}
	
	if (!bOverride) {
		EndMessage();
	}
	
	delete hKv;
	
	g_iLastAdvertTime[iClient] = GetTime();
	
	return true;
}

public void Query_MotdPlayAd(QueryCookie qCookie, int iClient, ConVarQueryResult cqResult, const char[] szCvarName, const char[] szCvarValue, bool bPlayAd)
{
	if (!IsValidClient(iClient)) {
		return;
	}
	
	if (IsClientImmune(iClient)) {
		return;
	}
	
	if (StringToInt(szCvarValue) > 0) {
		g_bMotdDisabled[iClient] = true;
		
		if(g_iMotdAction == 1) {
			KickClient(iClient, "%t", "Kick Message");
		} else if (g_iMotdAction == 2) {
			PrintHintText(iClient, "%t", "Menu_Title");
			g_mMenuWarning.Display(iClient, 10);
		}
	} else {
		if (!g_bFirstJoin[iClient] && bPlayAd) {
			CreateTimer(0.0, Timer_PlayAdvert, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
		
		g_bMotdDisabled[iClient] = false;
	}
}

public void CreateMotdMenu()
{
	if (g_mMenuWarning != null) {
		return;
	}
	
	char szBuffer[128];
	
	g_mMenuWarning = new Menu(MenuHandler);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Title");
	
	g_mMenuWarning.SetTitle(szBuffer);
	g_mMenuWarning.Pagination = MENU_NO_PAGINATION;
	g_mMenuWarning.ExitBackButton = false;
	g_mMenuWarning.ExitButton = false;
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_0");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_1");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_2");
	g_mMenuWarning.AddItem("", szBuffer, ITEMDRAW_DISABLED);
	
	Format(szBuffer, sizeof(szBuffer), "%t", "Menu_Phrase_Exit");
	g_mMenuWarning.AddItem("0", szBuffer);
}

public int MenuHandler(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {  }

public Action Timer_AdvertFinished(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(iClient)) {
		return Plugin_Stop;
	}
	
	if (!g_bAdvertPlaying[iClient]) {
		return Plugin_Stop;
	}
	
	if (g_bMessages) {
		CPrintToChat(iClient, "%s%t", PREFIX, "Advert Finished");
	}
	
	g_bAdvertPlaying[iClient] = false;
	
	if (g_bRadioResumation && !StrEqual(g_szResumeUrl[iClient], "about:blank", false) && !StrEqual(g_szResumeUrl[iClient], "", false)) {
		ShowVGUIPanelEx(iClient, "Radio Resumation", g_szResumeUrl[iClient], MOTDPANEL_TYPE_URL, 0, false);
	}
	
	RequestFrame(Frame_AdvertFinishedForward, GetClientUserId(iClient));
	
	g_hFinishedTimer[iClient] = null;
	
	return Plugin_Stop;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	if (!IsClientInGame(iClient)) {
		return false;
	}
	
	if (IsFakeClient(iClient)) {
		return false;
	}
	
	return true;
}

stock bool IsClientImmune(int iClient)
{
	if (!IsClientConnected(iClient)) {
		return true;
	}
	
	if (!g_bImmunityEnabled) {
		return false;
	}
	
	return CheckCommandAccess(iClient, "advertisement_immunity", ADMFLAG_RESERVATION);
}

stock bool CheckGameSpecificConditions()
{
	if (g_eVersion == Engine_CSGO) {
		if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
			return true;
		}
	}
	
	return false;
}

stock bool AdShouldWait(int iClient)
{
	char szAuthId[64];
	
	if (!IsClientAuthorized(iClient) || !GetClientAuthId(iClient, AuthId_Steam2, szAuthId, 64, true)) {
		return true;
	}
	
	if (StrEqual(szAuthId, "STEAM_ID_PENDING", false)) {
		return true;
	}
	
	if(g_hFinishedTimer[iClient] != null) {
		return true;
	}
	
	int iTeam = GetClientTeam(iClient);
	
	if (iTeam < 1 && (g_eVersion == Engine_DODS || (g_bFirstJoin[iClient] && g_iJoinType == 2))) {
		return true;
	}
	
	if (g_bWaitUntilDead && IsPlayerAlive(iClient) && iTeam > 1 && (!g_bPhase && !g_bFirstJoin[iClient] && !CheckGameSpecificConditions())) {
		return true;
	}
	
	if (g_bAdvertPlaying[iClient] || g_hFinishedTimer[iClient] != null || (g_iLastAdvertTime[iClient] > 0 && GetTime() - g_iLastAdvertTime[iClient] < 180)) {
		return true;
	}
	
	return false;
}

stock bool HasClientFinishedAds(int iClient)
{
	if (g_iAdvertTotal > 0 && !g_bFirstJoin[iClient] && g_iAdvertPlays[iClient] >= g_iAdvertTotal) {
		return true;
	}
	
	if (g_iAdvertTotal <= -1 && !g_bFirstJoin[iClient]) {
		return true;
	}
	
	if (!g_bFirstJoin[iClient] && g_fAdvertPeriod <= 0.0 && g_iDeathAdCount <= 0) {
		return true;
	}
	
	return false;
}

stock bool RadioEntryExists(const char[] szEntry)
{
	int iRadioStations = g_alRadioStations.Length;
	
	if (iRadioStations <= 0) {
		return false;
	}
	
	char szBuffer[256];
	
	for (int i = 0; i < iRadioStations; i++) {
		g_alRadioStations.GetString(i, szBuffer, sizeof(szBuffer));
		
		
		if (StrEqual(szEntry, szBuffer, false)) {
			return true;
		}
	}
	
	return false;
} 


BuildPhrases()
{
	decl String:imFile[PLATFORM_MAX_PATH];
	decl String:line[192];
	new i = 0;
	new totalLines = 0;
	
	BuildPath(Path_SM, imFile, sizeof(imFile), "configs/franug_adverts.ini");
	
	new Handle:file = OpenFile(imFile, "rt");
	
	if(file != INVALID_HANDLE)
	{
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))
			{
				break;
			}
			
			TrimString(line);
			if( strlen(line) > 0 )
			{
				FormatEx(g_Phrases[i],192, "%s", line);
				totalLines++;
			}
			
			i++;
			
			//check for max no. of entries
			if( i >= sizeof(g_Phrases) )
			{
				SetFailState("Attempted to add more than the maximum allowed phrases from file");
				break;
			}
		}
				
		CloseHandle(file);
	}
	else
	{
		SetFailState("[SM] no file found (configs/franug_adverts.ini)");
	}
	
	return totalLines;
}

stock urlencode(const String:sString[], String:sResult[], len)
{
	new String:sHexTable[] = "0123456789abcdef";
	new from, c;
	new to;

	while(from < len)
	{
		c = sString[from++];
		if(c == 0)
		{
			sResult[to++] = c;
			break;
		}
		else if(c == ' ')
		{
			sResult[to++] = '+';
		}
		else if((c < '0' && c != '-' && c != '.') ||
				(c < 'A' && c > '9') ||
				(c > 'Z' && c < 'a' && c != '_') ||
				(c > 'z'))
		{
			if((to + 3) > len)
			{
				sResult[to] = 0;
				break;
			}
			sResult[to++] = '%';
			sResult[to++] = sHexTable[c >> 4];
			sResult[to++] = sHexTable[c & 15];
		}
		else
		{
			sResult[to++] = c;
		}
	}
}  