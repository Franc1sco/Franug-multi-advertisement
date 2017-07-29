/*  SM MULTI Adverts
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
 

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <weblync>

// CONFIGURATION
//
// time between advert
#define MIN_TIME 10.0
#define MAX_TIME 15.0
//

// advert lifetime
#define MIN_DURATION 20.0
#define MAX_DURATION 30.0
//

#define IDAYS 1 // purge old clients in database every X days
//
//
// END CONFIGURATION


new String:gameDir[255];
new String:g_serverIP[16];

new g_serverPort;

new ismysql;
new Handle:db;
new bool:uselocal = false;
new bool:comprobado[MAXPLAYERS+1];

new g_phraseCount;
new String:g_Phrases[256][192];
new Handle:arbol[MAXPLAYERS+1] = INVALID_HANDLE;

//new String:g_sCmdLogPath[256];

new Handle:tiempo[MAXPLAYERS+1];

public Plugin:myinfo =
{
    name = "MULTI Adverts",
    author = "Franc1sco franug",
    description = "",
    version = "3.2.1",
    url = "http://steamcommunity.com/id/franug"
};

ConVar gc_sURL;
ConVar cvar_alive;

bool weblync = false;

public OnPluginStart()
{
	gc_sURL = CreateConVar("sm_franugadverts_url", "http://cola-team.com/franug/redirect.php", "URL to your webspace with webshortcuts webpart");
	
	cvar_alive = CreateConVar("sm_franugadverts_alive", "1", "1 = enable adverts to alive players. 0 = disabled for alive players.");
	
	GetGameFolderName(gameDir, sizeof(gameDir));
	new Handle:serverIP = FindConVar("hostip");
	new Handle:serverPort = FindConVar("hostport");
	if (serverIP == INVALID_HANDLE || serverPort == INVALID_HANDLE)
		SetFailState("Could not determine server ip and port.");

	new IP = GetConVarInt(serverIP);
	g_serverPort = GetConVarInt(serverPort);
	Format(g_serverIP, sizeof(g_serverIP), "%d.%d.%d.%d", IP >>> 24 & 255, IP >>> 16 & 255, IP >>> 8 & 255, IP & 255);
	
	
	RegConsoleCmd("sm_publicidad", Comando);
	
	ComprobarDB(true, "multiadvers");
	
	CreateTimer(GetRandomFloat(MIN_TIME, MAX_TIME), Tiempo);
}

public void OnAllPluginsLoaded()
{
	weblync = LibraryExists("weblync");
}
 
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "weblync"))
	{
		weblync = false;
	}
}
 
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "weblync"))
	{
		weblync = true;
	}
}

public OnClientDisconnect(client)
{	
	if(comprobado[client] && !IsFakeClient(client)) SaveCookies(client);
	comprobado[client] = false;
	if(arbol[client] != INVALID_HANDLE)
	{
		ClearTrie(arbol[client]);
		CloseHandle(arbol[client]);
		arbol[client] = INVALID_HANDLE;
	}
	if(tiempo[client] != INVALID_HANDLE)
	{
		KillTimer(tiempo[client]);
		tiempo[client] = INVALID_HANDLE;
	}
}

SaveCookies(client)
{
	decl String:steamid[32];
	//GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
	GetClientIP(client, steamid, sizeof(steamid) );
	new String:Name[MAX_NAME_LENGTH+1];
	new String:SafeName[(sizeof(Name)*2)+1];
	if (!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(db, Name, SafeName, sizeof(SafeName));
	}	

	decl String:buffer[3096];
	Format(buffer, sizeof(buffer), "UPDATE publicidad SET last_accountuse = %d, playername = '%s' WHERE ip = '%s';",GetTime(), SafeName,steamid);
	//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasico2, buffer);
}

ComprobarDB(bool:reconnect = false,String:basedatos[64] = "weaponpaints")
{
	if(uselocal) basedatos = "clientprefs";
	if(reconnect)
	{
		if (db != INVALID_HANDLE)
		{
			//LogMessage("Reconnecting DB connection");
			CloseHandle(db);
			db = INVALID_HANDLE;
		}
	}
	else if (db != INVALID_HANDLE)
	{
		return;
	}

	if (!SQL_CheckConfig( basedatos ))
	{
		if(StrEqual(basedatos, "clientprefs")) SetFailState("Databases not found");
		else 
		{
			//base = "clientprefs";
			ComprobarDB(true,"clientprefs");
			uselocal = true;
		}
		
		return;
	}
	SQL_TConnect(OnSqlConnect, basedatos);
}

public OnSqlConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Database failure: %s", error);
		
		SetFailState("Databases dont work");
	}
	else
	{
		db = hndl;
		decl String:buffer[3096];
		
		SQL_GetDriverIdent(SQL_ReadDriver(db), buffer, sizeof(buffer));
		ismysql = StrEqual(buffer,"mysql", false) ? 1 : 0;
	
		if (ismysql == 1)
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `publicidad` (`playername` varchar(128) NOT NULL, `ip` varchar(32) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0',`link1` int(64) , `link2` int(64),`link3` int(64) ,`link4` int(64) ,`link5` int(64) ,`link6` int(64) ,`link7` int(64) ,`link8` int(64) ,`link9` int(64) , PRIMARY KEY  (`ip`))");

			//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);

		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS publicidad (playername varchar(128) NOT NULL, ip varchar(32) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0', link1 int(64) , link2 int(64) ,link3 int(64) ,link4 int(64) ,link5 int(64) ,link6 int(64) ,link7 int(64) ,link8 int(64) ,link9 int(64) , PRIMARY KEY  (ip))");
		
			//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);
		}
	}
}

public OnMapStart()
{
	g_phraseCount = BuildPhrases();
	
	
}

public Action:Tiempo(Handle:timer)
{
	CreateTimer(GetRandomFloat(MIN_TIME, MAX_TIME), Tiempo);
	
	new client = GetRandomPlayer();
	
	if(client > 0) Comando(client, 0);
}

public Action:Comando(client, args)
{
	decl String:frase[512];

	new link = GetRandomInt(0,(g_phraseCount -1 ));
	link++;
	new valor;
	decl String:temp[32];
	Format(temp, 32, "link%i", link);
	//PrintToChatAll("paso1 %s", link);
	new String:partes[3][512];
	link--;
	ExplodeString(g_Phrases[link], " ", partes, 3, 512);
	Format(frase, 512, "%s",partes[0]);
	//PrintToChatAll("paso1 %s %s %s", partes[0],partes[1],partes[2]);
	if(!GetTrieValue(arbol[client], temp, valor)) return Plugin_Handled;
	
	//PrintToConsole(client, "test1");
	
	//PrintToConsole(client, partes[0]);
	//PrintToConsole(client, partes[1]);
	//PrintToConsole(client, partes[2]);
	
	if(valor != 0)
	{
		new maxlastaccuse;
		maxlastaccuse = GetTime() - (1 * StringToInt(partes[1]));
		if(maxlastaccuse < valor) return Plugin_Handled;
	}
	
	//PrintToConsole(client, "test2");
/* 	new valorf = link+1;
	decl String:temp2[32];
	Format(temp2, 32, "link%i", valorf);
	PrintToChatAll("paso1 %s", link); */
	if(!GetConVarBool(cvar_alive) && IsPlayerAlive(client) && StrEqual(partes[2], "no")) return Plugin_Handled;
	
	//decl String:url[255];
	decl String:steamid[255];
	decl String:name[MAX_NAME_LENGTH];
	decl String:name_encoded[MAX_NAME_LENGTH*2];
	GetClientName(client, name, sizeof(name));
	urlencode(name, name_encoded, sizeof(name_encoded));
	
	GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid));

	char temport[24];
	IntToString(g_serverPort, temport, 24);
	ReplaceString(frase, 255, "{NAME}", name_encoded, true);
	ReplaceString(frase, 255, "{IP}", g_serverIP, true);
	ReplaceString(frase, 255, "{PORT}", temport, true);
	ReplaceString(frase, 255, "{STEAMID}", steamid, true);
	ReplaceString(frase, 255, "{GAME}", gameDir, true);
	
	if(StrEqual(partes[2], "no", false))
	{
		StreamPanel(frase, client);
	}
	else StreamPanel3(frase, client);
	
	SetTrieValue(arbol[client], temp, GetTime());
	
	
	decl String:ip[32];
	GetClientIP(client, ip, sizeof(ip) );
	decl String:buffer[3096];
	Format(buffer, sizeof(buffer), "UPDATE publicidad SET %s = %d WHERE ip = '%s';",temp,GetTime(),ip);
	//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasico2, buffer);
	
	if (tiempo[client] != INVALID_HANDLE)KillTimer(tiempo[client]);
	
	
	tiempo[client] = CreateTimer(GetRandomFloat(MIN_DURATION, MAX_DURATION), Pasado, client);
	//PrintToConsole(client, "test3");
	
	return Plugin_Handled;
	//PrintToChat(client, "hecho");
}

