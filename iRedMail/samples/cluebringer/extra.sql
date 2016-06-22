-- Reference: http://wiki.policyd.org/

-- Priorities (Lower integer has higher priority):
--  priority=6  server-wide Whitelist
--  priority=7  server-wide Blacklist
--  priority=20 No greylisting. Works for both per-domain and per-user account.

-- Cluebringer default priorities:
--  priority=0  Default
--  priority=10 Default Inbound
--  priority=10 Default Outbound

-- Disable unused policy: 'Default'.
UPDATE policies SET Disabled=1 WHERE ID=1;

-- Don't use '%internal_ips' in 'Default Outbound'.
UPDATE policy_members SET Source='%internal_domains' WHERE PolicyID=2;

DELIMITER $$
DROP PROCEDURE IF EXISTS update_policy $$
CREATE PROCEDURE update_policy() BEGIN
-- Add new column: policy_group_members.Type.
-- It's used to identify record type/kind in iRedAdmin-Pro, for easier
-- management of white/blacklists.
--
-- Samples:
--   - Type=ip: value of `Member` is an IP address or CIDR range
--   - Type=sender: a valid full email address
--   - Type=domain: a valid domain name
--
-- We can use multiple policies for different types, but it brings more SQL
-- queries for each policy request, this is not a good idea for performance
-- since Cluebringer is used to process every in/out SMTP session.
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_group_members' AND COLUMN_NAME='Type'
    )
    THEN
        ALTER TABLE policy_group_members ADD COLUMN Type VARCHAR(10) NOT NULL DEFAULT '';
END IF;

IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_group_members' AND index_name='policy_group_members_type'
    )
    THEN
        CREATE INDEX policy_group_members_type ON policy_group_members (Type);
END IF;

IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_group_members' AND index_name='policy_group_members_policygroupid_type'
    )
    THEN
        CREATE INDEX policy_group_members_policygroupid_type ON policy_group_members (PolicyGroupID, Type);
END IF;

-- ------------------------------
-- Whitelists (priority=6)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('whitelists', 6, 0, 'Whitelisted sender, domain, IP') ON DUPLICATE KEY UPDATE Name=Name;

INSERT INTO policy_groups (Name, Disabled) VALUES ('whitelists', 0) ON DUPLICATE KEY UPDATE Name=Name;

IF NOT EXISTS(
        SELECT pm.ID FROM policy_members AS pm JOIN policies AS p ON p.ID=pm.PolicyID 
        WHERE pm.Source='%whitelists' AND pm.Destination='%internal_domains' AND p.Name='whitelists'
    )
    THEN
        INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
            SELECT id, '%whitelists', '%internal_domains', 0
            FROM policies WHERE name='whitelists' LIMIT 1;
END IF;

-- Add access_control record to bypass whitelisted senders
IF NOT EXISTS(
        SELECT a.ID FROM access_control AS a JOIN policies AS p ON p.ID=a.PolicyID 
        WHERE a.Name='bypass_whitelisted' AND a.Verdict='OK' AND a.Data='Whitelisted' AND p.Name='whitelists'
    )
    THEN
        INSERT INTO access_control (PolicyID, Name, Verdict, Data)
            SELECT id, 'bypass_whitelisted', 'OK', 'Whitelisted'
            FROM policies WHERE name='whitelists' LIMIT 1;
END IF;

-- Samples: Add whitelisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, 'user@domain.com', 0, 'sender' FROM policy_groups
--    WHERE name='whitelists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '@domain.com', 0, 'domain' FROM policy_groups
--    WHERE name='whitelists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '123.123.123.123', 0, 'ip' FROM policy_groups
--    WHERE name='whitelists' LIMIT 1;

-- ------------------------------
-- Blacklist (priority=8)
-- ------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description) 
    VALUES ('blacklists', 8, 0, 'Blacklisted sender, domain, IP') ON DUPLICATE KEY UPDATE Name=Name;

INSERT INTO policy_groups (Name, Disabled) VALUES ('blacklists', 0) ON DUPLICATE KEY UPDATE Name=Name;

