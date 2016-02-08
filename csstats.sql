CREATE TABLE IF NOT EXISTS `csstats` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`steamid` varchar(30) NOT NULL,
	`name` varchar(32) NOT NULL,
	`ip` varchar(16) NOT NULL,
	`kills` int(11) NOT NULL DEFAULT '0',
	`deaths` int(11) NOT NULL DEFAULT '0',
	`hs` int(11) NOT NULL DEFAULT '0',
	`tks` int(11) NOT NULL DEFAULT '0',
	`shots` int(11) NOT NULL DEFAULT '0',
	`hits` int(11) NOT NULL DEFAULT '0',
	`dmg` int(11) NOT NULL DEFAULT '0',
	`bombdef` int(11) NOT NULL DEFAULT '0',
	`bombdefused` int(11) NOT NULL DEFAULT '0',
	`bombplants` int(11) NOT NULL DEFAULT '0',
	`bombexplosions` int(11) NOT NULL DEFAULT '0',
	`hits_xml` tinytext NOT NULL,
	`connection_time` int(11) NOT NULL,
	`first_join` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`last_join` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (id),
	KEY `steamid` (`steamid`(16)),
	KEY `name` (`name`(16)),
	KEY `ip` (`ip`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

DELIMITER //
CREATE TRIGGER `hits_xml update` BEFORE UPDATE ON `csstats`
 FOR EACH ROW BEGIN
	IF (NEW.hits_xml != OLD.hits_xml) THEN
	SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[1]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[1]') + 							ExtractValue(NEW.hits_xml,'//i[1]'),
			'</i>')
	);
	SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[2]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[2]') + 							ExtractValue(NEW.hits_xml,'//i[2]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[3]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[3]') + 							ExtractValue(NEW.hits_xml,'//i[3]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[4]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[4]') + 							ExtractValue(NEW.hits_xml,'//i[4]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[5]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[5]') + 							ExtractValue(NEW.hits_xml,'//i[5]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[6]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[6]') + 							ExtractValue(NEW.hits_xml,'//i[6]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[7]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[7]') + 							ExtractValue(NEW.hits_xml,'//i[7]'),
			'</i>')
	);
    SET NEW.hits_xml = 
		UpdateXml(NEW.hits_xml,
			'//i[8]',
			CONCAT('<i>',
				ExtractValue(OLD.hits_xml,'//i[8]') + 							ExtractValue(NEW.hits_xml,'//i[8]'),
			'</i>')
	);
END IF;
END
//
DELIMITER ;