/* public StreamPanel(String:title[], String:url[], client) {
	new Handle:Radio = CreateKeyValues("data");
	KvSetString(Radio, "title", title);
	KvSetString(Radio, "type", "2");
	KvSetString(Radio, "msg", url);
	ShowVGUIPanel(client, "info", Radio, false);
	CloseHandle(Radio);
}
 */
 
 stock void StreamPanel(char [] web, client) 
{ 
	//PrintToChat(client, "mostrando %s", web);
	//ShowMOTDScreen(client, web, false);
	
	if(weblync)
	{
		WebLync_OpenUrl(client, web);
		return;
	}
	char temp[256];
	//PrintToConsole(client, web);
	char url[256]; 
	gc_sURL.GetString(url, sizeof(url)); 
	//PrintToConsole(client, url);
	Format(temp, 512, "%s?web=%s&fullsize=1", url, web); 
	//PrintToConsole(client, temp);
	ShowMOTDPanel(client, "Web Shortcuts", temp, MOTDPANEL_TYPE_URL );
	
	
} 
/*
stock StreamPanel(String:url[512], client)
{
	Format(url, sizeof(url), "javascript: var x = screen.width * 0.90;var y = screen.height * 0.90;window.open(\"%s\", \"Really boomix, JS?\",\"scrollbars=yes, width='+x+',height='+y+'\");", url);
	ShowMOTDPanel( client, " ", url, MOTDPANEL_TYPE_URL );
	
}*/

