/************************************************************************
*************************************************************************
Tf2 Show Ammow
Description:
	Shows medics how mucha ammo the person they are healing has
*************************************************************************
*************************************************************************

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id$
$Author$
$Revision$
$Date$
$LastChangedBy$
$LastChangedDate$
$URL$
$Copyright: (c) Tf2Tmng 2009-2011$
*************************************************************************
*************************************************************************
*/
#define PL_VERSION "1.01"
#pragma semicolon 1
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#undef REQUIRE_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS

#define COLOR_RED 		0
#define COLOR_BLUE 	1
#define COLOR_PINK 	2
#define COLOR_GREEN 	3
#define COLOR_WHITE	4
#define COLOR_TEAM		5

#define POS_LEFT 		0
#define POS_MIDLEFT 	1
#define POS_CENTER		2
#define POS_BOTTOM		3


new Handle:g_hVarUpdateSpeed = INVALID_HANDLE;
new Handle:g_hVarChargeLevel = INVALID_HANDLE;

new Handle:g_hCookieEnable 	= INVALID_HANDLE,
	Handle:g_hCookiePosition 	= INVALID_HANDLE,
	Handle:g_hCookieColor 		= INVALID_HANDLE;

new Float:g_fTextPositions[4][2] = { 	{0.01, 0.78},
										{0.01, 0.55},
										{0.3, 0.25},
										{0.3, 0.91} };
new g_iColors[5][3] = { 	{255, 0, 0},
							{180, 150, 255},
							{255, 78, 140},
							{121, 255, 107},
							{240, 240, 240}	};
new Handle:h_HudMessage = INVALID_HANDLE;
new bool:g_bUseClientPrefs = false;

enum e_ClientSettings
{
	bEnabled,
	iPosition,
	iColor
};

new g_aClientSettings[MAXPLAYERS+1][e_ClientSettings];

public Plugin:myinfo = 
{
	name = "[TF2] Show My Ammo",
	author = "Goerge",
	description = "Shows medics how much ammo a person has",
	version = PL_VERSION,
	url = "http://tf2tmng.googlecode.com/"
};

