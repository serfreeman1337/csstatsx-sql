/*
*	CSStatsX SQL						v. 0.7.4+2
*	by serfreeman1337		https://github.com/serfreeman1337
*/

#include <amxmodx>
#include <sqlx>

//#define REAPI

#if !defined REAPI
	#include <hamsandwich>
#else
	#include <reapi>
#endif

#include <fakemeta>

#define PLUGIN "CSStatsX SQL"
#define VERSION "0.7.4+2"
#define AUTHOR "serfreeman1337"

#define LASTUPDATE "14, May(05), 2019"

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
	SQL_INITDB,	// автоматическое созданием таблиц
	SQL_LOAD,	// загрузка статистики
	SQL_UPDATE,	// обновление
	SQL_INSERT,	// внесение новой записи
	SQL_UPDATERANK,	// получение ранков игроков,
	SQL_GETSTATS,	// потоквый запрос на get_stats
	
	// 0.7
	SQL_GETWSTATS,	// статистика по оружию
	SQL_GETSESSID,	// id сессии статистики за карту
	SQL_GETSESTATS,	// статистика по картам
	SQL_AUTOCLEAR	// чистка БД от неактивных записей
}

enum _:load_state_type	// состояние получение статистики
{
	LOAD_NO,	// данных нет
	LOAD_WAIT,	// ожидание данных
	LOAD_NEWWAIT,	// новая запись, ждем ответа
	LOAD_UPDATE,	// перезагрузить после обновления
	LOAD_NEW,	// новая запись
	LOAD_OK		// есть данные
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
	
	// 0.7
	ROW_CONNECTS,
	ROW_ROUNDT,
	ROW_WINT,
	ROW_ROUNDCT,
	ROW_WINCT,
	
	// 0.7.2
	ROW_ASSISTS,
	
	ROW_FIRSTJOIN,
	ROW_LASTJOIN,
	
	// 0.7
	ROW_SESSIONID,
	ROW_SESSIONNAME
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
	
	// 0.7
	"connects",
	"roundt",
	"wint",
	"roundct",
	"winct",
	
	// 0.7.2
	"assists",
	
	"first_join",
	"last_join",
	
	// 0.7
	"session_id",
	"session_map"
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
new const task_flush		=	11337

#define MAX_CWEAPONS		6
#define CSX_MAX_WEAPONS		CSW_P90 + 1 + MAX_CWEAPONS
#define HIT_END			HIT_RIGHTLEG + 1

// 0.7

enum _:row_weapons_ids		// столбцы таблицы
{
	ROW_WEAPON_ID,
	ROW_WEAPON_PLAYER,
	ROW_WEAPON_NAME,
	ROW_WEAPON_KILLS,
	ROW_WEAPON_DEATHS,
	ROW_WEAPON_HS,
	ROW_WEAPON_TKS,
	ROW_WEAPON_SHOTS,
	ROW_WEAPON_HITS,
	ROW_WEAPON_DMG,
	ROW_WEAPON_H0,
	ROW_WEAPON_H1,
	ROW_WEAPON_H2,
	ROW_WEAPON_H3,
	ROW_WEAPON_H4,
	ROW_WEAPON_H5,
	ROW_WEAPON_H6,
	ROW_WEAPON_H7
}

new const row_weapons_names[row_weapons_ids][] = // имена столбцов
{
	"id",
	"player_id",
	"weapon",
	"kills",
	"deaths",
	"hs",
	"tks",
	"shots",
	"hits",
	"dmg",
	"h_0",
	"h_1",
	"h_2",
	"h_3",
	"h_4",
	"h_5",
	"h_6",
	"h_7"
}

enum _:row_maps_ids
{
	ROW_MAP_ID,
	ROW_MAP_SESSID,
	ROW_MAP_PLRID,
	ROW_MAP_MAP,
	ROW_MAP_SKILL,
	ROW_MAP_KILLS,
	ROW_MAP_DEATHS,
	ROW_MAP_HS,
	ROW_MAP_TKS,
	ROW_MAP_SHOTS,
	ROW_MAP_HITS,
	ROW_MAP_DMG,
	ROW_MAP_BOMBDEF,
	ROW_MAP_BOMBDEFUSED,
	ROW_MAP_BOMBPLANTS,
	ROW_MAP_BOMBEXPLOSIONS,
	ROW_MAP_H0,
	ROW_MAP_H1,
	ROW_MAP_H2,
	ROW_MAP_H3,
	ROW_MAP_H4,
	ROW_MAP_H5,
	ROW_MAP_H6,
	ROW_MAP_H7,
	ROW_MAP_ONLINETIME,
	ROW_MAP_CONNECTS,
	ROW_MAP_ROUNDT,
	ROW_MAP_WINT,
	ROW_MAP_ROUNDCT,
	ROW_MAP_WINCT,
	ROW_MAP_ASSISTS,
	ROW_MAP_FIRSTJOIN,
	ROW_MAP_LASTJOIN,
}

/* - СТРУКТУРА ДАННЫХ - */

// 0.7
enum _:STATS3_END
{
	STATS3_CURRENTTEAM,	// тек. команда игрока (определяется в начале раунда)
	
	STATS3_CONNECT,		// подключения к серверу
	STATS3_ROUNDT,		// раунды за теров
	STATS3_WINT,		// побед за теров
	STATS3_ROUNDCT,		// раунды за спецов
	STATS3_WINCT,		// побед за спецов
	
	// 0.7.2
	STATS3_ASSIST		// помощь в убийстве
}


enum _:sestats_array_struct
{
	SESTATS_ID,
	SESTATS_PLAYERID,
	SESTATS_MAP[MAX_NAME_LENGTH],
	SESTATS_STATS[8],
	SESTATS_HITS[8],
	SESTATS_STATS2[4],
	SESTATS_STATS3[STATS3_END],
	Float:SESTATS_SKILL,
	SESTATS_ONLINETIME,
	SESTATS_FIRSTJOIN,
	SESTATS_LASTJOIN
}

enum _:player_data_struct
{
	PLAYER_ID,			// ид игрока в базе данных
	PLAYER_LOADSTATE,		// состояние загрузки статистики игрока
	PLAYER_RANK,			// ранк игрока
	PLAYER_STATS[STATS_END],	// статистика игрока
	PLAYER_STATSLAST[STATS_END],	// разница в статистики
	PLAYER_HITS[HIT_END],		// статистика попаданий
	PLAYER_HITSLAST[HIT_END],	// разница в статистике попаданий
	PLAYER_STATS2[4],		// статистика cstrike
	PLAYER_STATS2LAST[4],		// разница
	Float:PLAYER_SKILL,		// скилл
	PLAYER_ONLINE,			// время онлайна
	// я не помню чо за diff и last, но без этого не работает XD
	Float:PLAYER_SKILLLAST,
	PLAYER_ONLINEDIFF,
	PLAYER_ONLINELAST,
	
	PLAYER_NAME[MAX_NAME_LENGTH * 3],
	PLAYER_STEAMID[30],
	PLAYER_IP[16],
	
	// 0.7
	PLAYER_STATS3[STATS3_END],	// stast3
	PLAYER_STATS3LAST[STATS3_END],	// stast3
	PLAYER_FIRSTJOIN,
	PLAYER_LASTJOIN
}

enum _:stats_cache_struct	// кеширование для get_stats
{
	CACHE_NAME[32],
	CACHE_STEAMID[30],
	CACHE_STATS[8],
	CACHE_HITS[8],
	CACHE_SKILL,
	bool:CACHE_LAST,
	
	// 0.5.1
	CACHE_ID,
	CACHE_TIME,
	
	// 0.7
	CACHE_STATS2[4],
	CACHE_STATS3[STATS3_END],
	CACHE_FIRSTJOIN,
	CACHE_LASTJOIN
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
	CVAR_USEFORWARDS,
	
	// 0.7
	CVAR_WEAPONSTATS,
	CVAR_MAPSTATS,
	
	CVAR_AUTOCLEAR,
	CVAR_CACHETIME,
	CVAR_AUTOCLEAR_DAY,
	
	// 0.7.2
	CVAR_ASSISTHP,
	
	// 0.7.4+1
	CVAR_PAUSE
}


// 0.7
enum _:stats_cache_queue_struct
{
	CACHE_QUE_START,
	CACHE_QUE_TOP,
}

#define	MAX_DATA_PARAMS	32

/* - ПЕРЕМЕННЫЕ - */

// 0.7
new session_id,session_map[MAX_NAME_LENGTH]

new player_data[MAX_PLAYERS + 1][player_data_struct]
new flush_que[QUERY_LENGTH * 3],flush_que_len
new statsnum

//
 // Общая стата по оружию
 //
// 1ый STATS_END + HIT_END - текущая общая статистика по оружию игрока
// 2ой STATS_END + HIT_END - последнее значение player_wstats, использует для расчета разницы
// последний индекс - определяет INSERT или UPDATE для запроса
//
new player_awstats[MAX_PLAYERS + 1][CSX_MAX_WEAPONS][((STATS_END + HIT_END) * 2) + 1]

new cvar[cvar_set]

new Trie:stats_cache_trie	// дерево кеша для get_stats // ключ - ранг

new tbl_name[32]

/* - CSSTATS CORE - */

