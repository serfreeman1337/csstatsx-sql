//
// CSstatsX SQL API
//

//
// by serfreeman1337 
// Visit: http://1337.uz
//

#pragma reqlib csstatsx_sql

enum _:
{
	CSXSQL_RANK_DEF,
	CSXSQL_RANK_K,
	CSXSQL_RANK_KHS,
	CSXSQL_RANK_SKILL,
	CSXSQL_RANK_TIME
}

enum _:STATS3_END
{
	STATS3_CONNECT,			// player connects
	STATS3_ROUNDT,			// rounds as t
	STATS3_WINT,				// wins as t
	STATS3_ROUNDCT,			// round as ct
	STATS3_WINCT,				// win as ct
	STATS3_CURRENTTEAM		// do not use
}

//
// SQL alternative stats natives from csx module
//
native get_statsnum_sql()
native get_user_stats_sql(index, stats[8], bodyhits[8])
native get_stats_sql(index, stats[8], bodyhits[8], name[], len, authid[] = "", authidlen = 0)
native get_stats2_sql(index, stats2[4], authid[] = "", authidlen = 0)

//
// Perfrom thread query for top15 stats
//	@id - store player id
//	@position - start position
//	@top - top positions
//	@callback - callback function
//		public myHandler(id,pos)
//			@id - stored player id
//			@pos - total stats count
//	@order - custom rank formula for this query 
//
//	@note stats are cached so you can use get_stats and etc. natives to get stats without lags
//
native get_stats_sql_thread(id,position,top,callback[],order = CSXSQL_RANK_DEF)

//
// Get player stats3
//	@id - player id
//	@stats3 - stats3 array
//
//	@return - player rank or 0 on fail
//
native get_user_stats3_sql(id,stats3[STATS3_END])

//
// Get player stats3 by stats index
//	@id - stats index
//	@stats3 - stats3 array
//	@authid - player authid
//	@authidlen - authid len
//
//	@return - next stats index or 0 on last
//
native get_stats3_sql(index, stats3[STATS3_END], authid[] = "", authidlen = 0)

//
// Get skill value by stats index
//	@index - stats index
//	@skill - float value to save skill to
//
//	@return - next stats index or 0 on last
//
native get_skill(index,&Float:skill)

//
// Get player skill value
//	@player - player id
//	@skill - float value to save skill to
//
//	@return - true on success
//		         false on fail
//
native get_user_skill(player,&Float:skill)

//
// Returns player played time in seconds
//	@return - played time in seconds
//			-1 if no played time recorded
//
native get_user_gametime(id)

//
// Get played time by stats index
//	@index - stats index
//	@game_time - integer value to save played time to
//
//	@return - next stats index or 0 on last
//
native get_stats_gametime(index,&game_time)

//
// Get player stats id in database
//	@id - player id
//
//	@return - database id or 0 if no stats record
//
native get_user_stats_id(id)

//
// Get database id by stats index
//	@index - stats index
//	@stats_id - integer value to save played time to
//
//	@return - next stats index or 0 on last
//
native get_stats_id(index,&stats_id)

//
// Refresh stats cache
//
native update_stats_cache()