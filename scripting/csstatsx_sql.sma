/*
*	CSStatsX MySQL			  	  v. 0.5
*	by serfreeman1337	     	 http://1337.uz/
*/

#include <amxmodx>
#include <sqlx>

#include <fakemeta>

#define PLUGIN "CSStatsX MySQL"
#define VERSION "0.5.1"
#define AUTHOR "serfreeman1337"	// AKA SerSQL1337

#define LASTUPDATE "22, April (04), 2016"

#if AMXX_VERSION_NUM < 183
	#define MAX_PLAYERS 32
	#define MAX_NAME_LENGTH 32
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
	SQL_UPDATERANK,	// получение ранков игроков,
	SQL_GETSTATS	// потоквый запрос на get_stats
}

enum _:load_state_type	// состояние получение статистики
{
	LOAD_NO,	// данных нет
	LOAD_WAIT,	// ожидание данных
	LOAD_OK,	// есть данные
	LOAD_NEW,	// новая запись
	LOAD_NEWWAIT,	// новая запись, ждем ответа
	LOAD_UPDATE	// перезагрузить после обновления
}

enum _:row_ids		// столбцы таблицы
{
	ROW_ID,
	ROW_STEAMID,
	ROW_NAME,
	ROW_IP,
	ROW_SKILL,
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
	ROW_H0,
	ROW_H1,
	ROW_H2,
	ROW_H3,
	ROW_H4,
	ROW_H5,
	ROW_H6,
	ROW_H7,
	ROW_ONLINETIME,
	ROW_FIRSTJOIN,
	ROW_LASTJOIN
}

new const row_names[row_ids][] = // имена столбцов
{
	"id",
	"steamid",
	"name",
	"ip",
	"skill",
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
	"h_0",
	"h_1",
	"h_2",
	"h_3",
	"h_4",
	"h_5",
	"h_6",
	"h_7",
	"connection_time",
	"first_join",
	"last_join"
}

enum _:STATS
{
	STATS_KILLS,
	STATS_DEATHS,
	STATS_HS,
	STATS_TK,
	STATS_SHOTS,
	STATS_HITS,
	STATS_DMG,
	
	STATS_END
}

enum _:KILL_EVENT
{
	NORMAL,
	SUICIDE,
	WORLD,
	WORLDSPAWN
}

const QUERY_LENGTH =	1472	// размер переменной sql запроса

#define STATS2_DEFAT	0
#define STATS2_DEFOK	1
#define STATS2_PLAAT	2
#define STATS2_PLAOK	3
#define STATS2_END	4

new const task_rankupdate	=	31337
new const task_confin		=	21337

#define MAX_CWEAPONS		6
#define MAX_WEAPONS		CSW_P90 + 1 + MAX_CWEAPONS
#define HIT_END			HIT_RIGHTLEG + 1

/* - СТРУКТУРА ДАННЫХ - */

enum _:player_data_struct
{
	PLAYER_ID,		// ид игрока в базе данных
	PLAYER_LOADSTATE,	// состояние загрузки статистики игрока
	PLAYER_RANK,		// ранк игрока
	PLAYER_STATS[STATS_END],	// статистика игрока
	PLAYER_STATSLAST[STATS_END],	// разница в статистики
	PLAYER_HITS[HIT_END],		// статистика попаданий
	PLAYER_HITSLAST[HIT_END],	// разница в статистике попаданий
	PLAYER_STATS2[4],	// статистика cstrike
	PLAYER_STATS2LAST[4],	// разница
	Float:PLAYER_SKILL,		// скилл
	PLAYER_ONLINE,		// время онлайна
	// я не помню чо за diff и last, но без этого не работает XD
	Float:PLAYER_SKILLLAST,
	PLAYER_ONLINEDIFF,
	PLAYER_ONLINELAST,
	
	PLAYER_NAME[MAX_NAME_LENGTH * 3],
	PLAYER_STEAMID[30],
	PLAYER_IP[16]
}

enum _:stats_cache_struct	// кеширование для get_stats
{
	CACHE_STATS[8],
	CACHE_STATS2[8],
	CACHE_HITS[8],
	CACHE_NAME[32],
	CACHE_STEAMID[30],
	CACHE_SKILL,
	bool:CACHE_LAST,
	
	// 0.5.1
	CACHE_ID,
	CACHE_TIME
}

enum _:cvar_set
{
	CVAR_SQL_HOST,
	CVAR_SQL_USER,
	CVAR_SQL_PASS,
	CVAR_SQL_DB,
	CVAR_SQL_TABLE,
	CVAR_SQL_TYPE,
	CVAR_SQL_CREATE_DB,
	
	CVAR_UPDATESTYLE,
	CVAR_RANK,
	CVAR_RANKFORMULA,
	CVAR_SKILLFORMULA,
	CVAR_RANKBOTS,
	CVAR_USEFORWARDS
}

/* - ПЕРЕМЕННЫЕ - */

new player_data[MAX_PLAYERS + 1][player_data_struct]
new statsnum

new cvar[cvar_set]

new Trie:stats_cache_trie	// дерево кеша для get_stats // ключ - ранг

/* - CSSTATS CORE - */

 #pragma dynamic 32768

// wstats
new player_wstats[MAX_PLAYERS + 1][MAX_WEAPONS][STATS_END + HIT_END]

// wstats2
new player_wstats2[MAX_PLAYERS + 1][STATS2_END]

// wrstats rstats
new player_wrstats[MAX_PLAYERS + 1][MAX_WEAPONS][STATS_END + HIT_END]

// vstats
new player_vstats[MAX_PLAYERS + 1][MAX_PLAYERS + 1][STATS_END + HIT_END + MAX_NAME_LENGTH]

// astats
new player_astats[MAX_PLAYERS + 1][MAX_PLAYERS + 1][STATS_END + HIT_END + MAX_NAME_LENGTH]

new FW_Death
new FW_Damage
new FW_BPlanting
new FW_BPlanted
new FW_BExplode
new FW_BDefusing
new FW_BDefused
new FW_GThrow

new dummy_ret

// осталось монитор прихуярить

new g_planter
new g_defuser

#define WEAPON_INFO_SIZE		1 + (MAX_NAME_LENGTH * 2)

new Array:weapons_data			// массив с инфой по оружию
new Trie:log_ids_trie			// дерево для быстрого определения id оружия по лог-коду