IF NOT EXISTS(
        SELECT pm.ID FROM policy_members AS pm JOIN policies AS p ON p.ID=pm.PolicyID 
        WHERE pm.Source='%blacklists' AND pm.Destination='%internal_domains' AND p.Name='blacklists'
    )
    THEN
        INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
            SELECT id, '%blacklists', '%internal_domains', 0
            FROM policies WHERE name='blacklists' LIMIT 1;
END IF;

-- Add access control to reject whitelisted senders.
IF NOT EXISTS(
        SELECT a.ID FROM access_control AS a JOIN policies AS p ON p.ID=a.PolicyID 
        WHERE a.Name='reject_blacklisted' AND a.Verdict='REJECT' AND a.Data='Blacklisted' AND p.Name='blacklists'
    )
    THEN
        INSERT INTO access_control (PolicyID, Name, Verdict, Data)
            SELECT id, 'reject_blacklisted', 'REJECT', 'Blacklisted'
            FROM policies WHERE name='blacklists' LIMIT 1;
END IF;

-- Samples: Add blacklisted sender, domain, IP
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, 'user@domain.com', 0, 'sender' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '@domain.com', 0, 'domain' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled, Type)
--    SELECT id, '123.123.123.123', 0, 'ip' FROM policy_groups
--    WHERE name='blacklists' LIMIT 1;

-- ------------------------------------
-- Per-domain and per-user greylisting
-- ------------------------------------
INSERT INTO policies (Name, Priority, Disabled, Description)
    VALUES ('no_greylisting', 20, 0, 'Disable grelisting for certain domain and users') ON DUPLICATE KEY UPDATE Name=Name;

-- No greylisting for certain local domains/users
INSERT INTO policy_groups (Name, Disabled) VALUES ('no_greylisting_for_internal', 0) ON DUPLICATE KEY UPDATE Name=Name;
IF NOT EXISTS(
        SELECT pm.ID FROM policy_members AS pm JOIN policies AS p ON p.ID=pm.PolicyID 
        WHERE pm.Source='!%internal_ips,!%internal_domains' AND pm.Destination='%no_greylisting_for_internal' AND p.Name='no_greylisting'
    )
    THEN
        INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
            SELECT id, '!%internal_ips,!%internal_domains', '%no_greylisting_for_internal', 0
            FROM policies WHERE name='no_greylisting' LIMIT 1;
END IF;

-- No greylisting for certain external domains/users
INSERT INTO policy_groups (Name, Disabled) VALUES ('no_greylisting_for_external', 0) ON DUPLICATE KEY UPDATE Name=Name;
IF NOT EXISTS(
        SELECT pm.ID FROM policy_members AS pm JOIN policies AS p ON p.ID=pm.PolicyID 
        WHERE pm.Source='%no_greylisting_for_external' AND pm.Destination='%internal_domains' AND p.Name='no_greylisting'
    )
    THEN
        INSERT INTO policy_members (PolicyID, Source, Destination, Disabled)
            SELECT id, '%no_greylisting_for_external', '%internal_domains', 0
            FROM policies WHERE name='no_greylisting' LIMIT 1;
END IF;

-- Disable greylisting for %no_greylisting
IF NOT EXISTS(
        SELECT g.ID FROM greylisting AS g JOIN policies AS p ON p.ID=g.PolicyID 
        WHERE g.Name='no_greylisting' AND g.Track='SenderIP:/32' AND p.Name='no_greylisting'
    )
    THEN
        INSERT INTO greylisting (PolicyID, Name, UseGreylisting, Track, UseAutoWhitelist, AutoWhitelistCount, AutoWhitelistPercentage, UseAutoBlacklist, AutoBlacklistCount, AutoBlacklistPercentage, Disabled)
            SELECT id, 'no_greylisting', 0, 'SenderIP:/32', 0, 0, 0, 0, 0, 0, 0
            FROM policies WHERE name='no_greylisting' LIMIT 1;
END IF;

