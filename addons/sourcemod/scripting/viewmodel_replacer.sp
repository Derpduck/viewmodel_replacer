#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2util>
#include <colors>

#define ENTITY_MAX_NAME_LENGTH 64
#define TEAM_SURVIVOR 2

ConVar
	hViewmodelOption;

int
	g_iModel_shotgun_chrome,
	g_iModel_pumpshotgun,
	g_iModel_silenced_smg,
	g_iModel_smg,
	iViewmodelOption[MAXPLAYERS + 1],
	ViewmodelOption;

bool
	bLateLoad,
	bAllowDownload[MAXPLAYERS + 1],
	bDownloadFilter[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Viewmodel Replacer",
	author = " Derpduck",
	version = "1.0",
	description = "Replaces weapon viewmodels with custom models downloaded from the server",
	url = "https://github.com/Derpduck/viewmodel_replacer"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	hViewmodelOption = CreateConVar("viewmodel_replacer_viewmodel_option", "0", "Default option for using custom viewmodels (0: Default, 1: Original, 2: Shotguns Only, 3: SMGs Only)", _, true, 0.0, true, 3.0);
	ViewmodelOption = hViewmodelOption.IntValue;
	HookConVarChange(hViewmodelOption, CVarChanged);

	RegConsoleCmd("sm_viewmodel", CmdViewmodel);
	RegConsoleCmd("sm_vm", CmdViewmodel);

	if (bLateLoad) {
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i)) SDKHook(i, SDKHook_WeaponSwitchPost, Hook_WeaponSwitch);
		}
	}
}

public void OnClientPutInServer(int client)
{
	HookValidClient(client, true);

	if (iViewmodelOption[client] == -1)
	{
		iViewmodelOption[client] = ViewmodelOption;
	}

	//Check client download settings
	bAllowDownload[client] = false;
	bDownloadFilter[client] = false;
	char buffer[ENTITY_MAX_NAME_LENGTH];

	Format(buffer, sizeof(buffer), "cl_allowdownload");
	QueryClientConVar(client, buffer, ReturnClientConVar);

	Format(buffer, sizeof(buffer), "cl_downloadfilter");
	QueryClientConVar(client, buffer, ReturnClientConVar);
}

public void OnClientDisconnect_Post(int client)
{
	HookValidClient(client, false);

	//Reset client options
	iViewmodelOption[client] = -1;
	bAllowDownload[client] = false;
	bDownloadFilter[client] = false;
}

public void OnMapStart() 
{
	//shotgun_chrome
	AddFileToDownloadsTable("models/v_models/v_shotgun_chrome_old.mdl");
	AddFileToDownloadsTable("models/v_models/v_shotgun_chrome_old.dx90.vtx");
	AddFileToDownloadsTable("models/v_models/v_shotgun_chrome_old.vvd");
	//pumpshotgun
	AddFileToDownloadsTable("models/v_models/v_pumpshotgun_old.mdl");
	AddFileToDownloadsTable("models/v_models/v_pumpshotgun_old.dx90.vtx");
	AddFileToDownloadsTable("models/v_models/v_pumpshotgun_old.vvd");
	//smg_silenced
	AddFileToDownloadsTable("models/v_models/v_silenced_smg_old.mdl");
	AddFileToDownloadsTable("models/v_models/v_silenced_smg_old.dx90.vtx");
	AddFileToDownloadsTable("models/v_models/v_silenced_smg_old.vvd");
	//smg
	AddFileToDownloadsTable("models/v_models/v_smg_old.mdl");
	AddFileToDownloadsTable("models/v_models/v_smg_old.dx90.vtx");
	AddFileToDownloadsTable("models/v_models/v_smg_old.vvd");

	//Precache models and assign to variables so we can set the viewmodel net prop
	g_iModel_shotgun_chrome = PrecacheModel("models/v_models/v_shotgun_chrome_old.mdl", true);
	g_iModel_pumpshotgun = PrecacheModel("models/v_models/v_pumpshotgun_old.mdl", true);
	g_iModel_silenced_smg = PrecacheModel("models/v_models/v_silenced_smg_old.mdl", true);
	g_iModel_smg = PrecacheModel("models/v_models/v_smg_old.mdl", true);
}

//When a survivor changes weapons their viewmodel gets reset, so we need to check if that weapon should use a modified viewmodel
//If it should, then we can swap it out
public Action Hook_WeaponSwitch(int client, int weapon)
{
	//Disallow any client without valid download settings
	//We NEED clients to have the models, and be identical to the server's, otherwise there is exploit potential
	//Since we can't check client's files, require them to have downloads enabled
	if (bAllowDownload[client] == false || bDownloadFilter[client] == false)
	{
		return;
	}

	if (iViewmodelOption[client] > 0)
	{
		UpdateViewmodel(client);
	}
}

