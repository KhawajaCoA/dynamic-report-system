#define FILTERSCRIPT

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>
#include <easyDialog>
#include <foreach>
#include "colors2.inc"

#if defined FILTERSCRIPT

new MySQL: Database;

#define MYSQL_HOST		"localhost"
#define MYSQL_USER		"root"
#define MYSQL_PASS		""
#define MYSQL_DATABASE	"testwo"

public OnFilterScriptInit()
{
	new MySQLOpt: option_id = mysql_init_options();
	mysql_set_option(option_id, AUTO_RECONNECT, true); // We will set that option to automatically reconnect on timeouts.
	Database = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE, option_id);
	
	if (Database == MYSQL_INVALID_HANDLE || mysql_errno(Database) != 0) // Checking if the database connection is invalid to shutdown.
	{
		print("Connection to MySQL database has failed! Shutting down the server.");
		printf("[DEBUG] Host: %s, User: %s, Password: %s, Database: %s", MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE);
		SendRconCommand("exit");
		return 1;
	}
	else
	{
		print("Connection to MySQL database was successful.");
	}
	
	return 1;
}

SendAdminMessage(color, string[]) {

	foreach(new i : Player) {
		if(! IsPlayerAdmin(i)) continue;
		
		SendClientMessage(i, COLOR_LIGHTBLUE, query);
	}
	
	return 1;
}

/*
	Logic_'s changes:
	- Updated /report to use one string var for the query and admin message
	- Updated targetid check validation with INVALID_PLAYER_ID since SSCANF already does that internally and returns that if the player is not connected.
*/

CMD:report(playerid, params[]) {
	new targetid, reason[100], query[300];
	if(sscanf(params, "ds[100]", targetid, reason)) return SendClientMessage(playerid, COLOR_LIGHTBLUE, "[USAGE]: {FFFFFF}/report [targetid] [reason]");
	if(targetid == INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}That player is not connected.");

	mysql_format(Database, query, sizeof(query), "INSERT INTO `reports` (`Reporter`, `Reported`, `Reason`, `Date`) VALUES ('%e', '%e', '%e', '%e')", GetName(playerid), GetName(targetid), reason, ReturnDate());
	mysql_pquery(Database, query);

	format(query, query, "REPORT: {FFFFFF}%s has reported %s for the reason: %s", GetName(playerid), GetName(targetid), reason);
	SendAdminMessage(COLOR_LIGHTBLUE, query);
	
	SendClientMessage(playerid, COLOR_LIGHTBLUE, "[SUCCESS]: {FFFFFF}Your report has been successfully sent to all administrators online.");
	return 1;
}

/*
	- Changed /reports to make use of threaded queries and added support for OFFSET functionality
*/

GetReports(playerid) {

	new
		query[];
	mysql_format(Database, query, sizeof query, "SELECT * FROM `reports` ORDER BY `Date` LIMIT 15 OFFSET %d", p_Offset[playerid]);
	mysql_tquery(Database, query, "ShowReportsMenu", "i");

	return 1;
}

forward ShowReportsMenu(playerid);
public ShowReportsMenu(playerid) {

	new
		rows;
	
	cache_get_row_count(rows);
	
	if (!rows) {
		return Dialog_Show(playerid, DIALOG_REPORTS, DIALOG_STYLE_MSGBOX, "No reports were found", "No reports were found on the MySQL database.", "Close", "");
	}
	
	new
		string[256], // format-ed text
		info[1000]; // text displayed in the dialog
	
	strcat(info, "{FF7256}Displaying 15 latest reports:\n\n{FFFFFF}"); // Colored it :D
	
	for (i = 0; i < rows; i++) {
		cache_get_value_name(i, "Reporter", Reporter, 24);
        	cache_get_value_name(i, "Reported", Reported, 24);
        	cache_get_value_name(i, "Reason", Reason, 200);
        	cache_get_value_name(i, "Date", Date, 30);
        	cache_get_value_name_int(i, "ID", reportid);
        	cache_get_value_name_int(i, "Accepted", Accepted);
		
		switch(Accepted) {
        		case 0: format(rinfo, sizeof(rinfo), "{AFAFAF}[ID: %d]: {FFFFFF}%s has reported %s for the reason {AFAFAF}'%s'{FFFFFF} on %s - {AFAFAF}Not Checked\n", reportid, Reporter, Reported, Reason, Date);
        		case 1: format(rinfo, sizeof(rinfo), "{AFAFAF}[ID: %d]: {FFFFFF}%s has reported %s for the reason {AFAFAF}'%s'{FFFFFF} on %s - {00AA00}Accepted\n", reportid, Reporter, Reported, Reason, Date);
        		case 2: format(rinfo, sizeof(rinfo), "{AFAFAF}[ID: %d]: {FFFFFF}%s has reported %s for the reason {AFAFAF}'%s'{FFFFFF} on %s - {FF0000}Denied\n", reportid, Reporter, Reported, Reason, Date);
        	}
        	strcat(string, rinfo);
        }
	
	Dialog_Show(playerid, DIALOG_REPORTS, DIALOG_STYLE_MSGBOX, "Latest 15 Reports", string, "Okay", "");

	return 1;
}

