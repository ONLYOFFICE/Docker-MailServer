#!/usr/bin/python
# -*- coding: utf-8
import MySQLdb
import string
import settings
import urllib2
import os
import email
import hashlib
import datetime
import logging
import logging.handlers
import subprocess
import shlex
import time

#third party libs
from daemon import runner

class App():

    def setQueueStatus (self, cursor, id_task, state):
        sql = "UPDATE api_sa_training_queue SET state = " + str(state) + " WHERE id = " + str(id_task) 
        cursor.execute(sql)


    def deleteFile (self, file_path):
        try:
            os.remove(file_path)
        except:
            logger.error( u'Delete file error: %s' % file_path )


    def renameFile (self, old_file, new_file):
        try:
            os.rename(old_file, new_file)
        except:
            logger.error( u'Rename file error. Old file: %s New file: %s' % (old_file, new_file) )


    def getStorageFolder(self, is_spam):
        if is_spam == 0:
            file_path = settings.FOLDER_NOT_SPAM
        else:
            file_path = settings.FOLDER_SPAM
        return file_path


    def processingError (self, cursor, id_task, file_path, state):
        self.setQueueStatus (cursor, id_task, state)
        self.deleteFile (file_path)


    def checkFormat (self, file_path):
        fp = open(file_path, 'rb')
        msg = email.message_from_file(fp)
        fp.close()
        if msg.__len__() == 0:
            logger.warning( u'This is not eml format')
            return False
        elif (msg['Reply-To']):
            logger.warning( u'This is reply or forward message')
            return False
        else:
            return True


    def getMd5 (self, file_path):
        md5 = hashlib.md5()
        fp = open(file_path, 'rb')
        while True:
            data = fp.read(128)
            if not data:
                break
            md5.update(data)
        return md5.hexdigest()


    def findInHistroy (self, cursor, md5):
        result = {}
        sql = "Select is_spam, date_trained FROM api_sa_training_history WHERE md5 = '" + str(md5) + "'" 
        cursor.execute(sql)
        data =  cursor.fetchall()
        for rec in data:
            is_spam, date_trained = rec
            result = {'is_spam': is_spam, 'date_trained': date_trained}
        return result


    def insertHistory (self, cursor, md5, is_spam):
        now = datetime.datetime.utcnow()
        sql = "INSERT INTO api_sa_training_history (md5, is_spam, date_created) VALUES ('" + str(md5) + "', " + str(is_spam) + ", '" + now.strftime("%Y-%m-%d %H:%M:%S") + "')"
        cursor.execute(sql)


    def updateHistory (self, cursor, md5, is_spam):
        now = datetime.datetime.utcnow()
        sql = "Update api_sa_training_history SET is_spam = " + str(is_spam) + ", date_trained = NULL WHERE md5 = '" + str(md5) + "'"
        cursor.execute(sql)


    def setDateTrained (self, cursor, md5, date_trained):
        sql = "Update api_sa_training_history SET date_trained = '" + date_trained + "' WHERE md5 = '" + str(md5) + "'"
        cursor.execute(sql)


    def downloadFile (self, url, file_path):
        result = True
        try:
            file = open(file_path, 'wb')

            response = urllib2.urlopen(url)

            if(int(response.headers["Content-Length"]) > settings.MAX_FILE_SIZE):
                logger.warning( u'Content-Length more than the allowed value. Url: %s' % url)
                result = False
            else:
                while True:
                    buffer = response.read(settings.DOWNLOAD_BUFFER_SIZE)
                    if not buffer:
                        break
                    file.write(buffer)
        except:
            logger.error( u'Download file error: %s' % url )
            result = False
        finally:
            file.close()

        return result


    def clearStorageFolders (self, cursor):
        now = datetime.datetime.utcnow()

        folders = [ settings.FOLDER_SPAM, settings.FOLDER_NOT_SPAM]

        for folder in folders:
            for filename in os.listdir(folder):
                self.setDateTrained (cursor, filename.split('.')[0], now.strftime("%Y-%m-%d %H:%M:%S"))
                self.deleteFile ( os.path.join(folder, filename))


    def saLearnForget (self, file_path):
        args = [settings.COMAND_LINE, r'--forget', file_path]
        PIPE = subprocess.PIPE
        p = subprocess.Popen(args, shell = False, stdin=PIPE, stdout=PIPE, stderr=subprocess.STDOUT)
        p.wait()
        logger.debug( u'SA learn foget: %r' % p.stdout.read())
        return p.poll()


    def saLearnTraining (self):
        args = [settings.COMAND_LINE, r'--spam', settings.FOLDER_SPAM]
        PIPE = subprocess.PIPE
        p = subprocess.Popen(args, shell = False, stdin=PIPE, stdout=PIPE, stderr=subprocess.STDOUT)
        p.wait()
        logger.debug( u'Spam training: %r' % p.stdout.read())

        if(p.poll() == 0):
            args = [settings.COMAND_LINE, r'--ham', settings.FOLDER_NOT_SPAM]
            p = subprocess.Popen(args, shell = False, stdin=PIPE, stdout=PIPE, stderr=subprocess.STDOUT)
            p.wait()
            logger.debug( u'Ham training: %r' % p.stdout.read())
        return p.poll()


    def training (self):
        logger.info( u'Check queue' )

        db = MySQLdb.connect(host=settings.DATABASE_HOST, user=settings.DATABASE_USER, 
                             passwd=settings.DATABASE_PASSWORD, db=settings.DATABASE_NAME)

        cursor = db.cursor()

        sql = "SELECT id, url, is_spam FROM api_sa_training_queue WHERE state = 0 ORDER BY date_created LIMIT " + str(settings.NUMBER_OF_DOWNLOADED_FILES)

        cursor.execute(sql)
        data =  cursor.fetchall()

        if(not data):
            logger.info( u'Nothing to do' )

        for rec in data:
            id, url, is_spam = rec

            file_path = self.getStorageFolder(is_spam) + str(id) + '.eml'

            logger.info( u'Start process: id = %d, url: %s' % (id, url))

            if(not self.downloadFile (url, file_path)):
                self.processingError (cursor, id, file_path, settings.STATE_DOWNLOAD_ERROR)
                logger.info( u'End process: id = %d, url: %s' % (id, url))
                continue

            if(not self.checkFormat(file_path)):
                self.processingError (cursor, id, file_path, settings.STATE_EML_PARSE_ERROR)
                logger.info( u'End process: id = %d, url: %s' % (id, url))
                continue

            self.setQueueStatus(cursor, id, settings.STATE_OK)

            md5 = self.getMd5(file_path)
            history = self.findInHistroy(cursor, md5)

            if(not history):
                self.renameFile(file_path, self.getStorageFolder(is_spam) + str(md5) + '.eml')
                self.insertHistory (cursor, md5, is_spam)
            elif (history['is_spam'] == is_spam):
                logger.debug( u'The file has already been used in training. Md5 = %s' % md5)
                self.deleteFile (file_path)
            else:
                new_file_path = self.getStorageFolder(is_spam) + str(md5) + '.eml'
                self.renameFile(file_path, new_file_path)
                logger.debug( u'The file will be used to retrain. Md5 = %s' % md5)
                self.updateHistory (cursor, md5, is_spam)

                if (not history['date_trained']):
                   self.deleteFile(self.getStorageFolder(history['is_spam']) + str(md5) + '.eml')
                else:
                    result = self.saLearnForget(new_file_path)
                    logger.debug( u'Sa-learn forget result: %s' % result)

                logger.info( u'End process: id = %d, url: %s' % (id, url))

            logger.debug( u'Start sa-learn' )
            result = self.saLearnTraining()
            logger.info( u'Sa-learn training result: %s' % result )

            if(result == 0):
                logger.info( u'Clear storage folders' )
                self.clearStorageFolders (cursor)

        db.close()

    def __init__(self):
        self.stdin_path = '/dev/null'
        self.stdout_path = '/dev/null'
        self.stderr_path = '/dev/null'
        self.pidfile_path =  '/var/run/spamtrainer/spamtrainer.pid'
        self.pidfile_timeout = 5


    def run(self):
        while True:
            self.training ()
            time.sleep(settings.SERVICE_WAITING_TIME)

app = App()

logger = logging.getLogger("DaemonLog")
logger.setLevel(settings.LOGGING_LEVEL)
formatter = logging.Formatter("%(levelname)-8s [%(asctime)s]  %(message)s")
handler = logging.handlers.TimedRotatingFileHandler(
    settings.LOG_FILE, when=settings.LOG_TIMED_ROTATING,  backupCount = settings.BACKUP_COUNT)
handler.setFormatter(formatter)
logger.addHandler(handler)

daemon_runner = runner.DaemonRunner(app)
#This ensures that the logger file handle does not get closed during daemonization
daemon_runner.daemon_context.files_preserve=[handler.stream]
daemon_runner.do_action()