stock StreamPanel3(String:url[512], client)
{
	ShowMOTDPanel( client, " ", url, MOTDPANEL_TYPE_URL );
	//PrintToChat(client, "mostrando %s escondido", url);
	//ShowMOTDScreen(client, url, true);
	
}

public Action:Pasado(Handle:timer, any:client)
{
	if(weblync)
	{
		WebLync_OpenUrl(client, "about:blank");
	}
	else FakeClientCommand(client, "say /motd");
	//StreamPanel3("about:blank", client);
	
	//PrintToChat(client, "fin de advert");
	//ShowMOTDScreen(client, "http://", false);
	
	tiempo[client] = INVALID_HANDLE;
}

stock ShowMOTDScreen(client, String:url[], bool:hidden)
{
	new Handle:kv = CreateKeyValues("data");

	KvSetNum(kv, "cmd", 5);

	KvSetString(kv, "msg", url);
	KvSetString(kv, "title", "_blank");
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	ShowVGUIPanel(client, "info", kv, !hidden);
	CloseHandle(kv);
}

GetRandomPlayer()
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && tiempo[i] == INVALID_HANDLE) clients[clientCount++] = i;
		
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
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
		SetFailState("[SM] no file found (configs/publicidad.ini)");
	}
	
	return totalLines;
}