CMD:reports(playerid, params[]) {
	
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");
	
	return GetReports(playerid);
}

CMD:clearreports(playerid) {
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");

	mysql_pquery(Database, query, "DELETE FROM `reports` ORDER BY `Date` LIMIT 15;"); // removed the format line, made it pquery and simple

	return SendClientMessage(playerid, COLOR_LIGHTBLUE, "You have deleted 15 latest reports that existed on the MySQL database.");
}

CMD:ar(playerid, params[])
{	
	new reportid, string[200], query[300];
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");
	if(sscanf(params, "d", reportid)) return SendClientMessage(playerid, COLOR_LIGHTBLUE, "[USAGE]: {FFFFFF}/ar [reportid]");
	mysql_format(Database, query, sizeof(query), "SELECT * FROM `reports` WHERE `ID` = '%i'", reportid);
	new Cache:result = mysql_query(Database, query);
	if(cache_num_rows())
	{
		new Accepted, Reported[MAX_PLAYER_NAME], Reason[200];
		for(new i = 0; i < cache_num_rows(); i++)
		{
			cache_get_value_name_int(i, "Accepted", Accepted);
			cache_get_value_name(i, "Reported", Reported, MAX_PLAYER_NAME);
			cache_get_value_name(i, "Reason", Reason, 200);
		}
		if(Accepted == 1) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: That report has been already accepted once.");

		format(string, sizeof(string), "You have accepted report id %d", reportid);
		SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
		mysql_format(Database, query, sizeof(query), "UPDATE `reports` SET `Accepted` = '1' WHERE `ID` = '%i'", reportid);
		mysql_query(Database, query);
	}
	else
	{
		format(string, sizeof(string), "Report ID [%d] couldn't be found in the MySQL Database.", reportid);
		SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
	}
	cache_delete(result);
	return 1;
}

CMD:dr(playerid, params[])
{	
	new reportid, string[200], query[300];
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");
	if(sscanf(params, "d", reportid)) return SendClientMessage(playerid, COLOR_LIGHTBLUE, "[USAGE]: {FFFFFF}/dr [reportid]");
	mysql_format(Database, query, sizeof(query), "SELECT * FROM `reports` WHERE `ID` = '%i'", reportid);
	new Cache:result = mysql_query(Database, query);
	if(cache_num_rows())
	{
		new Accepted, Reported[MAX_PLAYER_NAME], Reason[200];
		for(new i = 0; i < cache_num_rows(); i++)
		{
			cache_get_value_name_int(i, "Accepted", Accepted);
			cache_get_value_name(i, "Reported", Reported, MAX_PLAYER_NAME);
			cache_get_value_name(i, "Reason", Reason, 200);
		}
		if(Accepted == 2) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: That report has been already denied once.");

		format(string, sizeof(string), "You have denied report id %d", reportid);
		SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
		mysql_format(Database, query, sizeof(query), "UPDATE `reports` SET `Accepted` = '2' WHERE `ID` = '%i'", reportid);
		mysql_query(Database, query);
	}
	else
	{
		format(string, sizeof(string), "Report ID [%d] couldn't be found in the MySQL Database.", reportid);
		SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
	}
	cache_delete(result);
	return 1;
}

ReturnDate()
{
    new sendString[90], MonthStr[40], month, day, year;
    new hour, minute, second;
 
    gettime(hour, minute, second);
    getdate(year, month, day);
    switch(month)
    {
        case 1:  MonthStr = "January";
        case 2:  MonthStr = "February";
        case 3:  MonthStr = "March";
        case 4:  MonthStr = "April";
        case 5:  MonthStr = "May";
        case 6:  MonthStr = "June";
        case 7:  MonthStr = "July";
        case 8:  MonthStr = "August";
        case 9:  MonthStr = "September";
        case 10: MonthStr = "October";
        case 11: MonthStr = "November";
        case 12: MonthStr = "December";
    }
 
    format(sendString, 90, "%s %d, %d %02d:%02d:%02d", MonthStr, day, year, hour, minute, second);
    return sendString;
}

GetName(playerid) {
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

#endif
