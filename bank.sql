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

-- 8. Loans table
CREATE TABLE IF NOT EXISTS `swisser_bank_loans` (
  `citizenid` varchar(50) NOT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `original_amount` int(11) NOT NULL DEFAULT 0,
  `interest_rate` float NOT NULL DEFAULT 0.10,
  `due_date` datetime NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `overdue_notified` int(11) NOT NULL DEFAULT 0,   -- highest warning day already sent (1-3)
  `penalty_applied` tinyint(1) NOT NULL DEFAULT 0, -- 1 = 15% penalty already added on day 4
  `account_locked` tinyint(1) NOT NULL DEFAULT 0,  -- 1 = withdrawals/transfers blocked
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration: add new columns if upgrading from an older version
ALTER TABLE `swisser_bank_loans` ADD COLUMN IF NOT EXISTS `overdue_notified` int(11) NOT NULL DEFAULT 0;
ALTER TABLE `swisser_bank_loans` ADD COLUMN IF NOT EXISTS `penalty_applied` tinyint(1) NOT NULL DEFAULT 0;
ALTER TABLE `swisser_bank_loans` ADD COLUMN IF NOT EXISTS `account_locked` tinyint(1) NOT NULL DEFAULT 0;

-- 9. Organization (gang) shared accounts
CREATE TABLE IF NOT EXISTS `swisser_bank_org_accounts` (
  `org_id`     varchar(50)  NOT NULL,
  `label`      varchar(100) NOT NULL DEFAULT 'Organization',
  `balance`    int(11)      NOT NULL DEFAULT 0,
  `account_no` varchar(10)  NOT NULL,
  `created_at` timestamp    NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`org_id`),
  UNIQUE KEY `idx_org_account_no` (`account_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. Org members with roles
CREATE TABLE IF NOT EXISTS `swisser_bank_org_members` (
  `org_id`     varchar(50) NOT NULL,
  `citizenid`  varchar(50) NOT NULL,
  `role`       varchar(20) NOT NULL DEFAULT 'member',
  `added_by`   varchar(50) DEFAULT NULL,
  `added_at`   timestamp   NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`org_id`, `citizenid`),
  KEY `idx_orgmember_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. Org transaction audit log (who did what)
CREATE TABLE IF NOT EXISTS `swisser_bank_org_transactions` (
  `id`          int(11)      NOT NULL AUTO_INCREMENT,
  `org_id`      varchar(50)  NOT NULL,
  `citizenid`   varchar(50)  NOT NULL,
  `player_name` varchar(100) NOT NULL,
  `amount`      int(11)      NOT NULL,
  `type`        varchar(20)  NOT NULL,
  `label`       varchar(255) NOT NULL,
  `date`        timestamp    NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_orgtx_org` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 12. Money laundering queue
CREATE TABLE IF NOT EXISTS `swisser_bank_laundry` (
  `citizenid`    varchar(50) NOT NULL,
  `amount_dirty` int(11)     NOT NULL,
  `amount_clean` int(11)     NOT NULL,
  `ready_at`     int(11)     NOT NULL,
  `collected`    tinyint(1)  NOT NULL DEFAULT 0,
  `created_at`   timestamp   NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;