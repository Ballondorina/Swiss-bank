-- ============================================================
-- UNDERWORLD — v3 Migration: Wars, Alliances, Votes, Announcements, Cooldowns
-- Safe to run on existing databases (IF NOT EXISTS / ADD COLUMN guards)
-- ============================================================

-- ============================================================
-- WAR SYSTEM
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_wars` (
    `id`                 INT AUTO_INCREMENT PRIMARY KEY,
    `attacker_org_id`    INT         NOT NULL,
    `defender_org_id`    INT         NOT NULL,
    `status`             ENUM('pending', 'active', 'ended', 'rejected') DEFAULT 'pending',
    `score_attacker`     INT         NOT NULL DEFAULT 0,
    `score_defender`     INT         NOT NULL DEFAULT 0,
    `winner_org_id`      INT         DEFAULT NULL,
    `vault_wager`        BIGINT      NOT NULL DEFAULT 0,
    `influence_wager`    INT         NOT NULL DEFAULT 0,
    `started_at`         TIMESTAMP   NULL DEFAULT NULL,
    `ends_at`            TIMESTAMP   NULL DEFAULT NULL,
    `ended_at`           TIMESTAMP   NULL DEFAULT NULL,
    `created_at`         TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`attacker_org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`defender_org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_war_kills` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `war_id`       INT         NOT NULL,
    `killer_cid`   VARCHAR(64) NOT NULL,
    `killer_org`   INT         NOT NULL,
    `victim_cid`   VARCHAR(64) NOT NULL,
    `victim_org`   INT         NOT NULL,
    `created_at`   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`war_id`) REFERENCES `uw_wars`(`id`) ON DELETE CASCADE
);

-- ============================================================
-- ALLIANCE SYSTEM
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_alliances` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `org_id_1`    INT NOT NULL,
    `org_id_2`    INT NOT NULL,
    `status`      ENUM('pending', 'active', 'dissolved') DEFAULT 'pending',
    `initiated_by` INT NOT NULL,
    `created_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id_1`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`org_id_2`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `alliance_pair` (`org_id_1`, `org_id_2`)
);

-- ============================================================
-- ORG ANNOUNCEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_announcements` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`      INT          NOT NULL,
    `author_cid`  VARCHAR(64)  NOT NULL,
    `author_name` VARCHAR(128) NOT NULL,
    `content`     TEXT         NOT NULL,
    `pinned`      TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

-- ============================================================
-- VOTE RECORDS (individual vote tracking for uw_votes)
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_vote_records` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `vote_id`    INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `vote`       ENUM('for', 'against') NOT NULL,
    `voted_at`   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`vote_id`) REFERENCES `uw_votes`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `vote_citizen` (`vote_id`, `citizen_id`)
);

-- ============================================================
-- PERSISTENT MISSION COOLDOWNS
-- ============================================================

ALTER TABLE `uw_members` ADD COLUMN IF NOT EXISTS `mission_cooldown_expires` BIGINT NOT NULL DEFAULT 0;

-- ============================================================
-- OPTIONAL: Add description column to uw_votes for vote context
-- ============================================================

ALTER TABLE `uw_votes` ADD COLUMN IF NOT EXISTS `description` VARCHAR(256) DEFAULT NULL;

-- ============================================================
-- DRUG LAB SYSTEM (Grand RP-style operations)
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_drug_labs` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`        INT          NOT NULL,
    `lab_type`      VARCHAR(32)  NOT NULL DEFAULT 'cocaine',
    `location_id`   INT          NOT NULL DEFAULT 1,
    `stock`         INT          NOT NULL DEFAULT 0,
    `is_active`     TINYINT(1)   NOT NULL DEFAULT 1,
    `last_produced` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `org_location` (`org_id`, `location_id`)
);

CREATE TABLE IF NOT EXISTS `uw_lab_sell_log` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`      INT          NOT NULL,
    `lab_id`      INT          NOT NULL,
    `citizen_id`  VARCHAR(64)  NOT NULL,
    `units_sold`  INT          NOT NULL,
    `revenue`     BIGINT       NOT NULL,
    `sold_at`     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- STORE ROBBERY COOLDOWNS
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_robbery_log` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`     INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `store_id`   INT         NOT NULL DEFAULT 1,
    `payout`     BIGINT      NOT NULL,
    `robbed_at`  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);