// макрос для помощи реагистрации инфы по оружию
#define REG_INFO(%0,%1,%2)\
	weapon_info[0] = %0;\
	copy(weapon_info[1],MAX_NAME_LENGTH,%1);\
	copy(weapon_info[MAX_NAME_LENGTH ],MAX_NAME_LENGTH,%2);\
	ArrayPushArray(weapons_data,weapon_info);\
	TrieSetCell(log_ids_trie,%2,ArraySize(weapons_data) - 1)

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
	register_cvar("csstatsx_sql", VERSION, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED)
	
	/*
	* хост mysql
	*/
	cvar[CVAR_SQL_HOST] = register_cvar("csstats_sql_host","localhost",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	/*
	* пользователь mysql
	*/
	cvar[CVAR_SQL_USER] = register_cvar("csstats_sql_user","root",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	/*
	* пароль mysql
	*/
	cvar[CVAR_SQL_PASS] = register_cvar("csstats_sql_pass","",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	/*
	* название БД mysql или sqlite
	*/
	cvar[CVAR_SQL_DB] = register_cvar("csstats_sql_db","amxx",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	/*
	* название таблицы в БД
	*/
	cvar[CVAR_SQL_TABLE] = register_cvar("csstats_sql_table","csstats",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	/*
	* тип бд
	*	mysql - база данных MySQL
	*	sqlite - локальная база данных SQLite
	*/
	cvar[CVAR_SQL_TYPE] = register_cvar("csstats_sql_type","mysql")
	
	/*
	* отправка запроса на создание таблицы
	*	0 - не отправлять запрос
	*	1 - отправлять запрос при загрузке карты
	*/
	cvar[CVAR_SQL_CREATE_DB] = register_cvar("csstats_sql_create_db","1")
	
	/*
	* как вести учет игроков
	*	-1			- не учитывать
	*	0			- по нику
	*	1			- по steamid
	*	2			- по ip
	*/
	cvar[CVAR_RANK] = get_cvar_pointer("csstats_rank")
	
	if(!cvar[CVAR_RANK])
		cvar[CVAR_RANK] = register_cvar("csstats_rank","1")
		
	/*
	* запись статистики ботов
	*	0			- не записывать
	*	1			- записывать0
	*/
	cvar[CVAR_RANKBOTS] = get_cvar_pointer("csstats_rankbots")
	
	if(!cvar[CVAR_RANKBOTS])
		cvar[CVAR_RANKBOTS] = register_cvar("csstats_rankbots","1")
	
	/*
	* как обновлять статистику игрока в БД
	*	-2 			- при смерти и дисконнекте
	*	-1			- в конце раунда и дисконнекте
	*	0 			- при дисконнекте
	*	значение больше 0 	- через указанное кол-во секунд и дисконнекте
	*/
	cvar[CVAR_UPDATESTYLE] = register_cvar("csstats_sql_update","-2")
	
	/*
	* включить собственные форварды для client_death, client_damage
	*	0			- выключить
	*	1			- включить, небоходимо, если csstats_sql используется в качестве замены модуля
	*/
	cvar[CVAR_USEFORWARDS] = register_cvar("csstats_sql_forwards","0")
	
	/*
	* формула расчета ранга
	*	0			- убйиства - смерти - тк
	*	1			- убийства
	*	2			- убийства + хедшоты
	*	3			- скилл
	*	4			- время онлайн
	*/
	cvar[CVAR_RANKFORMULA] = register_cvar("csstats_sql_rankformula","0")
	
	/*
	* формула расчета скилла
	*	0			- The ELO Method (http://fastcup.net/rating.html)
	*/
	cvar[CVAR_SKILLFORMULA] = register_cvar("csstats_sql_skillformula","0")
	
	#if AMXX_VERSION_NUM < 183
	MaxClients = get_maxplayers()
	#endif
	
	register_logevent("LogEventHooK_RoundEnd", 2, "1=Round_End") 
	register_logevent("LogEventHooK_RoundStart", 2, "1=Round_Start") 
	
	register_event("CurWeapon","EventHook_CurWeapon","b","1=1")
	register_event("Damage","EventHook_Damage","b","2!0")
	register_event("BarTime","EventHook_BarTime","be")
	register_event("SendAudio","EventHook_SendAudio","a")
	register_event("TextMsg","EventHook_TextMsg","a")
}

public plugin_cfg()
{
	// форсируем выполнение exec addons/amxmodx/configs/amxx.cfg
	server_exec()
	
	// читаем квары на подключение
	new host[128],user[64],pass[64],db[64],table[30],type[10]
	get_pcvar_string(cvar[CVAR_SQL_HOST],host,charsmax(host))
	get_pcvar_string(cvar[CVAR_SQL_USER],user,charsmax(user))
	get_pcvar_string(cvar[CVAR_SQL_PASS],pass,charsmax(pass))
	get_pcvar_string(cvar[CVAR_SQL_DB],db,charsmax(db))
	get_pcvar_string(cvar[CVAR_SQL_TABLE],table,charsmax(table))
	get_pcvar_string(cvar[CVAR_SQL_TYPE],type,charsmax(type))
	
	SQL_SetAffinity(type)
	
	sql = SQL_MakeDbTuple(host,user,pass,db)
	
	// запрос на создание таблицы
	if(get_pcvar_num(cvar[CVAR_SQL_CREATE_DB]))
	{
		new query[QUERY_LENGTH],que_len
			
		new sql_data[1]
		sql_data[0] = SQL_DUMMY
		
		// запрос для mysql
		if(strcmp(type,"mysql") == 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				CREATE TABLE IF NOT EXISTS `%s` (\
					`id` int(11) NOT NULL AUTO_INCREMENT,\
					`steamid` varchar(30) NOT NULL,\
					`name` varchar(32) NOT NULL,\
					`ip` varchar(16) NOT NULL,\
					`skill` float NOT NULL DEFAULT '0.0',\
					`kills` int(11) NOT NULL DEFAULT '0',\
					`deaths` int(11) NOT NULL DEFAULT '0',\
					`hs` int(11) NOT NULL DEFAULT '0',",table)
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`tks` int(11) NOT NULL DEFAULT '0',\
					`shots` int(11) NOT NULL DEFAULT '0',\
					`hits` int(11) NOT NULL DEFAULT '0',\
					`dmg` int(11) NOT NULL DEFAULT '0',\
					`bombdef` int(11) NOT NULL DEFAULT '0',\
					`bombdefused` int(11) NOT NULL DEFAULT '0',\
					`bombplants` int(11) NOT NULL DEFAULT '0',\
					`bombexplosions` int(11) NOT NULL DEFAULT '0',\
					`h_0` int(11) NOT NULL DEFAULT '0',")
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`h_1` int(11) NOT NULL DEFAULT '0',\
					`h_2` int(11) NOT NULL DEFAULT '0',\
					`h_3` int(11) NOT NULL DEFAULT '0',\
					`h_4` int(11) NOT NULL DEFAULT '0',\
					`h_5` int(11) NOT NULL DEFAULT '0',\
					`h_6` int(11) NOT NULL DEFAULT '0',\
					`h_7` int(11) NOT NULL DEFAULT '0',\
					`connection_time` int(11) NOT NULL,\
					`first_join` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,")
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`last_join` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',\
					PRIMARY KEY (id),\
					KEY `steamid` (`steamid`(16)),\
					KEY `name` (`name`(16)),\
					KEY `ip` (`ip`)\
				) DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;")
		}
		// запрос для sqlite
		else if(strcmp(type,"sqlite") == 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				CREATE TABLE IF NOT EXISTS `%s` (\
					`id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,\
					`steamid`	TEXT NOT NULL,\
					`name`	TEXT NOT NULL,\
					`ip`	TEXT NOT NULL,\
					`skill`	REAL NOT NULL DEFAULT 0.0,\
					`kills`	INTEGER NOT NULL DEFAULT 0,\
					`deaths`	INTEGER NOT NULL DEFAULT 0,",table)
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`hs`	INTEGER NOT NULL DEFAULT 0,\
					`tks`	INTEGER NOT NULL DEFAULT 0,\
					`shots`	INTEGER NOT NULL DEFAULT 0,\
					`hits`	INTEGER NOT NULL DEFAULT 0,\
					`dmg`	INTEGER NOT NULL DEFAULT 0,\
					`bombdef`	INTEGER NOT NULL DEFAULT 0,\
					`bombdefused`	INTEGER NOT NULL DEFAULT 0,\
					`bombplants`	INTEGER NOT NULL DEFAULT 0,\
					`bombexplosions`	INTEGER NOT NULL DEFAULT 0,")
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`h_0`	INTEGER NOT NULL DEFAULT 0,\
					`h_1`	INTEGER NOT NULL DEFAULT 0,\
					`h_2`	INTEGER NOT NULL DEFAULT 0,\
					`h_3`	INTEGER NOT NULL DEFAULT 0,\
					`h_4`	INTEGER NOT NULL DEFAULT 0,\
					`h_5`	INTEGER NOT NULL DEFAULT 0,\
					`h_6`	INTEGER NOT NULL DEFAULT 0,\
					`h_7`	INTEGER NOT NULL DEFAULT 0,")
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`connection_time`	INTEGER NOT NULL DEFAULT 0,\
					`first_join`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,\
					`last_join`	TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00'\
				);")
		}
		else
		{
			set_fail_state("invalid ^"csstats_sql_type^" cvar value")
		}
		
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	// для поддержки utf8 ников требуется AMXX 1.8.3-dev-git3799 или выше
	
	#if AMXX_VERSION_NUM >= 183
	SQL_SetCharset(sql,"utf8")
	#endif
	
	// обновление статистики в БД каждые n сек
	if(get_pcvar_num(cvar[CVAR_UPDATESTYLE]) > 0)
	{
		set_task(
			float(get_pcvar_num(cvar[CVAR_UPDATESTYLE])),
			"DB_SaveAll",
			.flags = "b"
		)
	}
	
	if(get_pcvar_num(cvar[CVAR_USEFORWARDS]))
	{	FW_Death =  CreateMultiForward("client_death",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL,FP_CELL,FP_CELL)
		FW_Damage = CreateMultiForward("client_damage",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL,FP_CELL,FP_CELL,FP_CELL)
		FW_BPlanting = CreateMultiForward("bomb_planting",ET_IGNORE,FP_CELL)
		FW_BPlanted = CreateMultiForward("bomb_planted",ET_IGNORE,FP_CELL)
		FW_BExplode = CreateMultiForward("bomb_explode",ET_IGNORE,FP_CELL,FP_CELL)
		FW_BDefusing = CreateMultiForward("bomb_defusing",ET_IGNORE,FP_CELL)
		FW_BDefused = CreateMultiForward("bomb_defused",ET_IGNORE,FP_CELL)
		FW_GThrow = CreateMultiForward("grenade_throw",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
		
		register_forward(FM_SetModel,"FMHook_SetModel",true)
	}
	
	new weapon_info[WEAPON_INFO_SIZE]
	
	// 
	
	
	
	log_ids_trie = TrieCreate()
	// 	               is_meele  + название +   логнейм
	weapons_data = ArrayCreate(WEAPON_INFO_SIZE)
	
	REG_INFO(false,"","")
	REG_INFO(false,"p228","p228")
	REG_INFO(false,"","")
	REG_INFO(false,"scout","scout")
	REG_INFO(false,"hegrenade","grenade")
	REG_INFO(false,"xm1014","xm1014")
	REG_INFO(false,"c4","weapon_c4")
	REG_INFO(false,"mac10","mac10")
	REG_INFO(false,"aug","aug")
	REG_INFO(false,"sgrenade","grenade")
	REG_INFO(false,"elite","elite")
	REG_INFO(false,"fiveseven","fiveseven")
	REG_INFO(false,"ump45","ump45")
	REG_INFO(false,"sg550","sg550")
	REG_INFO(false,"galil","galil")
	REG_INFO(false,"famas","famas")
	REG_INFO(false,"usp","usp")
	REG_INFO(false,"glock18","glock18")
	REG_INFO(false,"awp","awp")
	REG_INFO(false,"mp5navy","mp5navy")
	REG_INFO(false,"m249","m249")
	REG_INFO(false,"m3","m3")
	REG_INFO(false,"m4a1","m4a1")
	REG_INFO(false,"tmp","tmp")
	REG_INFO(false,"g3sg1","g3sg1")
	REG_INFO(false,"flashbang","flashbang")
	REG_INFO(false,"deagle","deagle")
	REG_INFO(false,"sg552","sg552")
	REG_INFO(false,"ak47","ak47")
	REG_INFO(true,"knife","knife")
	REG_INFO(false,"p90","p90")
}

/*
* загружаем статистику при подключении
*/
public client_putinserver(id)
{
	arrayset(player_data[id],0,player_data_struct)
	DB_LoadPlayerData(id)
}

/*
* сохраняем статистику при дисконнекте
*/
#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
	DB_SavePlayerData(id)
	
	reset_user_allstats(id)
	reset_user_wstats(id)
}

//
// Регистрация выстрелов
//
public EventHook_CurWeapon(player)
{
	#define LASTWEAPON 	0	// id посл. оружия
	#define LASTCLIP	1	// кол-во потронов посл. оружия
	
	static event_tmp[MAX_PLAYERS + 1][LASTCLIP + 1]	// помним послед
	static weapon_id; weapon_id = read_data(2)
	static clip_ammo; clip_ammo = read_data(3)
	
	if(event_tmp[player][LASTWEAPON] != weapon_id) // оружие было изменено, запоминаем новое кол-во патронов
	{
		event_tmp[player][LASTWEAPON] = weapon_id
		event_tmp[player][LASTCLIP] = clip_ammo
	}
	else if(event_tmp[player][LASTCLIP] > clip_ammo) // кол-во патронов в магазине уменьшилось, регистрируем выстрел
	{
		Stats_SaveShot(player,weapon_id)
		event_tmp[player][LASTCLIP] = clip_ammo
	}
}

//
// Регистрация попадания
//
public EventHook_Damage(player)
{
	static damage_take;damage_take = read_data(2)
	static dmg_inflictor;dmg_inflictor = pev(player,pev_dmg_inflictor)
	
	if(pev_valid(dmg_inflictor) != 2)
	{
		return PLUGIN_CONTINUE
	}
	
	if(!(0 < dmg_inflictor <= MaxClients))
	{
		// урон с гранаты на данным момент не учитывается
		
		return PLUGIN_CONTINUE
	}
	
	static weapon_id,last_hit,attacker
	attacker = get_user_attacker(player,weapon_id,last_hit)
	
	if(0 <= last_hit < HIT_END)
	{
		Stats_SaveHit(dmg_inflictor,player,damage_take,weapon_id,last_hit)
	}
	
	if(!is_user_alive(player))
	{
		if(is_user_connected(attacker))
		{
			Stats_SaveKill(attacker,player,weapon_id,last_hit)
		}
	}
	
	return PLUGIN_CONTINUE
}

//
// Регистрация установки и дефьюза бомбы
//
public EventHook_BarTime(player)
{
	new duration = read_data(1)
	
	if(!duration)
	{
		return PLUGIN_CONTINUE
	}
	
	if(duration == 3)
	{
		g_planter = player
		g_defuser = 0
		
		if(FW_BPlanting)
			ExecuteForward(FW_BPlanting,dummy_ret,player)
	}
	else
	{
		g_defuser = player
		
		Stats_SaveBDefusing(player)
	}
	
	return PLUGIN_CONTINUE
}

public EventHook_SendAudio(player)
{
	new audio_code[16]
	read_data(2,audio_code,charsmax(audio_code))
	
	if (!player && audio_code[7] == 'B') 
	{
		if (audio_code[11]=='P' && g_planter)
		{
			Stats_SaveBPlanted(g_planter)
		}
		else if (audio_code[11] =='D' && g_defuser)
		{
			Stats_SaveBDefused(g_defuser)
		}
	}
}

public EventHook_TextMsg(player)
{
	new message[16]
	read_data(2,message,charsmax(message))
	
	if (!player)
	{
		if (message[1]=='T' && message[8] == 'B' && g_planter)
		{
			Stats_SaveBExplode(g_planter)
			
			g_planter = 0
			g_defuser = 0
		}
	}
}

//
// Форвард grenade_throw
//
public FMHook_SetModel(ent,model[])
{
	new owner = pev(ent,pev_owner)
	
	new Float:dmg_time
	pev(ent,pev_dmgtime,dmg_time)
	
	if(dmg_time <= 0.0 || !is_user_connected(owner))
	{
		return FMRES_IGNORED
	}
	
	new classname[32]
	pev(ent,pev_classname,classname,charsmax(classname))
	
	if(strcmp(classname,"grenade") != 0) // реагируем только на гранаты
	{
		return FMRES_IGNORED
	}
	
	new wId
	
	if(model[9] == 'h') // модель хеешки
	{
		wId = CSW_HEGRENADE
	}
	else if(model[9] == 'f') // модель флешки
	{
		wId = CSW_FLASHBANG
	}
	else if(model[9] == 's') // модель смока
	{
		wId = CSW_SMOKEGRENADE
	}
	
	ExecuteForward(FW_GThrow,dummy_ret,owner,ent,wId)
	
	return FMRES_IGNORED
}

//
// Учет выстрелов
//
Stats_SaveShot(player,wpn_id)
{
	player_wstats[player][0][STATS_SHOTS] ++
	player_wstats[player][wpn_id][STATS_SHOTS] ++
	
	player_wrstats[player][0][STATS_SHOTS] ++
	player_wrstats[player][wpn_id][STATS_SHOTS] ++
	
	return true
}

//
// Учет попадания
//
Stats_SaveHit(attacker,victim,damage,wpn_id,hit_place)
{
	player_wstats[attacker][0][STATS_HITS] ++
	player_wstats[attacker][0][STATS_DMG] += damage
	player_wstats[attacker][0][hit_place + STATS_END] ++
	
	player_wrstats[attacker][0][STATS_HITS] ++
	player_wrstats[attacker][0][STATS_DMG] += damage
	player_wrstats[attacker][0][hit_place + STATS_END] ++
	
	player_wstats[attacker][wpn_id][STATS_DMG] += damage
	player_wrstats[attacker][wpn_id][STATS_DMG] += damage
	player_wstats[attacker][wpn_id][STATS_HITS] ++
	player_wrstats[attacker][wpn_id][STATS_HITS] ++
	player_wstats[attacker][wpn_id][hit_place + STATS_END] ++
	player_wrstats[attacker][wpn_id][hit_place + STATS_END] ++
	
	player_vstats[attacker][victim][STATS_HITS] ++
	player_vstats[attacker][victim][STATS_DMG] += damage
	player_vstats[attacker][victim][hit_place + STATS_END] ++
	player_astats[victim][attacker][STATS_HITS] ++
	player_astats[victim][attacker][STATS_DMG] += damage
	player_astats[victim][attacker][hit_place + STATS_END] ++
	player_vstats[attacker][0][STATS_HITS] ++
	player_vstats[attacker][0][STATS_DMG] += damage
	player_vstats[attacker][0][hit_place + STATS_END] ++
	player_astats[victim][0][STATS_HITS] ++
	player_astats[victim][0][STATS_DMG] += damage
	player_astats[victim][0][hit_place + STATS_END] ++
	
	// оружие, с которого убил для astats, vstats
	new weapon_info[WEAPON_INFO_SIZE]
	ArrayGetArray(weapons_data,wpn_id,weapon_info)
	
	copy(player_vstats[attacker][victim][STATS_END + HIT_END],
		MAX_NAME_LENGTH - 1,
		weapon_info[1]
	)
	
	copy(player_astats[victim][attacker][STATS_END + HIT_END],
		MAX_NAME_LENGTH - 1,
		weapon_info[1]
	)
	
	if(FW_Damage)
		ExecuteForward(FW_Damage,dummy_ret,attacker,victim,damage,wpn_id,hit_place,is_tk(attacker,victim))
		
	return true
}

//
// Учет смертей
//
Stats_SaveKill(killer,victim,wpn_id,hit_place)
{
	if(killer == victim) // не учитываем суицид
	{
		return false
	}
	
	if(!is_tk(killer,victim))
	{
		player_wstats[killer][0][STATS_KILLS] ++
		player_wstats[killer][wpn_id][STATS_KILLS] ++
			
		player_wrstats[killer][0][STATS_KILLS] ++
		player_wrstats[killer][wpn_id][STATS_KILLS] ++
			
		player_vstats[killer][victim][STATS_KILLS] ++
		player_astats[victim][killer][STATS_KILLS] ++
		player_vstats[killer][0][STATS_KILLS] ++
		player_astats[victim][0][STATS_KILLS] ++
			
		if(hit_place == HIT_HEAD)
		{
			player_wstats[killer][0][STATS_HS] ++
			player_wstats[killer][wpn_id][STATS_HS] ++
				
			player_wrstats[killer][0][STATS_HS] ++
			player_wrstats[killer][wpn_id][STATS_HS] ++
				
			player_vstats[killer][victim][STATS_HS] ++
			player_astats[victim][killer][STATS_HS] ++
			player_vstats[killer][0][STATS_HS] ++
			player_astats[victim][0][STATS_HS] ++
		}
	}
	else
	{
		player_wstats[killer][0][STATS_TK] ++
		player_wstats[killer][wpn_id][STATS_TK] ++
		
		player_wrstats[killer][0][STATS_TK] ++
		player_wrstats[killer][wpn_id][STATS_TK] ++
		
		player_vstats[killer][victim][STATS_TK] ++
		player_astats[victim][killer][STATS_TK] ++
		player_vstats[killer][0][STATS_TK] ++
		player_astats[victim][0][STATS_TK] ++
	}
		
	player_wstats[victim][0][STATS_DEATHS] ++
	player_wrstats[victim][0][STATS_DEATHS] ++
	
	new victim_wpn_id = get_user_weapon(victim)
	
	if(victim_wpn_id)
	{
		player_wstats[victim][victim_wpn_id][STATS_DEATHS] ++
		player_wrstats[victim][victim_wpn_id][STATS_DEATHS] ++
	}
	
	if(FW_Death)
		ExecuteForward(FW_Death,dummy_ret,killer,victim,wpn_id,hit_place,is_tk(killer,victim))
		
	
	if(player_data[killer][PLAYER_LOADSTATE] == LOAD_OK && player_data[victim][PLAYER_LOADSTATE] == LOAD_OK) // скилл расчитывается только при наличии статистики из БД
	{
		switch(get_pcvar_num(cvar[CVAR_SKILLFORMULA])) // расчет скилла
		{
			case 0: // The ELO Method (http://fastcup.net/rating.html)
			{
				new Float:delta = 1.0 / (1.0 + floatpower(10.0,(player_data[killer][PLAYER_SKILL] - player_data[victim][PLAYER_SKILL]) / 100.0))
				new Float:koeff = 0.0
				
				if(player_data[killer][PLAYER_STATS][STATS_KILLS] < 100)
				{
					koeff = 2.0
				}
				else
				{
					koeff = 1.5
				}
				
				player_data[killer][PLAYER_SKILL] += (koeff * delta)
				player_data[victim][PLAYER_SKILL] -= (koeff * delta)
			}
		}
	}
	
	
	// обновляем статистику в БД при смерти
	if(get_pcvar_num(cvar[CVAR_UPDATESTYLE]) == -2)
	{
		DB_SavePlayerData(victim)
	}
	
	
	
	return true
}

//
// Учет статистики по бомба
//
Stats_SaveBDefusing(id)
{
	player_wstats2[id][STATS2_DEFAT] ++
	
	if(FW_BDefusing)
		ExecuteForward(FW_BDefusing,dummy_ret,id)
		
	return true
}

Stats_SaveBDefused(id)
{
	player_wstats2[id][STATS2_DEFOK] ++
	
	if(FW_BDefused)
		ExecuteForward(FW_BDefused,dummy_ret,id)
		
	return true
}

Stats_SaveBPlanted(id)
{
	player_wstats2[id][STATS2_PLAAT] ++
	
	if(FW_BPlanted)
		ExecuteForward(FW_BPlanted,dummy_ret,id)
		
	return true
}

Stats_SaveBExplode(id)
{
	player_wstats2[id][STATS2_PLAOK] ++
	
	if(FW_BExplode)
		ExecuteForward(FW_BExplode,dummy_ret,id,g_defuser)
		
	return true
}

/*
* изменение ника игрока
*/
public client_infochanged(id)
{
	new cur_name[MAX_NAME_LENGTH],new_name[MAX_NAME_LENGTH]
	get_user_name(id,cur_name,charsmax(cur_name))
	get_user_info(id,"name",new_name,charsmax(new_name))
	
	if(strcmp(cur_name,new_name) != 0)
	{
		copy(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]),new_name)
		mysql_escape_string(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
		
		if(get_pcvar_num(cvar[CVAR_RANK]) == 0)
		{
			DB_SavePlayerData(id,true)
		}
	}
}

/*
* сбрасываем astats,vstats статистику в начале раунда
*/
public LogEventHooK_RoundStart()
{
	// сбрасываем wrstats, vstats, astats в начале раунда
	new players[32],pnum
	get_players(players,pnum)
	
	for(new i,player ; i < pnum ; i++)
	{
		player = players[i]
		reset_user_wstats(player)
	}

	
}

//
// сохраняем статистику в конце раунда
//
public LogEventHooK_RoundEnd()
{
	if(get_pcvar_num(cvar[CVAR_UPDATESTYLE]) == -1)
	{
		DB_SaveAll()
	}
}

/*
* загрузка статистики игрока из базы данных
*/
DB_LoadPlayerData(id)
{
	// пропускаем HLTV
	if(is_user_hltv(id))
	{
		return false
	}
	
	// пропускаем ботов, если отключена запись статистики ботов
	if(!get_pcvar_num(cvar[CVAR_RANKBOTS]) && is_user_bot(id))
	{
		return false
	}
	
	get_user_info(id,"name",player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	mysql_escape_string(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	
	get_user_authid(id,player_data[id][PLAYER_STEAMID],charsmax(player_data[][PLAYER_STEAMID]))
	get_user_ip(id,player_data[id][PLAYER_IP],charsmax(player_data[][PLAYER_IP]),true)
	
	// формируем SQL запрос
	new query[QUERY_LENGTH],len,sql_data[2],tbl_name[32]
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	
	sql_data[0] = SQL_LOAD
	sql_data[1] = id
	player_data[id][PLAYER_LOADSTATE] = LOAD_WAIT
	
	len += formatex(query[len],charsmax(query)-len,"SELECT *,(")
	len += DB_QueryBuildScore(query[len],charsmax(query)-len)
	len += formatex(query[len],charsmax(query)-len,"),(")
	len += DB_QueryBuildStatsnum(query[len],charsmax(query)-len)
	len += formatex(query[len],charsmax(query)-len,")")
	
	switch(get_pcvar_num(cvar[CVAR_RANK]))
	{
		case 0: // статистика по нику
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` AS `a` WHERE `name` = '%s'",
				tbl_name,player_data[id][PLAYER_NAME]
			)
		}
		case 1: // статистика по steamid
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` AS `a` WHERE `steamid` = '%s'",
				tbl_name,player_data[id][PLAYER_STEAMID]
			)
		}
		case 2: // статистика по ip
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` AS `a` WHERE `ip` = '%s'",
				tbl_name,player_data[id][PLAYER_IP]
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
DB_SavePlayerData(id,bool:reload = false)
{
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // игрок не загрузился
	{
		return false
	}
	
	new query[QUERY_LENGTH],i
	new tbl_name[32]
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	
	new sql_data[2 + 					// 2
		sizeof player_data[][PLAYER_STATS] + // 8
		sizeof player_data[][PLAYER_HITS] + // 8
		sizeof player_data[][PLAYER_STATS2] // 4
	]
	
	sql_data[1] = id
	
	new stats[8],stats2[4],hits[8]
	get_user_wstats(id,0,stats,hits)
	get_user_stats2(id,stats2)
	
	/*if(!stats[STATS_DEATHS] && !stats[STATS_SHOTS])
	{
		return false
	}*/
	
	switch(player_data[id][PLAYER_LOADSTATE])
	{
		case LOAD_OK: // обновление данных
		{
			if(reload)
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_UPDATE
			}
			
			sql_data[0] = SQL_UPDATE
			
			new diffstats[sizeof player_data[][PLAYER_STATS]]
			new diffstats2[sizeof player_data[][PLAYER_STATS2]]
			new diffhits[sizeof player_data[][PLAYER_HITS]]
			new len,to_save
			
			len += formatex(query[len],charsmax(query) - len,"UPDATE `%s` SET",tbl_name)
			
			// обновляем по разнице с предедущими данными
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				diffstats[i] = stats[i] - player_data[id][PLAYER_STATSLAST][i] // узнаем разницу
				player_data[id][PLAYER_STATSLAST][i] = stats[i]
				
				if(diffstats[i])
				{
					len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + %d",
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
				
				if(diffstats2[i])
				{
					len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + %d",
						!to_save ? " " : ",",
						row_names[i + ROW_BOMBDEF],
						row_names[i + ROW_BOMBDEF],
						diffstats2[i]
					)
					
					to_save ++
				}
			}
			
			
			// 
			player_data[id][PLAYER_ONLINE] += get_user_time(id) - player_data[id][PLAYER_ONLINEDIFF]
			player_data[id][PLAYER_ONLINEDIFF] = get_user_time(id)
			
			new diffonline = player_data[id][PLAYER_ONLINE]- player_data[id][PLAYER_ONLINELAST]
			player_data[id][PLAYER_ONLINELAST] = player_data[id][PLAYER_ONLINE]
			
			if(diffonline)
			{
				len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + %d",
					!to_save ? " " : ",",
					row_names[ROW_ONLINETIME],
					row_names[ROW_ONLINETIME],
					diffonline
				)
					
				to_save ++
			}
			
			new Float:diffskill = player_data[id][PLAYER_SKILL] - player_data[id][PLAYER_SKILLLAST]
			player_data[id][PLAYER_SKILLLAST] = _:player_data[id][PLAYER_SKILL]
			
			if(diffskill != 0.0)
			{
				len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + %.2f",
					!to_save ? " " : ",",
					row_names[ROW_SKILL],
					row_names[ROW_SKILL],
					diffskill
				)
					
				to_save ++
			}
			
			if(stats[STATS_HITS])
			{
				// запрос на сохранение мест попаданий
				for(i = 0; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					diffhits[i] = hits[i] - player_data[id][PLAYER_HITSLAST][i] // узнаем разницу
					player_data[id][PLAYER_HITSLAST][i] = hits[i]
					
					if(diffhits[i])
					{
						len += formatex(query[len],charsmax(query) - len,",`%s` = `%s` + '%d'",
							row_names[i + ROW_H0],row_names[i + ROW_H0],
							diffhits[i]
						)
					}
				}
			}
			
			// обновляем время последнего подключения, ник, ип и steamid
			len += formatex(query[len],charsmax(query) - len,",\
				`last_join` = CURRENT_TIMESTAMP,\
				`%s` = '%s',\
				`%s` = '%s'",
				
				
				row_names[ROW_STEAMID],player_data[id][PLAYER_STEAMID],
				row_names[ROW_IP],player_data[id][PLAYER_IP],
				
				row_names[ROW_ID],player_data[id][PLAYER_ID]
			)
			
			if(!reload) // не обновляем ник при его смене
			{
				len += formatex(query[len],charsmax(query) - len,",`%s` = '%s'",
					row_names[ROW_NAME],player_data[id][PLAYER_NAME]
				)
			}
			
			len += formatex(query[len],charsmax(query) - len,"WHERE `%s` = '%d'",row_names[ROW_ID],player_data[id][PLAYER_ID])
			
			if(!to_save) // нечего сохранять
			{
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
				}
				
				return false
			}
			
			// stats
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				sql_data[i + 2] = diffstats[i]
			}
			
			// hits
			for(i = 0 ; i < sizeof player_data[][PLAYER_HITS] ; i++)
			{
				sql_data[2 + i + sizeof player_data[][PLAYER_STATS]] = diffhits[i]
			}
			
			// stats2
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
			{
				sql_data[2 + i + sizeof player_data[][PLAYER_STATS] + sizeof player_data[][PLAYER_HITS]] = diffstats[i]
			}
			
			
		}
		case LOAD_NEW: // запрос на добавление новой записи
		{
			sql_data[0] = SQL_INSERT
			
			new Float:skill
			
			switch(get_pcvar_num(cvar[CVAR_SKILLFORMULA]))
			{
				case 0: skill = 100.0
			}
			
			formatex(query,charsmax(query),"INSERT INTO `%s` \
							(`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`,`%s`)\
							VALUES('%s','%s','%s','%.2f','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d','%d',CURRENT_TIMESTAMP)\
							",tbl_name,
							
					row_names[ROW_STEAMID],
					row_names[ROW_NAME],
					row_names[ROW_IP],
					row_names[ROW_SKILL],
					row_names[ROW_KILLS],
					row_names[ROW_DEATHS],
					row_names[ROW_HS],
					row_names[ROW_TKS],
					row_names[ROW_SHOTS],
					row_names[ROW_HITS],
					row_names[ROW_DMG],
					row_names[ROW_BOMBDEF],
					row_names[ROW_BOMBDEFUSED],
					row_names[ROW_BOMBPLANTS],
					row_names[ROW_BOMBEXPLOSIONS],
					row_names[ROW_LASTJOIN],
					
					player_data[id][PLAYER_STEAMID],
					player_data[id][PLAYER_NAME],
					player_data[id][PLAYER_IP],
					
					skill,
					
					stats[STATS_KILLS] - player_data[id][PLAYER_STATSLAST][STATS_KILLS],
					stats[STATS_DEATHS] - player_data[id][PLAYER_STATSLAST][STATS_DEATHS],
					stats[STATS_HS] - player_data[id][PLAYER_STATSLAST][STATS_HS],
					stats[STATS_TK] - player_data[id][PLAYER_STATSLAST][STATS_TK],
					stats[STATS_SHOTS] - player_data[id][PLAYER_STATSLAST][STATS_SHOTS],
					stats[STATS_HITS] - player_data[id][PLAYER_STATSLAST][STATS_HITS],
					stats[STATS_DMG] - player_data[id][PLAYER_STATSLAST][STATS_DMG],
					
					stats2[STATS2_DEFAT] - player_data[id][PLAYER_STATS2LAST][STATS2_DEFAT],
					stats2[STATS2_DEFOK] - player_data[id][PLAYER_STATS2LAST][STATS2_DEFOK],
					stats2[STATS2_PLAAT] - player_data[id][PLAYER_STATS2LAST][STATS2_PLAAT],
					stats2[STATS2_PLAOK] - player_data[id][PLAYER_STATS2LAST][STATS2_PLAOK]
			)
			
			// stats
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				sql_data[i + 2] = stats[i]
			}
			
			// hits
			for(i = 0 ; i < sizeof player_data[][PLAYER_HITS] ; i++)
			{
				sql_data[2 + i + sizeof player_data[][PLAYER_STATS]] = hits[i]
			}
			
			// stats2
			for(i = 0 ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
			{
				sql_data[2 + i + sizeof player_data[][PLAYER_STATS] + sizeof player_data[][PLAYER_HITS]] = stats2[i]
			}
			
			if(reload)
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_UPDATE
			}
			else
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_NEWWAIT
			}
		}
	}
	
	if(query[0])
	{
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	return true
}