 #pragma dynamic 32768

// wstats
new player_wstats[MAX_PLAYERS + 1][CSX_MAX_WEAPONS][STATS_END + HIT_END]

// wstats2
new player_wstats2[MAX_PLAYERS + 1][STATS2_END]

// wrstats rstats
new player_wrstats[MAX_PLAYERS + 1][CSX_MAX_WEAPONS][STATS_END + HIT_END]

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

// 0.7.2
new FW_Assist

// 0.7.3
new FW_Initialized

new dummy_ret

// осталось монитор прихуярить

new g_planter
new g_defuser

#define WEAPON_INFO_SIZE		1 + (MAX_NAME_LENGTH * 2)

new Array:weapons_data			// массив с инфой по оружию
new Trie:log_ids_trie			// дерево для быстрого определения id оружия по лог-коду

// 0.7
new Array:stats_cache_queue

// 0.7.1
new bool:weapon_stats_enabled,bool:map_stats_enabled

// 0.7.3
new init_seq = -1
new bool:is_ready = false

// 0.7.4+2

new evts_guns_bitsum

// am i doing it right ?
new const evt_for_wpn[29] = {
	0, CSW_AWP, CSW_G3SG1, CSW_AK47, CSW_SCOUT, CSW_M249, CSW_M4A1, CSW_SG552, CSW_AUG, CSW_SG550, 
	CSW_M3, CSW_XM1014, CSW_USP, CSW_MAC10, CSW_UMP45, CSW_FIVESEVEN, CSW_P90, CSW_DEAGLE, CSW_P228,
	0, CSW_GLOCK18, CSW_MP5NAVY, CSW_TMP, CSW_ELITE, CSW_ELITE, 0, 0, CSW_GALIL, CSW_FAMAS
}

// макрос для помощи реагистрации инфы по оружию
#define REG_INFO(%0,%1,%2)\
	weapon_info[0] = %0;\
	copy(weapon_info[1],MAX_NAME_LENGTH,%1);\
	copy(weapon_info[MAX_NAME_LENGTH ],MAX_NAME_LENGTH,%2);\
	ArrayPushArray(weapons_data,weapon_info);\
	TrieSetCell(log_ids_trie,%2,ArraySize(weapons_data) - 1)

	
public plugin_precache() {
	register_plugin(PLUGIN,VERSION,AUTHOR)
	
	#if AMXX_VERSION_NUM >= 183

	//
	// For AMXX 1.8.3 and higher
	// Configuration file: amxmodx/configs/plugins/plugin-csstatsx_sql.cfg
	//
	
		create_cvar("csstatsx_sql", VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY, "Plugin version^nDo not edit this cvar")
		cvar[CVAR_SQL_HOST] = create_cvar("csstats_sql_host", "localhost", FCVAR_PROTECTED, "MySQL host")
		cvar[CVAR_SQL_USER] = create_cvar("csstats_sql_user", "root", FCVAR_PROTECTED, "MySQL user")
		cvar[CVAR_SQL_PASS] = create_cvar("csstats_sql_pass", "", FCVAR_PROTECTED, "MySQL user password")
		cvar[CVAR_SQL_DB] = create_cvar("csstats_sql_db", "amxx", FCVAR_PROTECTED, "DB Name")
		cvar[CVAR_SQL_TABLE] = create_cvar("csstats_sql_table", "csstats", FCVAR_PROTECTED, "Table name")
		cvar[CVAR_SQL_TYPE] = create_cvar("csstats_sql_type", "mysql", FCVAR_NONE, "Database type^n\
												mysql - MySQL^n\
												sqlite - SQLite")
		cvar[CVAR_SQL_CREATE_DB] = create_cvar("csstats_sql_create_db", "1", FCVAR_NONE, "Auto create tables^n\
												0 - don't send create table query^n\
												1 - send create table query on map load")
		cvar[CVAR_UPDATESTYLE] = create_cvar("csstats_sql_update", "-1", FCVAR_NONE, "How to update player stats in db^n\
												-2 - on death and disconnect^n\
												-1 - on round end and disconnect^n\
												0 - on disconnect^n\
												higher than 0 - every n seconds and disconnect")
		cvar[CVAR_USEFORWARDS] = create_cvar("csstats_sql_forwards", "0", FCVAR_NONE, "Enable own forwards for client_death, client_damage^n\
												0 - disable^n\
												1 - enable. required if you want replace csx module")
		cvar[CVAR_RANKFORMULA] = create_cvar("csstats_sql_rankformula", "0", FCVAR_NONE, "How to rank player^n\
												0 - kills- deaths - tk^n\
												1 - kills^n\
												2 - kills + hs^n\
												3 - skill^n\
												4 - online time")
		cvar[CVAR_SKILLFORMULA] = create_cvar("csstats_sql_skillformula", "0", FCVAR_NONE, "Skill formula^n\
												0 - The ELO Method")
		cvar[CVAR_WEAPONSTATS] = create_cvar("csstats_sql_weapons", "0", FCVAR_NONE, "Enable weapon stats (/rankstats)^n\
												0 - disable^n\
												1 - enable^n\
												This will create new table csstats_weapons in your database^n\
												NOTE: table will be created only if you set cvar csstats_sql_create_db to 1")
		cvar[CVAR_MAPSTATS] = create_cvar("csstats_sql_maps", "0", FCVAR_NONE, "Enable player session stats (/sestats)^n\
												0 - disable^n\
												1 - enable^n\
												NOTE: you need to import csstats_maps.sql^n\
												Check install instructions")
		cvar[CVAR_AUTOCLEAR] = create_cvar("csstats_sql_autoclear", "0", FCVAR_NONE, "Number of inactive days after which player's stats will be retested. (prune function)")
		cvar[CVAR_CACHETIME] = create_cvar("csstats_sql_cachetime", "-1", FCVAR_NONE, "Cache option^n\
												-1 - enabled^n\
												0 - disabled^n\
												NOTE: Doesn't work with csstats_sql_update -2 or 0")
		cvar[CVAR_AUTOCLEAR_DAY] = create_cvar("csstats_sql_autoclear_day", "0", FCVAR_NONE, "Full stats reset in specified day of month") 
		cvar[CVAR_ASSISTHP] = create_cvar("csstats_sql_assisthp", "50", FCVAR_NONE, "Minimum damage to count assist^n0 - disable this feature")
		// csx
		cvar[CVAR_RANK] = get_cvar_pointer("csstats_rank")
		
		if(!cvar[CVAR_RANK])
			cvar[CVAR_RANK] = create_cvar("csstats_rank", "1", FCVAR_NONE, "Rank mode^n\
											0 - by nick^n\
											1 - by authid^n\
											2 - by ip")
		cvar[CVAR_RANKBOTS] = get_cvar_pointer("csstats_rankbots")
		
		if(!cvar[CVAR_RANKBOTS])
			cvar[CVAR_RANKBOTS] = create_cvar("csstats_rankbots", "1", FCVAR_NONE, "Rank bots^n\
												0 - do not rank bots^n\
												1 - rank bots")
		cvar[CVAR_PAUSE] = get_cvar_pointer("csstats_pause")
		
		if(!cvar[CVAR_PAUSE]) {
			cvar[CVAR_PAUSE] = create_cvar("csstats_pause", "0", FCVAR_NONE, "Pause stats^n\
												0 - do not pause stats^n\
												1 - pause stats")
		}
		// i am retarded ?
		hook_cvar_change(cvar[CVAR_PAUSE], "CvarHook_PauseStats")


		// csx

		AutoExecConfig()
	#else
	
	//
	// For AMX Mod X 1.8.2
	// Write cvars in amxx.cfg !
	//
	
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
		cvar[CVAR_UPDATESTYLE] = register_cvar("csstats_sql_update","-1")
		
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
		
		// 0.7
		
		/*
		* ведение статистики по оружию
		*/
		cvar[CVAR_WEAPONSTATS] = register_cvar("csstats_sql_weapons","0")
		
		/*
		* ведение статистики по картам
		*/
		cvar[CVAR_MAPSTATS] = register_cvar("csstats_sql_maps","0")
		
		/*
		* автоматическое удаление неактвиных игроков в БД
		*/
		cvar[CVAR_AUTOCLEAR] = register_cvar("csstats_sql_autoclear","0")
		
		/*
		* использование кеша для get_stats
		*	-1 - обновлять в конце раунда или по времени csstats_sql_update
		*	0 - отключить использование кеша
		*/
		cvar[CVAR_CACHETIME] = register_cvar("csstats_sql_cachetime","-1")
	
		/*
		* автоматическая очистка всей игровой статистики в БД в определенный день
		*/                               
		cvar[CVAR_AUTOCLEAR_DAY] = register_cvar("csstats_sql_autoclear_day","0") 
		
		/*
		* урон для засчитывания ассиста
		*/
		cvar[CVAR_ASSISTHP] = register_cvar("csstats_sql_assisthp","50")
		
		cvar[CVAR_PAUSE] = get_cvar_pointer("csstats_pause")
		
		if(!cvar[CVAR_PAUSE])
			cvar[CVAR_PAUSE] = register_cvar("csstats_pause", "0")
		
		MaxClients = get_maxplayers()
	#endif
}


#if AMXX_VERSION_NUM >= 183
// sure i am
new bool:pause_stats
public CvarHook_PauseStats(pcvar, const old_value[], const new_value[]) {
	pause_stats = (str_to_num(new_value) > 0)
}
#endif

is_stats_paused() {
	#if AMXX_VERSION_NUM >= 183
	return pause_stats
	#else
	return get_pcvar_num(cvar[CVAR_PAUSE])
	#endif
}

public plugin_init()
{
	register_logevent("LogEventHooK_RoundEnd", 2, "1=Round_End") 
	register_logevent("LogEventHooK_RoundStart", 2, "1=Round_Start") 
	
	register_event("Damage","EventHook_Damage","b","2!0")
	register_event("BarTime","EventHook_BarTime","be")
	register_event("SendAudio","EventHook_SendAudio","a")
	register_event("TextMsg","EventHook_TextMsg","a")
	
	register_srvcmd("csstats_sql_reset","SrvCmd_DBReset")
	
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
	
	#if !defined REAPI
	RegisterHam(Ham_Spawn,"player","HamHook_PlayerSpawn",true)
	#else
	RegisterHookChain(RG_CBasePlayer_Spawn, "RGHook_PlayerSpawn", true)
	#endif
	
	// credits to ConnorMcLeod (https://forums.alliedmods.net/showpost.php?p=1725505&postcount=49)
	new const evts_guns[][] = {
		"events/awp.sc", "events/g3sg1.sc", "events/ak47.sc", "events/scout.sc", "events/m249.sc",
		"events/m4a1.sc", "events/sg552.sc", "events/aug.sc", "events/sg550.sc", "events/m3.sc",
		"events/xm1014.sc", "events/usp.sc", "events/mac10.sc", "events/ump45.sc", "events/fiveseven.sc",
		"events/p90.sc", "events/deagle.sc", "events/p228.sc", "events/glock18.sc", "events/mp5n.sc",
		"events/tmp.sc", "events/elite_left.sc", "events/elite_right.sc", "events/galil.sc", "events/famas.sc"
	}
	
	for(new i ; i < sizeof(evts_guns) ; i++) {
		evts_guns_bitsum |= (1 << engfunc(EngFunc_PrecacheEvent, 1, evts_guns[i]))
	}
	
	register_forward(FM_PlaybackEvent, "FMHook_OnEventPlayback")
}

#if AMXX_VERSION_NUM < 183
	public plugin_cfg()
#else
	public OnConfigsExecuted()
#endif
{
	#if AMXX_VERSION_NUM < 183
		// форсируем выполнение exec addons/amxmodx/configs/amxx.cfg
		server_exec()
	#endif
	
	// читаем квары на подключение
	new host[128],user[64],pass[64],db[64],type[10]
	get_pcvar_string(cvar[CVAR_SQL_HOST],host,charsmax(host))
	get_pcvar_string(cvar[CVAR_SQL_USER],user,charsmax(user))
	get_pcvar_string(cvar[CVAR_SQL_PASS],pass,charsmax(pass))
	get_pcvar_string(cvar[CVAR_SQL_DB],db,charsmax(db))
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	get_pcvar_string(cvar[CVAR_SQL_TYPE],type,charsmax(type))
	
	// и снова здравствуй wopox3 
	if(!SQL_SetAffinity(type))
	{
		new error_msg[128]
		formatex(error_msg,charsmax(error_msg),"failed to use ^"%s^" for db driver",
			type)
			
		set_fail_state(error_msg)
		
		return
	}
	
	sql = SQL_MakeDbTuple(host,user,pass,db)
	
	// для поддержки utf8 ников требуется AMXX 1.8.3-dev-git3799 или выше
	
	#if AMXX_VERSION_NUM >= 183
		SQL_SetCharset(sql,"utf8")
	#endif
	
	weapon_stats_enabled = get_pcvar_num(cvar[CVAR_WEAPONSTATS]) == 1? true : false
	map_stats_enabled = get_pcvar_num(cvar[CVAR_MAPSTATS]) == 1 ? true : false
	
	new query[QUERY_LENGTH * 2],que_len
	
	new sql_data[1]
	sql_data[0] = SQL_INITDB

	// запрос на создание таблицы
	if(get_pcvar_num(cvar[CVAR_SQL_CREATE_DB]))
	{
		// запрос для mysql
		if(strcmp(type,"mysql") == 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				CREATE TABLE IF NOT EXISTS `%s` (\
					`%s` int(11) NOT NULL AUTO_INCREMENT,\
					`%s` varchar(30) NOT NULL,\
					`%s` varchar(32) NOT NULL,\
					`%s` varchar(16) NOT NULL,\
					`%s` float NOT NULL DEFAULT '0.0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',",
					
					tbl_name,
					
					row_names[ROW_ID],
					row_names[ROW_STEAMID],
					row_names[ROW_NAME],
					row_names[ROW_IP],
					row_names[ROW_SKILL],
					row_names[ROW_KILLS],
					row_names[ROW_DEATHS],
					row_names[ROW_HS]
			)
			
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',",
					
					row_names[ROW_TKS],
					row_names[ROW_SHOTS],
					row_names[ROW_HITS],
					row_names[ROW_DMG],
					row_names[ROW_BOMBDEF],
					row_names[ROW_BOMBDEFUSED],
					row_names[ROW_BOMBPLANTS],
					row_names[ROW_BOMBEXPLOSIONS],
					row_names[ROW_H0]
			)
			
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',",
					
					row_names[ROW_H1],
					row_names[ROW_H2],
					row_names[ROW_H3],
					row_names[ROW_H4],
					row_names[ROW_H5],
					row_names[ROW_H6],
					row_names[ROW_H7],
					row_names[ROW_ONLINETIME]
			)
			
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',\
					`%s` int(11) NOT NULL DEFAULT '0',",
					
					row_names[ROW_CONNECTS],
					row_names[ROW_ROUNDT],
					row_names[ROW_WINT],
					row_names[ROW_ROUNDCT],
					row_names[ROW_WINCT],
					row_names[ROW_ASSISTS]
			)
			
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,\
				`%s` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',\
				`%s` int(11) DEFAULT NULL,\
				`%s` varchar(32) DEFAULT NULL,\
					PRIMARY KEY (%s),\
					KEY `%s` (`%s`(16)),\
					KEY `%s` (`%s`(16)),\
					KEY `%s` (`%s`)\
				) DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;",
				
