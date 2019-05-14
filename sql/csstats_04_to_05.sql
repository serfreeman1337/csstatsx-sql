ALTER TABLE `csstats` ADD `connection_time` INT NOT NULL DEFAULT '0' AFTER `hits_xml`;
ALTER TABLE `csstats` ADD KEY `steamid` (`steamid`(16)), ADD KEY `name` (`name`(16)), ADD KEY `ip` (`ip`);