#define falos false

/*
* получение новых позиции в топе игроков
*/
public DB_GetPlayerRanks()
{
	new players[32],pnum
	get_players(players,pnum)
	
	new query[QUERY_LENGTH],len,tbl_name[32]
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	
	// строим SQL запрос
	len += formatex(query[len],charsmax(query) - len,"SELECT `id`,(")
	len += DB_QueryBuildScore(query[len],charsmax(query) - len)
	len += formatex(query[len],charsmax(query) - len,") FROM `%s` as `a` WHERE `id` IN(",tbl_name)
	
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
* сохранение статистики всех игроков
*/
public DB_SaveAll()
{
	new players[32],pnum
	get_players(players,pnum)
	
	for(new i ; i < pnum ; i++)
	{
		DB_SavePlayerData(players[i])
	}
}


/*
* запрос на просчет ранка
*/
DB_QueryBuildScore(sql_que[] = "",sql_que_len = 0,bool:only_rows = falos,overide_order = 0)
{
	// стандартная формула csstats (убийства-смерти-tk)
	
	if(only_rows)
	{
		switch(overide_order ? overide_order : get_pcvar_num(cvar[CVAR_RANKFORMULA]))
		{
			case 1: return formatex(sql_que,sql_que_len,"`kills`")
			case 2: return formatex(sql_que,sql_que_len,"`kills`+`hs`")
			case 3: return formatex(sql_que,sql_que_len,"`skill`")
			case 4: return formatex(sql_que,sql_que_len,"`connection_time`")
			default: return formatex(sql_que,sql_que_len,"`kills`-`deaths`-`tks`")
		}
	}
	else
	{
		new tbl_name[32]
		get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
		
		switch(overide_order ? overide_order : get_pcvar_num(cvar[CVAR_RANKFORMULA]))
		{
			case 1: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (kills)>=(a.kills)",tbl_name)
			case 2: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (kills+hs)>=(a.kills+a.hs)",tbl_name)
			case 3: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (skill)>=(a.skill)",tbl_name)
			case 4: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (connection_time)>=(a.connection_time)")
			default: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (kills-deaths-tks)>=(a.kills-a.deaths-a.tks)",tbl_name)
		}
	
	
	}
	
	return 0
}

/*
* запрос на общее кол-во записей в БД
*/ 
DB_QueryBuildStatsnum(sql_que[] = "",sql_que_len = 0)
{
	new tbl_name[32]
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	
	return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE 1",tbl_name)
}

/*
* запрос на выборку статистики по позиции
*	index - начальная позиция
*	index_count - кол-во выбираемых записей
*/
DB_QueryBuildGetstats(query[],query_max,len = 0,index,index_count = 2,overide_order = 0)
{
	new tbl_name[32]
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	
	// строим запрос
	len += formatex(query[len],query_max-len,"SELECT *")
	
	// запрос на ранк
	len += formatex(query[len],query_max-len,",(")
	len += DB_QueryBuildScore(query[len],query_max-len,true,overide_order)
	len += formatex(query[len],query_max-len,") as `rank`")
	
	// запрашиваем следующию запись
	// если есть, то возврашаем нативом index + 1
	len += formatex(query[len],query_max-len," FROM `%s` as `a` ORDER BY `rank` DESC LIMIT %d,%d",
		tbl_name,index,index_count
	)
	
	return len
}

/*
* чтение результата get_stats запроса
*/
DB_ReadGetStats(Handle:sqlQue,name[] = "",name_len = 0,authid[] = "",authid_len = 0,stats[8] = 0,hits[8] = 0,stats2[4] = 0,&stats_count = 0,index)
{
	stats_count = SQL_NumResults(sqlQue)
	
	switch(get_pcvar_num(cvar[CVAR_RANK]))
	{
		case 0: SQL_ReadResult(sqlQue,ROW_NAME,authid,authid_len)
		case 1: SQL_ReadResult(sqlQue,ROW_STEAMID,authid,authid_len)
		case 2: SQL_ReadResult(sqlQue,ROW_IP,authid,authid_len)
	}
	
	SQL_ReadResult(sqlQue,ROW_NAME,name,name_len)
	
	new i
	
	for(i = ROW_KILLS ; i <= ROW_H7 ; i++)
	{
		switch(i)
		{
			case ROW_KILLS..ROW_DMG:
			{
				stats[i - ROW_KILLS] = SQL_ReadResult(sqlQue,i)
			}
			case ROW_BOMBDEF..ROW_BOMBEXPLOSIONS:
			{
				stats2[i - ROW_BOMBDEF] = SQL_ReadResult(sqlQue,i)
			}
			case ROW_H0..ROW_H7:
			{
				hits[i - ROW_H0] = SQL_ReadResult(sqlQue,i)
			}
		}
		
	}
	
	// кеширование данных
	new stats_cache[stats_cache_struct]
	
	if(!stats_cache_trie)
	{
		stats_cache_trie = TrieCreate()
	}
	
	copy(stats_cache[CACHE_NAME],charsmax(stats_cache[CACHE_NAME]),name)
	copy(stats_cache[CACHE_STEAMID],charsmax(stats_cache[CACHE_STEAMID]),authid)
	
	for(i = 0; i < sizeof player_data[][PLAYER_STATS] ; i++)
	{
		stats_cache[CACHE_STATS][i] = stats[i]
	}
	
	for(i = 0; i < sizeof player_data[][PLAYER_STATS2] ; i++)
	{
		stats_cache[CACHE_STATS2][i] = stats2[i]
	}
	
	stats_cache[CACHE_LAST] = SQL_NumResults(sqlQue) <= 1
	SQL_ReadResult(sqlQue,ROW_SKILL,stats_cache[CACHE_SKILL])
	stats_cache[CACHE_ID] = SQL_ReadResult(sqlQue,ROW_ID)
	stats_cache[CACHE_TIME] = SQL_ReadResult(sqlQue,ROW_ONLINETIME)
	
	new index_str[10]
	num_to_str(index,index_str,charsmax(index_str))
	
	TrieSetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct)
	// кешироавние данных
	
	SQL_NextRow(sqlQue)
	
	return SQL_MoreResults(sqlQue)
}

