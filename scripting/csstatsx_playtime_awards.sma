/*
*	CSXSQL Onlinetime Awards	     v. 0.2
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <hamsandwich>
#include <csstatsx_sql>

#define PLUGIN "CSXSQL: Onlinetime Awards"
#define VERSION "0.2"
#define AUTHOR "serfreeman1337"

#define TOP 		3				// Скольким игрокам из топа выдавать флаги?
#define IGNORE_FLAGS	(ADMIN_MENU|ADMIN_LEVEL_H)	// Не выдавать плюшки игрокам с этими флагами
#define GIVE_FLAGS	ADMIN_LEVEL_H			// Выдаваемые флаги

new top_ids[TOP] = -1

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
	RegisterHam(Ham_Spawn,"player","PlayerSpawn",true)
	
}

public csxsql_initialized()
{
	update_stats_cache()
	get_stats_sql_thread(0,0,TOP,"TopPlayedTime",CSXSQL_RANK_TIME)
}

public PlayerSpawn(id)
{
	if(!is_user_connected(id))
	{
		return
	}
	
	new flags = get_user_flags(id)
	
	if(flags & IGNORE_FLAGS)
	{
		return
	}
	
	for(new i,db_id = get_user_stats_id(id) ; i < TOP ; i++)
	{
		if(top_ids[i] == db_id)
		{
			set_user_flags(id,flags | GIVE_FLAGS)
			break
		}
	}
}

public TopPlayedTime(id,pos)
{
	new index
	
	while((index = get_stats_id(index,top_ids[index])))
	{
		if(index >= TOP)
			break
	}
}
