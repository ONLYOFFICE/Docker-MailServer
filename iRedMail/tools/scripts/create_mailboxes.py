#!/usr/bin/env python3

import pkg_resources, sys
from pkg_resources import DistributionNotFound, VersionConflict

def exception_handler(exception_type, exception, traceback):
    print("%s: %s" % (exception_type.__name__, exception))

sys.excepthook = exception_handler

dependencies = [
  'mysql-connector',
  'ArgumentParser'
]

pkg_resources.require(dependencies)

import os, subprocess, json, string, csv, crypt, base64
import mysql.connector
from mysql.connector import Error
from mysql.connector import errorcode
from argparse import ArgumentParser
from getpass import getpass
from datetime import datetime

parser = ArgumentParser(description="""Create mailboxes in ONLYOFFICE Mail Server""")
parser.add_argument('-d', dest='mysql_host', required=True, help='mysql domain/ip')
parser.add_argument('-u', dest='mysql_admin', required=True, help='mysql admin user account')
parser.add_argument('-p', dest='mysql_password', help='mysql admin password will be prompted for if not provided')
parser.add_argument('-dn', dest='db_name', required=True, help="mysql db name")
parser.add_argument('-mb', dest='mb_file', required=True, help="mailboxes file path")
 
args = parser.parse_args()

if not args.mysql_password:
    args.mysql_password = getpass()

def main():
    HOST = args.mysql_host
    PORT = "3306"
    LOGIN = args.mysql_admin
    PASSWORD = args.mysql_password
    DB_NAME = args.db_name
    MAILBOXES_FILE = args.mb_file

    print('\n___ VARIABLES ___\n')
    print(("HOST: " + HOST))
    print(("PORT: " + PORT))
    print(("LOGIN: " + LOGIN))
    # print("PASSWORD: " + PASSWORD)
    print(("DB_NAME: " + DB_NAME))
    print(("MAILBOXES_FILE: " + MAILBOXES_FILE))

    print("\n___ CHECK REQUIREMENTS ___\n")

    IS_OK = True

    if not os.path.isfile(MAILBOXES_FILE):
        print(("ERROR: File '%s' does not exist\n" % MAILBOXES_FILE))

    if not IS_OK:
        sys.exit(2)

    print("OK")

    print("\n___ START ___\n")
    
    print(("Start date {0}".format(datetime.utcnow())))

    csvfile = open(MAILBOXES_FILE, 'r')

    fieldnames = ("Email","Password")
    
    reader = csv.DictReader([row for row in csvfile if row[0]!='#'], fieldnames, delimiter=',', quotechar='"')
    
    next(reader, None)  # skip the headers
    
    user_str = json.dumps([ row for row in reader ])

    # print user_str

    db = mysql.connector.connect(
         user=LOGIN,
         password=PASSWORD,
         host=HOST,
         database=DB_NAME)

    cursor = db.cursor(buffered=True)

    i=0
    users = json.loads(user_str)
    count=len(users)
    
    print(("Found {0} mailboxes".format(count)))
    
    for user in users:
        email=user["Email"]
        password=user["Password"]

        print("Seek user in db ", email)
        
        query = ("SELECT * FROM mailbox WHERE username = '{0}'".format(email))

        cursor.execute(query)

        if cursor.rowcount > 0:
            # existUser = cursor.fetchone()
            print(("User '{0}' exist".format(email)))
            # print(existUser)
        else:
            print(("User '{0}' not exist".format(email)))
            encrypted_password = crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512))
            splited=email.split("@")
            local_part=splited[0]       
            domain=splited[1]
            now = datetime.utcnow()
            today = now.strftime("%Y.%m.%d.%H.%M.%S")
            maildir='{0}/{1}/{2}/{3}/{4}-{5}/'.format(domain, local_part[0], local_part[1], local_part[2], local_part, today)
            print(("User '{0}' Password: '{1}' Local-Part: '{2}' Domain: '{3}' MailDir: '{4}'".format(email, encrypted_password, local_part, domain, maildir)))

            add_mailbox = ("INSERT INTO `mailbox` "
                "(`username`, `password`, `name`, `language`, `maildir`, `domain`, `allow_nets`, `disclaimer`, `allowedsenders`, `rejectedsenders`, `allowedrecipients`, `rejectedrecipients`, `settings`, `created`, `modified`, `local_part`) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")

            add_alias = ("INSERT INTO `alias` "
                "(`address`, `goto`, `name`, `moderators`, `accesspolicy`, `domain`, `islist`, `created`, `modified`, `expired`, `active`) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")

            date_mailbox = (email, encrypted_password, '', 'en_US', maildir, domain, None, None, None, None, None, None, None, now, now, local_part)

            data_alias = (email, email, '', None, '', domain, 0, now, now, '9999-12-31 00:00:00', 1)

            try:
                # Insert new mailbox
                cursor.execute(add_mailbox, date_mailbox)
                username = cursor.lastrowid

                # Insert alias information
                cursor.execute(add_alias, data_alias)

                # Make sure data is committed to the database
                db.commit()

                print(("Mailbox '{0}' has been created successfully".format(email)));

            except mysql.connector.Error as error :
                db.rollback() #rollback if any exception occured
                print(("Failed inserting records {}".format(error)))

    if(db.is_connected()):
        cursor.close()
        db.close()
        print("MySQL connection is closed")

    print("___ END ___\n")

if __name__ == "__main__":
   main()
