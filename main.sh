#!/bin/bash
#filename: main.sh

function update {
	###Login Procedure

	##Read NIM and Password
	echo Welcome to UKDW-notice
	echo -n NIM: ;read NIM
	echo -n Password: ;

	stty -echo;       #to hide user's input
	read PASSWORD
	stty echo;        #to show user's input

	##Login to UKDW
	echo -n Login to UKDW as $NIM...
	curl -s 'http://ukdw.ac.id/id/home/do_login' \
	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
	--data "return_url=http%3A%2F%2Fukdw.ac.id%2Fe-class%2Fid%2Fkelas%2Findex&id=${NIM}&password=${PASSWORD}" \
	--compressed -c cookies.txt

	##Check if login is failed
	CHECK="$?"
	if [ $CHECK -ne 0 ]
	then
		echo Failed with error code $CHECK
		exit
	else
		echo [OK]
	fi

	###Grab Procedure

	##Grab http://ukdw.ac.id/e-class/id/kelas/index
	echo -n Grabbing http://ukdw.ac.id/e-class/id/kelas/index...
	curl -s 'http://ukdw.ac.id//e-class/id/kelas/index' \
	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
	-b cookies.txt \
	--compressed -o index.txt

	##Check if grabbing is failed
	CHECK="$?"
	if [ $CHECK -ne 0 ]
	then
		echo [FAILED]
		echo error code $CHECK
		exit
	else
		echo [OK]
	fi

	###Filtering Tugas and Pengumuman link
	echo -n Filtering Pengumuman link and Tugas Link...
	grep -Eoi '<a class="menu mc"[^>]+>' index.txt | grep -Eo 'href="[^\"]+"' > link.txt

	##Check if link.txt is empty or grep is failed
	CHECK="$?"
	if [ -s link.txt ] && [ $CHECK -eq 0 ]
	then
	    echo [OK]
	else
	    echo [FAILED]
		echo error code $CHECK
	    exit
	fi

	echo -e "\n Ada $(cat link.txt | grep "pengumuman" | wc -l) pengumuman dan $(cat link.txt |grep "detail" | wc -l) tugas!"
}

update
