ALTER TABLE `csstats`
	ADD `connects` INT NOT NULL DEFAULT '0' AFTER `connection_time`,
	ADD `roundt` INT NOT NULL DEFAULT '0' AFTER `connects`,
	ADD `wint` INT NOT NULL DEFAULT '0' AFTER `roundt`,
	ADD `roundct` INT NOT NULL DEFAULT '0' AFTER `wint`,
	ADD `winct` INT NOT NULL DEFAULT '0' AFTER `roundct`;