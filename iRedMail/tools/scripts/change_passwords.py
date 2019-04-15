#!/usr/bin/env python

import pkg_resources, sys
from pkg_resources import DistributionNotFound, VersionConflict

def exception_handler(exception_type, exception, traceback):
    print "%s: %s" % (exception_type.__name__, exception)

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
parser.add_argument('-mb', dest='mb_file', help="mailboxes file path")
parser.add_argument('-mba', dest='mb_address', help="existing mailbox address")
parser.add_argument('-mbp', dest='mb_password', help="new mailbox password")

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
    MAILBOX_ADDRESS = args.mb_address
    MAILBOX_PASSWORD = args.mb_password

    print('\n___ VARIABLES ___\n')
    print("HOST: " + HOST)
    print("PORT: " + PORT)
    print("LOGIN: " + LOGIN)
    # print("PASSWORD: " + PASSWORD)
    print("DB_NAME: " + DB_NAME)

    print("\n___ CHECK REQUIREMENTS ___\n")

    IS_OK = True

    if not (MAILBOXES_FILE is None):
        print(("MAILBOXES_FILE: " + MAILBOXES_FILE))
        if not os.path.isfile(MAILBOXES_FILE):
            print(("ERROR: File '%s' does not exist\n" % MAILBOXES_FILE))
            IS_OK = False
    else:
        print(("NEW MAILBOX_ADDRESS: " + MAILBOX_ADDRESS))
        print(("NEW MAILBOX_PASSWORD: " + MAILBOX_PASSWORD))
        if (MAILBOX_ADDRESS is None) or (MAILBOX_PASSWORD is None):
            print(("ERROR: Empty mailbox address or password\n"))
            IS_OK = False

    if not IS_OK:
        sys.exit(2)

    print("OK")

    print("\n___ START ___\n")

    print("Start date {0}".format(datetime.utcnow()))

    if not (MAILBOXES_FILE is None):
        csvfile = open(MAILBOXES_FILE, 'r')
        fieldnames = ("Email","Password")
        reader = csv.DictReader([row for row in csvfile if row[0]!='#'], fieldnames, delimiter=',', quotechar='"')
        next(reader, None)  # skip the headers
        user_str = json.dumps([ row for row in reader ])
    else:
        user_str = '[{{"Email": "{0}", "Password": "{1}"}}]'.format(MAILBOX_ADDRESS, MAILBOX_PASSWORD)

    # print user_str
    users = json.loads(user_str)

    count=len(users)

    print(("Found {0} mailboxes".format(count)))

    if count == 0:
        sys.exit(2)

    print("Connecting to db...")

    db = mysql.connector.connect(
         user=LOGIN,
         password=PASSWORD,
         host=HOST,
         database=DB_NAME)

    cursor = db.cursor(buffered=True)

    i=0
    
    for user in users:
        email=user["Email"]
        password=user["Password"]

        i=i+1
        print("({0}/{1}) Seek user in db ".format(i, count, email))
        
        query = ("SELECT * FROM mailbox WHERE username = '{0}'".format(email))

        cursor.execute(query)

        if cursor.rowcount > 0:
            # existUser = cursor.fetchone()
            print("User '{0}' exist".format(email))
            # print(existUser)
            update_mailbox = ("UPDATE `mailbox` SET `password` = %s WHERE `username` = %s")
            encrypted_password = crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512))

            date_mailbox = (encrypted_password, email)

            try:
                # Update mailbox
                cursor.execute(update_mailbox, date_mailbox)

                # Make sure data is committed to the database
                db.commit()

                print("Mailbox '{0}' password has been changed".format(email));

            except mysql.connector.Error as error :
                db.rollback() #rollback if any exception occured
                print("Failed inserting records {}".format(error))

    if(db.is_connected()):
        cursor.close()
        db.close()
        print("MySQL connection is closed")

    print("___ END ___\n")

if __name__ == "__main__":
   main()
