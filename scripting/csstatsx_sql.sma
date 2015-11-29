/*
*	CSStatsX MySQL			     v. 0.1 Beta
*	by serfreeman1337	     http://gf.hldm.org/
*/

#include <amxmodx>
#include <csstats>
#include <sqlx>

#define PLUGIN "CSStatsX MySQL"
#define VERSION "0.1 Beta"
#define AUTHOR "serfreeman1337"	// AKA SerSQL1337

#define MYSQL_HOST	"localhost"
#define MYSQL_USER	"root"
#define MYSQL_PASS	""
#define MYSQL_DB	"amxx"

#if AMXX_VERSION_NUM < 183
	#define MAX_PLAYERS 32
	new MaxClients
#endif

/* - SQL - */

new Handle:sql
new Handle:sql_con

/* -  КОНСТАНТЫ - */

enum _:sql_que_type	// тип sql запроса
{
	SQL_DUMMY,
	SQL_LOAD,	// загрузка статистики
	SQL_UPDATE,	// обновление
	SQL_INSERT,	// внесение новой записи
	SQL_UPDATERANK	// получение ранков игроков
}

enum _:load_state_type	// состояние получение статистики
{
	LOAD_NO,	// данных нет
	LOAD_WAIT,	// ожидание данных
	LOAD_OK,	// есть данные
	LOAD_NEW	// новая запись
}

enum _:row_ids		// столбцы таблицы
{
	ROW_ID,
	ROW_IP,
	ROW_STEAMID,
	ROW_NAME,
	ROW_KILLS,
	ROW_DEATHS,
	ROW_HS,
	ROW_TKS,
	ROW_SHOTS,
	ROW_HITS,
	ROW_DMG,
	ROW_BOMBDEF,
	ROW_BOMBDEFUSED,
	ROW_BOMBPLANTS,
	ROW_BOMBEXPLOSIONS,
	ROW_HITSARRAY,
	ROW_FIRSTJOIN,
	ROW_LASTJOIN
}

new const row_names[row_ids][] = // имена столбцов
{
	"id",
	"ip",
	"steamid",
	"name",
	"kills",
	"deaths",
	"hs",
	"tks",
	"shots",
	"hits",
	"dmg",
	"bombdef",
	"bombdefused",
	"bombplants",
	"bombexplosions",
	"hits_xml",
	"first_join",
	"last_join"
}

const QUERY_LENGTH =	1216	// размер переменной sql запроса

#define STATS_KILLS 	0
#define STATS_DEATHS 	1
#define STATS_HS 	2
#define STATS_TK 	3
#define STATS_SHOTS 	4
#define STATS_HITS	5
#define STATS_DMG 	6

#define STATS2_DEFAT	0
#define STATS2_DEFOK	1
#define STATS2_PLAAT	2
#define STATS2_PLAOK	3

new const task_rankupdate	=	31337
new const task_confin		=	21337

/* - СТРУКТУРА ДАННЫХ - */

enum _:player_data_struct
{
	PLAYER_ID,		// ид игрока в базе данных
	PLAYER_LOADSTATE,	// состояние загрузки статистики игрока
	PLAYER_RANK,		// ранк игрока
	PLAYER_STATS[8],	// статистика игрока
	PLAYER_STATSLAST[8],	// разница в статистики
	PLAYER_HITS[8],		// статистика попаданий
	PLAYER_HITSLAST[8],	// разница в статистике попаданий
	PLAYER_STATS2[4],	// статистика cstrike
	PLAYER_STATS2LAST[4]	// разница
}

/* - ПЕРЕМЕННЫЕ - */

new player_data[MAX_PLAYERS + 1][player_data_struct]
new statsnum
new track_set

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
	
	track_set = get_cvar_num("csstats_rank")
	
	register_logevent("logevent_round_end", 2, "1=Round_End") 
	
	#if AMXX_VERSION_NUM < 183
	MaxClients = get_maxplayers()
	#endif
}

public logevent_round_end()
{
	DB_GetPlayerRanks()
}

public plugin_natives()
{
	register_native("get_statsnum_sql","native_get_statsnum")
	register_native("get_user_stats_sql","native_get_user_stats")
	register_native("get_stats_sql","native_get_stats")
	//register_native("get_user_stats2_sql","native_get_user_stats2")
	//register_native("get_stats2_sql","native_get_stats2")
}