public OnClientPostAdminCheck(client)
{
	if(!IsFakeClient(client)) CheckSteamID(client);
}

CheckSteamID(client)
{
	tiempo[client] = CreateTimer(20.0, estabien, client);
	decl String:query[255], String:steamid[32];
	//GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
	GetClientIP(client, steamid, sizeof(steamid) );
	
	Format(query, sizeof(query), "SELECT * FROM publicidad WHERE ip = '%s'", steamid);
	//LogToFileEx(g_sCmdLogPath, "Query %s", query);
	SQL_TQuery(db, T_CheckSteamID, query, GetClientUserId(client));
}

public Action:estabien(Handle:timer, any:client)
{
	
	tiempo[client] = INVALID_HANDLE;
}
 
public T_CheckSteamID(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	if (hndl == INVALID_HANDLE)
	{
		ComprobarDB();
		return;
	}
	//PrintToChatAll("comprobado");
	if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) 
	{
		Nuevo(client);
		return;
	}
	
	arbol[client] = CreateTrie();
	
	new String:temp2[64];
	new temp;
	new contar = 3;
	new link = 1;
	for(new i=0;i<g_phraseCount;++i)
	{
		temp = SQL_FetchInt(hndl, contar);
		Format(temp2, sizeof(temp2), "link%i", link);
		SetTrieValue(arbol[client], temp2, temp);
		link++;
		//PrintToChatAll(temp2);
		//LogMessage("Sacado %i del arma %s", FindStringInArray(array_paints, temp),Items);
		
		contar++;
	}
	
	comprobado[client] = true;
}

Nuevo(client)
{
	decl String:query[255], String:steamid[32];
	//GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
	GetClientIP(client, steamid, sizeof(steamid) );
	new userid = GetClientUserId(client);
	
	new String:Name[MAX_NAME_LENGTH+1];
	new String:SafeName[(sizeof(Name)*2)+1];
	if (!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(db, Name, SafeName, sizeof(SafeName));
	}
		
	Format(query, sizeof(query), "INSERT INTO publicidad(playername, ip, last_accountuse) VALUES('%s', '%s', '0');", SafeName, steamid);
	//LogToFileEx(g_sCmdLogPath, "Query %s", query);
	SQL_TQuery(db, tbasico3, query, userid);
}


public PruneDatabase()
{
	if (db == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Prune Database: No connection");
		ComprobarDB();
		return;
	}

	new maxlastaccuse;
	maxlastaccuse = GetTime() - (IDAYS * 86400);

	decl String:buffer[1024];

	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "DELETE FROM `publicidad` WHERE `last_accountuse`<'%d' AND `last_accountuse`>'0';", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "DELETE FROM publicidad WHERE last_accountuse<'%d' AND last_accountuse>'0';", maxlastaccuse);

	//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasicoP, buffer);
}

public tbasico(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
	}
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	comprobado[client] = true;
	
}

public tbasico2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
	}
}

public tbasico3(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
	}
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	
	arbol[client] = CreateTrie();

	SetTrieValue(arbol[client], "link0", 0);
	SetTrieValue(arbol[client], "link1", 0);
	SetTrieValue(arbol[client], "link2", 0);
	SetTrieValue(arbol[client], "link3", 0);
	SetTrieValue(arbol[client], "link4", 0);
	SetTrieValue(arbol[client], "link5", 0);
	SetTrieValue(arbol[client], "link6", 0);
	SetTrieValue(arbol[client], "link7", 0);
	SetTrieValue(arbol[client], "link8", 0);
	SetTrieValue(arbol[client], "link9", 0);
	
	
	comprobado[client] = true;
}

public tbasicoC(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
	}
	LogMessage("Database connection successful");
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPostAdminCheck(client);
		}
	}
}

public tbasicoP(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
	}
	LogMessage("Prune Database successful");
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
