#include <a_samp>

#undef MAX_PLAYERS
#define MAX_PLAYERS (100) // Be sure to change this and redefine it! This is mandatory!

#include <a_mysql>
#include <sscanf2>
#include <zcmd>
#include <foreach>
#include "colors2.inc"

new
	MySQL: Database,
	p_Offset[MAX_PLAYERS];

#define MYSQL_HOST		"localhost"
#define MYSQL_USER		"root"
#define MYSQL_PASS		""
#define MYSQL_DATABASE	"testwo"

public OnFilterScriptInit()
{
	new MySQLOpt: option_id = mysql_init_options();
	mysql_set_option(option_id, AUTO_RECONNECT, true); // We will set that option to automatically reconnect on timeouts.
	Database = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE, option_id);
	
	if (Database == MYSQL_INVALID_HANDLE || mysql_errno(Database) != 0) { // Checking if the database connection is invalid or there's an error to shutdown
		print("Connection to MySQL database has failed! Shutting down the server.");
		printf("[DEBUG] Host: %s, User: %s, Password: %s, Database: %s", MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE);
		SendRconCommand("exit");
		return 1;
	}
	else {
		print("Connection to MySQL database was successful.");
	}
	
	return 1;
}

SendAdminMessage(color, string[]) {

	foreach(new i : Player) {
		if (!IsPlayerAdmin(i)) continue;
		
		SendClientMessage(i, color, query);
	}
	
	return 1;
}

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

GetReports(playerid) {

	new
		query[128];
	
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
		i,
		string[256], // format-ed text
		info[1000], // text displayed in the dialog
		Reporter[MAX_PLAYER_NAME],
		Repoted[MAX_PLAYER_NAME],
		Reason[100],
		Date[30], // Use UNIX TIMESTAMPS!!!
		reportid,
		Accepted;
	
	strcat(info, "{FF7256}Displaying 15 latest reports:\n\n{FFFFFF}"); // Colored it :D
	
	for (i = 0; i < rows; i++) {
		cache_get_value_name(i, "Reporter", Reporter, 24);
        	cache_get_value_name(i, "Reported", Reported, 24);
        	cache_get_value_name(i, "Reason", Reason, 100);
        	cache_get_value_name(i, "Date", Date, 30);
        	cache_get_value_name_int(i, "ID", reportid);
        	cache_get_value_name_int(i, "Accepted", Accepted);
		
		format(string, sizeof string, "{AFAFAF}[ID: %d]: {FFFFFF}%s has reported %s for the reason {AFAFAF}'%s' on %s - ");
		switch(Accepted) {
        		case 0: strcat(string, {AFAFAF}Not Checked\n");
        		case 1: strcat(string, {00AA00}Accepted\n");
        		case 2: strcat(string, {FF0000}Denied\n");
        	}
		
		strcat(info, string);
        }
	
	Dialog_Show(playerid, DIALOG_REPORTS, DIALOG_STYLE_MSGBOX, "Latest 15 Reports", info, "Close", "Next page");

	return 1;
}

CMD:reports(playerid, params[]) {
	
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");
	
	p_Offset[playerid] = 0;
	
	return GetReports(playerid);
}

CMD:clearreports(playerid) {
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");

	mysql_pquery(Database, query, "DELETE FROM `reports` ORDER BY `Date` LIMIT 15;"); // removed the format line, made it pquery and simple

	return SendClientMessage(playerid, COLOR_LIGHTBLUE, "You have deleted 15 latest reports that existed on the MySQL database.");
}

forward AcceptReport(playerid, report_id, vote);
public AcceptReport(playerid, report_id, vote) {

	new
		rows, string[100], accepted, reported[MAX_PLAYER_NAME], reason[100];
	
	cache_get_row_count(rows);
	
	if (!rows) {
		format(string, sizeof string, "ERROR: Report ID [%d] couldn't be found in the MySQL Database.", reportid);
		return SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
	}
	
	cache_get_value_name_int(i, "Accepted", accepted);
	
	if (Accepted != 0) {
		format(string, sizeof string, "ERROR: Report ID [%d] is already accepted or denied before.");
		return SendClientMessage(playerid, COLOR_RED, string);
	}
	
	cache_get_value_name(i, "Reported", reported, sizeof reported);
	cache_get_value_name(i, "Reason", reason sizeof report);

	format(string, sizeof string, "You have %s report ID [%i].", (vote == 1) ? ("accepted") : ("denied"), reportid);
	SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
	
	mysql_format(Database, string, sizeof string, "UPDATE `reports` SET `Accepted` = '%i' WHERE `ID` = '%i'", vote, reportid);
	mysql_pquery(Database, query);

	return 1;

}

CMD:r(playerid, params[]) {
	
	if (!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR]: {FFFFFF}You are not authorized to use that command.");
	
	new reportid, string[200], query[300], character;
	if (sscanf(params, "dc", reportid, character)) return SendClientMessage(playerid, COLOR_LIGHTBLUE, "[USAGE]: {FFFFFF}/R [Report ID] [Y/N]");
	if (character != 'Y' || character != 'N') return SendClientMessage(playerid, COLOR_LIGHTBLUE, "[USAGE]: {FFFFFF}Y or N is the only supported answer.");
	
	mysql_format(Database, query, sizeof(query), "SELECT * FROM `reports` WHERE `ID` = '%i'", reportid);
	mysql_pquery(Database, query, "VoteReport", "iii", playerid, reportid, (character == 'Y') ? (1) : ((character == 'N') ? (2) : (0)));
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {

	if (dialogid == DIALOG_REPORTS) {
		if (!response) {
			GetReports(playerid);
		}
		
		return 1;
	}
	
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

GetPlayerNameEx(playerid) {
	new player_Name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, player_Name, sizeof player_Name);
	return player_Name;
}