/*
* Возвращает общее количество записей в базе данных
*
* native get_statsnum_sql()
*/
public native_get_statsnum(plugin_id,params)
{
	return statsnum
}

/*
* Получение статистики игрока
*
* native get_user_stats_sql(index, stats[8], bodyhits[8])
*/
public native_get_user_stats(plugin_id,params)
{
	new id = get_param(1)
	
	if(!(0 < id <= MaxClients))	// неверно задан айди игрока
	{
		log_error(AMX_ERR_NATIVE,"Player index out of bounds (%d)",id)
		
		return 0
	}
	
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // данные отсутствуют
	{
		return 0
	}
	
	set_array(2,player_data[id][PLAYER_STATS],8)
	set_array(3,player_data[id][PLAYER_HITS],8)
	
	return player_data[id][PLAYER_RANK]
}

/*
* Получение статистик по позиции
*
* native get_stats_sql(index, stats[8], bodyhits[8], name[], len, authid[] = "", authidlen = 0);
*/
public native_get_stats(plugin_id,params)
{
	// открываем соединение с БД для получения актуальных данных
	// TODO: поддержка потоков, кеш
	if(!DB_OpenConnection())
	{
		return false	// ошибка открытия соединения
	}
	else
	{
		// задание на сброс содеинения
		// чтобы не открывать новые и успеть получить сразу несколько данных за одно соединение
		if(!task_exists(task_confin))
		{
			set_task(0.1,"DB_CloseConnection",task_confin)
		}
	}
	
	new index = get_param(1)	// индекс в статистике
	
	new query[QUERY_LENGTH],len
	
	
	// строим запрос
	len += formatex(query[len],charsmax(query)-len,"SELECT ")
	
	// общая статистика (да, я ленивая жопа и специально сделал цикл)
	for(new i = ROW_STEAMID ; i <= ROW_DMG ; i++)
	{
		len += formatex(query[len],charsmax(query)-len,"%s`%s`",
			i == ROW_STEAMID ? "" : ",",
			row_names[i]
		)
	}
	
	// разбираем xml статистик попаданий
	for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
	{
		len += formatex(query[len],charsmax(query)-len,",ExtractValue(`%s`,'//i[%d]')",
			row_names[ROW_HITSARRAY],i + 1
		)
	}
	
	// запрос на ранк
	len += formatex(query[len],charsmax(query)-len,",(")
	len += get_score_sql(query[len],charsmax(query)-len)
	len += formatex(query[len],charsmax(query)-len,") as `rank`")
	
	// запрашиваем следующию запись
	// если есть, то возврашаем нативом index + 1
	len += formatex(query[len],charsmax(query)-len," FROM `csstats` as `a` ORDER BY `rank` LIMIT %d,2",
		index
	)
	
	new Handle:sqlQue = SQL_PrepareQuery(sql_con,query)
	
	if(!SQL_Execute(sqlQue))
	{
		new errNum,err[256]
		errNum = SQL_QueryError(sqlQue,err,charsmax(err))
		
		log_amx("MySQL query failed")
		log_amx("[ %d ] %s",errNum,err)
		log_amx("[ SQL ] %s",query)
		
		SQL_FreeHandle(sqlQue)
		
		return 0
	}
	
	if(SQL_NumResults(sqlQue))
	{
		new name[32],steamid[30],stats[8],hits[8]
		
		SQL_ReadResult(sqlQue,0,steamid,charsmax(steamid))
		SQL_ReadResult(sqlQue,1,name,charsmax(name))
		
		// разбор данных (да, мне опять лень и опять тут супер цикл)
		for(new i = 2; i < sizeof player_data[][PLAYER_STATS] +  sizeof player_data[][PLAYER_HITS] + 2 ; i++)
		{
			// обычная статистка
			if(i - 2 < sizeof player_data[][PLAYER_STATS])
				stats[i - 2] = SQL_ReadResult(sqlQue,i)
			else // статистика попаданий
				hits[i - sizeof player_data[][PLAYER_STATS] - 2] = SQL_ReadResult(sqlQue,i)
		}
		
		set_array(2,stats,sizeof player_data[][PLAYER_STATS])
		set_array(3,hits,sizeof player_data[][PLAYER_HITS])
		set_string(4,name,get_param(5))
		
		// TODO: сделать нормально
		if(params > 5)
		{
			set_string(6,steamid,get_param(7))
		}
		
		return SQL_NumResults(sqlQue) > 1 ? index + 1 : 0
	}
	
	SQL_FreeHandle(sqlQue)
	
	return 0
}