				row_names[ROW_FIRSTJOIN],
				row_names[ROW_LASTJOIN],
				
				row_names[ROW_SESSIONID],
				row_names[ROW_SESSIONNAME],
				
				row_names[ROW_ID],
				row_names[ROW_STEAMID],row_names[ROW_STEAMID],
				row_names[ROW_NAME],row_names[ROW_NAME],
				row_names[ROW_IP],row_names[ROW_IP]
			)
		}
		// запрос для sqlite
		else if(strcmp(type,"sqlite") == 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				CREATE TABLE IF NOT EXISTS `%s` (\
					`%s` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,\
					`%s`	TEXT NOT NULL,\
					`%s`	TEXT NOT NULL,\
					`%s`	TEXT NOT NULL,\
					`%s`	REAL NOT NULL DEFAULT 0.0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,",
					
					tbl_name,
					
					row_names[ROW_ID],
					row_names[ROW_STEAMID],
					row_names[ROW_NAME],
					row_names[ROW_IP],
					row_names[ROW_SKILL],
					row_names[ROW_KILLS],
					row_names[ROW_DEATHS]
			)
				
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,",
					
					row_names[ROW_HS],
					row_names[ROW_TKS],
					row_names[ROW_SHOTS],
					row_names[ROW_HITS],
					row_names[ROW_DMG],
					row_names[ROW_BOMBDEF],
					row_names[ROW_BOMBDEFUSED],
					row_names[ROW_BOMBPLANTS],
					row_names[ROW_BOMBEXPLOSIONS]
			)
					
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,",
					
					row_names[ROW_H0],
					row_names[ROW_H1],
					row_names[ROW_H2],
					row_names[ROW_H3],
					row_names[ROW_H4],
					row_names[ROW_H5],
					row_names[ROW_H6],
					row_names[ROW_H7]
			)
					
			// 0.7
			
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,",
					
					row_names[ROW_ONLINETIME],
					row_names[ROW_CONNECTS],
					row_names[ROW_ROUNDT],
					row_names[ROW_WINT],
					row_names[ROW_ROUNDCT],
					row_names[ROW_WINCT],
					row_names[ROW_ASSISTS]
			)
					
			que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,\
					`%s`	TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',\
					`%s`	INTEGER,\
					`%s`	TEXT\
				);",
				
				row_names[ROW_FIRSTJOIN],
				row_names[ROW_LASTJOIN],
				row_names[ROW_SESSIONID],
				row_names[ROW_SESSIONNAME]
			)
		}
		else
		{
			set_fail_state("invalid ^"csstats_sql_type^" cvar value")
		}
		
		DB_AddInitSeq()
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
		
		if(weapon_stats_enabled)
		{
			que_len = 0
			
			// запрос для mysql
			if(strcmp(type,"mysql") == 0)
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					CREATE TABLE IF NOT EXISTS `%s_weapons` (\
						`%s` int(11) NOT NULL AUTO_INCREMENT,\
						`%s` int(11) NOT NULL,\
						`%s` varchar(32) NOT NULL,\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',",
						
						tbl_name,
						row_weapons_names[ROW_WEAPON_ID],
						row_weapons_names[ROW_WEAPON_PLAYER],
						row_weapons_names[ROW_WEAPON_NAME],
						row_weapons_names[ROW_WEAPON_KILLS],
						row_weapons_names[ROW_WEAPON_DEATHS],
						row_weapons_names[ROW_WEAPON_HS]
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',",
						
						row_weapons_names[ROW_WEAPON_TKS],
						row_weapons_names[ROW_WEAPON_SHOTS],
						row_weapons_names[ROW_WEAPON_HITS],
						row_weapons_names[ROW_WEAPON_DMG]	
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',\
						`%s` int(11) NOT NULL DEFAULT '0',",
						
						row_weapons_names[ROW_WEAPON_H0],
						row_weapons_names[ROW_WEAPON_H1],
						row_weapons_names[ROW_WEAPON_H2],
						row_weapons_names[ROW_WEAPON_H3],
						row_weapons_names[ROW_WEAPON_H4],
						row_weapons_names[ROW_WEAPON_H5],
						row_weapons_names[ROW_WEAPON_H6],
						row_weapons_names[ROW_WEAPON_H7]
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
						PRIMARY KEY (%s),\
						KEY `%s` (`%s`(16))\
					) DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;",
					
					row_weapons_names[ROW_WEAPON_ID],
					row_weapons_names[ROW_WEAPON_NAME],
					row_weapons_names[ROW_WEAPON_NAME]
				)
			}
			// запрос для sqlite
			else if(strcmp(type,"sqlite") == 0)
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					CREATE TABLE IF NOT EXISTS `%s_weapons` (\
						`%s` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,\
						`%s`	INTEGER NOT NULL,\
						`%s`	TEXT NOT NULL,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,",
						
						tbl_name,
						row_weapons_names[ROW_WEAPON_ID],
						row_weapons_names[ROW_WEAPON_PLAYER],
						row_weapons_names[ROW_WEAPON_NAME],
						row_weapons_names[ROW_WEAPON_KILLS],
						row_weapons_names[ROW_WEAPON_DEATHS]
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,",
						
						row_weapons_names[ROW_WEAPON_HS],
						row_weapons_names[ROW_WEAPON_TKS],
						row_weapons_names[ROW_WEAPON_SHOTS],
						row_weapons_names[ROW_WEAPON_HITS],
						row_weapons_names[ROW_WEAPON_DMG]
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,"`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0,\
						`%s`	INTEGER NOT NULL DEFAULT 0",
						
						row_weapons_names[ROW_WEAPON_H0],
						row_weapons_names[ROW_WEAPON_H1],
						row_weapons_names[ROW_WEAPON_H2],
						row_weapons_names[ROW_WEAPON_H3],
						row_weapons_names[ROW_WEAPON_H4],
						row_weapons_names[ROW_WEAPON_H5],
						row_weapons_names[ROW_WEAPON_H6],
						row_weapons_names[ROW_WEAPON_H7]
				)
				que_len += formatex(query[que_len],charsmax(query) - que_len,");")
			}
			else
			{
				set_fail_state("invalid ^"csstats_sql_type^" cvar value")
			}
			
			if(que_len)
			{
				DB_AddInitSeq()
				SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
			}
		}
	}
	
	DB_AutoClearOpt()
	
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
		
		#if !defined REAPI
		register_forward(FM_SetModel,"FMHook_SetModel",true)
		#else
		RegisterHookChain(RG_ThrowFlashbang, "RGHook_ThrowFlashbang", true)
		RegisterHookChain(RG_ThrowHeGrenade, "RGHook_ThrowHeGrenade", true)
		RegisterHookChain(RG_ThrowSmokeGrenade, "RGHook_ThrowSmokeGrenade", true)
		#endif
	}
	
	// 0.7.2
	FW_Assist = CreateMultiForward("client_assist_sql",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
	
	// 0.7.3
	FW_Initialized = CreateMultiForward("csxsql_initialized",ET_IGNORE)
	
	// 0.7
	
	//
	// запрос на получение ID сессии статистики за карту
	//
	if(map_stats_enabled)
	{
		new query[128],sql_data[1] = SQL_GETSESSID
		
		formatex(query,charsmax(query),"SELECT MAX(`session_id`) FROM `%s_maps`",
			tbl_name
		)
		
		DB_AddInitSeq()
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	// защита от ретардов, которые не читаю README
	if(
		(get_pcvar_num(cvar[CVAR_UPDATESTYLE]) == -2) ||
		(get_pcvar_num(cvar[CVAR_UPDATESTYLE]) == 0)
	)
	{
		// выключаем кеширование
		set_pcvar_num(cvar[CVAR_CACHETIME],0)
	}
	
	DB_InitSeq()
}

//
// последовательность перед началом работы плагина
//
DB_AddInitSeq()
{
	init_seq --
}

//
// проверяем выполнение последовательности инициализации
//
DB_InitSeq()
{
	if(init_seq ==0)
	{
		log_amx("!?!?!?!?!?")
		return
	}
	
	init_seq ++
	
	// все выполнено, начинаем работу
	if(init_seq == 0)
	{
		ExecuteForward(FW_Initialized,dummy_ret)
	}
}

//
// Функция очистки БД от неактивных игроков
//
DB_AutoClearOpt()
{
	// 0.7
	new autoclear_days = get_pcvar_num(cvar[CVAR_AUTOCLEAR])
	
	if(autoclear_days > 0)
	{
		DB_ClearTables(autoclear_days)
	}
	
	// полные сброс статистики в определенный день
	autoclear_days = get_pcvar_num(cvar[CVAR_AUTOCLEAR_DAY])
	
	if(autoclear_days > 0)
	{
		  new s_data[10]
		  get_time("%d",s_data,charsmax(s_data))
		  
		  if(str_to_num(s_data) == autoclear_days)
		  {
		  	s_data[0] = 0
		  	get_vaultdata("csxsql_clear",s_data,charsmax(s_data))
			
			// проверяем не было ли сброса
			if(!str_to_num(s_data))
			{
				set_vaultdata("csxsql_clear","1")
				DB_ClearTables(-1)
			}
		  }
		  /// очищяем проверку на сброс
		  else
		  {
		  	set_vaultdata("csxsql_clear","0")
		  }
	}
}

//
// Начало работы с БД
//
public csxsql_initialized()
{
	is_ready = true
	
	new players[MAX_PLAYERS],pnum
	get_players(players,pnum)
	
	// загружаем стату игроков
	for(new i ; i < pnum ; i++)
	{ 
		client_putinserver(players[i])
	}
}

public SrvCmd_DBReset()
{
	DB_ClearTables(-1)
}

//
// Очистка таблиц от неактивных записей
//
DB_ClearTables(by_days)
{
	if(by_days == -1)
	{
		log_amx("database reset")
	}
	
	new query[QUERY_LENGTH],que_len 
	
	new type[10]
	get_pcvar_string(cvar[CVAR_SQL_TYPE],type,charsmax(type))
		
	if(strcmp(type,"mysql") == 0)
	{
		que_len += formatex(query[que_len],charsmax(query) - que_len,"DELETE `%s`",
			tbl_name
		)
		
		if(weapon_stats_enabled)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,",`%s_weapons`",tbl_name)
		}
		
		if(map_stats_enabled)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,",`%s_maps`",tbl_name)
		}
		
		que_len += formatex(query[que_len],charsmax(query) - que_len," FROM `%s`",
			tbl_name
		)
		
		if(weapon_stats_enabled)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				LEFT JOIN `%s_weapons` ON `%s`.`%s` = `%s_weapons`.`%s`",
				tbl_name,
				tbl_name,row_names[ROW_ID],
				tbl_name,row_weapons_names[ROW_WEAPON_PLAYER]
			)
		}
		
		if(map_stats_enabled)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
				LEFT JOIN `%s_maps` ON `%s`.`%s` = `%s_maps`.`%s`",
				tbl_name,
				tbl_name,row_names[ROW_ID],
				tbl_name,row_weapons_names[ROW_WEAPON_PLAYER]
			)
		}
		
		if(by_days > 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"WHERE `%s`.`%s` <= DATE_SUB(NOW(),INTERVAL %d DAY);",
				tbl_name,row_names[ROW_LASTJOIN],by_days
			)
		}
		else
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"WHERE 1")
		}
	}
	else if(strcmp(type,"sqlite") == 0)
	{
		if(weapon_stats_enabled)
		{
			if(by_days > 0)
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
						DELETE FROM `%s_weapons` WHERE `%s` IN (\
							SELECT `%s` FROM `%s` WHERE `%s` <= DATETIME('now','-%d day')\
						);",
						tbl_name,row_weapons_names[ROW_WEAPON_PLAYER],
						row_names[ROW_ID],tbl_name,row_names[ROW_LASTJOIN],
						by_days
				)
			}
			else
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
						DELETE FROM `%s_weapons` WHERE `%s` IN (\
							SELECT `%s` FROM `%s` WHERE 1\
						);",
						tbl_name,row_weapons_names[ROW_WEAPON_PLAYER],
						row_names[ROW_ID],tbl_name
					)
			}
		}
		
		if(map_stats_enabled)
		{
			if(by_days > 0)
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					DELETE FROM `%s_maps` WHERE `%s` IN (\
						SELECT `%s` FROM `%s` WHERE `%s` <= DATETIME('now','-%d day')\
					);",
					tbl_name,row_weapons_names[ROW_WEAPON_PLAYER],
					row_names[ROW_ID],tbl_name,row_names[ROW_LASTJOIN],
					by_days
				)
			}
			else
			{
				que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					DELETE FROM `%s_maps` WHERE `%s` IN (\
						SELECT `%s` FROM `%s` WHERE 1\
					);",
					tbl_name,row_weapons_names[ROW_WEAPON_PLAYER],
					row_names[ROW_ID],tbl_name
				)
			}
		}
		
		if(by_days > 0)
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					DELETE FROM `%s` WHERE `%s` <= DATETIME('now','-%d day');",
					tbl_name,row_names[ROW_LASTJOIN],by_days
			)
		}
		else
		{
			que_len += formatex(query[que_len],charsmax(query) - que_len,"\
					DELETE FROM `%s` WHERE 1;",tbl_name
			)
		}
	}
	
	new sql_data[1]
	sql_data[0] = SQL_AUTOCLEAR
	
	DB_AddInitSeq()
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
}