public OnPluginStart()
{
	CreateConVar("medic_ammocounts_version", PL_VERSION, _, FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	h_HudMessage = CreateHudSynchronizer();
	g_hVarUpdateSpeed = CreateConVar("sm_showammo_update_speed", "0.5", "Delay between updates", FCVAR_PLUGIN, true, 0.1, true, 5.0);
	g_hVarChargeLevel = CreateConVar("sm_showammo_charge_level", "0.90", "Charge level where medics see ammo counts", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	decl String:sExtError[256];
	new iExtStatus = GetExtensionFileStatus("clientprefs.ext", sExtError, sizeof(sExtError));
	if (iExtStatus == 1)
	{
		if (SQL_CheckConfig("clientprefs"))
		{
			g_bUseClientPrefs = true;
			g_hCookieEnable = RegClientCookie("tf2_showammo_enabed", "enable showing of ammo counts to medics", CookieAccess_Public);
			g_hCookiePosition = RegClientCookie("tf2_showammo_position", "client position of the text", CookieAccess_Public);
			g_hCookieColor		= RegClientCookie("tf2_showammo_color", "client text color setting", CookieAccess_Public);
			SetCookieMenuItem(AmmoCookieSettings, g_hCookieEnable, "TF2 Show Ammo");
		}
	}
	if (!g_bUseClientPrefs)
	{
		LogAction(0, -1, "tf2_showammo has detected errors in your clientprefs installation. %s", sExtError);
	}
	AutoExecConfig();
}

public OnMapStart()
{
	CreateTimer(GetConVarFloat(g_hVarUpdateSpeed), Timer_MedicCheck, _, TIMER_REPEAT);
}

public AmmoCookieSettings(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		//don't think we need to do anything
	}
	else
	{
		new Handle:hMenu = CreateMenu(Menu_CookieSettings);
		SetMenuTitle(hMenu, "Options [Current Setting]");
		if (g_aClientSettings[client][bEnabled])
		{
			AddMenuItem(hMenu, "enable", "Enabled/Disable [Enabled]");
		}
		else
		{
			AddMenuItem(hMenu, "enable", "Enabled/Disable [Disabled]");
		}
		switch (g_aClientSettings[client][iColor])
		{
			case COLOR_RED:
			{
				AddMenuItem(hMenu, "color", "Color [Red]");
			}
			case COLOR_BLUE:
			{
				AddMenuItem(hMenu, "color", "Color [Blue]");
			}
			case COLOR_PINK:
			{
				AddMenuItem(hMenu, "color", "Color [Pink]");
			}
			case COLOR_GREEN:
			{
				AddMenuItem(hMenu, "color", "Color [Green]");
			}
			case COLOR_TEAM:
			{
				AddMenuItem(hMenu, "color", "Color [Team]");
			}
			case COLOR_WHITE:
			{
				AddMenuItem(hMenu, "color", "Color [White]");
			}
		}
		switch (g_aClientSettings[client][iPosition])
		{
			case POS_LEFT:
			{
				AddMenuItem(hMenu, "pos", "Position [Left]");
			}
			case POS_MIDLEFT:
			{
				AddMenuItem(hMenu, "pos", "Position [High Left]");
			}
			case POS_CENTER:
			{
				AddMenuItem(hMenu, "pos", "Position [Center]");
			}
			case POS_BOTTOM:
			{
				AddMenuItem(hMenu, "pos", "Position [Bottom]");
			}
		}
		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}

public Menu_CookieSettings(Handle:menu, MenuAction:action, param1, param2)
{
	new client = param1;
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "enable", false))
		{
			new Handle:hMenu = CreateMenu(Menu_CookieSettingsEnable);
			SetMenuTitle(hMenu, "Enable/Disable TF2 Show Ammo");
			
			if (g_aClientSettings[client][bEnabled])
			{
				AddMenuItem(hMenu, "enable", "Enable [Set]");
				AddMenuItem(hMenu, "disable", "Disable");
			}
			else
			{
				AddMenuItem(hMenu, "enable", "Enabled");
				AddMenuItem(hMenu, "disable", "Disable [Set]");
			}
			
			SetMenuExitBackButton(hMenu, true);
			DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		}
		else if (StrEqual(sSelection, "color", false))
		{
			new Handle:hMenu = CreateMenu(Menu_CookieSettingsColors);
			SetMenuTitle(hMenu, "Select Medic Ammo Text Color");
			AddMenuItem(hMenu, "red", "Red");
			AddMenuItem(hMenu, "blue", "Blue");
			AddMenuItem(hMenu, "pink", "Pink");
			AddMenuItem(hMenu, "green", "Green");
			AddMenuItem(hMenu, "team", "Team Color");
			AddMenuItem(hMenu, "white", "White");
			SetMenuExitBackButton(hMenu, true);
			DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		}
		else
		{
			new Handle:hMenu = CreateMenu(Menu_CookieSettingsPosition);
			{
				SetMenuTitle(hMenu, "Select Medic Ammo Position");
				AddMenuItem(hMenu, "left", "Left Side Near Bottom");
				AddMenuItem(hMenu, "midleft", "Left Side Higher Up");
				AddMenuItem(hMenu, "center", "Middle of Screen High Up");
				AddMenuItem(hMenu, "bottom", "Middle of Screen Bottom");
				SetMenuExitBackButton(hMenu, true);
				DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
			}
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_CookieSettingsEnable(Handle:menu, MenuAction:action, param1, param2)
{
	new client = param1;
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "enable", false))
		{
			SetClientCookie(client, g_hCookieEnable, "enabled");
			g_aClientSettings[client][bEnabled] = 1;
			PrintToChat(client, "[SM] TF2 Show Ammo is ENABLED for you");
		}
		else
		{
			SetClientCookie(client, g_hCookieEnable, "disabled");
			g_aClientSettings[client][bEnabled] = 0;
			PrintToChat(client, "[SM] TF2 Show Ammo is is DISABLED for you");
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_CookieSettingsColors(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "red", false))
		{
			g_aClientSettings[client][iColor] = COLOR_RED;
			SetClientCookie(client, g_hCookieColor, "red");
			PrintToChat(client, "[SM] Color set to RED");
		}
		if (StrEqual(sSelection, "blue", false))
		{
			g_aClientSettings[client][iColor] = COLOR_BLUE;
			SetClientCookie(client, g_hCookieColor, "blue");
			PrintToChat(client, "[SM] Color set to BLUE");
		}
		if (StrEqual(sSelection, "pink", false))
		{
			g_aClientSettings[client][iColor] = COLOR_PINK;
			SetClientCookie(client, g_hCookieColor, "pink");
			PrintToChat(client, "[SM] Color set to PINK");
		}
		if (StrEqual(sSelection, "green", false))
		{
			g_aClientSettings[client][iColor] = COLOR_GREEN;
			SetClientCookie(client, g_hCookieColor, "green");
			PrintToChat(client, "[SM] Color set to GREEN");
		}
		if (StrEqual(sSelection, "team", false))
		{
			g_aClientSettings[client][iColor] = COLOR_TEAM;
			SetClientCookie(client, g_hCookieColor, "team");
			PrintToChat(client, "[SM] Color set to TEAM COLOR");
		}
		if (StrEqual(sSelection, "white", false))
		{
			g_aClientSettings[client][iColor] = COLOR_WHITE;
			SetClientCookie(client, g_hCookieColor, "white");
			PrintToChat(client, "[SM] Color set to WHITE");
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_CookieSettingsPosition(Handle:menu, MenuAction:action, client, param2)
{
if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "left", false))
		{
			g_aClientSettings[client][iPosition] = POS_LEFT;
			SetClientCookie(client, g_hCookiePosition, "left");
			PrintToChat(client, "[SM] Position set to LEFT");
		}
		if (StrEqual(sSelection, "midleft", false))
		{
			g_aClientSettings[client][iPosition] = POS_MIDLEFT;
			SetClientCookie(client, g_hCookiePosition, "midleft");
			PrintToChat(client, "[SM] Position set to HISH LEFT");
		}
		if (StrEqual(sSelection, "center", false))
		{
			g_aClientSettings[client][iPosition] = POS_CENTER;
			SetClientCookie(client, g_hCookiePosition, "left");
			PrintToChat(client, "[SM] Position set to CENTER HIGH");
		}
		if (StrEqual(sSelection, "bottom", false))
		{
			g_aClientSettings[client][iPosition] = POS_BOTTOM;
			SetClientCookie(client, g_hCookiePosition, "bottom");
			PrintToChat(client, "[SM] Position set to BOTTOM");
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public OnClientCookiesCached(client)
{
	decl String:sSetting[24];
	GetClientCookie(client, g_hCookieEnable, sSetting, sizeof(sSetting));
	if (StrEqual(sSetting, "disabled", false))
	{
		g_aClientSettings[client][bEnabled] = 0;
	}
	else
	{
		g_aClientSettings[client][bEnabled] = 1;
	}
	
	GetClientCookie(client, g_hCookieColor, sSetting, sizeof(sSetting));
	if (StrEqual(sSetting, "red", false))
	{
		g_aClientSettings[client][iColor] = COLOR_RED;
	}
	else if (StrEqual(sSetting, "blue", false))
	{
		g_aClientSettings[client][iColor] = COLOR_BLUE;
	}
	else if (StrEqual(sSetting, "pink", false))
	{
		g_aClientSettings[client][iColor] = COLOR_PINK;
	}
	else if (StrEqual(sSetting, "green", false))
	{
		g_aClientSettings[client][iColor] = COLOR_GREEN;
	}
	else if (StrEqual(sSetting, "white", false))
	{
		g_aClientSettings[client][iColor] = COLOR_WHITE;
	}
	else
	{
		g_aClientSettings[client][iColor] = COLOR_TEAM;
	}
	
	GetClientCookie(client, g_hCookiePosition, sSetting, sizeof(sSetting));
	if (StrEqual(sSetting, "midleft", false))
	{
		g_aClientSettings[client][iPosition] = POS_MIDLEFT;
	}
	else if (StrEqual(sSetting, "center", false))
	{
		g_aClientSettings[client][iPosition] = POS_CENTER;
	}
	else if (StrEqual(sSetting, "bottom", false))
	{
		g_aClientSettings[client][iPosition] = POS_BOTTOM;
	}
	else
	{
		g_aClientSettings[client][iPosition] = POS_LEFT;
	}
}

public Action:Timer_MedicCheck(Handle:timer)
{
	CheckHealers();
	return Plugin_Continue;
}

stock CheckHealers()
{
	new iTarget;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)&& IsPlayerAlive(i) && !IsFakeClient(i) && g_aClientSettings[i][bEnabled])
		{
			iTarget = TF2_GetHealingTarget(i);
			if (iTarget > 0)
			{
				ShowInfo(i, iTarget);
			}
		}
	}
}