public DB_OpenConnection()
{
	if(sql_con != Empty_Handle)
	{
		return true
	}
	
	new errNum,err[256]
	sql_con = SQL_Connect(sql,errNum,err,charsmax(err))
	
	if(errNum)
	{
		log_amx("MySQL query failed")
		log_amx("[ %d ] %s",errNum,err)
			
		return false
	}
	
	log_amx("--> sql connection open %.2f",get_gametime())
	
	return true
}

public DB_CloseConnection()
{
	if(sql_con != Empty_Handle)
	{
		SQL_FreeHandle(sql_con)
		sql_con = Empty_Handle
		
		log_amx("--> sql connection closed %.2f",get_gametime())
	}
}

// TODO: нативы get_stats
public native_get_user_stats2(plugin_id,params)
{
	return 0
}

public native_get_stats2(plugin_id,params)
{
	return 0
}

public plugin_end()
{
	log_amx("--> plugin end [%.2f]",get_gametime())
}

public test1(id)
{
	DB_GetPlayerRanks()
}

public test2(id)
{
	DB_SavePlayerData(id)
}

public plugin_cfg()
{
	sql = SQL_MakeDbTuple(MYSQL_HOST,MYSQL_USER,MYSQL_PASS,MYSQL_DB)
}

public client_putinserver(id)
{
	arrayset(player_data[id],0,player_data_struct)
	DB_LoadPlayerData(id)
}

public client_disconnect(id)
{
	DB_SavePlayerData(id)
}

/*
* загрузка статистики игрока из базы данных
*/
DB_LoadPlayerData(id)
{
	new name[96],steamid[30],ip[16]
	
	// узнаем ник, ид, айпи игрока
	get_user_name(id,name,charsmax(name))
	get_user_authid(id,steamid,charsmax(steamid))
	get_user_ip(id,ip,charsmax(ip),true)
	
	mysql_escape_string(name,charsmax(name))
	
	// формируем SQL запрос
	new query[QUERY_LENGTH],len,sql_data[2]
	
	sql_data[0] = SQL_LOAD
	sql_data[1] = id
	player_data[id][PLAYER_LOADSTATE] = LOAD_WAIT
	
	// TODO: sql escape
	
	len += formatex(query[len],charsmax(query)-len,"SELECT *,(")
	len += get_score_sql(query[len],charsmax(query)-len)
	len += formatex(query[len],charsmax(query)-len,"),(")
	len += get_statsnum_sql(query[len],charsmax(query)-len)
	len += formatex(query[len],charsmax(query)-len,")")
	
	// разбираем xml статистик попаданий
	for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
	{
		len += formatex(query[len],charsmax(query)-len,",ExtractValue(`%s`,'//i[%d]')",
			row_names[ROW_HITSARRAY],i + 1
		)
	}
	
	
	switch(track_set)
	{
		case 0: // статистика по нику
		{
			len += formatex(query[len],charsmax(query)-len," FROM `csstats` AS `a` WHERE `name` = '%s'",
				name
			)
		}
		case 1: // статистика по steamid
		{
			len += formatex(query[len],charsmax(query)-len," FROM `csstats` AS `a` WHERE `steamid` = '%s'",
				steamid
			)
		}
		case 2: // статистика по ip
		{
			len += formatex(query[len],charsmax(query)-len," FROM `csstats` AS `a` WHERE `ip` = '%s'",
				ip
			)
		}
		default:
		{
			return false
		}
	}
	
	// отправка потокового запроса
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	
	return true
}