public plugin_end()
{
	if(!is_ready) {
		return
	}
	
	// выполняем накопившиеся запросы при смене карты или выключении серваре
	DB_FlushQuery()
	
	if(sql_con != Empty_Handle) {
		SQL_FreeHandle(sql)
	}
	
	if(sql_con != Empty_Handle)
	{
		SQL_FreeHandle(sql_con)
	}
	
	if(stats_cache_trie)
	{
		TrieDestroy(stats_cache_trie)
	}
	
	TrieDestroy(log_ids_trie)
	ArrayDestroy(weapons_data)
}

/*
* загружаем статистику при подключении
*/
public client_putinserver(id)
{
	// ждем начала работы с БД
	if(!is_ready)
	{
		return PLUGIN_CONTINUE
	}
	
	reset_user_allstats(id)
	reset_user_wstats(id)
	
	arrayset(player_data[id],0,player_data_struct)
	
	for(new wpn ; wpn < CSX_MAX_WEAPONS ; wpn ++)
	{
		arrayset(player_awstats[id][wpn],0,sizeof player_awstats[][])
	}
	
	DB_LoadPlayerData(id)
	
	return PLUGIN_CONTINUE
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
}

#if !defined REAPI
public HamHook_PlayerSpawn(id)
#else
public RGHook_PlayerSpawn(id)
#endif
{
	reset_user_wstats(id)
}

//
// Shots registration
//
public FMHook_OnEventPlayback(flags, invoker, eventid) {
	if(!(evts_guns_bitsum & (1 << eventid)) || !(1 <= invoker <= MaxClients))
		return FMRES_IGNORED
	
	Stats_SaveShot(invoker, evt_for_wpn[eventid])
		
	return FMRES_HANDLED
}

//
// Регистрация попадания
//
public EventHook_Damage(player)
{
	static damage_take;damage_take = read_data(2)
	
	// thanks voed
	static weapon_id,last_hit,attacker,bool:alive
	attacker = get_user_attacker(player,weapon_id,last_hit)
	alive = (is_user_alive(player) ? true : false)
	
	if(!is_user_connected(attacker)) {
		
		if(!alive) {
			Stats_SaveKill(0,player,0,0)
		}
		
		return PLUGIN_CONTINUE
	}
	
	if(0 <= last_hit < HIT_END)
	{
		Stats_SaveHit(attacker,player,damage_take,weapon_id,last_hit)
	}
	
	if(!alive) {
		Stats_SaveKill(attacker,player,weapon_id,last_hit)
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
			
			Event_CTWin()
		}
	}
}

public EventHook_TextMsg(player)
{
	new message[16]
	read_data(2,message,charsmax(message))
	
	if (!player)
	{
		// #Target_Bombed
		if ((message[1]=='T' && message[8] == 'B') && g_planter)
		{
			Stats_SaveBExplode(g_planter)
			
			g_planter = 0
			g_defuser = 0
			
			Event_TWin()
		}
		// #Terrorists_Win -- #Hostages_Not_R
		else if(
			(message[2] == 'e' && message[12] == 'W') ||
			(message[1] == 'H' && message[14] == 'R')
		)
		{
			Event_TWin()
		}
		// #Target_Saved -- #CTs_Win -- #All_Hostages_R
		else if(
			(message[1] == 'T' && message[8] == 'S') ||
			(message[2] == 'T' && message[5] == 'W') ||
			(message[1] == 'A' && message[14] == 'R')
		)
		{
			Event_CTWin()
		}
		
	}
}

//
// Победа TERRORIST
//
Event_TWin()
{
	new players[MAX_PLAYERS],pnum
	get_players(players,pnum)
	
	for(new i,player ; i < pnum ; i++)
	{
		player = players[i]
		
		// считаем статистику побед по командам
		if(player_data[player][PLAYER_STATS3][STATS3_CURRENTTEAM] == 1)
		{
			player_data[player][PLAYER_STATS3][STATS3_WINT] ++
		}
	}
}

//
// Победа CT
//
Event_CTWin()
{
	new players[MAX_PLAYERS],pnum
	get_players(players,pnum)
	
	for(new i,player ; i < pnum ; i++)
	{
		player = players[i]
		
		// считаем статистику побед по командам
		if(player_data[player][PLAYER_STATS3][STATS3_CURRENTTEAM] == 2)
		{
			player_data[player][PLAYER_STATS3][STATS3_WINCT] ++
		}
	}
}

//
// Форвард grenade_throw
//
#if !defined REAPI
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
#else
public RGHook_ThrowFlashbang(const index) {
	ExecuteForward(FW_GThrow, dummy_ret, index, GetHookChainReturn(ATYPE_INTEGER), CSW_FLASHBANG)
}
public RGHook_ThrowHeGrenade(const index) {
	ExecuteForward(FW_GThrow, dummy_ret, index, GetHookChainReturn(ATYPE_INTEGER), CSW_HEGRENADE)
}
public RGHook_ThrowSmokeGrenade(const index) {
	ExecuteForward(FW_GThrow, dummy_ret, index, GetHookChainReturn(ATYPE_INTEGER), CSW_SMOKEGRENADE)
}
#endif
//
// Учет ассистов
//
Stats_SaveAssist(player,victim,assisted)
{
	ExecuteForward(FW_Assist,dummy_ret,player,victim,assisted)
	
	if(is_stats_paused()) {
		return false
	}
	
	player_data[player][PLAYER_STATS3][STATS3_ASSIST] ++
	
	return true
}

//
// Учет выстрелов
//
Stats_SaveShot(player,wpn_id)
{
	if(is_stats_paused()) {
		return false
	}
	
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
	if(FW_Damage)
		ExecuteForward(FW_Damage,dummy_ret,attacker,victim,damage,wpn_id,hit_place,is_tk(attacker,victim))
		
	if(is_stats_paused()) {
		return false
	}
	
	if(attacker == victim) {
		return false
	}
	
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
		
	return true
}

