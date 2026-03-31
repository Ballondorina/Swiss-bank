-- ============================================================
-- UNDERWORLD v3 — Full Install SQL
-- Run this ONE file on a fresh database.
-- If upgrading from v2, run sql/v3_migration.sql instead.
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
    `id`                       INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`                   INT          NOT NULL,
    `citizen_id`               VARCHAR(64)  NOT NULL,
    `name`                     VARCHAR(128) NOT NULL,
    `rank`                     INT          NOT NULL DEFAULT 1,
    `division`                 VARCHAR(32)  DEFAULT NULL,
    `loyalty`                  INT          NOT NULL DEFAULT 100,
    `weekly_contribution`      BIGINT       NOT NULL DEFAULT 0,
    `total_contribution`       BIGINT       NOT NULL DEFAULT 0,
    `salary`                   INT          NOT NULL DEFAULT 0,
    `mission_cooldown_expires` BIGINT       NOT NULL DEFAULT 0,
    `joined_at`                TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
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
    `description`    VARCHAR(256) DEFAULT NULL,
    `created_at`     TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    `expires_at`     TIMESTAMP   NOT NULL,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_vote_records` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `vote_id`    INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `vote`       ENUM('for', 'against') NOT NULL,
    `voted_at`   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`vote_id`) REFERENCES `uw_votes`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `vote_citizen` (`vote_id`, `citizen_id`)
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

CREATE TABLE IF NOT EXISTS `uw_wars` (
    `id`              INT AUTO_INCREMENT PRIMARY KEY,
    `attacker_org_id` INT       NOT NULL,
    `defender_org_id` INT       NOT NULL,
    `status`          ENUM('pending', 'active', 'ended', 'rejected') DEFAULT 'pending',
    `score_attacker`  INT       NOT NULL DEFAULT 0,
    `score_defender`  INT       NOT NULL DEFAULT 0,
    `winner_org_id`   INT       DEFAULT NULL,
    `vault_wager`     BIGINT    NOT NULL DEFAULT 0,
    `influence_wager` INT       NOT NULL DEFAULT 0,
    `started_at`      TIMESTAMP NULL DEFAULT NULL,
    `ends_at`         TIMESTAMP NULL DEFAULT NULL,
    `ended_at`        TIMESTAMP NULL DEFAULT NULL,
    `created_at`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`attacker_org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`defender_org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_war_kills` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `war_id`     INT         NOT NULL,
    `killer_cid` VARCHAR(64) NOT NULL,
    `killer_org` INT         NOT NULL,
    `victim_cid` VARCHAR(64) NOT NULL,
    `victim_org` INT         NOT NULL,
    `created_at` TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`war_id`) REFERENCES `uw_wars`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `uw_alliances` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `org_id_1`     INT NOT NULL,
    `org_id_2`     INT NOT NULL,
    `status`       ENUM('pending', 'active', 'dissolved') DEFAULT 'pending',
    `initiated_by` INT NOT NULL,
    `created_at`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id_1`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`org_id_2`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `alliance_pair` (`org_id_1`, `org_id_2`)
);

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

CREATE TABLE IF NOT EXISTS `uw_robbery_log` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `org_id`     INT         NOT NULL,
    `citizen_id` VARCHAR(64) NOT NULL,
    `store_id`   INT         NOT NULL DEFAULT 1,
    `payout`     BIGINT      NOT NULL,
    `robbed_at`  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`org_id`) REFERENCES `uw_organizations`(`id`) ON DELETE CASCADE
);