/*
* сохранение статистики игрока
*/
DB_SavePlayerData(id)
{
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // игрок не загрузился
	{
		return false
	}
	
	new name[32],steamid[30],ip[16],query[QUERY_LENGTH],i
	
	new sql_data[2 + 					// 2
		sizeof player_data[][PLAYER_STATS] + // 8
		sizeof player_data[][PLAYER_HITS] // 8
	]
	
	sql_data[1] = id
	
	// узнаем ник, ид, айпи игрока
	get_user_name(id,name,charsmax(name))
	get_user_authid(id,steamid,charsmax(steamid))
	get_user_ip(id,ip,charsmax(ip),true)
	
	new stats[8],stats2[4],hits[8]
	get_user_wstats(id,0,stats,hits)
	get_user_stats2(id,stats2)
	
	new hits_xml[256],xml_len
	
	/*
	if(!stats[STATS_DEATHS] && !stats[STATS_SHOTS])
	{
		return false
	}
	*/
	
	switch(player_data[id][PLAYER_LOADSTATE])
	{
		case LOAD_OK: // обновление данных
		{
			sql_data[0] = SQL_UPDATE
			
			new diffstats[sizeof player_data[][PLAYER_STATS]]
			new diffstats2[sizeof player_data[][PLAYER_STATS2]]
			new diffhits[sizeof player_data[][PLAYER_HITS]]
			new len,to_save
			
			len += formatex(query[len],charsmax(query) - len,"UPDATE `csstats` SET")
			
			// обновляем по разнице с предедущими данными
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				diffstats[i] = stats[i] - player_data[id][PLAYER_STATSLAST][i] // узнаем разницу
				player_data[id][PLAYER_STATSLAST][i] = stats[i]
				
				if(diffstats[i])
				{
					len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
						!to_save ? " " : ",",
						row_names[i + ROW_KILLS],
						row_names[i + ROW_KILLS],
						diffstats[i]
					)
					
					to_save ++
				}
			}
			
			// обновляем по разнице с предедущими данными
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
			{
				diffstats2[i] = stats2[i] - player_data[id][PLAYER_STATS2LAST][i] // узнаем разницу
				player_data[id][PLAYER_STATS2LAST][i] = stats2[i]
				
				if(diffstats[i])
				{
					len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
						!to_save ? " " : ",",
						row_names[i + ROW_BOMBDEF],
						row_names[i + ROW_BOMBDEF],
						diffstats2[i]
					)
					
					to_save ++
				}
			}
			
			if(to_save)
			{
				// передаем хмл с разницей, которую обработает триггер на стороне хмл
				for(i = 0,xml_len = 0 ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					diffhits[i] = hits[i] - player_data[id][PLAYER_HITSLAST][i] // узнаем разницу
					player_data[id][PLAYER_HITSLAST][i] = hits[i]
					
					xml_len += formatex(hits_xml[xml_len],charsmax(hits_xml) - xml_len,"<i>%d</i>",diffhits[i])
				}
				
				len += formatex(query[len],charsmax(query) - len,",`%s` = '%s'",
					row_names[ROW_HITSARRAY],hits_xml
				)
			}
			
			len += formatex(query[len],charsmax(query) - len,",`last_join` = CURRENT_TIMESTAMP() WHERE `%s` = '%d'",
				row_names[ROW_ID],player_data[id][PLAYER_ID]
			)
			
			if(!to_save) // нечего сохранять
			{
				return false
			}
		}
		case LOAD_NEW: // запрос на добавление новой записи
		{
			// строим xml для статистики попаданий
			for(i = 0,xml_len = 0 ; i < sizeof player_data[][PLAYER_HITS];i++)
			{
				xml_len += formatex(hits_xml[xml_len],charsmax(hits_xml) - xml_len,"<i>%d</i>",player_data[id][PLAYER_HITS])
			}
			
			sql_data[0] = SQL_INSERT
			
			formatex(query,charsmax(query),"INSERT INTO `csstats` \
							(`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`)\
							VALUES('%s','%s','%s','%d','%d','%d','%d','%d','%d','%d','%s','%d','%d','%d','%d')\
							",
							
					row_names[ROW_STEAMID],
					row_names[ROW_NAME],
					row_names[ROW_IP],
					row_names[ROW_KILLS],
					row_names[ROW_DEATHS],
					row_names[ROW_HS],
					row_names[ROW_TKS],
					row_names[ROW_SHOTS],
					row_names[ROW_HITS],
					row_names[ROW_DMG],
					row_names[ROW_HITSARRAY],
					row_names[ROW_BOMBDEF],
					row_names[ROW_BOMBDEFUSED],
					row_names[ROW_BOMBPLANTS],
					row_names[ROW_BOMBEXPLOSIONS],
					
					steamid,name,ip,
					
					stats[STATS_KILLS],
					stats[STATS_DEATHS],
					stats[STATS_HS],
					stats[STATS_TK],
					stats[STATS_SHOTS],
					stats[STATS_HITS],
					stats[STATS_DMG],
					
					hits_xml,
					
					stats2[STATS2_DEFAT],
					stats2[STATS2_DEFOK],
					stats2[STATS2_PLAAT],
					stats2[STATS2_PLAOK]
			)
			
			// stats
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				sql_data[i + 2] = stats[i]
			}
			
			// hits
			for(i = 0 ; i < sizeof player_data[][PLAYER_HITS] ; i++)
			{
				sql_data[i + 2 + sizeof player_data[][PLAYER_STATS]] = hits[i]
			}
		}
	}
	
	if(query[0])
	{
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	return true
}