/*
* обновляем кеш для get_stats
*/
Cache_Stats_Update()
{
	if(!stats_cache_trie)
		return false
	
	TrieClear(stats_cache_trie)
	
	return true
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
			log_amx("SQL connection failed")
			log_amx("[ %d ] %s",errNum,err)
			
			return PLUGIN_HANDLED
		}
		case TQUERY_QUERY_FAILED:  // ошибка SQL запроса
		{
			new lastQue[QUERY_LENGTH]
			SQL_GetQueryString(sqlQue,lastQue,charsmax(lastQue)) // узнаем последний SQL запрос
			
			log_amx("SQL query failed")
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
				
				// время онлайн
				player_data[id][PLAYER_ONLINE] = player_data[id][PLAYER_ONLINELAST] = SQL_ReadResult(sqlQue,ROW_ONLINETIME)
				
				// скилл
				SQL_ReadResult(sqlQue,ROW_SKILL,player_data[id][PLAYER_SKILL])
				player_data[id][PLAYER_SKILLLAST] = _:player_data[id][PLAYER_SKILL]
				
				// доп. запросы
				player_data[id][PLAYER_RANK] = SQL_ReadResult(sqlQue,row_ids)	// ранк игрока
				statsnum = SQL_ReadResult(sqlQue,row_ids + 1)			// общее кол-во игроков в БД
				
				// статистика попаданий
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] = SQL_ReadResult(sqlQue,ROW_H0 + i)
				}
				
			}
			else // помечаем как нового игрока
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_NEW
				
				DB_SavePlayerData(id) // добавляем запись в базу данных
			}
		}
		case SQL_INSERT:	// запись новых данных
		{
			new id = data[1]
			
			if(is_user_connected(id))
			{
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
					
					return PLUGIN_HANDLED
				}
				
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
					player_data[id][PLAYER_HITS][i] = data[2 + i + sizeof player_data[][PLAYER_STATS]]
				}
				
				// пииздец
				for(new i ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
				{
					player_data[id][PLAYER_STATS2][i] = data[
						2 + i + sizeof player_data[][PLAYER_STATS] + sizeof player_data[][PLAYER_HITS]
					]
				}
				
				// дефолтное значение для скилла
				switch(get_pcvar_num(cvar[CVAR_SKILLFORMULA]))
				{
					case 0: player_data[id][PLAYER_SKILL] = _:player_data[id][PLAYER_SKILLLAST] = _:100.0
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
					player_data[id][PLAYER_STATS][i] += data[2 + i]
				}
				
				// сравниваем статистику
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] += data[2 + i + sizeof player_data[][PLAYER_STATS]]
				}
				
				// пииздец
				for(new i ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
				{
					player_data[id][PLAYER_STATS2][i] += data[
						2 + i + sizeof player_data[][PLAYER_STATS] + sizeof player_data[][PLAYER_HITS]
					]
				}
				
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
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
				
				for(new i ; i < MAX_PLAYERS ; i++)
				{
					if(player_data[i][PLAYER_ID] == pK)	// задаем ранк по первичному ключу
					{
						player_data[i][PLAYER_RANK] = rank
					}
				}
				
				SQL_NextRow(sqlQue)
			}
			
			Cache_Stats_Update()
		}
		case SQL_GETSTATS: // потоковый get_stats
		{
			new id = data[1]
			
			if(id && !is_user_connected(id))
			{
				return PLUGIN_HANDLED
			}
			
			new index = data[5]
			new name[32],authid[30]
			
			// кешируем ответ
			while(DB_ReadGetStats(sqlQue,name,charsmax(name),authid,charsmax(authid),.index = index ++))
			{
			}
			
			// вызываем хандлер другого плагина
			if(callfunc_begin_i(data[3],data[2]))
			{
				callfunc_push_int(id)
				callfunc_push_int(data[4])
				callfunc_end()
			}
		}
	}

	return PLUGIN_HANDLED
}

