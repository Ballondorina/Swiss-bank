-- ============================================================
-- UNDERWORLD — Database Schema v2
-- ============================================================

CREATE TABLE IF NOT EXISTS `uw_organizations` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `name`        VARCHAR(64)  NOT NULL UNIQUE,
    `label`       VARCHAR(128) NOT NULL,
    `type`        ENUM('legal', 'illegal', 'family') NOT NULL DEFAULT 'illegal',
    `tier`        INT          NOT NULL DEFAULT 1,
    `vault`       BIGINT       NOT NULL DEFAULT 0,
    `heat`        INT          NOT NULL DEFAULT 0,
    `xp`          INT          NOT NULL DEFAULT 0,
    `level`       INT          NOT NULL DEFAULT 1,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `last_active` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `uw_members` (
    `id`                  INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`              INT          NOT NULL,
    `citizen_id`          VARCHAR(64)  NOT NULL,
    `name`                VARCHAR(128) NOT NULL,
    `rank`                INT          NOT NULL DEFAULT 1,
    `division`            VARCHAR(32)  DEFAULT NULL,
    `loyalty`             INT          NOT NULL DEFAULT 100,
    `weekly_contribution` BIGINT       NOT NULL DEFAULT 0,
    `total_contribution`  BIGINT       NOT NULL DEFAULT 0,
    `salary`              INT          NOT NULL DEFAULT 0,
    `joined_at`           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `citizen_org` (`citizen_id`, `org_id`)
);

CREATE TABLE IF NOT EXISTS `uw_ledger` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`      INT          NOT NULL,
    `citizen_id`  VARCHAR(64)  DEFAULT NULL,
    `type`        VARCHAR(32)  NOT NULL,
    `amount`      BIGINT       NOT NULL,
    `description` VARCHAR(256) DEFAULT NULL,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_daily_missions` (
    `id`              INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`          INT         NOT NULL,
    `mission_type`    VARCHAR(64) NOT NULL,
    `status`          ENUM('pending', 'active', 'completed', 'failed', 'expired') DEFAULT 'pending',
    `assigned_to`     VARCHAR(64) DEFAULT NULL,
    `reward`          INT         NOT NULL DEFAULT 0,
    `pickup_coords`   TEXT        DEFAULT NULL,
    `delivery_coords` TEXT        DEFAULT NULL,
    `zone_id`         VARCHAR(32) DEFAULT NULL,
    `started_at`      TIMESTAMP   NULL DEFAULT NULL,
    `completed_at`    TIMESTAMP   NULL DEFAULT NULL,
    `expires_at`      TIMESTAMP   NOT NULL,
    `created_at`      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_passive_log` (
    `id`                 INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`             INT    NOT NULL,
    `amount`             BIGINT NOT NULL,
    `missions_completed` INT    NOT NULL DEFAULT 0,
    `missions_required`  INT    NOT NULL DEFAULT 0,
    `paid_at`            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `uw_withdraw_log` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`     INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `amount`     BIGINT      NOT NULL,
    `date`       DATE        NOT NULL DEFAULT (CURDATE()),
    `created_at` TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `uw_votes` (
    `id`             INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`         INT         NOT NULL,
    `type`           VARCHAR(32) NOT NULL,
    `target_citizen` VARCHAR(64) DEFAULT NULL,
    `initiated_by`   VARCHAR(64) NOT NULL,
    `votes_for`      INT         NOT NULL DEFAULT 0,
    `votes_against`  INT         NOT NULL DEFAULT 0,
    `total_eligible` INT         NOT NULL DEFAULT 0,
    `status`         ENUM('active', 'passed', 'failed') DEFAULT 'active',
    `created_at`     TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    `expires_at`     TIMESTAMP   NOT NULL
);

CREATE TABLE IF NOT EXISTS `uw_influence` (
    `id`            INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`        INT         NOT NULL,
    `zone_id`       VARCHAR(32) NOT NULL,
    `score`         INT         NOT NULL DEFAULT 0,
    `last_activity` TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `org_zone` (`org_id`, `zone_id`)
);

CREATE TABLE IF NOT EXISTS `uw_creation_log` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`     INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `fee_paid`   BIGINT      NOT NULL,
    `created_at` TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MIGRATION: Add columns to existing installs
-- (Safe to run on a fresh install too — IF NOT EXISTS guards above handle it)
-- ============================================================

-- Run these manually on existing databases:
-- ALTER TABLE uw_organizations ADD COLUMN IF NOT EXISTS xp INT NOT NULL DEFAULT 0;
-- ALTER TABLE uw_organizations ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1;
-- ALTER TABLE uw_daily_missions ADD COLUMN IF NOT EXISTS zone_id VARCHAR(32) DEFAULT NULL;