stock ShowInfo(medic, target)
{
	if (!TF2_IsClientUberCharged(medic))
	{
		return;
	}
	new TFClassType:class, iAmmo1, iAmmo2, iClip1, iClip2, 
		iColorSetting = g_aClientSettings[medic][iColor],
		iPos = g_aClientSettings[medic][iPosition];
	new String:sMessage[255];
	iAmmo1 = TF2_GetSlotAmmo(target, 0);
	iClip1 = TF2_WeaponClip(TF2_GetSlotWeapon(target, 0));
	iAmmo2 = TF2_GetSlotAmmo(target, 1);
	iClip2 = TF2_WeaponClip(TF2_GetSlotWeapon(target, 1));
	if (iColorSetting == COLOR_TEAM)
	{
		if (GetClientTeam(medic) == 2)
		{
			iColorSetting = COLOR_RED;
		}
		else
		{
			iColorSetting = COLOR_BLUE;
		}
	}
	class = TF2_GetPlayerClass(target);
	if (class == TFClass_Pyro || class == TFClass_Heavy)
	{
		iAmmo1 = GetHeavyPyroAmmo(target);
		Format(sMessage, sizeof(sMessage), "#1 Ammo: %i ", iAmmo1);
	}	
	if (iClip1 != -1)
	{
		Format(sMessage, sizeof(sMessage), "#1 Clip: %i ", iClip1);
	}

	if (class == TFClass_DemoMan)
	{

		if (iClip2 != -1 && class != TFClass_Medic)
		{
			Format(sMessage, sizeof(sMessage), "%s#2 Clip: %i ", sMessage, iClip2);
		}
	}	
	if (iAmmo1 != -1 && class != TFClass_Heavy && class != TFClass_Pyro)
	{
		Format(sMessage, sizeof(sMessage), "%s #1 Ammo: %i ", sMessage, iAmmo1);
	}
	if (iAmmo2 != -1 && class == TFClass_DemoMan)
	{
		Format(sMessage, sizeof(sMessage), "%s#2 Ammo: %i ", sMessage, iAmmo2);
	}	
	SetHudTextParams(g_fTextPositions[iPos][0], g_fTextPositions[iPos][1], 1.0, g_iColors[iColorSetting][0], g_iColors[iColorSetting][1], g_iColors[iColorSetting][2], 255);
	ShowSyncHudText(medic, h_HudMessage, sMessage);
}