/*
*
* API
*
*/

#define CHECK_PLAYER(%1) \
	if (%1 < 1 || %1 > MaxClients) { \
		log_error(AMX_ERR_NATIVE, "Player out of range (%d)", %1); \
		return 0; \
	} else { \
		if (!is_user_connected(%1) || pev_valid(%1) != 2) { \
			log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
			return 0; \
		} \
	}
	
#define CHECK_PLAYERRANGE(%1) \
	if(%1 < 0 || %1 > MaxClients) {\
		log_error(AMX_ERR_NATIVE,"Player out of range (%d)",%1);\
		return 0;\
	}
	
#define CHECK_WEAPON(%1) \
	if(%1 < 0 || %1 > ArraySize(weapons_data)){\
		log_error(AMX_ERR_NATIVE,"Invalid weapon id %d",%1);\
		return 0;\
	}
	
/*
native get_skill(index,&Float:skill)
native get_user_skill(player,&Float:skill)
native get_user_gametime(id)
native get_stats_gametime(index,&game_time)
native get_user_stats_id(id)
native get_stats_id(index,&stats_id)
*/

public plugin_natives()
{
	// default csstats
	register_library("xstats")
	
	register_native("get_user_wstats","native_get_user_wstats")
	register_native("get_user_wrstats","native_get_user_wrstats")
	register_native("get_user_stats","native_get_user_stats")
	register_native("get_user_rstats","native_get_user_rstats")
	register_native("get_user_vstats","native_get_user_vstats")
	register_native("get_user_astats","native_get_user_astats")
	register_native("reset_user_wstats","native_reset_user_wstats")
	register_native("get_stats","native_get_stats")
	register_native("get_statsnum","native_get_statsnum")
	register_native("get_user_stats2","native_get_user_stats2")
	register_native("get_stats2","native_get_stats2")
	
	register_native("xmod_is_melee_wpn","native_xmod_is_melee_wpn")
	register_native("xmod_get_wpnname","native_xmod_get_wpnname")
	register_native("xmod_get_wpnlogname","native_xmod_get_wpnlogname")
	register_native("xmod_get_maxweapons","native_xmod_get_maxweapons")
	register_native("xmod_get_stats_size","native_get_statsnum")
	register_native("get_map_objectives","native_get_map_objectives")
	
	register_native("custom_weapon_add","native_custom_weapon_add")
	register_native("custom_weapon_dmg","native_custom_weapon_dmg")
	register_native("custom_weapon_shot","native_custom_weapon_shot")
	
	register_library("csstatsx_sql")
	
	// csstats mysql
	register_native("get_statsnum_sql","native_get_statsnum")
	register_native("get_user_stats_sql","native_get_user_stats")
	register_native("get_stats_sql","native_get_stats")
	register_native("get_stats_sql_thread","native_get_stats_thread")
	register_native("get_user_skill","native_get_user_skill")
	register_native("get_skill","native_get_skill")
	
	// 0.5.1
	register_native("get_user_gametime","native_get_user_gametime")
	register_native("get_stats_gametime","native_get_stats_gametime")
	register_native("get_user_stats_id","native_get_user_stats_id")
	register_native("get_stats_id","native_get_stats_id")
	register_native("update_stats_cache","native_update_stats_cache")
}

