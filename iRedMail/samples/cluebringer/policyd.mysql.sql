SET FOREIGN_KEY_CHECKS=0;


/*
Priorities...
        0      - System policy priority (fallthrough)
        1-50   - System policies
        50-100 - Custom policies
*/

/* Policies */
CREATE TABLE IF NOT EXISTS policies (
        ID                      SERIAL,

        Name                    VARCHAR(255) NOT NULL,

        Priority                SMALLINT NOT NULL,

        Description             TEXT,

        Disabled                SMALLINT NOT NULL DEFAULT '0'

) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

DELIMITER $$
DROP PROCEDURE IF EXISTS insert_policy $$
CREATE PROCEDURE insert_policy() BEGIN
IF NOT EXISTS(
        SELECT ID FROM policies WHERE Name='Default' AND Priority=0
    )
    THEN
        INSERT INTO policies (Name,Priority,Description) VALUES ('Default',0,'Default System Policy');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policies WHERE Name='Default Outbound' AND Priority=10
    )
    THEN
        INSERT INTO policies (Name,Priority,Description) VALUES ('Default Outbound',10,'Default Outbound System Policy');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policies WHERE Name='Default Inbound' AND Priority=10
    )
    THEN
        INSERT INTO policies (Name,Priority,Description) VALUES ('Default Inbound',10,'Default Inbound System Policy');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policies WHERE Name='Default Internal' AND Priority=20
    )
    THEN
        INSERT INTO policies (Name,Priority,Description) VALUES ('Default Internal',20,'Default Internal System Policy');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policies WHERE Name='Test' AND Priority=50
    )
    THEN
        INSERT INTO policies (Name,Priority,Description) VALUES ('Test',50,'Test policy');
END IF;

/* Member list for policies */
CREATE TABLE IF NOT EXISTS policy_members (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        /*
                Format of key:
                NULL = any
                a.b.c.d/e = IP address with optional /e
                @domain = domain specification,
                %xyz = xyz group,
                abc@domain = abc user specification

                all options support negation using !<key>
        */
        Source                  TEXT,
        Destination             TEXT,

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Default System Policy */
IF NOT EXISTS(
        SELECT ID FROM policy_members WHERE PolicyID=1
    )
    THEN
        INSERT INTO policy_members (PolicyID,Source,Destination) VALUES (1,NULL,NULL);
END IF;
/* Default Outbound System Policy */
IF NOT EXISTS(
        SELECT ID FROM policy_members WHERE PolicyID=2
    )
    THEN
        INSERT INTO policy_members (PolicyID,Source,Destination) VALUES (2,'%internal_ips,%internal_domains','!%internal_domains');
END IF;
/* Default Inbound System Policy */
IF NOT EXISTS(
        SELECT ID FROM policy_members WHERE PolicyID=3
    )
    THEN
        INSERT INTO policy_members (PolicyID,Source,Destination) VALUES (3,'!%internal_ips,!%internal_domains','%internal_domains');
END IF;
/* Default Internal System Policy */
IF NOT EXISTS(
        SELECT ID FROM policy_members WHERE PolicyID=4
    )
    THEN
        INSERT INTO policy_members (PolicyID,Source,Destination) VALUES (4,'%internal_ips,%internal_domains','%internal_domains');
END IF;
/* Test Policy */
IF NOT EXISTS(
        SELECT ID FROM policy_members WHERE PolicyID=5
    )
    THEN
        INSERT INTO policy_members (PolicyID,Source,Destination) VALUES (5,'@example.net',NULL);
END IF;

/* Groups usable in ACL */
CREATE TABLE IF NOT EXISTS policy_groups (
        ID                      SERIAL,

        Name                    VARCHAR(255) NOT NULL,


        Disabled                SMALLINT NOT NULL DEFAULT '0',

        Comment                 VARCHAR(1024),


        UNIQUE (Name)
)  ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

INSERT INTO policy_groups (Name) VALUES ('internal_ips') ON DUPLICATE KEY UPDATE Name='internal_ips';
INSERT INTO policy_groups (Name) VALUES ('internal_domains') ON DUPLICATE KEY UPDATE Name='internal_domains';

/* Group members */
CREATE TABLE IF NOT EXISTS policy_group_members (
        ID                      SERIAL,

        PolicyGroupID           BIGINT UNSIGNED,

        /* Format of member: a.b.c.d/e = ip,  @domain = domain, %xyz = xyz group, abc@domain = abc user */
        Member                  VARCHAR(255) NOT NULL,


        Disabled                SMALLINT NOT NULL DEFAULT '0',
        Comment                 VARCHAR(1024),


        FOREIGN KEY (PolicyGroupID) REFERENCES policy_groups(ID)
)  ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

IF NOT EXISTS(
        SELECT ID FROM policy_group_members WHERE PolicyGroupID=1 AND Member='10.0.0.0/8'
    )
    THEN
        INSERT INTO policy_group_members (PolicyGroupID,Member) VALUES (1,'10.0.0.0/8');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policy_group_members WHERE PolicyGroupID=2 AND Member='@example.org'
    )
    THEN
        INSERT INTO policy_group_members (PolicyGroupID,Member) VALUES (2,'@example.org');