//
// Учет смертей
//
Stats_SaveKill(killer,victim,wpn_id,hit_place)
{
	if(FW_Death)
		ExecuteForward(FW_Death,dummy_ret,killer,victim,wpn_id,hit_place,is_tk(killer,victim))
		
	if(is_stats_paused()) {
		return false
	}
	
	if(killer == victim || !killer) // не учитываем суицид
	{
		player_wstats[victim][0][STATS_DEATHS] ++
		player_wrstats[victim][0][STATS_DEATHS] ++
		
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
	
	// смотрим ассисты
	for(new i = 1,assist_hp = get_pcvar_num(cvar[CVAR_ASSISTHP]); (assist_hp) && (i <= MAX_PLAYERS) ; i++)
	{
		if(i == killer)
		{
			continue
		}
		
		if(player_astats[victim][i][STATS_DMG] >= assist_hp)
		{
			Stats_SaveAssist(i,victim,killer)
		}
	}
	
	new victim_wpn_id = get_user_weapon(victim)
	
	if(victim_wpn_id)
	{
		player_wstats[victim][victim_wpn_id][STATS_DEATHS] ++
		player_wrstats[victim][victim_wpn_id][STATS_DEATHS] ++
	}
	
	if(player_data[killer][PLAYER_LOADSTATE] == LOAD_OK && player_data[victim][PLAYER_LOADSTATE] == LOAD_OK) // скилл расчитывается только при наличии статистики из БД
	{
		switch(get_pcvar_num(cvar[CVAR_SKILLFORMULA])) // расчет скилла
		{
			case -1: // Pre 0.7.4+1 ELO
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
			case 0: // The ELO Method (http://fastcup.net/rating.html)
			{
				// thanks In-line
				new Float:delta = 1.0 / (1.0 + floatpower(10.0,(player_data[killer][PLAYER_SKILL] - player_data[victim][PLAYER_SKILL]) / 100.0))
				new Float:killer_koeff = (player_data[killer][PLAYER_STATS][STATS_KILLS] < 100) ? 2.0 : 1.5
				new Float:victim_koeff = (player_data[victim][PLAYER_STATS][STATS_KILLS] < 100) ? 2.0 : 1.5
				
				player_data[killer][PLAYER_SKILL] += (killer_koeff * delta)
				player_data[victim][PLAYER_SKILL] -= (victim_koeff * delta)
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
	if(FW_BDefusing)
		ExecuteForward(FW_BDefusing,dummy_ret,id)
		
	if(is_stats_paused()) {
		return false
	}
	
	player_wstats2[id][STATS2_DEFAT] ++
		
	return true
}

Stats_SaveBDefused(id)
{
	if(FW_BDefused)
		ExecuteForward(FW_BDefused,dummy_ret,id)
		
	if(is_stats_paused()) {
		return false
	}
	
	player_wstats2[id][STATS2_DEFOK] ++
		
	return true
}

Stats_SaveBPlanted(id)
{
	if(FW_BPlanted)
		ExecuteForward(FW_BPlanted,dummy_ret,id)
		
	if(is_stats_paused()) {
		return false
	}
	
	player_wstats2[id][STATS2_PLAAT] ++
		
	return true
}

Stats_SaveBExplode(id)
{
	if(FW_BExplode)
		ExecuteForward(FW_BExplode,dummy_ret,id,g_defuser)
		
	if(is_stats_paused()) {
		return false
	}
	
	player_wstats2[id][STATS2_PLAOK] ++
		
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
		
		// определяем в какой команде игрок
		switch(get_user_team(player))
		{
			// статистика сыгранных раундов по командам
			case 1:
			{
				player_data[player][PLAYER_STATS3][STATS3_ROUNDT] ++
				player_data[player][PLAYER_STATS3][STATS3_CURRENTTEAM] = 1
			}
			case 2:
			{
				player_data[player][PLAYER_STATS3][STATS3_ROUNDCT] ++
				player_data[player][PLAYER_STATS3][STATS3_CURRENTTEAM] = 2
			}
		}
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
	if( is_user_bot(id) && !get_pcvar_num(cvar[CVAR_RANKBOTS]))
	{
		return false
	}
	
	get_user_info(id,"name",player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	mysql_escape_string(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	
	get_user_authid(id,player_data[id][PLAYER_STEAMID],charsmax(player_data[][PLAYER_STEAMID]))
	get_user_ip(id,player_data[id][PLAYER_IP],charsmax(player_data[][PLAYER_IP]),true)
	
	// формируем SQL запрос
	new query[QUERY_LENGTH],len,sql_data[2]
	
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

//
// Загрузка статистики по оружию
//
DB_LoadPlayerWstats(id)
{
	if(!player_data[id][PLAYER_ID])
	{
		return false
	}
	
	new query[QUERY_LENGTH],sql_data[2]
	
	sql_data[0] = SQL_GETWSTATS
	sql_data[1] = id
	
	formatex(query,charsmax(query),"SELECT * FROM `%s_weapons` WHERE `player_id` = '%d'",
		tbl_name,player_data[id][PLAYER_ID]
	)
	
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	
	return true
		
}

/*
* сохранение статистики игрока
*/
DB_SavePlayerData(id,bool:reload = false)
{
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_NEW) // игрок не загрузился
	{
		return false
	}
	
	new query[QUERY_LENGTH],i,len
	new sql_data[2]
	
	sql_data[1] = id
	
	new stats[8],stats2[4],hits[8]
	get_user_wstats(id,0,stats,hits)
	get_user_stats2(id,stats2)
	
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
			new to_save
			
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
						len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
							!to_save ? " " : ",",
							row_names[i + ROW_H0],row_names[i + ROW_H0],
							diffhits[i]
						)
					}
				}
			}
			
			// 0.7
			new diffstats3[STATS3_END]
			
			for(i = STATS3_CONNECT ; i < sizeof player_data[][PLAYER_STATS3] ; i++)
			{
				diffstats3[i] = player_data[id][PLAYER_STATS3][i] - player_data[id][PLAYER_STATS3LAST][i]
				
				if(diffstats3[i])
				{
					len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
						!to_save ? " " : ",",
						row_names[(i - 1) + ROW_CONNECTS],row_names[(i - 1) + ROW_CONNECTS],
						diffstats3[i]
					)
					
					to_save ++
				}
			}
			
			// не сохраняем только подключения
			to_save --
			
			// 0.7 задаем поля для тригерром статистики по картам
			if(session_id)
			{
				len += formatex(query[len],charsmax(query) - len,"%s`%s` = '%d',`%s` = '%s'",
						to_save <= 0 ? " " : ",",
						row_names[ROW_SESSIONID],session_id,
						row_names[ROW_SESSIONNAME],session_map
				)
			}
			
			// 
			player_data[id][PLAYER_ONLINE] += (get_user_time(id) - player_data[id][PLAYER_ONLINEDIFF])
			player_data[id][PLAYER_ONLINEDIFF] = get_user_time(id)
			
			new diffonline = player_data[id][PLAYER_ONLINE]- player_data[id][PLAYER_ONLINELAST]
			
			if(diffonline)
			{
				len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + %d",
					to_save <= 0 ? " " : ",",
					row_names[ROW_ONLINETIME],
					row_names[ROW_ONLINETIME],
					diffonline
				)
				
				//to_save ++
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
			
			if(to_save <= 0) // нечего сохранять
			{
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE) // релоад для обновления ника
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
				}
				
				return false
			}
			else
			{
				//
				// Сравниваем статистику
				//
				for(new i ; i < sizeof player_data[][PLAYER_STATS] ; i++)
				{
					player_data[id][PLAYER_STATS][i] += diffstats[i]
				}
				
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] += diffhits[i]
				}
				
				for(new i ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
				{
					player_data[id][PLAYER_STATS2][i] += diffstats2[i]
				}
				
				for(i = STATS3_CONNECT ; i < sizeof player_data[][PLAYER_STATS3] ; i++)
				{
					player_data[id][PLAYER_STATS3LAST][i] = player_data[id][PLAYER_STATS3][i]
				}
				
				player_data[id][PLAYER_ONLINELAST] = player_data[id][PLAYER_ONLINE]
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
					
					stats[STATS_KILLS],
					stats[STATS_DEATHS],
					stats[STATS_HS],
					stats[STATS_TK],
					stats[STATS_SHOTS],
					stats[STATS_HITS],
					stats[STATS_DMG],
					
					stats2[STATS2_DEFAT],
					stats2[STATS2_DEFOK],
					stats2[STATS2_PLAAT],
					stats2[STATS2_PLAOK]
			)
			
			//
			// Сравниваем статистику
			//
			for(new i ; i < sizeof player_data[][PLAYER_STATS] ; i++)
			{
				player_data[id][PLAYER_STATS][i] = stats[i]
			}
				
			for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
			{
				player_data[id][PLAYER_HITS][i] = hits[i]
			}
				
			for(new i ; i < sizeof player_data[][PLAYER_STATS2] ; i++)
			{
				player_data[id][PLAYER_STATS2][i] = stats2[i]
			}
				
			player_data[id][PLAYER_SKILL] = _:player_data[id][PLAYER_SKILLLAST] = _:skill
			
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
		if(weapon_stats_enabled)
		{
			DB_SavePlayerWstats(id)
		}
		
		switch(sql_data[0])
		{
			// накапливаем запросы 
			case SQL_UPDATE:
			{
				// запросов достаточно, сбрасываем их
				DB_AddQuery(query,len)
				
				return true
			}
		}
		
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	return true
}

