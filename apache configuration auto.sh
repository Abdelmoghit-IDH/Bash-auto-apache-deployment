#!/bin/bash

### Set default arguments

action=$1
domain=$2
owner=$(whoami)
email="webmaster@localhost"
siteEnable="/etc/apache2/sites-enabled/"
siteAvailable="/etc/apache2/sites-available/"
userDir=$(echo ~)
sitesAvailableDomain=$sitesAvailable$domain.conf

echo "Automate Apache configuration"
sleep 2

### Implementation of the script

if [ $owner != "root" ]; then
	echo "You have no permission to run $0 as no-root user. Use 'sudo -i' command"
	exit 1
fi

if [[ "$action" != "create" && "$action" != "delete" ]]
then
	echo "You need to prompt for action (create or delete) -- Lower-case only"
	exit 1
fi

while [[ "$domain" == "" ]]
do
	echo "Please provide domain. example: dev,staging.."
	read -p "domain ? " domain
done

sitesAvailableDomain="$siteAvailable$domain.conf"
rootDir="/var/www/$domain"

### Softaware installation
#apt update && apt install apache2 git

if [[ "$action" == "create" ]]
then
	### Check if the domain exist	
	if [ -e $sitesAvailableDomain  ]
	then
		echo -e "This domain already exist.\nPlease try another one"
		exit;
	fi

	### check if directory exists or not
	if ! [[ -d $rootDir ]]; then
		echo "This is the root dir : $rootDir"
		### create the directory
		mkdir $rootDir

		### clone from git repository
		cd $rootDir
		git clone https://github.com/Prankster08/automation_website.git
		mv ./automation_website/* ./
		### give execution permission to rootDir
		chmod 755 $rootDir
	fi

	### create virtual host rules file
	if ! echo "
		<VirtualHost *:80>
			ServerAdmin $email
			ServerName $domain
			ServerAlias www.$domain
			DocumentRoot $rootDir
			<Directory $rootDir>
				Options Indexes FollowSymLinks MultiViews
				AllowOverride all
				Require all granted
			</Directory>
			ErrorLog /var/log/apache2/$domain-error.log
			LogLevel error
			CustomLog /var/log/apache2/$domain-access.log combined
		</VirtualHost>" > $sitesAvailableDomain
	then
		echo -e "There is an ERROR creating $domain file"
		exit;
	else
		echo -e "\nNew Virtual Host Created\n"
	fi

	### Add domain in /etc/hosts
	if ! sudo  sh -c -e "echo '127.0.0.1\t$domain' >> /etc/hosts";
	then
		echo "ERROR: Not able to write in /etc/hosts"
		exit;
	else
		echo -e "Host added to /etc/hosts file \n"
	fi

	### Change the owner of rootdir
	if [ "$owner" == "" ]; then
		chown -R $(whoami):$(whoami) $rootDir
	else
		chown -R $owner:$owner $rootDir
	fi

	### Enable website
	a2ensite $domain

	### Restart Apache
	systemctl restart apache2

	### show the finished message
	echo -e "Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $rootDir"
	exit;
else 
	### check whether domain already exists
	if [ ! -e $sitesAvailableDomain ]
	then
		echo -e "This domain does not exist.\nPlease try another one"
		exit;
	else
		### disable website
		a2dissite $domain
		
		### restart Apache
		systemctl restart apache2

		### Delete virtual host rules files
		rm $sitesAvailableDomain
	fi


	### check if directory exists or not
	if [ -d $rootDir ]; then
		echo "Delete host root directory ? (y/n)"
		read deldir

		if [[ "$deldir" == 'y' || "$deldir" == 'Y' ]] ; then
			### Delete the directory
			rm -rf $rootDir
			echo "Directory deleted"
		else
			echo "Host directory conserved"
			exit;
		fi
	else 
		echo "Host directory not found. Ignored"
	fi

	### show the finished message
	echo -e "Complete!\nYou just removed Virtual Host $domain"
	exit 0;
fi
