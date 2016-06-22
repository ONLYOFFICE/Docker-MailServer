# database settings
DATABASE_NAME = 
DATABASE_USER = 
DATABASE_PASSWORD = 
DATABASE_HOST = 

# storage folders
FOLDER_SPAM = '/usr/share/spamtrainer/spam/'
FOLDER_NOT_SPAM = '/usr/share/spamtrainer/ham/'

SERVICE_WAITING_TIME = 300 # seconds

NUMBER_OF_DOWNLOADED_FILES = 50
DOWNLOAD_BUFFER_SIZE = 1048576

STATE_OK = 1
STATE_DOWNLOAD_ERROR = -1
STATE_EML_PARSE_ERROR = -2

MAX_FILE_SIZE = 15728640 # 15 Mb

LOG_FILE = '/var/log/spamtrainer/spamtrainer.log'
# Backup intervals
# Seconds 'S'
# Minutes 'M'
# Hours 'H'
# Days 'D'
# Weekday (0=Monday) 'W0'-'W6'
# Roll over at midnight 'midnight'
LOG_TIMED_ROTATING = 'midnight'
BACKUP_COUNT = 5
# Logging levels
# CRITICAL 50
# ERROR 40
# WARNING 30
# INFO 20
# DEBUG 10
# NOTSET 0
LOGGING_LEVEL = 10

COMAND_LINE = 'sa-learn'