public native_update_stats_cache()
{
	return Cache_Stats_Update()
}

/*
* Функция возвращает онлайн время игрока
*
* native get_user_gametime(id)
*/
public native_get_user_gametime(plugin_id,params)
{
	new id = get_param(1)
	CHECK_PLAYER(id)
	
	if(player_data[id][PLAYER_LOADSTATE] == LOAD_NO)
	{
		return -1
	}
	
	return player_data[id][PLAYER_ONLINE]
}

/*
* Получение времени по позиции
*
* native get_stats_gametime(index,&game_time)
*/
public native_get_stats_gametime(plugin_id,params)
{
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_param_byref(2,stats_cache[CACHE_TIME])
		return !stats_cache[CACHE_LAST] ? index + 1 : 0
	}
	// кеширование
	
	return 0
}


/*
* Функция возрващает ID игрока в БД
*
* native get_user_stats_id(id)
*/
public native_get_user_stats_id(plugin_id,params)
{
	new id = get_param(1)
	CHECK_PLAYER(id)
	
	return player_data[id][PLAYER_ID]
}

/*
* Получение ID по позиции
*
* native get_stats_id(index,&db_id)
*/
public native_get_stats_id(plugin_id,params)
{
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_param_byref(2,stats_cache[CACHE_ID])
		return !stats_cache[CACHE_LAST] ? index + 1 : 0
	}
	// кеширование
	
	return 0
}

