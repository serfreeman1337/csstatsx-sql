-- phpMyAdmin SQL Dump
-- version 4.2.7.1
-- http://www.phpmyadmin.net
--
-- Хост: 127.0.0.1
-- Время создания: Ноя 10 2015 г., 15:23
-- Версия сервера: 5.5.39
-- Версия PHP: 5.4.31

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- База данных: `amxx`
--

-- --------------------------------------------------------

--
-- Структура таблицы `csstats`
--

CREATE TABLE IF NOT EXISTS `csstats` (
`id` int(11) NOT NULL,
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
  `first_join` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_join` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

--
-- Триггеры `csstats`
--
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

--
-- Indexes for dumped tables
--

--
-- Indexes for table `csstats`
--
ALTER TABLE `csstats`
 ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `csstats`
--
ALTER TABLE `csstats`
MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