public void UpdateViewmodel(int client)
{
	if (IsValidSurvivor(client) && !IsFakeClient(client))
	{
		int clientWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		int viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

		//Ensure client has a valid weapon
		if (clientWeapon == -1 || viewmodel == -1)
		{
			return;
		}

		//Get new weapon ID
		int weaponId = IdentifyWeapon(clientWeapon);
		int modelIndex = -1;
		char modelName[ENTITY_MAX_NAME_LENGTH];
		Format(modelName, sizeof(modelName), "");

		//Check if it's a weapon we want to modify
		switch (weaponId)
		{
			case WEPID_SHOTGUN_CHROME:
			{
				if (iViewmodelOption[client] == 1 || iViewmodelOption[client] == 2)
				{
					modelIndex = g_iModel_shotgun_chrome;
					Format(modelName, sizeof(modelName), "models/v_models/v_shotgun_chrome_old.mdl");
				}
			}
			case WEPID_PUMPSHOTGUN:
			{
				if (iViewmodelOption[client] == 1 || iViewmodelOption[client] == 2)
				{
					modelIndex = g_iModel_pumpshotgun;
					Format(modelName, sizeof(modelName), "models/v_models/v_pumpshotgun_old.mdl");
				}
			}
			case WEPID_SMG_SILENCED:
			{
				if (iViewmodelOption[client] == 1 || iViewmodelOption[client] == 3)
				{
					modelIndex = g_iModel_silenced_smg;
					Format(modelName, sizeof(modelName), "models/v_models/v_silenced_smg_old.mdl");
				}
			}
			case WEPID_SMG:
			{
				if (iViewmodelOption[client] == 1 || iViewmodelOption[client] == 3)
				{
					modelIndex = g_iModel_smg;
					Format(modelName, sizeof(modelName), "models/v_models/v_smg_old.mdl");
				}
			}
			default:
			{
				return;
			}
		}

		if (modelIndex == -1 || strlen(modelName) == 0)
		{
			return;
		}

		//Set the new viewmodel
		if (!IsModelPrecached(modelName))
		{
			PrecacheModel(modelName);
		}

		SetEntProp(viewmodel, Prop_Send, "m_nModelIndex", modelIndex);

		//Testing
		//SetEntProp(viewmodel, Prop_Send, "m_nViewModelIndex", modelIndex);
		//SetEntProp(viewmodel, Prop_Send, "m_nSequence", 0);
		//SetEntPropString(viewmodel, Prop_Data, "m_ModelName", modelName);
		//DispatchKeyValue(viewmodel, "model", modelName);
	}
}

public Action CmdViewmodel(int client, int args)
{
	//Disallow any client without valid download settings
	if (bAllowDownload[client] == false || bDownloadFilter[client] == false)
	{
		CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} You must enable downloads, then reconnect to the server to use this command.");
		if (bAllowDownload[client] == false)
		{
			CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Set {green}cl_allowdownload{default} to {green}1{default}.");
		}
		if (bDownloadFilter[client] == false)
		{
			CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Set {green}cl_downloadfilter{default} to {green}all{default}.");
		}
		return Plugin_Handled;
	}

	char arg1[ENTITY_MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (StrEqual(arg1, "shotgun", false) || StrEqual(arg1, "shotguns", false) || StrEqual(arg1, "sg", false) || StrEqual(arg1, "chrome", false) || StrEqual(arg1, "pump", false))
	{
		iViewmodelOption[client] = 2;
		CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Enabled {green}old{default} view models for {green}T1 Shotguns{default} only.");
	}
	else if (StrEqual(arg1, "smg", false) || StrEqual(arg1, "smgs", false) || StrEqual(arg1, "uzi", false) || StrEqual(arg1, "uzis", false) || StrEqual(arg1, "mac10", false))
	{
		iViewmodelOption[client] = 3;
		CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Enabled {green}old{default} view models for {green}T1 SMGs{default} only.");
	}
	else if ((iViewmodelOption[client] != 1 && strlen(arg1) == 0) || (StrEqual(arg1, "old", false) || StrEqual(arg1, "original", false) || StrEqual(arg1, "on", false)))
	{
		iViewmodelOption[client] = 1;
		CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Enabled {green}old{default} view models for {green}all T1 Weapons{default}.");
	}
	else if ((iViewmodelOption[client] == 1 && strlen(arg1) == 0) || (StrEqual(arg1, "new", false) || StrEqual(arg1, "default", false) || StrEqual(arg1, "tls", false) || StrEqual(arg1, "off", false)))
	{
		iViewmodelOption[client] = 0;
		CPrintToChat(client, "{blue}[{default}View Models{blue}]{default} Enabled {green}default{default} view models for {green}all T1 weapons{default}.");
	}

	UpdateViewmodel(client);

	return Plugin_Handled;
}

public void ReturnClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	//PrintToChatAll("Cvar %s at %N: %s", cvarName, client, cvarValue);

	if (StrEqual(cvarName, "cl_allowdownload"))
	{
		if (StrEqual(cvarValue, "1"))
		{
			bAllowDownload[client] = true;
		}
		else
		{
			bAllowDownload[client] = false;
		}
	}
	else if (StrEqual(cvarName, "cl_downloadfilter"))
	{
		if (StrEqual(cvarValue, "all"))
		{
			bDownloadFilter[client] = true;
		}
		else
		{
			bDownloadFilter[client] = false;
		}
	}
}

void HookValidClient(int client, bool Hook)
{
	if (IsValidClient(client))
	{
		if (Hook)
		{
			SDKHook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitch);
		}
		else
		{
			SDKUnhook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitch);
		}
	}
}

public void CVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	ViewmodelOption = hViewmodelOption.IntValue;
}

stock bool IsValidClient(int client) 
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
	return IsClientInGame(client); 
}

stock int FindEntityByClassname2(int startIndex, const char[] classname) 
{ 
    while (startIndex > -1 && !IsValidEntity(startIndex)) startIndex--; 
    return FindEntityByClassname(startIndex, classname); 
}  