/*
* Функция возрващает скилл игрока
*
* native get_user_skill(player,&Float:skill)
*/
public native_get_user_skill(plugin_id,params)
{
	new id = get_param(1)
	CHECK_PLAYER(id)
	
	set_float_byref(2,player_data[id][PLAYER_SKILL])
	
	return true
}


/*
* Получение скилла по позиции
*
* native get_skill(index,&Float:skill)
*/
public native_get_skill(plugin_id,params)
{
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_float_byref(2,Float:stats_cache[CACHE_SKILL])
		return !stats_cache[CACHE_LAST] ? index + 1 : 0
	}
	// кеширование
	
	return 0
}

/*
* Добавление кастомного оружия для статистики
*
* native custom_weapon_add(const wpnname[], melee = 0, const logname[] = "")
*/
public native_custom_weapon_add(plugin_id,params)
{
	if(ArraySize(weapons_data) >= MAX_WEAPONS)
	{
		return 0
	}
	
	new weapon_name[MAX_NAME_LENGTH],weapon_log[MAX_NAME_LENGTH],is_melee
	get_string(1,weapon_name,charsmax(weapon_name))
	
	if(params >= 2) // задан флаг is_melee
		is_melee = get_param(2)
		
	if(params == 3) // указан лог код
	{
		get_string(3,weapon_log,charsmax(weapon_log))
	}
	else // копируем название оружия для лог кода
	{
		copy(weapon_log,charsmax(weapon_log),weapon_name)
	}
	
	// регистриурем
	new weapon_info[WEAPON_INFO_SIZE]
	REG_INFO(is_melee,weapon_name,weapon_info)
	
	return ArraySize(weapons_data) - 1
}

/*
* Учет урона кастомного оружия
*
* native custom_weapon_dmg(weapon, att, vic, damage, hitplace = 0)
*/
public native_custom_weapon_dmg(plugin_id,params)
{
	new weapon_id = get_param(1)
	
	CHECK_WEAPON(weapon_id)
	
	new att = get_param(2)
	
	CHECK_PLAYER(att)
	
	new vic = get_param(3)
	
	CHECK_PLAYER(vic)
	
	new dmg = get_param(4)
	
	if(dmg < 1)
	{
		log_error(AMX_ERR_NATIVE,"Invalid damage %d", dmg)
		
		return 0
	}
	
	new hit_place = get_param(5)
	
	return Stats_SaveHit(att,vic,dmg,weapon_id,hit_place)
}

/*
* Регистрация выстрела кастомного оружия
*
* native custom_weapon_shot(weapon, index)
*/
public native_custom_weapon_shot(plugin_id,params)
{
	new weapon_id = get_param(1)
	
	CHECK_WEAPON(weapon_id)
	
	new id = get_param(2)
	
	CHECK_PLAYER(id)
	
	return Stats_SaveShot(id,weapon_id)
}

/*
* Возвращает true, если оружие рукопашного боя
*
* native xmod_is_melee_wpn(wpnindex)
*/
public native_xmod_is_melee_wpn(plugin_id,params)
{
	new wpn_id = get_param(1)
	
	CHECK_WEAPON(wpn_id)
	
	new weapon_info[WEAPON_INFO_SIZE]
	ArrayGetArray(weapons_data,wpn_id,weapon_info)
	
	return weapon_info[0]
}

/*
* Получение полного названия оружия
*
* native xmod_get_wpnname(wpnindex, name[], len)
*/
public native_xmod_get_wpnname(plugin_id,params)
{
	new wpn_id = get_param(1)
	
	CHECK_WEAPON(wpn_id)
	
	new weapon_info[WEAPON_INFO_SIZE]
	ArrayGetArray(weapons_data,wpn_id,weapon_info)
	
	new weapon_name[MAX_NAME_LENGTH]
	copy(weapon_name,charsmax(weapon_name),weapon_info[1])
	
	set_string(2,weapon_name,get_param(3))
	
	return strlen(weapon_name)
}

/*
* Получение лог кода для оружия
*
* native xmod_get_wpnlogname(wpnindex, name[], len)
*/
public native_xmod_get_wpnlogname(plugin_id,params)
{
	new wpn_id = get_param(1)
	
	CHECK_WEAPON(wpn_id)
	
	new weapon_info[WEAPON_INFO_SIZE]
	ArrayGetArray(weapons_data,wpn_id,weapon_info)
	
	new weapon_name[MAX_NAME_LENGTH]
	copy(weapon_name,charsmax(weapon_name),weapon_info[MAX_NAME_LENGTH])
	
	set_string(2,weapon_name,get_param(3))
	
	return strlen(weapon_name)
}

/*
* Возврашение общего количества оружия для статистики
*
* native xmod_get_maxweapons()
*/
public native_xmod_get_maxweapons(plugin_id,params)
{
	return ArraySize(weapons_data)
}

public native_get_map_objectives(plugin_id,params)
{
	return false
}

/*
* Статистика за текущую сессию
*
* native get_user_wstats(index, wpnindex, stats[8], bodyhits[8])
*/
public native_get_user_wstats(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	new wpn_id = get_param(2)
	
	CHECK_WEAPON(wpn_id)
	
	new stats[8],bh[8]
	get_user_wstats(id,wpn_id,stats,bh)
	
	set_array(3,stats,STATS_END)
	set_array(4,bh,HIT_END)
	
	return (stats[STATS_DEATHS] || stats[STATS_SHOTS])
}

/*
* Статистика за текущий раунд
*
* native get_user_wrstats(index, wpnindex, stats[8], bodyhits[8])
*/
public native_get_user_wrstats(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	new wpn_id = get_param(2)
	
	CHECK_WEAPON(wpn_id)
	
	if(wpn_id != 0 && !(0 < wpn_id < MAX_WEAPONS))
	{
		log_error(AMX_ERR_NATIVE,"Weapon index out of bounds (%d)",id)
		
		return false
	}
	
	new stats[8],bh[8]
	get_user_wrstats(id,wpn_id,stats,bh)
	
	set_array(3,stats,STATS_END)
	set_array(4,bh,HIT_END)
	
	return (stats[STATS_DEATHS] || stats[STATS_SHOTS])
}


/*
* Получение статистики игрока
*
* native get_user_stats(index, stats[8], bodyhits[8])
*/
public native_get_user_stats(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // данные отсутствуют
	{
		return 0
	}
	
	set_array(2,player_data[id][PLAYER_STATS],8)
	set_array(3,player_data[id][PLAYER_HITS],8)
	
	return player_data[id][PLAYER_RANK]
}

/*
* Статистика за текущий раунд
*
* native get_user_rstats(index, stats[8], bodyhits[8])
*/
public native_get_user_rstats(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	new stats[8],bh[8]
	get_user_rstats(id,stats,bh)
	
	set_array(2,stats,STATS_END)
	set_array(3,bh,HIT_END)
	
	return (stats[STATS_DEATHS] || stats[STATS_SHOTS])
}
/*
* Статистика по жертвам
*
* native get_user_vstats(index, victim, stats[8], bodyhits[8], wpnname[] = "", len = 0);
*/
public native_get_user_vstats(plugin_id,params)
{
	if(params != 6)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 6, passed %d",params)
		
		return false
	}
	
	new id = get_param(1)
	new victim = get_param(2)
	
	CHECK_PLAYER(id)
	CHECK_PLAYERRANGE(victim)
	
	new stats[STATS_END],hits[HIT_END],wname[MAX_NAME_LENGTH]
	unpack_vstats(id,victim,stats,hits,wname,charsmax(wname))
	
	set_array(3,stats,STATS_END)
	set_array(4,hits,HIT_END)
	set_string(5,wname,get_param(6))
	
	return (stats[STATS_KILLS] || stats[STATS_HITS])
}


unpack_vstats(killer,victim,stats[STATS_END],hits[HIT_END],vname[],vname_len)
{
	new i,stats_i
	
	for(i = 0; i < STATS_END ; i++,stats_i++)
	{
		stats[i]= player_vstats[killer][victim][stats_i]
	}
	
	for(i = 0; i < HIT_END ; i++,stats_i++)
	{
		hits[i]= player_vstats[killer][victim][stats_i]
	}
	
	copy(vname,vname_len,player_vstats[killer][victim][stats_i])
}