stock TF2_GetHealingTarget(client)
{
	new String:classname[64];
	TF2_GetCurrentWeaponClass(client, classname, sizeof(classname));
	
	if(StrEqual(classname, "CWeaponMedigun"))
	{
		new index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( GetEntProp(index, Prop_Send, "m_bHealing") == 1 )
		{
			return GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
		}
	}
	return -1;
}

stock TF2_GetCurrentWeaponClass(client, String:name[], maxlength)
{
	if( client > 0 )
	{
		new index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (index > 0)
			GetEntityNetClass(index, name, maxlength);
	}
}

stock TF2_WeaponClip(weapon, clip = 1)
{
	if ( weapon != -1 )
	{
		if (clip == 1)
		{
			return GetEntProp( weapon, Prop_Send, "m_iClip1" );
		}
		else
		{
			return GetEntProp( weapon, Prop_Send, "m_iClip2" );
		}
	}
	return -1;
}

stock GetHeavyPyroAmmo(client)
{
	new ammoOffset = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	return GetEntData(client, ammoOffset + 4, 4);
}

stock TF2_GetSlotAmmo(any:client, slot)
{
	if( client > 0 )
	{
		new offset = FindDataMapOffs(client, "m_iAmmo") + ((slot + 1) * 4);
		return GetEntData(client, offset, 4);
	}
	return -1;
}

stock TF2_GetSlotWeapon(any:client, slot)
{
	if( client > 0 && slot >= 0)
	{
		new weaponIndex = GetPlayerWeaponSlot(client, slot);
		return weaponIndex;
	}
	return -1;
}

stock bool:TF2_IsClientUberCharged(client)
{
	if (!IsPlayerAlive(client))
		return false;
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{			
		new entityIndex = GetPlayerWeaponSlot(client, 1);
		new Float:chargeLevel = GetEntPropFloat(entityIndex, Prop_Send, "m_flChargeLevel");
		if (chargeLevel >= GetConVarFloat(g_hVarChargeLevel))				
			return true;				
	}
	return false;
}
