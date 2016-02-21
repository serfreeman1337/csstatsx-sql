ALTER TABLE `csstats`
	ADD `skill` INT NOT NULL DEFAULT '0.0' AFTER `ip`,
	ADD `h_0` INT NOT NULL AFTER `hits_xml`,
	ADD `h_1` INT NOT NULL AFTER `h_0`,
	ADD `h_2` INT NOT NULL AFTER `h_1`,
	ADD `h_3` INT NOT NULL AFTER `h_2`,
	ADD `h_4` INT NOT NULL AFTER `h_3`,
	ADD `h_5` INT NOT NULL AFTER `h_4`,
	ADD `h_6` INT NOT NULL AFTER `h_5`,
	ADD `h_7` INT NOT NULL AFTER `h_6`;
UPDATE `csstats` SET
	`h_0` = ExtractValue(`hits_xml`,'//i[1]'),
	`h_1` = ExtractValue(`hits_xml`,'//i[2]'),
	`h_2` = ExtractValue(`hits_xml`,'//i[3]'),
	`h_3` = ExtractValue(`hits_xml`,'//i[4]'),
	`h_4` = ExtractValue(`hits_xml`,'//i[5]'),
	`h_5` = ExtractValue(`hits_xml`,'//i[6]'),
	`h_6` = ExtractValue(`hits_xml`,'//i[7]'),
	`h_6` = ExtractValue(`hits_xml`,'//i[8]')
WHERE 1;
ALTER TABLE `csstats` DROP `hits_xml`;