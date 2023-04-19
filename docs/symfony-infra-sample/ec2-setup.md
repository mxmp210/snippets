## Prerequisites for Setting up in EC2

The application is standard symfony application which requires following software installed in standard LEMP/LAMP stack.

 - Php 8.0+ or LEMP / LAMP stack pre installed image
 - Remote or local Database Access where messages and data is stored from main application
 - Amazon SQS Access to particular EC2 instance
 - Any Service manager or crontab i.e. Supervisor, PM2, init or systemd to regularly process email processing
 - Whitelist EC2 for ssh access in git repository to pull latest code and add private ssh key to running users account.

## System setup
**Directory Structure (considering standard ubuntu image) :**
USER_HOME  : /home/ubuntu
PROJECT_HOME : /home/ubuntu/webapp
LOGS_HOME : /home/ubuntu/crontablogs
SCRIPTS_HOME : /home/ubuntu/webapp/deploy/ec2/
DOCS_HOME : /home/ubuntu/webapp/docs/

Project setup will follow standard one time installation

**Step 1 : Pull code**
Pull code from main repository after allowing ec2 to pull code via ssh

    git pull git@github.com:myapp/webapp.git

Create logs directory  and transfer it to www:

    mkdir crontablogs && sudo chown www-data:www-data crontablogs/

**Step 2 : Transfer ownership to  www user**
cd into directory and transfer files ownership to web user
If image is ubuntu web user is `www-data` if image is AMI web users is usually `www`

    cd webapp && sudo chown -R www-data:www-data *
    
**Step 3 : Install Dependencies & setup environment**
Install all composer dependencies as web user

    sudo -u www-data composer install
    
Install Supervisor:

    sudo apt-get install supervisor

Copy .env to .enc.local and setup local values specific to server which does not need to be replaced at every pipeline push

    sudo -u www-data cp .env .env.local

Edit local env file to override any values specific to email server :

    sudo -u www-data nano .env.local

**Step 4 : Setup scripts**
Add config to supervisor with following command

    sudo nano /etc/supervisor/conf.d/messenger-worker.conf

**Worker configuration**

    [program:messenger-consume]
    command=/bin/bash -c "/home/ubuntu/webapp/deploy/ec2/email-cron.sh"
    user=www-data
    numprocs=1
    startsecs=0
    autostart=true
    autorestart=true
    process_name=%(program_name)s_%(process_num)02d
    # environment=MESSENGER_CONSUMER_NAME=%(program_name)s_%(process_num)02d

Reload supervisor procedure 
First stop messages via :

    sudo supervisorctl stop all
Ask supervisor to read new configuration & start consuming messages :

    sudo supervisorctl reread && supervisorctl update && supervisorctl start messenger-consume:*

*Without config reload - script will not be executed periodically.*

**Step 5: Setup Log Rotate**
Setup log rotate so logs are automatically discarded and disk space remains constant

Create rotate file via :

    sudo nano /etc/logrotate.d/messenger-consumer

Rotate file config :

    /home/ubuntu/crontablogs/*.log {
        daily
        missingok
        rotate 14
        compress
        notifempty
        su www-data www-data
        create 0640 www-data www-data
    }

## Some useful commands

**Manually process queue :**

    php /home/ubuntu/webapp/bin/console messenger:consume async sqs --limit=14 --memory-limit=128M -v

**Display failed messages**
Show all messages:

    sudo -u www-data php bin/console messenger:failed:show

Show specific message (with message ID):

    sudo -u www-data php bin/console messenger:failed:show 20 -vv
    
**Manually process failed messages**
Retry all failed message :

    php bin/console messenger:failed:retry -vv

Retry specific message :

    php bin/console messenger:failed:retry 20 30 -vv
 
 `**Manually remove failed messages**

    php bin/console messenger:failed:remove 20

**Clear App cache :**

    sudo -u www-data php bin/console cache:clear

**Check Error logs :**

Critical errors

    tail -1000 webapp/var/log/prod.log | grep -i -B 10 CRITICAL

Errors only :

    tail -1000 webapp/var/log/prod.log | grep -i -B 10 ERROR
    
**Stop workers  :**

    sudo supervisorctl stop all

**Start Workers :** 

    sudo supervisorctl start messenger-consume:*
    
**Perform database migrations**

    sudo -u www-data php bin/console doctrine:migrations:migrate

## Settings up SMTP Credentials in env file

Edit following DSN's for changing respective transports :

SES+SMTP Example for MAILER_DSN: 

    MAILER_DSN="ses+smtp://<<KEY>>:<<SECRET>>@default?region=us-east-1"
    
SMTP Host:

    MAILER_DSN=smtp://username:password@smtp.host.com:587


To use standard SMTP transport edit (example is to use MYSQL via doctrine)

    ###> symfony/messenger ###
    MESSENGER_TRANSPORT_DSN=doctrine://default
    ###< symfony/messenger ###

To use SQS transport edit (SQS example):

    ###> enqueue/enqueue-bundle ###
    ENQUEUE_DSN=sqs:?key=<<SQS_KEY>>&secret=<<SQS_SECRET>>&region=us-east-1
    ###< enqueue/enqueue-bundle ###

**Default NULL transports which disables sending emails :**
Symfony mailer `async` transport

    ###> symfony/mailer ###
    MAILER_DSN=null://null
    ###< symfony/mailer ###

Enqueue `sqs`  transport : 

    ###> enqueue/enqueue-bundle ###
    ENQUEUE_DSN=null://
    ###< enqueue/enqueue-bundle ###

**How to switch SQS & Doctrine Transports**

Transport configuration is setup via
*<PROJECT_HOME>/config/packages/messenger.yaml* 

To switch to doctrine change routing config to :

    routing:
        # Route your messages to the transports    
        'Symfony\Component\Mailer\Messenger\SendEmailMessage': async
        
To switch to SQS change routing config to :

    routing:
        # Route your messages to the transports    
        'Symfony\Component\Mailer\Messenger\SendEmailMessage': sqs

To change SQS queue name change transport configs accordingly :

    transports:
        async: '%env(MESSENGER_TRANSPORT_DSN)%'
        failed: 'doctrine://default?queue_name=failed'
        sqs : 'enqueue://default?topic[name]=email_queue&queue[name]=email_queue&receiveTimeout=20000'

# Route your messages to the transports

'Symfony\Component\Mailer\Messenger\SendEmailMessage': sqs

## MISC  OS Maintenance Commands

Update ubuntu repo :

    sudo apt-get update

Install updated packages :

    sudo apt-get upgrade -y

