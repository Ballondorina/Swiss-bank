-- 1. Ensure the pins table exists first
CREATE TABLE IF NOT EXISTS `swisser_bank_pins` (
  `citizenid` varchar(50) NOT NULL,
  `pin` varchar(10) NOT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Add the account_no column if it doesn't exist
ALTER TABLE `swisser_bank_pins` ADD COLUMN IF NOT EXISTS `account_no` VARCHAR(10) DEFAULT NULL;
ALTER TABLE `swisser_bank_pins` ADD UNIQUE INDEX IF NOT EXISTS `idx_account_no` (`account_no`);

-- 3. Transactions table
CREATE TABLE IF NOT EXISTS `swisser_bank_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `amount` int(11) NOT NULL,
  `type` varchar(50) NOT NULL,
  `label` varchar(255) NOT NULL,
  `account` varchar(50) DEFAULT 'personal',
  `date` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Goals table
CREATE TABLE IF NOT EXISTS `swisser_bank_goals` (
  `citizenid` varchar(50) NOT NULL,
  `title` varchar(100) DEFAULT 'My Savings Goal',
  `target` int(11) DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Mails table
CREATE TABLE IF NOT EXISTS `swisser_bank_mails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `subject` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `sender` varchar(100) NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `date` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_mail_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Custom Cards table
CREATE TABLE IF NOT EXISTS `swisser_bank_cards` (
  `citizenid` varchar(50) NOT NULL,
  `url` text NOT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Custom Avatars table
CREATE TABLE IF NOT EXISTS `swisser_bank_avatars` (
  `citizenid` varchar(50) NOT NULL,
  `url` text NOT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;