#!/usr/bin/env python
import argparse
import csv
import os
import subprocess

parser = argparse.ArgumentParser(description='Batch migrate e-mail with imapsync reading from a CSV-file')
parser.add_argument('csvfile',help='The CSV file to parse. The file should have a header like this: host1,user1,password1,host2,user2,password2')
parser.add_argument('--dry',action='store_true',help="Use imapsync's dry mode: don't sync, show what would happen")
args = parser.parse_args()

if os.path.isfile(args.csvfile):
    input_file = csv.DictReader(open(args.csvfile))
    # TODO check if header matches required columns
    for row in input_file:
        imapsync_cmd=('imapsync' +\
                ' --host1 ' + row['host1'] +\
                ' --user1 ' + row['user1'] +\
                ' --password1 \"' + row['password1'] +'\"' +\
                ' --host2 ' + row['host2'] +\
                ' --user2 ' + row['user2'] +\
                ' --password2 \"' + row['password2'] + '\"' +\
                ' --logdir /home/centos/scripts/LOG_imapsync' +\
                ' --tls1 --tls2'
                )
        if args.dry:
            #TODO try using subprocess here
            os.system(imapsync_cmd + ' --dry')
        else:
            os.system(imapsync_cmd)
else:
    print("Can't find the file specified: " + args.csvfile)
