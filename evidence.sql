-- Create blood type table if not exists
CREATE TABLE IF NOT EXISTS `player_blood` (
  `citizenid` varchar(50) NOT NULL,
  `blood_type` varchar(3) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`citizenid`),
  CONSTRAINT `fk_player_blood_players` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Optional: Evidence tracking table
CREATE TABLE IF NOT EXISTS `evidence_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evidence_id` varchar(50) NOT NULL,
  `evidence_type` enum('casing','blood') NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `officer_id` varchar(50) DEFAULT NULL,
  `collected_at` timestamp NULL DEFAULT NULL,
  `weapon_hash` int(11) DEFAULT NULL,
  `weapon_serial` varchar(20) DEFAULT NULL,
  `blood_type` varchar(3) DEFAULT NULL,
  `status` enum('collected','processed','archived') DEFAULT 'collected',
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `officer_id` (`officer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;