END IF;
IF NOT EXISTS(
        SELECT ID FROM policy_group_members WHERE PolicyGroupID=2 AND Member='@example.com'
    )
    THEN
        INSERT INTO policy_group_members (PolicyGroupID,Member) VALUES (2,'@example.com');
END IF;

/* Message session tracking */
CREATE TABLE IF NOT EXISTS session_tracking (
        Instance                VARCHAR(255),
        QueueID                 VARCHAR(255),

        Timestamp               BIGINT NOT NULL,

        ClientAddress           VARCHAR(64),
        ClientName              VARCHAR(255),
        ClientReverseName       VARCHAR(255),

        Protocol                VARCHAR(255),

        EncryptionProtocol      VARCHAR(255),
        EncryptionCipher        VARCHAR(255),
        EncryptionKeySize       VARCHAR(255),

        SASLMethod              VARCHAR(255),
        SASLSender              VARCHAR(255),
        SASLUsername            VARCHAR(255),

        Helo                    VARCHAR(255),

        Sender                  VARCHAR(255),

        Size                    BIGINT UNSIGNED,

        RecipientData           TEXT,  /* Policy state information */

        UNIQUE (Instance),
        INDEX session_tracking_idx1 (QueueID, ClientAddress, Sender),
        INDEX session_tracking_idx2 (Timestamp)
)  ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* SPF checking */