/*
* получение новых позиции в топе игроков
*/
public DB_GetPlayerRanks()
{
	new players[32],pnum
	get_players(players,pnum)
	
	new query[QUERY_LENGTH],len
	
	// строим SQL запрос
	len += formatex(query[len],charsmax(query) - len,"SELECT `id`,(")
	len += get_score_sql(query[len],charsmax(query) - len)
	len += formatex(query[len],charsmax(query) - len,") FROM `csstats` as `a` WHERE `id` IN(")
	
	new bool:letsgo
	
	for(new i,player,bool:y  ; i < pnum ; i++)
	{
		player = players[i]
		
		if(player_data[player][PLAYER_ID])
		{
			len += formatex(query[len],charsmax(query) - len,"%s'%d'",y ? "," : "",player_data[player][PLAYER_ID])
			y = true
			letsgo = true
		}
	}
	
	len += formatex(query[len],charsmax(query) - len,")")
	
	if(letsgo)
	{
		new data[1] = SQL_UPDATERANK
		SQL_ThreadQuery(sql,"SQL_Handler",query,data,sizeof data)
	}
}

/*
* обработка ответов на SQL запросы
*/
public SQL_Handler(failstate,Handle:sqlQue,err[],errNum,data[],dataSize){
	// есть ошибки
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED:  // ошибка соединения с mysql сервером
		{
			log_amx("MySQL connection failed")
			log_amx("[ %d ] %s",errNum,err)

			return PLUGIN_HANDLED
		}
		case TQUERY_QUERY_FAILED:  // ошибка SQL запроса
		{
			new lastQue[QUERY_LENGTH]
			SQL_GetQueryString(sqlQue,lastQue,charsmax(lastQue)) // узнаем последний SQL запрос
			
			log_amx("MySQL query failed")
			log_amx("[ %d ] %s",errNum,err)
			log_amx("[ SQL ] %s",lastQue)
			
			return PLUGIN_HANDLED
		}
	}
	

	switch(data[0])
	{
		case SQL_LOAD: // загрзука статистики игрока
		{
			new id = data[1]
		
			log_amx("--> load report: [%d] [%d] [%.2f]",id,is_user_connected(id),get_gametime())
		
			if(!is_user_connected(id))
			{
				return PLUGIN_HANDLED
			}
			
			if(SQL_NumResults(sqlQue)) // считываем статистику
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_OK
				player_data[id][PLAYER_ID] = SQL_ReadResult(sqlQue,ROW_ID)
				
				// общая статистика
				player_data[id][PLAYER_STATS][STATS_KILLS] = SQL_ReadResult(sqlQue,ROW_KILLS)
				player_data[id][PLAYER_STATS][STATS_DEATHS] = SQL_ReadResult(sqlQue,ROW_DEATHS)
				player_data[id][PLAYER_STATS][STATS_HS] = SQL_ReadResult(sqlQue,ROW_HS)
				player_data[id][PLAYER_STATS][STATS_TK] = SQL_ReadResult(sqlQue,ROW_TKS)
				player_data[id][PLAYER_STATS][STATS_SHOTS] = SQL_ReadResult(sqlQue,ROW_SHOTS)
				player_data[id][PLAYER_STATS][STATS_HITS] = SQL_ReadResult(sqlQue,ROW_HITS)
				player_data[id][PLAYER_STATS][STATS_DMG] = SQL_ReadResult(sqlQue,ROW_DMG)
				
				// статистика cstrike
				player_data[id][PLAYER_STATS2][STATS2_DEFAT] = SQL_ReadResult(sqlQue,ROW_BOMBDEF)
				player_data[id][PLAYER_STATS2][STATS2_DEFOK] = SQL_ReadResult(sqlQue,ROW_BOMBDEFUSED)
				player_data[id][PLAYER_STATS2][STATS2_PLAAT] = SQL_ReadResult(sqlQue,ROW_BOMBPLANTS)
				player_data[id][PLAYER_STATS2][STATS2_PLAOK] = SQL_ReadResult(sqlQue,ROW_BOMBEXPLOSIONS)
				
				// доп. запросы
				player_data[id][PLAYER_RANK] = SQL_ReadResult(sqlQue,row_ids)	// ранк игрока
				statsnum = SQL_ReadResult(sqlQue,row_ids + 1)			// общее кол-во игроков в БД
				
				// статистика попаданий
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] = SQL_ReadResult(sqlQue,row_ids + 2 + i)
				}
				
				log_amx("--> load ok! %d, rank: %d of %d [%.2f]",player_data[id][PLAYER_ID],player_data[id][PLAYER_RANK],statsnum,get_gametime())
			}
			else // помечаем как нового игрока
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_NEW
				
				DB_SavePlayerData(id) // добавляем запись в базу данных
				log_amx("--> load new %d! [%.2f]",id,get_gametime())
			}
		}
		case SQL_INSERT:	// запись новых данных
		{
			new id = data[1]
			
			if(is_user_connected(id))
			{
				player_data[id][PLAYER_ID] = SQL_GetInsertId(sqlQue)	// первичный ключ
				player_data[id][PLAYER_LOADSTATE] = LOAD_OK		// данные загружены
				
				
				// я упрлся 0)0)0
				
				// сравниваем статистику
				for(new i ; i < sizeof player_data[][PLAYER_STATS] ; i++)
				{
					player_data[id][PLAYER_STATS][i] = data[2 + i]
				}
				
				// статистика по попаданиям
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] = data[2 + i + player_data[id][PLAYER_STATS]]
				}
				
				// обновляем счетчик общего кол-ва записей
				statsnum++
			}
			
			// обновляем позици игроков
			// действие с задержкой, что-бы учесть изменения при множественном обновлении данных
			if(!task_exists(task_rankupdate))
			{
				set_task(1.0,"DB_GetPlayerRanks",task_rankupdate)
			}
		}
		case SQL_UPDATE: // обновление данных
		{
			new id = data[1]
			
			if(is_user_connected(id))
			{	
				// сравниваем статистику
				for(new i ; i < sizeof player_data[][PLAYER_STATS] ; i++)
				{
					player_data[id][PLAYER_STATS][i] = player_data[id][PLAYER_STATSLAST][i]
				}
				
				// сравниваем статистику
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] = player_data[id][PLAYER_HITSLAST][i]
				}
			}
			
			// обновляем позици игроков
			// действие с задержкой, что-бы учесть изменения при множественном обновлении данных
			if(!task_exists(task_rankupdate))
			{
				set_task(0.1,"DB_GetPlayerRanks",task_rankupdate)
			}
		}
		case SQL_UPDATERANK:
		{
			while(SQL_MoreResults(sqlQue))
			{
				new pK =  SQL_ReadResult(sqlQue,0)
				new rank = SQL_ReadResult(sqlQue,1)
				
				log_amx("--> get rank: [%d - > %d] [%.2f]",
					pK,rank,get_gametime()
				)
				
				for(new i ; i < MAX_PLAYERS ; i++)
				{
					if(player_data[i][PLAYER_ID] == pK)	// задаем ранк по первичному ключу
					{
						log_amx("--> rank compare: [%d -> %d] [%.2f]",
							pK,rank,get_gametime())
							
						player_data[i][PLAYER_RANK] = rank
					}
				}
				
				SQL_NextRow(sqlQue)
			}
		}
	}

	return PLUGIN_HANDLED
}

/*
* запрос на просчет ранка
*/
get_score_sql(sql_que[] = "",sql_que_len = 0)
{
	// стандартная формула csstats (убийства-смерти-tk)
	return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM csstats WHERE (kills-deaths-tks)>=(a.kills-a.deaths-a.tks)")
}

/*
* запрос на общее кол-во записей в БД
*/ 
get_statsnum_sql(sql_que[] = "",sql_que_len = 0)
{
	return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM csstats WHERE 1")
}

/*********    mysql escape functions     ************/
mysql_escape_string(dest[],len)
{
	//copy(dest, len, source);
	replace_all(dest,len,"\\","\\\\");
	replace_all(dest,len,"\0","\\0");
	replace_all(dest,len,"\n","\\n");
	replace_all(dest,len,"\r","\\r");
	replace_all(dest,len,"\x1a","\Z");
	replace_all(dest,len,"'","\'");
	replace_all(dest,len,"^"","\^"");
}
