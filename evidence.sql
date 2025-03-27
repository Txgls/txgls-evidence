ALTER TABLE `players` 
ADD COLUMN IF NOT EXISTS `blood_type` VARCHAR(10) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS `weapon_serials` (
  `citizenid` VARCHAR(50) NOT NULL,
  `weapon_name` VARCHAR(50) NOT NULL,
  `serial` VARCHAR(20) NOT NULL,
  PRIMARY KEY (`citizenid`, `weapon_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX IF NOT EXISTS `idx_weapon_serials_serial` ON `weapon_serials` (`serial`);