/*
    NULL means to inherit
*/
CREATE TABLE IF NOT EXISTS checkspf (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,

        /* Do we want to use SPF?  1 or 0 */
        UseSPF                          SMALLINT,
        /* Reject when SPF fails */
        RejectFailedSPF                 SMALLINT,
        /* Add SPF header */
        AddSPFHeader                    SMALLINT,

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Plain and simple access control */

CREATE TABLE IF NOT EXISTS access_control (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,

        Verdict                 VARCHAR(255),
        Data                    TEXT,


        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* INSERT INTO access_control (PolicyID,Verdict,Data) VALUES (5,'REJECT','POP,SNAPPLE,CRAK'); */

/* Helo checking */

/*
    NULL means to inherit
*/
CREATE TABLE IF NOT EXISTS checkhelo (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,


        /* Blacklisting, we want to reject people impersonating us */
        UseBlacklist                    SMALLINT,  /* Checks blacklist table */
        BlacklistPeriod                 BIGINT UNSIGNED,  /* Period to keep the host blacklisted for, if not set or 0
                                                    the check will be live */

        /* Random helo prevention */
        UseHRP                          SMALLINT,  /* Use helo randomization prevention */
        HRPPeriod                       BIGINT UNSIGNED,  /* Period/window we check for random helo's */
        HRPLimit                        BIGINT UNSIGNED,  /* Our limit for the number of helo's is this */

        /* RFC compliance options */
        RejectInvalid                   SMALLINT,  /* Reject invalid HELO */
        RejectIP                        SMALLINT,  /* Reject if HELO is an IP */
        RejectUnresolvable              SMALLINT,  /* Reject unresolvable HELO */


        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Blacklisted HELO's */
CREATE TABLE IF NOT EXISTS checkhelo_blacklist (
        ID                      SERIAL,

        Helo                    VARCHAR(255) NOT NULL,

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        UNIQUE (Helo)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

INSERT INTO checkhelo_blacklist (Helo,Comment) VALUES
        ('127.0.0.1','Blacklist hosts claiming to be 127.0.0.1') ON DUPLICATE KEY UPDATE Helo='127.0.0.1';

INSERT INTO checkhelo_blacklist (Helo,Comment) VALUES
        ('[127.0.0.1]','Blacklist hosts claiming to be [127.0.0.1]') ON DUPLICATE KEY UPDATE Helo='[127.0.0.1]';

INSERT INTO checkhelo_blacklist (Helo,Comment) VALUES
        ('localhost','Blacklist hosts claiming to be localhost') ON DUPLICATE KEY UPDATE Helo='localhost';

INSERT INTO checkhelo_blacklist (Helo,Comment) VALUES
        ('localhost.localdomain','Blacklist hosts claiming to be localhost.localdomain') ON DUPLICATE KEY UPDATE Helo='localhost.localdomain';

/* Whitelisted CIDR's */
CREATE TABLE IF NOT EXISTS checkhelo_whitelist (
        ID                      SERIAL,

        Source                  VARCHAR(512) NOT NULL,  /* Valid format is:    SenderIP:a.b.c.d[/e]  */

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        UNIQUE (Source)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;


/* Helo tracking table */
CREATE TABLE IF NOT EXISTS checkhelo_tracking (
        Address                 VARCHAR(64) NOT NULL,
        Helo                    VARCHAR(255) NOT NULL,
        LastUpdate              BIGINT UNSIGNED NOT NULL,

        UNIQUE (Address,Helo),
        INDEX checkhelo_tracking_idx1 (`LastUpdate`)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Amavisd-new integration for Policyd */

CREATE TABLE IF NOT EXISTS amavis_rules (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,

/*
Mode of operation (the _m columns):

        This is done with the _m column names

        0 - Inherit
        1 - Merge  (only valid for lists)
        2 - Overwrite

*/


        /* Bypass options */
        bypass_virus_checks     SMALLINT,
        bypass_virus_checks_m   SMALLINT NOT NULL DEFAULT '0',

        bypass_banned_checks    SMALLINT,
        bypass_banned_checks_m  SMALLINT NOT NULL DEFAULT '0',

        bypass_spam_checks      SMALLINT,
        bypass_spam_checks_m    SMALLINT NOT NULL DEFAULT '0',

        bypass_header_checks    SMALLINT,
        bypass_header_checks_m  SMALLINT NOT NULL DEFAULT '0',


        /* Anti-spam options: NULL = inherit */
        spam_tag_level          FLOAT,
        spam_tag_level_m        SMALLINT NOT NULL DEFAULT '0',

        spam_tag2_level         FLOAT,
        spam_tag2_level_m       SMALLINT NOT NULL DEFAULT '0',

        spam_tag3_level         FLOAT,
        spam_tag3_level_m       SMALLINT NOT NULL DEFAULT '0',

        spam_kill_level         FLOAT,
        spam_kill_level_m       SMALLINT NOT NULL DEFAULT '0',

        spam_dsn_cutoff_level   FLOAT,
        spam_dsn_cutoff_level_m SMALLINT NOT NULL DEFAULT '0',

        spam_quarantine_cutoff_level    FLOAT,
        spam_quarantine_cutoff_level_m  SMALLINT NOT NULL DEFAULT '0',

        spam_modifies_subject   SMALLINT,
        spam_modifies_subject_m SMALLINT NOT NULL DEFAULT '0',

        spam_tag_subject        VARCHAR(255),  /* _SCORE_ is the score, _REQD_ is the required score */
        spam_tag_subject_m      SMALLINT NOT NULL DEFAULT '0',

        spam_tag2_subject       VARCHAR(255),
        spam_tag2_subject_m     SMALLINT NOT NULL DEFAULT '0',

        spam_tag3_subject       VARCHAR(255),
        spam_tag3_subject_m     SMALLINT NOT NULL DEFAULT '0',


        /* General checks: NULL = inherit */
        max_message_size        BIGINT,  /* in Kbyte */
        max_message_size_m      SMALLINT NOT NULL DEFAULT '0',

        banned_files            TEXT,
        banned_files_m          SMALLINT NOT NULL DEFAULT '0',


        /* Whitelist & blacklist */
        sender_whitelist        TEXT,
        sender_whitelist_m      SMALLINT NOT NULL DEFAULT '0',
 
        sender_blacklist        TEXT,
        sender_blacklist_m      SMALLINT NOT NULL DEFAULT '0',


        /* Admin notifications */
        notify_admin_newvirus   VARCHAR(255),
        notify_admin_newvirus_m SMALLINT NOT NULL DEFAULT '0',

        notify_admin_virus      VARCHAR(255),
        notify_admin_virus_m    SMALLINT NOT NULL DEFAULT '0',

        notify_admin_spam       VARCHAR(255),
        notify_admin_spam_m     SMALLINT NOT NULL DEFAULT '0',

        notify_admin_banned_file        VARCHAR(255),
        notify_admin_banned_file_m      SMALLINT NOT NULL DEFAULT '0',

        notify_admin_bad_header VARCHAR(255),
        notify_admin_bad_header_m       SMALLINT NOT NULL DEFAULT '0',


        /* Quarantine options */
        quarantine_virus        VARCHAR(255),
        quarantine_virus_m      SMALLINT NOT NULL DEFAULT '0',

        quarantine_banned_file  VARCHAR(255),
        quarantine_banned_file_m        SMALLINT NOT NULL DEFAULT '0',
 
        quarantine_bad_header   VARCHAR(255),
        quarantine_bad_header_m SMALLINT NOT NULL DEFAULT '0',

        quarantine_spam         VARCHAR(255),
        quarantine_spam_m       SMALLINT NOT NULL DEFAULT '0',


        /* Interception options */
        bcc_to                  VARCHAR(255),
        bcc_to_m                SMALLINT NOT NULL DEFAULT '0',


        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

IF NOT EXISTS(
        SELECT ID FROM amavis_rules WHERE PolicyID=1 AND Name='Default system amavis policy'
    )
    THEN
        INSERT INTO amavis_rules (PolicyID, Name, max_message_size,max_message_size_m, bypass_banned_checks, bypass_banned_checks_m)
                        VALUES (1, 'Default system amavis policy', 100000, 2, 1, 2 );
END IF;

/* Greylisting */

/*
    NULL means to inherit
*/
CREATE TABLE IF NOT EXISTS greylisting (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,


        /* General greylisting settings */
        UseGreylisting                  SMALLINT,  /* Actually use greylisting */
        GreylistPeriod                  BIGINT UNSIGNED,  /* Period in seconds to greylist for */

        /* Record tracking */
        Track                           VARCHAR(255) NOT NULL DEFAULT "",  /* Format:   <type>:<spec>
                                                        SenderIP - This takes a bitmask to mask the IP with, A good default is /24
                                                */

        /* Bypass greylisting: sender+recipient level */
        GreylistAuthValidity            BIGINT UNSIGNED,  /* Period for which last authenticated greylist entry is valid for.
                                                    This effectively bypasses greylisting for the second email a sender
                                                    sends a recipient. */
        GreylistUnAuthValidity          BIGINT UNSIGNED,  /* Same as above but for unauthenticated entries */


        /* Auto-whitelisting: sending server level */
        UseAutoWhitelist                SMALLINT,  /* Use auto-whitelisting */
        AutoWhitelistPeriod             BIGINT UNSIGNED,  /* Period to look back to find authenticated triplets */
        AutoWhitelistCount              BIGINT UNSIGNED,  /* Count of authenticated triplets after which we auto-whitelist */
        AutoWhitelistPercentage         BIGINT UNSIGNED,  /* Percentage of at least Count triplets that must be authenticated
                                                           before auto-whitelisting. This changes the behaviour or Count */

        /* Auto-blacklisting: sending server level */
        UseAutoBlacklist                SMALLINT,  /* Use auto-blacklisting */
        AutoBlacklistPeriod             BIGINT UNSIGNED,  /* Period to look back to find unauthenticated triplets */
        AutoBlacklistCount              BIGINT UNSIGNED,  /* Count of authenticated triplets after which we auto-whitelist */
        AutoBlacklistPercentage         BIGINT UNSIGNED,  /* Percentage of at least Count triplets that must be authenticated
                                                           before auto-whitelisting. This changes the behaviour or Count */

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Whitelisted */
CREATE TABLE IF NOT EXISTS greylisting_whitelist (
        ID                      SERIAL,

        Source                  VARCHAR(255) NOT NULL,  /* Either CIDR  a.b.c.d, a.b.c.d/x, or reversed   host*-*.whatever.com */

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        UNIQUE (Source)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;



/* Auto-whitelistings */
CREATE TABLE IF NOT EXISTS greylisting_autowhitelist (
        ID                      SERIAL,

        TrackKey                VARCHAR(512) NOT NULL DEFAULT "",

        Added                   BIGINT UNSIGNED NOT NULL,
        LastSeen                BIGINT UNSIGNED NOT NULL,

        Comment                 VARCHAR(1024),

        UNIQUE (TrackKey)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Auto-blacklistings */
CREATE TABLE IF NOT EXISTS greylisting_autoblacklist (
        ID                      SERIAL,

        TrackKey                VARCHAR(512) NOT NULL DEFAULT "",

        Added                   BIGINT UNSIGNED NOT NULL,

        Comment                 VARCHAR(1024),

        UNIQUE (TrackKey)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;



/* Greylist triplet tracking table */
CREATE TABLE IF NOT EXISTS greylisting_tracking (

        TrackKey                VARCHAR(512) NOT NULL DEFAULT "", /* The address really, masked with whatever */
        Sender                  VARCHAR(255) NOT NULL,
        Recipient               VARCHAR(255) NOT NULL,

        FirstSeen               BIGINT UNSIGNED NOT NULL,
        LastUpdate              BIGINT UNSIGNED NOT NULL,

        Tries                   BIGINT UNSIGNED NOT NULL,  /* Authentication tries */
        Count                   BIGINT UNSIGNED NOT NULL,  /* Authenticated count */

        UNIQUE(TrackKey,Sender,Recipient),
        INDEX greylisting_tracking_idx1 (`LastUpdate`, `Count`)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;

/* Main quotas table, this defines the period the quota is over and how to track it */
CREATE TABLE IF NOT EXISTS quotas (
        ID                      SERIAL,

        PolicyID                BIGINT UNSIGNED,

        Name                    VARCHAR(255) NOT NULL,

        /* Tracking Options */
        Track                   VARCHAR(255) NOT NULL DEFAULT "",  /* Format:   <type>:<spec>

                                              SenderIP - This takes a bitmask to mask the IP with. A good default is /24

                                              Sender & Recipient - Either "user@domain" (default), "user@" or "@domain" for the entire
                                                        email addy or email addy domain respectively.
                                           */

        /* Period over which this policy is valid,  this is in seconds */
        Period                  BIGINT UNSIGNED,

        Verdict                 VARCHAR(255),
        Data                    TEXT,

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (PolicyID) REFERENCES policies(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;
IF NOT EXISTS(
        SELECT ID FROM quotas WHERE PolicyID=5 AND Name='Recipient quotas' AND Track='Recipient:user@domain'
    )
    THEN
        INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict) VALUES (5,'Recipient quotas','Recipient:user@domain',3600,'REJECT');
END IF;
IF NOT EXISTS(
        SELECT ID FROM quotas WHERE PolicyID=5 AND Name='Quota on all /24s' AND Track='SenderIP:/24'
    )
    THEN
        INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict) VALUES (5,'Quota on all /24s','SenderIP:/24',3600,'REJECT');
END IF;

/* Limits for the quota */
CREATE TABLE IF NOT EXISTS quotas_limits (
        ID                      SERIAL,

        QuotasID                BIGINT UNSIGNED,

        Type                    VARCHAR(255),  /* "MessageCount" or "MessageCumulativeSize" */
        CounterLimit            BIGINT UNSIGNED,

        Comment                 VARCHAR(1024),

        Disabled                SMALLINT NOT NULL DEFAULT '0',

        FOREIGN KEY (QuotasID) REFERENCES quotas(ID)
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;
IF NOT EXISTS(
        SELECT ID FROM quotas_limits WHERE QuotasID=1 AND Type='MessageCount'
    )
    THEN
        INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES (1,'MessageCount',10);
END IF;
IF NOT EXISTS(
        SELECT ID FROM quotas_limits WHERE QuotasID=1 AND Type='MessageCumulativeSize'
    )
    THEN
        INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES (1,'MessageCumulativeSize',8000);
END IF;
IF NOT EXISTS(
        SELECT ID FROM quotas_limits WHERE QuotasID=2 AND Type='MessageCount'
    )
    THEN
        INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES (2,'MessageCount',12);
END IF;

/* This table is used for tracking the quotas */
CREATE TABLE IF NOT EXISTS quotas_tracking (

        QuotasLimitsID          BIGINT UNSIGNED,
        TrackKey                VARCHAR(512),

        /* Last time this record was update */
        LastUpdate              BIGINT UNSIGNED,  /* NULL means not updated yet */

        Counter                 NUMERIC(10,4),

        UNIQUE (QuotasLimitsID,TrackKey),
        INDEX quotas_tracking_idx1 (LastUpdate),
        FOREIGN KEY (QuotasLimitsID) REFERENCES quotas_limits(ID)
        
) ENGINE=InnoDB CHARACTER SET latin1 COLLATE latin1_bin;
END;
$$
DELIMITER ;
CALL insert_policy();
DROP PROCEDURE insert_policy;