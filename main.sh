#!/bin/bash
#filename: main.sh

function login-page {
	##Login input
	CHECK=1
	##Loop is used so cancelled passwordbox goes back to nim inputbox
	while [ $CHECK -eq 1 ]
	do
		NIM=$(\
	 	dialog --inputbox "Masukkan NIM anda" 8 40 \
  		3>&1 1>&2 2>&3 3>&- \
		)

		CHECK=$?
		if [ $CHECK -eq 1 ]
		then
			exit
		fi

		PASSWORD=$(\
	 	dialog --passwordbox "Masukkan password" 8 40 \
	  	3>&1 1>&2 2>&3 3>&- \
		)
		CHECK=$?
	done
	update
}

function show-tugas {
	##Display all "Tugas"
	dialog --title "Menu Pengumuman" \
	--menu "" 10 30 4\
	1 placeholder
}

function show-pengumuman {
	##Display all "Pengumuman"
	LIMIT=`wc -l < pangka.txt`
	INDEX=1
	ASU=()

	while [ $INDEX -le $LIMIT ]
	do
		CODE=`sed "${INDEX}!d" pangka.txt`
		JUDUL=`sed '1!d' p$CODE.txt | cut -d':' -f2`
		MATKUL=`sed '3!d' p$CODE.txt | cut -d':' -f2`
		ASU+=($INDEX "$MATKUL")
		((INDEX++))
	done

	dialog --title "Menu Pengumuman" \
	--menu "" 20 70 4 \
	"${ASU[@]}"
}

function main-menu {
	##Display a menu dialog box which consists of all available "pengumuman" and "tugas" in an infinite loop until exit
	while true
	do
		pilihan=$(dialog --title "Menu Utama" \
		--menu "" 10 50 4 \
		Pengumuman "Menampilkan semua pengumuman" \
		Tugas "Menampilkan semua tugas" \
		Exit "Keluar dari menu ini" 3>&1 1>&2 2>&3 3>&-)

		case $pilihan in
			Pengumuman ) show-pengumuman;;
			Tugas ) show-tugas;;
			Exit) break;;
		esac

	done

}

function update {

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

	##Check whether user wants to go into main menu
	CHECK="$?"
	if [ $CHECK -eq 0 ]
	then
		pengumuman-parser

		main-menu
	else
		exit
	fi
}

function pengumuman-parser {
	grep -Eo '(http|https)://ukdw.ac.id/e-class/pengumuman/baca/[^"]+' link.txt > link_pengumuman.txt

	COUNT=`wc -l < link_pengumuman.txt`
	INDEX=1


	while [ $INDEX -le $COUNT ]
	do
    	LINK=`sed -n "${INDEX}p" link_pengumuman.txt | grep -Eo 'baca/[^\n]+' | grep -Eo '[[:digit:]]' | tr -d [:space:] | tee -a pangka.txt`
		echo >> pangka.txt

    	curl -s "http://ukdw.ac.id/e-class/id/pengumuman/baca/${LINK}" \
    	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
    	-H 'Connection: keep-alive' \
    	-b cookies.txt \
    	--compressed -o pengumuman${LINK}.txt

		FILE="pengumuman${LINK}.txt"

		#parsing judul
		JUDUL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f3 | cut -d'<' -f1)
		printf "Judul:$JUDUL \n" >> p${LINK}.txt

		#parsing tanggal
		TGL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f5 | cut -d'<' -f1)
		printf "Tanggal:$TGL \n" >> p${LINK}.txt

		#parsing matkul and grup
		MATKUL=$(grep 'MATAKULIAH' $FILE | cut -d'>' -f3 | cut -d' ' -f2-5)
		GRUP=$(grep 'MATAKULIAH' $FILE | cut -d'>' -f3 | cut -d'<' -f1 | awk '{for(i=1;i<=NF;i++){if($i=="GRUP")for(j=i;j<=NF;j++)printf"%s ",$j};printf"\n"}' )
		printf "Matkul:$MATKUL$GRUP \n" >> p${LINK}.txt

		#parsing dosen
		DOSEN=$(sed '132!d' $FILE | cut -d' ' -f2-20 | cut -d'<' -f1)
		printf "Dosen:$DOSEN \n\n" >> p${LINK}.txt

		#PARSING ISI PENGUMUMAN ($LF= last field)
		LF=$(ex +130p -scq $FILE | rev | cut -d'^' -f2 | cut -d'>' -f3 | rev)
		i=1
		while [ 1 ]
		do
			ISI=$(ex +130p -scq $FILE | cut -d'>' --fields=$i | cut -d'^' -f1)
			#CEK JIKA ADA HYPERLINK
   			if [[ $ISI == *"<a href="* ]]; then
        			ISI=$(echo $ISI | cut -d'<' -f1)
    			elif [[ $ISI == *"</a"* ]]; then
        			ISI=$(echo $ISI | cut -d'<' -f1)
    			fi

			if [ "$ISI" = "$LF" ]; then
				echo $ISI | cut -d'<' -f1 >> p${LINK}.txt
				break
			fi
			echo $ISI >> p${LINK}.txt
			i=$(( i + 1 ))
		done
		rm pengumuman${LINK}.txt
		((INDEX++))
	done
}

#login-page
main-menu
#rm p*.txt
rm index.txt
rm link.txt
rm cookies.txt
rm link_pengumuman.txt
#login-page
#
#CODE=`sed '4!d' pangka.txt`
#JUDUL=`sed '1!d' p$CODE.txt | cut -d':' -f2`
#TANGGAL=`sed '2!d' p$CODE.txt | cut -d':' -f2`
#MATKUL=`sed '3!d' p$CODE.txt | cut -d':' -f2`
#DOSEN=`sed '4!d' p$CODE.txt | cut -d':' -f2`
#LINES=`wc -l < p$CODE.txt`
#ISI=`sed -n "5,${LINES}p" p$CODE.txt`
#
