ALTER TABLE `csstats_players`
	CHANGE `nick` `name` VARCHAR(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
	CHANGE `authid` `steamid` VARCHAR(30) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
	CHANGE `ip` `ip` VARCHAR(16) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
	CHANGE `frags` `kills` INT(11) NOT NULL DEFAULT '0',
	CHANGE `deaths` `deaths` INT(11) NOT NULL DEFAULT '0',
	CHANGE `headshots` `hs` INT(11) NOT NULL DEFAULT '0',
	CHANGE `teamkills` `tks` INT(11) NOT NULL DEFAULT '0',
	CHANGE `shots` `shots` INT(11) NOT NULL DEFAULT '0',
	CHANGE `hits` `hits` INT(11) NOT NULL DEFAULT '0',
	CHANGE `damage` `dmg` INT(11) NOT NULL DEFAULT '0',
	CHANGE `defusing` `bombdef` INT(11) NOT NULL DEFAULT '0',
	CHANGE `defused` `bombdefused` INT(11) NOT NULL DEFAULT '0',
	CHANGE `planted` `bombplants` INT(11) NOT NULL DEFAULT '0',
	CHANGE `explode` `bombexplosions` INT(11) NOT NULL DEFAULT '0',
	CHANGE `gametime` `connection_time` INT(11) NOT NULL DEFAULT '0',
	CHANGE `skill` `skill` FLOAT NOT NULL DEFAULT '0.0'; 
;

ALTER TABLE `csstats_players`
	ADD `h_0` INT NOT NULL DEFAULT '0' AFTER `bombexplosions`,
	ADD `h_1` INT NOT NULL  DEFAULT '0' AFTER `h_0`,
	ADD `h_2` INT NOT NULL  DEFAULT '0' AFTER `h_1`,
	ADD `h_3` INT NOT NULL  DEFAULT '0' AFTER `h_2`,
	ADD `h_4` INT NOT NULL  DEFAULT '0' AFTER `h_3`,
	ADD `h_5` INT NOT NULL  DEFAULT '0' AFTER `h_4`,
	ADD `h_6` INT NOT NULL  DEFAULT '0' AFTER `h_5`,
	ADD `h_7` INT NOT NULL  DEFAULT '0' AFTER `h_6`,
	ADD `first_join` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `h_7`,
	ADD `last_join` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `first_join`
;

UPDATE `csstats_players` SET
	`first_join` = FROM_UNIXTIME(`lasttime`),
	`last_join` = FROM_UNIXTIME(`lasttime`)
WHERE 1;

ALTER TABLE `csstats_players`
	DROP `place`,
	DROP `suicide`,
	DROP `lasttime`,
	DROP `connects`,
	DROP `rounds`,
	DROP `wint`,
	DROP `winct`,
	DROP `ar_addxp`,
	DROP `ar_anew`;
	
ALTER TABLE `csstats_players` CHANGE `steamid` `steamid` VARCHAR(30)   CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL AFTER `id`, CHANGE `skill` `skill` FLOAT   NOT NULL DEFAULT '0' AFTER `ip`, CHANGE `connection_time` `connection_time` INT(11)   NOT NULL DEFAULT '0' AFTER `h_7`

ALTER TABLE `csstats_players`
	ADD `connects` INT NOT NULL DEFAULT '0' AFTER `connection_time`,
	ADD `roundt` INT NOT NULL DEFAULT '0' AFTER `connects`,
	ADD `wint` INT NOT NULL DEFAULT '0' AFTER `roundt`,
	ADD `roundct` INT NOT NULL DEFAULT '0' AFTER `wint`,
	ADD `winct` INT NOT NULL DEFAULT '0' AFTER `roundct`,
	ADD `assists` INT NOT NULL DEFAULT '0' AFTER `winct`;
	ADD `session_id` int(11) DEFAULT NULL AFTER `last_join`,
	ADD `session_map` varchar(32) DEFAULT NULL AFTER `session_id`
;