-- Sample: Disable greylisting for certain local domain/users:
-- INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
--    SELECT id, '@domain.com', 0 FROM policy_groups WHERE name='no_greylisting_for_internal' LIMIT 1;

-- ---------------
-- INDEXES
-- ---------------
-- Add indexes for columns used in Cluebringer modules
--
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policies' AND index_name='policies_disabled'
    )
    THEN
        CREATE INDEX policies_disabled ON policies (disabled);
END IF;

-- Used in module: access_control
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='access_control' AND index_name='access_control_policyid_disabled'
    )
    THEN
        CREATE INDEX access_control_policyid_disabled ON access_control (policyid, disabled);
END IF;

-- Used in module: checkhelo
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='checkhelo' AND index_name='checkhelo_policyid_disabled'
    )
    THEN
        CREATE INDEX checkhelo_policyid_disabled ON checkhelo (policyid, disabled);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='checkhelo_whitelist' AND index_name='checkhelo_whitelist_disabled'
    )
    THEN
        CREATE INDEX checkhelo_whitelist_disabled ON checkhelo_whitelist (disabled);
END IF;

-- Used in module: greylisting
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='greylisting' AND index_name='greylisting_policyid_disabled'
    )
    THEN
        CREATE INDEX greylisting_policyid_disabled ON greylisting (policyid, disabled);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='greylisting_whitelist' AND index_name='greylisting_whitelist_disabled'
    )
    THEN
        CREATE INDEX greylisting_whitelist_disabled ON greylisting_whitelist (disabled);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='greylisting_tracking' AND index_name='greylisting_tracking_trackkey_firstseen'
    )
    THEN
        CREATE INDEX greylisting_tracking_trackkey_firstseen ON greylisting_tracking (trackkey, firstseen);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='greylisting_tracking' AND index_name='greylisting_tracking_trackkey_firstseen_count'
    )
    THEN
        CREATE INDEX greylisting_tracking_trackkey_firstseen_count ON greylisting_tracking (trackkey, firstseen, count);
END IF;

-- Used in module: quotas
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='quotas' AND index_name='quotas_policyid_disabled'
    )
    THEN
        CREATE INDEX quotas_policyid_disabled ON quotas (policyid, disabled);
END IF;

-- Used in module: accounting_tracking. Available in cluebringer-2.1.x.
-- CREATE INDEX accounting_policyid_disabled ON accounting (policyid, disabled);
-- CREATE INDEX accounting_tracking_accountingid_trackkey_periodkey ON accounting_tracking (accountingid, trackkey, periodkey);

--
-- Add indexes for columns required by web interface
--
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policies' AND index_name='policies_name'
    )
    THEN
        CREATE UNIQUE INDEX policies_name ON policies (name);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_groups' AND index_name='policy_groups_name'
    )
    THEN
        CREATE UNIQUE INDEX policy_groups_name ON policy_groups (name);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_group_members' AND index_name='policy_group_members_member'
    )
    THEN
        CREATE INDEX policy_group_members_member ON policy_group_members (member);
END IF;

-- Unique index to avoid duplicate records
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='policy_group_members' AND index_name='policy_group_members_policygroupid_member'
    )
    THEN
        CREATE UNIQUE INDEX policy_group_members_policygroupid_member ON policy_group_members (policygroupid, member);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='quotas' AND index_name='quotas_name'
    )
    THEN
        CREATE INDEX quotas_name ON quotas (Name);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='quotas_limits' AND index_name='quotas_limits_quotasid_type'
    )
    THEN
        CREATE UNIQUE INDEX quotas_limits_quotasid_type ON quotas_limits (QuotasID, Type);
END IF;
IF NOT EXISTS(
        SELECT * FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=Database() AND TABLE_NAME='quotas_tracking' AND index_name='quotas_tracking_trackkey'
    )
    THEN
        CREATE INDEX quotas_tracking_trackkey ON quotas_tracking (TrackKey);
END IF;

END;
$$
DELIMITER ;
CALL update_policy();
DROP PROCEDURE update_policy;