//
// Сохранение статистики по оружию
//
public DB_SavePlayerWstats(id)
{
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // игрок не загрузился
	{
		return false
	}
	
	new query[QUERY_LENGTH],len,log[MAX_NAME_LENGTH],wpn,stats_index,stats_index_last,to_save
	new diff[STATS_END + HIT_END]
	
	const load_index = sizeof player_awstats[][] - 1
	
	// по всем оружиям
	for(wpn = 0; wpn < CSX_MAX_WEAPONS ; wpn++)
	{
		Info_Weapon_GetLog(wpn,log,charsmax(log))
		
		if(!log[0])
		{
			continue
		}
		
		to_save = 0
		len = 0
		
		// расчитываем разницу статисткии
		for(stats_index = 0;  stats_index < STATS_END + HIT_END;  stats_index++)
		{
			stats_index_last = stats_index + (STATS_END + HIT_END)
			
			diff[stats_index] = player_wstats[id][wpn][stats_index] - player_awstats[id][wpn][stats_index_last]
			player_awstats[id][wpn][stats_index_last] = player_wstats[id][wpn][stats_index]
		}
		
		switch(player_awstats[id][wpn][load_index])
		{
			// новая статистика оружия
			case LOAD_NEW:
			{
				new id_row 
				
				// строим запрос
				len += formatex(query[len],charsmax(query) - len,"INSERT INTO `%s_weapons` (`%s`,`%s`",
					tbl_name,
					
					row_weapons_names[ROW_WEAPON_PLAYER],
					row_weapons_names[ROW_WEAPON_NAME]
				)
				
				for(stats_index = 0;  stats_index < STATS_END + HIT_END;  stats_index++)
				{
					id_row = ROW_WEAPON_KILLS + stats_index
					
					if(diff[stats_index])
					{
						len += formatex(query[len],charsmax(query) - len,",`%s`",
							row_weapons_names[id_row]
						)
						
						to_save ++
					}
				}
				
				if(to_save)
				{
					len += formatex(query[len],charsmax(query) - len,") VALUES('%d','%s'",
						player_data[id][PLAYER_ID],
						log
					)
					
					for(stats_index = 0;  stats_index < STATS_END + HIT_END;  stats_index++)
					{
						id_row = ROW_WEAPON_KILLS + stats_index
						
						if(diff[stats_index])
						{
							len += formatex(query[len],charsmax(query) - len,",'%d'",
								diff[stats_index]
							)
						}
					}
					
					len += formatex(query[len],charsmax(query) - len,")")
					player_awstats[id][wpn][load_index]  = _:LOAD_OK
				}
				
				
			}
			// обновляем статистику
			case LOAD_OK:
			{
				new id_row 
				
				// строим запрос
				len += formatex(query[len],charsmax(query) - len,"UPDATE `%s_weapons` SET",tbl_name)
				
				for(stats_index = 0;  stats_index < STATS_END + HIT_END;  stats_index++)
				{
					id_row = ROW_WEAPON_KILLS + stats_index
					
					if(diff[stats_index])
					{
						len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
							to_save ? "," : "",
							row_weapons_names[id_row],
							row_weapons_names[id_row],
							diff[stats_index]
						)
						
						to_save ++
					}
				}
				
				len += formatex(query[len],charsmax(query) - len,"WHERE `%s` = '%s' AND `%s` = '%d'",
					row_weapons_names[ROW_WEAPON_NAME],log,
					row_weapons_names[ROW_WEAPON_PLAYER],player_data[id][PLAYER_ID]
				)
			}	
		}
		
		if(to_save)
		{
			DB_AddQuery(query,len)
		}
	}
	
	return true
}

DB_AddQuery(query[],len)
{
	if((flush_que_len + len + 1) > charsmax(flush_que))
	{
		DB_FlushQuery()
	}
	
	flush_que_len += formatex(
		flush_que[flush_que_len],
		charsmax(flush_que) - flush_que_len,
		"%s%s",flush_que_len ? ";" : "",
		query
	)
		
	// задание на сброс накопленных запросов
	remove_task(task_flush)
	set_task(0.1,"DB_FlushQuery",task_flush)
}

//
// Сброс накопленных запросов
//
public DB_FlushQuery()
{
	if(flush_que_len)
	{
		new sql_data[1] = SQL_UPDATE
		SQL_ThreadQuery(sql,"SQL_Handler",flush_que,sql_data,sizeof sql_data)
		
		flush_que_len = 0
	}
}

#define falos false

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

new bool:update_cache = false