unpack_astats(attacker,victim,stats[STATS_END],hits[HIT_END],vname[],vname_len)
{
	new i,stats_i
	
	for(i = 0; i < STATS_END ; i++,stats_i++)
	{
		stats[i]= player_astats[victim][attacker][stats_i]
	}
	
	for(i = 0; i < HIT_END ; i++,stats_i++)
	{
		hits[i]= player_astats[victim][attacker][stats_i]
	}
	
	copy(vname,vname_len,player_astats[victim][attacker][stats_i])
}

public plugin_precache()
{
	new amxx_version[10]
	get_amxx_verstring(amxx_version,charsmax(amxx_version))
	    
	if(contain(amxx_version,"1.8.1") != -1)
	{
		log_amx("idite nahooy")
		
		server_cmd("quit")
		server_exec()
	}
}

/*
* Статистика по врагам
*
* native get_user_astats(index, victim, stats[8], bodyhits[8], wpnname[] = "", len = 0);
*/
public native_get_user_astats(plugin_id,params)
{
	if(params != 6)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 6, passed %d",params)
		
		return false
	}
	
	new id = get_param(1)
	new attacker = get_param(2)
	
	CHECK_PLAYER(id)
	CHECK_PLAYERRANGE(attacker)
	
	new stats[STATS_END],hits[HIT_END],wname[MAX_NAME_LENGTH]
	unpack_astats(attacker,id,stats,hits,wname,charsmax(wname))
	
	set_array(3,stats,STATS_END)
	set_array(4,hits,HIT_END)
	set_string(5,wname,get_param(6))
	
	return (stats[STATS_KILLS] || stats[STATS_HITS])
}

public native_reset_user_wstats()
{
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	return reset_user_wstats(id)
}

/*
* Возвращает общее количество записей в базе данных
*
* native get_statsnum()
*/
public native_get_statsnum(plugin_id,params)
{
	return statsnum
}

/*
* Получение статистик по позиции
*
* native get_stats(index, stats[8], bodyhits[8], name[], len, authid[] = "", authidlen = 0);
*/
public native_get_stats(plugin_id,params)
{
	if(params < 5)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 5, passed %d",params)
		
		return false
	}
	else if(params > 5 && params != 7)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 7, passed %d",params)
		
		return false
	}
	
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_array(2,stats_cache[CACHE_STATS],sizeof stats_cache[CACHE_STATS])
		set_array(3,stats_cache[CACHE_HITS],sizeof stats_cache[CACHE_HITS])
		set_string(4,stats_cache[CACHE_NAME],get_param(5))
		
		if(params == 7)
		{
			set_string(6,stats_cache[CACHE_STEAMID],get_param(7))
		}
		
		return !stats_cache[CACHE_LAST] ? index + 1 : 0
	}
	// кеширование
	
	/*
	* прямой запрос в БД, в случае если нету данных в кеше
	*/
	
	// открываем соединение с БД для получения актуальных данных
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
	
	// подготавливаем запрос в БД
	new query[QUERY_LENGTH]
	DB_QueryBuildGetstats(query,charsmax(query),.index = index)
	new Handle:sqlQue = SQL_PrepareQuery(sql_con,query)
	
	// ошибка выполнения запроса
	if(!SQL_Execute(sqlQue))
	{
		new errNum,err[256]
		errNum = SQL_QueryError(sqlQue,err,charsmax(err))
		
		log_amx("SQL query failed")
		log_amx("[ %d ] %s",errNum,err)
		log_amx("[ SQL ] %s",query)
		
		SQL_FreeHandle(sqlQue)
		
		return 0
	}
	
	// читаем результат
	new name[32],steamid[30],stats[8],hits[8],stats2[4],stats_count
		
	DB_ReadGetStats(sqlQue,
		name,charsmax(name),
		steamid,charsmax(steamid),
		stats,
		hits,
		stats2,
		stats_count,
		index
	)
	
	// статистики нет
	if(!stats_count)
	{
		return false
	}
	
	SQL_FreeHandle(sqlQue)
	
	// возвращаем данные натива
	set_array(2,stats,sizeof player_data[][PLAYER_STATS])
	set_array(3,hits,sizeof player_data[][PLAYER_HITS])
	set_string(4,name,get_param(5))
		
	if(params == 7)
	{
		set_string(6,steamid,get_param(7))
	}
	
	return stats_count ? index + 1 : 0
}

/*
* Потоковый запрос на получение статистик по позиции
*	id - для кого мы запрашиваем
*	position - позиция
*	top - кол-во
*	callback[] - хандлер ответа
*
* native get_stats_sql_thread(id,position,top,callback[]);
*/
public native_get_stats_thread(plugin_id,params)
{
	if(params < 4)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 4, passed %d",params)
		
		return false
	}
	
	new id = get_param(1)
	new position = min(statsnum,get_param(2))
	new top = get_param(3)
	
	new start_index = max((position - top),0)
	
	new callback[20]
	get_string(4,callback,charsmax(callback))
	
	new func_id = get_func_id(callback,plugin_id)
	
	if(func_id == -1)
	{
		log_error(AMX_ERR_NATIVE,"Unable to locate ^"%s^" handler.",callback)
		
		return false
	}
	
	new query[QUERY_LENGTH]
	
	if(params == 5)
	{
		DB_QueryBuildGetstats(query,charsmax(query),.index = start_index,.index_count = top,.overide_order = get_param(5))
	}
	else
	{
		DB_QueryBuildGetstats(query,charsmax(query),.index = start_index,.index_count = top)
	}
	
	
	
	new sql_data[6]
	
	sql_data[0] = SQL_GETSTATS
	sql_data[1] = id
	sql_data[2] = plugin_id
	sql_data[3] = func_id
	sql_data[4] = position
	sql_data[5] = start_index
	
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	
	return true
}

/*
*
* ВСЯКАЯ ХРЕНЬ ДЛЯ САМОСТОЯТЕЛЬНОГО ПРОСЧЕТА СТАТИСТИКИ
*
*/

is_tk(killer,victim)
{
	if(killer == victim)
		return true	
	
	return false
}

get_user_wstats(index, wpnindex, stats[8], bh[8])
{
	for(new i ; i < STATS_END ; i++)
	{
		stats[i] = player_wstats[index][wpnindex][i]
	}
	
	#define krisa[%1] player_wstats[index][wpnindex][STATS_END + %1]
	
	for(new i ; i < HIT_END ; i++)
	{
		bh[i] = krisa[i]
	}
}

get_user_wrstats(index, wpnindex, stats[8], bh[8])
{
	for(new i ; i < STATS_END ; i++)
	{
		stats[i] = player_wrstats[index][wpnindex][i]
	}
	
	for(new i ; i < HIT_END ; i++)
	{
		bh[i] = player_wrstats[index][wpnindex][STATS_END + i]
	}
}

get_user_rstats(index, stats[8], bh[8])
{
	for(new i ; i < STATS_END ; i++)
	{
		stats[i] = player_wrstats[index][0][i]
	}
	
	for(new i ; i < HIT_END ; i++)
	{
		bh[i] = player_wrstats[index][0][STATS_END + i]
	}
}

get_user_stats2(index, stats[4])
{
	for(new i ; i < STATS2_END ; i++)
	{
		stats[i] = player_wstats2[index][i]
	}
	
	return true
}

reset_user_wstats(index)
{
	for(new i ; i < MAX_WEAPONS ; i++)
	{
		arrayset(player_wrstats[index][i],0,sizeof player_wrstats[][])
	}
	
	for(new i ; i < MAX_PLAYERS + 1 ;i++)
	{
		arrayset(player_vstats[index][i],0,sizeof player_vstats[][])
		arrayset(player_vstats[i][index],0,sizeof player_vstats[][])
		arrayset(player_astats[index][i],0,sizeof player_astats[][])
	}
	
	return true
}

reset_user_allstats(index)
{
	for(new i ; i < MAX_WEAPONS ; i++)
	{
		arrayset(player_wstats[index][i],0,sizeof player_wstats[][])
	}
	
	arrayset(player_wstats2[index],0,sizeof player_wstats2[])
	
	return true
}

public DB_OpenConnection()
{
	if(sql_con != Empty_Handle)
	{
		return true
	}
	
	new errNum,err[256]
	sql_con = SQL_Connect(sql,errNum,err,charsmax(err))
	
	#if AMXX_VERSION_NUM >= 183
	SQL_SetCharset(sql_con,"utf8")
	#endif
	
	if(errNum)
	{
		log_amx("SQL query failed")
		log_amx("[ %d ] %s",errNum,err)
			
		return false
	}
	
	return true
}

public DB_CloseConnection()
{
	if(sql_con != Empty_Handle)
	{
		SQL_FreeHandle(sql_con)
		sql_con = Empty_Handle
	}
}

public native_get_user_stats2(plugin_id,params)
{
	new id = get_param(1)
	
	if(!(0 < id <= MaxClients))	// неверно задан айди игрока
	{
		log_error(AMX_ERR_NATIVE,"Player index out of bounds (%d)",id)
		
		return false
	}
	
	set_array(2,player_data[id][PLAYER_STATS2],sizeof player_data[][PLAYER_STATS2])
	
	return true
}

public native_get_stats2(plugin_id,params)
{
	return 0
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
	replace_all(dest,len,"'","''");
	replace_all(dest,len,"^"","^"^"");
}