/*
* сохранение статистики всех игроков
*/
public DB_SaveAll()
{
	new players[32],pnum
	get_players(players,pnum)
	
	if(get_pcvar_num(cvar[CVAR_CACHETIME]) == -1)
	{
		update_cache = true
	}
	
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
		switch(overide_order ? overide_order : get_pcvar_num(cvar[CVAR_RANKFORMULA]))
		{
			case 1: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (kills)>=(a.kills)",tbl_name)
			case 2: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (kills+hs)>=(a.kills+a.hs)",tbl_name)
			case 3: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (skill)>=(a.skill)",tbl_name)
			case 4: return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE (connection_time)>=(a.connection_time)",tbl_name)
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
	return formatex(sql_que,sql_que_len,"SELECT COUNT(*) FROM %s WHERE 1",tbl_name)
}

/*
* запрос на выборку статистики по позиции
*	index - начальная позиция
*	index_count - кол-во выбираемых записей
*/
DB_QueryBuildGetstats(query[],query_max,len = 0,index,index_count = 2,overide_order = 0)
{
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
DB_ReadGetStats(Handle:sqlQue,name[] = "",name_len = 0,authid[] = "",authid_len = 0,stats[8] = 0,hits[8] = 0,stats2[4] = 0,stats3[STATS3_END] = 0,&stats_count = 0,index)
{
	stats_count = SQL_NumResults(sqlQue)
	
	if(!stats_count)
	{
		return false
	}
	
	new stats_cache[stats_cache_struct]
	
	switch(get_pcvar_num(cvar[CVAR_RANK]))
	{
		case 0: SQL_ReadResult(sqlQue,ROW_NAME,stats_cache[CACHE_STEAMID],charsmax(stats_cache[CACHE_STEAMID]))
		case 1: SQL_ReadResult(sqlQue,ROW_STEAMID,stats_cache[CACHE_STEAMID],charsmax(stats_cache[CACHE_STEAMID]))
		case 2: SQL_ReadResult(sqlQue,ROW_IP,stats_cache[CACHE_STEAMID],charsmax(stats_cache[CACHE_STEAMID]))
	}
	
	SQL_ReadResult(sqlQue,ROW_NAME,stats_cache[CACHE_NAME],charsmax(stats_cache[CACHE_NAME]))
	
	copy(name,name_len,stats_cache[CACHE_NAME])
	copy(authid,authid_len,stats_cache[CACHE_STEAMID])
	
	new i
	
	for(i = ROW_SKILL ; i <= ROW_LASTJOIN ; i++)
	{
		switch(i)
		{
			case ROW_SKILL: SQL_ReadResult(sqlQue,i,stats_cache[CACHE_SKILL])
			case ROW_KILLS..ROW_DMG:
			{
				stats_cache[CACHE_STATS][i - ROW_KILLS] = stats[i - ROW_KILLS] = SQL_ReadResult(sqlQue,i)
			}
			case ROW_BOMBDEF..ROW_BOMBEXPLOSIONS:
			{
				stats_cache[CACHE_STATS2][i - ROW_BOMBDEF] = stats2[i - ROW_BOMBDEF] = SQL_ReadResult(sqlQue,i)
			}
			case ROW_H0..ROW_H7:
			{
				stats_cache[CACHE_HITS][i - ROW_H0] = hits[i - ROW_H0] = SQL_ReadResult(sqlQue,i)
			}
			// 0.7
			case ROW_CONNECTS..ROW_ASSISTS:
			{
				stats_cache[CACHE_STATS3][((i - ROW_CONNECTS) + 1)] = stats3[((i - ROW_CONNECTS) + 1)] = SQL_ReadResult(sqlQue,i)
			}
			case ROW_FIRSTJOIN..ROW_LASTJOIN:
			{
				new date_str[32]
				SQL_ReadResult(sqlQue,i,date_str,charsmax(date_str))
							
				stats_cache[(CACHE_FIRSTJOIN + (i - ROW_FIRSTJOIN))] = parse_time(date_str,"%Y-%m-%d %H:%M:%S")
			}
		}
		
	}
	
	// кеширование данных
	if(!stats_cache_trie)
	{
		stats_cache_trie = TrieCreate()
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

//
// Задаем очередь для обновления кеша
//
Cache_Stats_SetQueue(start_index,top)
{
	// очередь уже создана
	if(Cache_Stats_CheckQueue(start_index,top))
	{
		return false
	}
	
	if(!stats_cache_queue)
	{
		stats_cache_queue = ArrayCreate(stats_cache_queue_struct)
	}
	
	new length = ArraySize(stats_cache_queue)
	
	new cache_queue_info[stats_cache_queue_struct]
	cache_queue_info[CACHE_QUE_START] = start_index
	cache_queue_info[CACHE_QUE_TOP] = top
	
	if(!length) // новая очередь
	{
		ArrayPushArray(stats_cache_queue,cache_queue_info)
	}
	else // в топ
	{
		ArrayInsertArrayBefore(stats_cache_queue,0,cache_queue_info)
	}
	
	length ++
	
	if(length > 5) // максимум 5 заданий в очереди
	{
		ArrayDeleteItem(stats_cache_queue,5)
		length --
	}
	
	return true
}

//
// Обновление кеша через очередь
//
Cache_Stats_UpdateQueue()
{
	if(!stats_cache_queue)
	{
		return false
	}
	
	for(new i,length = ArraySize(stats_cache_queue),cache_queue_info[stats_cache_queue_struct] ; i < length ; i++)
	{
		ArrayGetArray(stats_cache_queue,i,cache_queue_info)
		DB_QueryTop15(0,-1,-1,-1,cache_queue_info[CACHE_QUE_START],cache_queue_info[CACHE_QUE_TOP],-1)
	}
	
	return true
}

Cache_Stats_CheckQueue(start_index,top)
{
	if(!stats_cache_queue)
	{
		return false
	}
	
	for(new i,length = ArraySize(stats_cache_queue),cache_queue_info[stats_cache_queue_struct] ; i < length ; i++)
	{
		ArrayGetArray(stats_cache_queue,i,cache_queue_info)
		
		if(start_index == cache_queue_info[0] &&
			top == cache_queue_info[1]
		)
		{
			return true
		}
	}
	
	return false
}

//
// Потоковый запрос на Top15
//
DB_QueryTop15(id,plugin_id,func_id,position,start_index,top,params)
{
	// кеширование
	if((get_pcvar_num(cvar[CVAR_CACHETIME]) != 0) && stats_cache_trie)
	{
		Cache_Stats_SetQueue(start_index,top)
		
		new bool:use_cache = true
		
		// проверяем что требуемые данные есть в кеше
		for(new i =  start_index,index_str[10]; i < (start_index + top) ; i++)
		{
			num_to_str(i,index_str,charsmax(index_str))
			
			if(!TrieKeyExists(stats_cache_trie,index_str))
			{
				use_cache = false
			}
		}
		
		// юзаем кеш
		if(use_cache)
		{
			// вызываем хандлер другого плагина
			
			if(func_id > -1)
			{
				if(callfunc_begin_i(func_id,plugin_id))
				{
					callfunc_push_int(id)
					callfunc_push_int(position)
					callfunc_end()
				}
			}
			
			return true
		}
	}
	// кеширование
	
	// строим новый запрос
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
		case SQL_INITDB:
		{
			DB_InitSeq()
		}
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
				
				// посл подключение и первое подкчлючение
				new date_str[32]
				
				SQL_ReadResult(sqlQue,ROW_FIRSTJOIN,date_str,charsmax(date_str))
				player_data[id][PLAYER_FIRSTJOIN] = parse_time(date_str,"%Y-%m-%d %H:%M:%S")
				SQL_ReadResult(sqlQue,ROW_LASTJOIN,date_str,charsmax(date_str))
				player_data[id][PLAYER_LASTJOIN] = parse_time(date_str,"%Y-%m-%d %H:%M:%S")
				
				// доп. запросы
				player_data[id][PLAYER_RANK] = SQL_ReadResult(sqlQue,row_ids)	// ранк игрока
				statsnum = SQL_ReadResult(sqlQue,row_ids + 1)			// общее кол-во игроков в БД
				
				// статистика попаданий
				for(new i ; i < sizeof player_data[][PLAYER_HITS] ; i++)
				{
					player_data[id][PLAYER_HITS][i] = SQL_ReadResult(sqlQue,ROW_H0 + i)
				}
				
				// 0.7
				for(new i = STATS3_CONNECT ; i < sizeof player_data[][PLAYER_STATS3] ; i++)
				{
					player_data[id][PLAYER_STATS3][i] = player_data[id][PLAYER_STATS3LAST][i] = SQL_ReadResult(sqlQue,(i - 1) + ROW_CONNECTS)
					
					// плюсуем стату подключений
					if(i == STATS3_CONNECT)
					{
						player_data[id][PLAYER_STATS3][i] ++
					}
				}
				
				if(weapon_stats_enabled)
				{
					DB_LoadPlayerWstats(id)
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
				
				// обновляем счетчик общего кол-ва записей
				statsnum++
				
				if(weapon_stats_enabled)
				{
					DB_LoadPlayerWstats(id)
				}
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
			// обновляем позици игроков
			// действие с задержкой, что-бы учесть изменения при множественном обновлении данных
			if(!task_exists(task_rankupdate))
			{
				set_task(0.1,"DB_GetPlayerRanks",task_rankupdate)
			}
			
			new players[MAX_PLAYERS],pnum
			get_players(players,pnum)
			
			for(new i,player ; i < pnum ; i++)
			{
				player = players[i]
				
				if(player_data[player][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[player][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(player)
				}
			}
			
			if(update_cache)
			{
				update_cache = false
				
				Cache_Stats_Update()
				Cache_Stats_UpdateQueue()
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
			
			if(data[3] > -1)
			{
				// вызываем хандлер другого плагина
				if(callfunc_begin_i(data[3],data[2]))
				{
					callfunc_push_int(id)
					callfunc_push_int(data[4])
					callfunc_end()
				}
			}
		}
		
		// 0.7
		case SQL_GETWSTATS:
		{
			new id = data[1]
			
			if(!is_user_connected(id))
			{
				return PLUGIN_HANDLED
			}
			
			const load_index = sizeof player_awstats[][] - 1
			
			// загружаем статистику по оружию
			while(SQL_MoreResults(sqlQue))
			{
				new log[MAX_NAME_LENGTH]
				SQL_ReadResult(sqlQue,ROW_WEAPON_NAME,log,charsmax(log))
				
				new wpn = Info_Weapon_GetId(log)
				
				if(wpn == -1)
				{
					continue
				}
				
				for(new i ; i < STATS_END + HIT_END ; i++)
				{
					player_awstats[id][wpn][i] = SQL_ReadResult(sqlQue,i + ROW_WEAPON_KILLS)
				}
				
				player_awstats[id][wpn][load_index] = _:LOAD_OK
					
				SQL_NextRow(sqlQue)
			}
			
			// помечаем статистику по другим оружиям как новую
			for(new wpn ; wpn < CSX_MAX_WEAPONS ; wpn++)
			{
				if(_:player_awstats[id][wpn][load_index] != _:LOAD_OK)
				{
					player_awstats[id][wpn][load_index] = _:LOAD_NEW
				}
			}
		}
		case SQL_GETSESSID:
		{
			session_id = SQL_ReadResult(sqlQue,0) + 1
			get_mapname(session_map,charsmax(session_map))
			
			DB_InitSeq()
		}
		// get_sestats_thread_sql
		case SQL_GETSESTATS:
		{
			new Array:sestats_array = ArrayCreate(sestats_array_struct)
			new sestats_data[sestats_array_struct]
			
			while(SQL_MoreResults(sqlQue))
			{
				arrayset(sestats_data,0,sestats_array_struct)
				
				// заполняем массив со статой сессии
				for(new i = ROW_MAP_ID ; i <= ROW_MAP_LASTJOIN ; i++)
				{
					switch(i)
					{
						case ROW_MAP_ID: sestats_data[SESTATS_ID] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_PLRID: sestats_data[SESTATS_PLAYERID] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_MAP: SQL_ReadResult(sqlQue,i,sestats_data[SESTATS_MAP],charsmax(sestats_data[SESTATS_MAP]))
						case ROW_MAP_SKILL: SQL_ReadResult(sqlQue,i,sestats_data[SESTATS_SKILL])
						case ROW_MAP_KILLS..ROW_MAP_DMG: sestats_data[SESTATS_STATS][(i - ROW_MAP_KILLS)] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_H0..ROW_MAP_H7: sestats_data[SESTATS_HITS][(i - ROW_MAP_H0)] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_BOMBDEF..ROW_MAP_BOMBEXPLOSIONS: sestats_data[SESTATS_STATS2][(i - ROW_MAP_BOMBDEF)] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_ROUNDT..ROW_MAP_ASSISTS: sestats_data[SESTATS_STATS3][((i - ROW_MAP_ROUNDT) + 1)] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_ONLINETIME: sestats_data[SESTATS_ONLINETIME] = SQL_ReadResult(sqlQue,i)
						case ROW_MAP_FIRSTJOIN,ROW_LASTJOIN:
						{
							new date_str[32]
							SQL_ReadResult(sqlQue,i,date_str,charsmax(date_str))
							
							sestats_data[(SESTATS_FIRSTJOIN + (i - ROW_MAP_FIRSTJOIN))] = parse_time(date_str,"%Y-%m-%d %H:%M:%S")
						}
					}
				}
				
				ArrayPushArray(sestats_array,sestats_data)
				
				SQL_NextRow(sqlQue)
			}
			
			new func_id = data[1]
			new plugin_id = data[2]
			
			if(callfunc_begin_i(func_id,plugin_id))
			{
				callfunc_push_int(int:sestats_array)
				
				// передаваемые данные
				if(dataSize > 3)
				{
					new cb_data[MAX_DATA_PARAMS]
					
					for(new i ; i < (dataSize - 3) ; i++)
					{
						cb_data[i] = data[(3 + i)]
					}
					
					callfunc_push_array(cb_data,(dataSize - 3))
					callfunc_push_int((dataSize - 3))
				}
				
				callfunc_end()
			}
			else
			{
				log_amx("get_sestats_thread_sql callback function failed")
			}
		}
		case SQL_AUTOCLEAR:
		{
			if(SQL_AffectedRows(sqlQue))
			{
				log_amx("deleted %d inactive entries",
					SQL_AffectedRows(sqlQue)
				)
			}
			
			DB_InitSeq()
		}
	}

	return PLUGIN_HANDLED
}

//
// Поиск ID оружия по его лог коду
//
Info_Weapon_GetId(weapon[])
{
	new weapon_info[WEAPON_INFO_SIZE]
	new length = ArraySize(weapons_data)
	
	for(new i ; i < length; i++)
	{
		ArrayGetArray(weapons_data,i,weapon_info)
		
		new weapon_name[MAX_NAME_LENGTH]
		copy(weapon_name,charsmax(weapon_name),weapon_info[MAX_NAME_LENGTH])
		
		if(strcmp(weapon_name,weapon) == 0)
		{
			return i
		}
	}
	
	return -1
}

//
// Поиск лог кода по ID оружия
//
Info_Weapon_GetLog(wpn_id,weapon_name[],len)
{
	if(!(0 < wpn_id < ArraySize(weapons_data)))
	{
		formatex(weapon_name,len,"")
		return
	}
	
	new weapon_info[WEAPON_INFO_SIZE]
	ArrayGetArray(weapons_data,wpn_id,weapon_info)
	
	copy(weapon_name,len,weapon_info[MAX_NAME_LENGTH])
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
	if(!(0 <= %1 < ArraySize(weapons_data))){\
		log_error(AMX_ERR_NATIVE,"Invalid weapon id %d",%1);\
		return 0;\
	}
	
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
	register_native("get_stats2_sql","native_get_stats2")
	register_native("get_user_skill","native_get_user_skill")
	register_native("get_skill","native_get_skill")
	
	// 0.5.1
	register_native("get_user_gametime","native_get_user_gametime")
	register_native("get_stats_gametime","native_get_stats_gametime")
	register_native("get_user_stats_id","native_get_user_stats_id")
	register_native("get_stats_id","native_get_stats_id")
	register_native("update_stats_cache","native_update_stats_cache")
	
	// 0.7
	register_native("get_user_stats3_sql","native_get_user_stats3")
	register_native("get_stats3_sql","native_get_stats3")
	register_native("get_user_wstats_sql","native_get_user_wstats_sql")
	register_native("get_sestats_thread_sql","native_get_sestats_thread_sql")
	register_native("get_sestats_read_count","native_get_sestats_read_count")
	register_native("get_sestats_read_stats","native_get_sestats_read_stats")
	register_native("get_sestats_read_stats2","native_get_sestats_read_stats2")
	register_native("get_sestats_read_stats3","native_get_sestats_read_stats3")
	register_native("get_sestats_read_online","native_get_sestats_read_online")
	register_native("get_sestats_read_skill","native_get_sestats_read_skill")
	register_native("get_sestats_read_map","native_get_sestats_read_map")
	register_native("get_sestats_read_stime","native_get_sestats_read_stime")
	register_native("get_sestats_read_etime","native_get_sestats_read_etime")
	register_native("get_sestats_free","native_get_sestats_free")
	register_native("get_user_firstjoin_sql","native_get_user_firstjoin_sql")
	register_native("get_user_lastjoin_sql","native_get_user_lastjoin_sql")
	
	// 0.7.2
	register_native("xmod_get_maxweapons_sql","native_xmod_get_maxweapons")
}

public native_get_user_firstjoin_sql(plugin_id,params)
{
	new id = get_param(1)
	CHECK_PLAYERRANGE(id)
	
	if(player_data[id][PLAYER_LOADSTATE] == LOAD_NO)
	{
		return -1
	}
	
	return player_data[id][PLAYER_FIRSTJOIN]
}

public native_get_user_lastjoin_sql(plugin_id,params)
{
	new id = get_param(1)
	CHECK_PLAYERRANGE(id)
	
	if(player_data[id][PLAYER_LOADSTATE] == LOAD_NO)
	{
		return -1
	}
	
	return player_data[id][PLAYER_LASTJOIN]
}

public native_get_sestats_read_stime(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	return sestats_data[SESTATS_FIRSTJOIN]
}

public native_get_sestats_read_etime(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	return sestats_data[SESTATS_LASTJOIN]
}

public native_get_sestats_free(plugin_id,params)
{
	new sestats = get_param_byref(1)
	ArrayDestroy(Array:sestats)
	set_param_byref(1,0)
	return true
}

public native_get_sestats_read_map(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	new length = get_param(4)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	return set_string(3,sestats_data[SESTATS_MAP],length)
}

public Float:native_get_sestats_read_skill(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0.0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	return sestats_data[SESTATS_SKILL]
}

public native_get_sestats_read_online(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	return sestats_data[SESTATS_ONLINETIME]
}

public native_get_sestats_read_stats(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	set_array(3,sestats_data[SESTATS_STATS],8)
	set_array(4,sestats_data[SESTATS_HITS],8)
	
	index ++
	
	return (index >= sestats_size) ? 0 : index
}

public native_get_sestats_read_stats2(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 <= index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	set_array(3,sestats_data[SESTATS_STATS2],4)
	
	index ++
	
	return (index >= sestats_size) ? 0 : index
}

public native_get_sestats_read_stats3(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	new index = get_param(2)
	
	new sestats_size = ArraySize(sestats)
	
	if(!(0 < index < sestats_size))
	{
		log_error(AMX_ERR_NATIVE,"Stats index out of range (%d)",index)
		return 0
	}
	
	new sestats_data[sestats_array_struct]
	ArrayGetArray(sestats,index,sestats_data)
	
	set_array(3,sestats_data[SESTATS_STATS3],STATS3_END)
	
	index ++
	
	return (index >= sestats_size) ? 0 : index
}

public native_get_sestats_read_count(plugin_id,params)
{
	new Array:sestats = Array:get_param(1)
	
	return ArraySize(sestats)
}

public native_get_sestats_thread_sql(plugin_id,params)
{
	// статистика по картам выключена
	if(session_id == 0)
	{
		return false
	}
	
	new callback_func[32]
	get_string(2,callback_func,charsmax(callback_func))
	
	new func_id = get_func_id(callback_func,plugin_id)
	
	// функция ответа не найдена
	if(func_id == -1)
	{
		log_error(AMX_ERR_NATIVE,"Callback function ^"%s^" not found",callback_func)
		return false
	}
	
	new data_size = get_param(4)
	
	if(data_size > MAX_DATA_PARAMS)
	{
		log_error(AMX_ERR_NATIVE,"Max data size %d reached.",MAX_DATA_PARAMS)
		return false
	}
	
	// подготавливаем данные
	new sql_data[3 + MAX_DATA_PARAMS],data_array[MAX_DATA_PARAMS]
	
	sql_data[0] = SQL_GETSESTATS
	sql_data[1] = func_id
	sql_data[2] = plugin_id
	
	// передаваемые данные
	if(data_size)
	{
		get_array(3,data_array,data_size)
		
		for(new i ; i < data_size ; i++)
		{
			sql_data[i + 3] = data_array[i]
		}
	}
	
	new player_db_id = get_param(1)	// ищем по ID игрока
	new limit = get_param(5)		// лимит на выборку
	
	new query[QUERY_LENGTH]
	
	formatex(query,charsmax(query),"SELECT * FROM `%s_maps` WHERE `%s` = '%d' ORDER BY `%s` DESC LIMIT %d",
		tbl_name,
		row_weapons_names[ROW_WEAPON_PLAYER],player_db_id,
		row_names[ROW_FIRSTJOIN],limit
	)
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,3 + data_size)
	
	return true
}

public native_get_user_wstats_sql(plugin_id,params)
{
	if(params != 4)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 4, passed %d",params)
		
		return false
	}
	
	if(!weapon_stats_enabled)
	{
		return -1
	}
	
	new player_id = get_param(1)
	CHECK_PLAYERRANGE(player_id)
	
	new weapon_id = get_param(2)
	CHECK_WEAPON(weapon_id)
	
	new stats[8],bh[8]
	
	const stats_index_last = (STATS_END + HIT_END)
	
	for(new i ; i < STATS_END ; i++)
	{
		stats[i] = player_awstats[player_id][weapon_id][i] + player_awstats[player_id][weapon_id][i + stats_index_last]
	}
	
	// игрок не пользовался этим оружием
	if(!stats[STATS_DEATHS] &&  !stats[STATS_SHOTS])
	{
		return false
	}
	
	for(new i = STATS_END ; i < (STATS_END + HIT_END) ; i ++)
	{
		bh[(i - STATS_END)] = player_awstats[player_id][weapon_id][i] + player_awstats[player_id][weapon_id][i + stats_index_last]
	}
	
	set_array(3,stats,sizeof stats)
	set_array(4,bh,sizeof bh)
	
	return true
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
	CHECK_PLAYERRANGE(id)
	
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
	CHECK_PLAYERRANGE(id)
	
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
	CHECK_PLAYERRANGE(id)
	
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
	
	if(index < 0)
		index = 0
	
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
	if(ArraySize(weapons_data) >= CSX_MAX_WEAPONS)
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
	
	CHECK_PLAYERRANGE(att)
	
	new vic = get_param(3)
	
	CHECK_PLAYERRANGE(vic)
	
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
	
	CHECK_PLAYERRANGE(id)
	
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
	
	new weapon_name[MAX_NAME_LENGTH]
	Info_Weapon_GetLog(wpn_id,weapon_name,get_param(3))
	
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
	
	CHECK_PLAYERRANGE(id)
	
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
	
	CHECK_PLAYERRANGE(id)
	
	new wpn_id = get_param(2)
	
	CHECK_WEAPON(wpn_id)
	
	if(wpn_id != 0 && !(0 < wpn_id < CSX_MAX_WEAPONS))
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
	
	CHECK_PLAYERRANGE(id)
	
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
	
	CHECK_PLAYERRANGE(id)
	
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
	
	CHECK_PLAYERRANGE(id)
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
	
	CHECK_PLAYERRANGE(id)
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
	
	CHECK_PLAYERRANGE(id)
	
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
	// ждем начала работы с БД
	if(!is_ready)
	{
		return 0
	}
	
	if(params < 5)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 5, passed %d",params)
		
		return 0
	}
	else if(params > 5 && params != 7)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 7, passed %d",params)
		
		return 0
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
	new name[32],steamid[30],stats[8],hits[8],stats_count
		
	DB_ReadGetStats(sqlQue,
		name,charsmax(name),
		steamid,charsmax(steamid),
		stats,
		hits,
		.stats_count = stats_count,
		.index = index
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
	
	return stats_count > 1 ? index + 1 : 0
}

/*
* Получение статистик по позиции
*
* native get_stats2_sql(index, stats[4], authid[] = "", authidlen = 0)
*/
public native_get_stats2(plugin_id,params)
{
	// ждем начала работы с БД
	if(!is_ready)
	{
		return 0
	}
	
	if(params < 2)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 2, passed %d",params)
		
		return false
	}
	else if(params > 2 && params != 4)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 4, passed %d",params)
		
		return false
	}
	
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_array(2,stats_cache[CACHE_STATS2],sizeof stats_cache[CACHE_STATS2])
		
		if(params == 4)
		{
			set_string(3,stats_cache[CACHE_STEAMID],get_param(4))
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
	new name[32],steamid[30],stats2[4],stats_count
		
	DB_ReadGetStats(sqlQue,
		name,charsmax(name),
		steamid,charsmax(steamid),
		.stats2 = stats2,
		.stats_count = stats_count,
		.index = index
	)
	
	// статистики нет
	if(!stats_count)
	{
		return false
	}
	
	SQL_FreeHandle(sqlQue)
	
	// возвращаем данные натива
	set_array(2,stats2,sizeof player_data[][PLAYER_STATS2])
		
	if(params == 4)
	{
		set_string(3,steamid,get_param(4))
	}
	
	return stats_count > 1 ? index + 1 : 0
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
	// ждем начала работы с БД
	if(!is_ready)
	{
		return false
	}
	
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
	
	return DB_QueryTop15(id,plugin_id,func_id,position,start_index,top,params)
}

// 0.7
/*
* Получение статистик по позиции
*
* native get_stats3_sql(index, stats3[STATS3_END], authid[] = "", authidlen = 0)
*/
public native_get_stats3(plugin_id,params)
{
	// ждем начала работы с БД
	if(!is_ready)
	{
		return 0
	}
	
	if(params < 2)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 2, passed %d",params)
		
		return false
	}
	else if(params > 2 && params != 4)
	{
		log_error(AMX_ERR_NATIVE,"Bad arguments num, expected 4, passed %d",params)
		
		return false
	}
	
	new index = get_param(1)	// индекс в статистике
	
	// кеширование
	new index_str[10],stats_cache[stats_cache_struct]
	num_to_str(index,index_str,charsmax(index_str))
	
	// есть информация в кеше
	if(stats_cache_trie && TrieGetArray(stats_cache_trie,index_str,stats_cache,stats_cache_struct))
	{
		set_array(2,stats_cache[CACHE_STATS3],sizeof stats_cache[CACHE_STATS3])
		
		if(params == 4)
		{
			set_string(3,stats_cache[CACHE_STEAMID],get_param(4))
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
	new name[32],steamid[30],stats3[STATS3_END],stats_count
		
	DB_ReadGetStats(sqlQue,
		name,charsmax(name),
		steamid,charsmax(steamid),
		.stats3 = stats3,
		.stats_count = stats_count,
		.index = index
	)
	
	// статистики нет
	if(!stats_count)
	{
		return false
	}
	
	SQL_FreeHandle(sqlQue)
	
	// возвращаем данные натива
	set_array(2,stats3,sizeof player_data[][PLAYER_STATS3])
		
	if(params == 4)
	{
		set_string(3,steamid,get_param(4))
	}
	
	return stats_count > 1 ? index + 1 : 0
}

/*
* Получение статистик по позиции
*
* native get_user_stats3_sql(id,stats3[STATS3_END])
*/
public native_get_user_stats3(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYERRANGE(id)
	
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // данные отсутствуют
	{
		return 0
	}
	
	set_array(2,player_data[id][PLAYER_STATS3],STATS3_END)
	
	return player_data[id][PLAYER_RANK]
}

public native_get_user_stats2(plugin_id,params)
{
	new id = get_param(1)
	
	CHECK_PLAYERRANGE(id)
	
	set_array(2,player_data[id][PLAYER_STATS2],sizeof player_data[][PLAYER_STATS2])
	
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
	for(new i ; i < CSX_MAX_WEAPONS ; i++)
	{
		arrayset(player_wrstats[index][i],0,sizeof player_wrstats[][])
	}
	
	for(new i ; i < MAX_PLAYERS + 1 ;i++)
	{
		arrayset(player_vstats[index][i],0,sizeof player_vstats[][])
		arrayset(player_astats[index][i],0,sizeof player_astats[][])
	}
	
	return true
}

reset_user_allstats(index)
{
	for(new i ; i < CSX_MAX_WEAPONS ; i++)
	{
		arrayset(player_wstats[index][i],0,sizeof player_wstats[][])
	}
	
	arrayset(player_wstats2[index],0,sizeof player_wstats2[])
	
	return true
}

public DB_OpenConnection()
{
	if(!is_ready)
	{
		return false
	}
	
	if(sql_con != Empty_Handle)
	{
		return true
	}
	
	new errNum,err[256]
	sql_con = SQL_Connect(sql,errNum,err,charsmax(err))
	
	if(errNum)
	{
		log_amx("SQL query failed")
		log_amx("[ %d ] %s",errNum,err)
			
		return false
	}
	
	#if AMXX_VERSION_NUM >= 183
	SQL_SetCharset(sql_con,"utf8")
	#endif
	
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
