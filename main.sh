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
	 	dialog --title "User NIM: $NIM" --insecure --passwordbox "Masukkan password" 8 40 \
	  	3>&1 1>&2 2>&3 3>&- \
		)
		CHECK=$?
	done

	##Login to UKDW
	dialog --infobox "Login to UKDW as $NIM..." 8 50
	curl -s 'http://ukdw.ac.id/id/home/do_login' \
	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
	--data "return_url=http%3A%2F%2Fukdw.ac.id%2Fe-class%2Fid%2Fkelas%2Findex&id=${NIM}&password=${PASSWORD}" \
	--compressed -c cookies.txt
	##Check if lCHECK="$?"ogin is failed
	CHECK="$?"
	if [ $CHECK -ne 0 ]
	then
		dialog --msgbox "Login failed with error code $CHECK" 8 50
		exit
	fi

	update
}

function  pengumuman {
	##display the contents of the "pengumuman" that we choose
	MESSAGE=`cat p$1.txt`
	dialog --exit-label "Back" --msgbox "$MESSAGE" 25 60
}

function tugas {
	##display the contents of the "tugas" that we choose
	MESSAGE=`cat t$1.txt`
	dialog --exit-label "Back" --msgbox "$MESSAGE" 25 60

}

function show-tugas {
	##display all "Tugas"
	LIMIT=`wc -l < tangka.txt`
	INDEX=1
	LIST=()

	while [ $INDEX -le $LIMIT ]
	do
		CODE=`sed "${INDEX}q;d" tangka.txt`
		JUDUL=`sed '1q;d' t$CODE.txt | cut -d':' -f2`
		MATKUL=`sed '3q;d' t$CODE.txt | cut -d':' -f2`
		LIST+=("$CODE" "$MATKUL: $JUDUL")
		((INDEX++))
	done

	while true
	do
		RESPON=$(dialog --cancel-label "Back" --title "Menu Tugas" \
		--menu "" 20 80 100 \
		"${LIST[@]}" \
		3>&1 1>&2 2>&3 3>&- \
		)

		CHECK=$?
		if [ $CHECK -eq 0 ]
		then
			tugas $RESPON
		else
			break
		fi
	done
}

function show-pengumuman {
	##display all "Pengumuman"
	LIMIT=`wc -l < pangka.txt`
	INDEX=1
	LIST=()

	while [ $INDEX -le $LIMIT ]
	do
		CODE=`sed "${INDEX}q;d" pangka.txt`
		JUDUL=`sed '1q;d' p$CODE.txt | cut -d':' -f2`
		MATKUL=`sed '3q;d' p$CODE.txt | cut -d':' -f2`
		LIST+=("$CODE" "$MATKUL: $JUDUL")
		((INDEX++))
	done

	while true
	do
		RESPON=$(dialog --cancel-label "Back" --title "Menu Pengumuman" \
		--menu "" 20 80 100 \
		"${LIST[@]}" \
		3>&1 1>&2 2>&3 3>&- \
		)

		CHECK=$?
		if [ $CHECK -eq 0 ]
		then
			pengumuman $RESPON
		else
			break
		fi
	done
}

function main-menu {
	##display a menu dialog box which consists of all available "pengumuman" and "tugas" in an infinite loop until exit
	while true
	do
		pilihan=$(dialog --title "Menu Utama" --no-cancel --no-ok \
		--menu "" 9 50 3 \
		Pengumuman "Menampilkan semua pengumuman" \
		Tugas "Menampilkan semua tugas" \
		EXIT "Keluar dari program ini" \
		3>&1 1>&2 2>&3 3>&-)

		case $pilihan in
			Pengumuman ) show-pengumuman;;
			Tugas ) show-tugas;;
			EXIT ) break;;
		esac
	done

}

function update {

	###Grab Procedure

	##Grab http://ukdw.ac.id/e-class/id/kelas/index

		dialog --infobox "Grabbing http://ukdw.ac.id/e-class/id/kelas/index..." 8 50
		curl -s 'http://ukdw.ac.id//e-class/id/kelas/index' \
		-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
		-b cookies.txt \
		--compressed -o index.txt

	##Check if grabbing is failed
	CHECK="$?"
	if [ $CHECK -ne 0 ]
	then
		dialog --msgbox "Grabbing failed with Error code: $CHECK"
		exit
	fi

	###Filtering Tugas and Pengumuman link
	dialog --infobox "Filtering Pengumuman link and Tugas Link..." 8 50
	grep -Eoi '<a class="menu mc"[^>]+>' index.txt | grep -Eo 'href="[^\"]+"' > link.txt

	##Check if link.txt is empty or grep is failed
	CHECK="$?"
	if [ ! -s link.txt ] || [ ! $CHECK -eq 0 ]
	then
		dialog --msgbox "Filtering failed with Error code: $CHECK" 8 50
		exit
	fi

	##Check whether user wants to go into main menu
	CHECK="$?"
	if [ $CHECK -eq 0 ]
	then
		pengumuman-parser &
		PIDPENG=$!
		tugas-parser &
		PIDTUGAS=$!
		wait $PIDPENG
		wait $PIDTUGAS
		main-menu
	else
		exit
	fi
}

function pengumuman-parser {
	##mengambil kode pengumuman
	grep -Eo '(http|https)://ukdw.ac.id/e-class/pengumuman/baca/[^"]+' link.txt > link_pengumuman.txt
	
	##menghitung banyak pengumuman
	COUNT=`wc -l < link_pengumuman.txt`
	INDEX=1

	while [ $INDEX -le $COUNT ]
	do
    	LINK=`sed -n "${INDEX}p" link_pengumuman.txt | grep -Eo 'baca/[^\n]+' | grep -Eo '[[:digit:]]' | tr -d [:space:] | tee -a pangka.txt`
		echo >> pangka.txt
	
	##mengambil page pengumuman
    	curl -s "http://ukdw.ac.id/e-class/id/pengumuman/baca/${LINK}" \
    	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
    	-H 'Connection: keep-alive' \
    	-b cookies.txt \
    	--compressed -o pengumuman${LINK}.txt

		FILE="pengumuman${LINK}.txt"

		##PARSE JUDUL PENGUMUMAN
		JUDUL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f3 | cut -d'<' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Judul   : $JUDUL" >> p${LINK}.txt

		##PARSE TANGGAL PENGUMUMAN
		TGL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f5 | cut -d'<' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Tanggal : $TGL" >> p${LINK}.txt

		##PARSE MATAKULIAH PENGUMUMAN
		MATKUL=$(grep 'MATAKULIAH' $FILE | cut -d'>' -f3 | cut -d' ' -f2-5 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Matkul  : $MATKUL" >> p${LINK}.txt

		##PARSE NAMA DOSEN
		DOSEN=$(sed '132q;d' $FILE | cut -d' ' -f2-20 | cut -d'<' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Dosen   : $DOSEN" >> p${LINK}.txt
		
		##PARSE GRUP
		GRUP=$(grep 'MATAKULIAH' $FILE | cut -d'>' -f3 | cut -d'<' -f1 | awk '{for(i=1;i<=NF;i++){if($i=="GRUP")for(j=i;j<=NF;j++)printf"%s ",$j};printf"\n"}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')                                      
		echo -e "Grup    : $GRUP\n" >> p${LINK}.txt
		
		##PARSE ISI PENGUMUMAN ($LF= last field)
		LF=$(ex +130p -scq $FILE | rev | cut -d'^' -f2 | cut -d'>' -f3 | rev)
		i=1
		while [ 1 ]
		do
			ISI=$(ex +130p -scq $FILE | cut -d'>' --fields=$i | cut -d'^' -f1)
			##CEK JIKA ADA HYPERLINK
   			if [[ $ISI == *"<a href="* ]]; then
        			ISI=$(echo $ISI | cut -d'<' -f1)
    			elif [[ $ISI == *"</a"* ]]; then
        			ISI=$(echo $ISI | cut -d'<' -f1)
    			fi
			##CEK JIKA ISI MERUPAKAN YANG TERKAHIR MAKA KELUAR DARI INFINITE LOOP
			if [ "$ISI" = "$LF" ]; then
				echo $ISI | cut -d'<' -f1 >> p${LINK}.txt
				break
			fi
			echo $ISI >> p${LINK}.txt
			i=$(( i + 1 ))
		done
		
		##encode parse HTML "pengumuman"
		sed -i -e 's/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&quot;/\"/g; s/#&#39;/\'"'"'/g; s/&ldquo;/\"/g; s/&rdquo;/\"/g;' p${LINK}.txt
		
		rm pengumuman${LINK}.txt
		((INDEX++))
	done
}

function tugas-parser {
	##mengambil kode tugas
	grep -Eo '(http|https)://ukdw.ac.id/e-class/kelas/detail_tugas/[^"]+' link.txt > link_tugas.txt
	
	#menghitung berapa banyak tugas
	COUNT=`wc -l < link_tugas.txt`
	INDEX=1


	while [ $INDEX -le $COUNT ]
	do
    	LINK=`sed -n "${INDEX}p" link_tugas.txt | grep -Eo 'detail_tugas/[^\n]+' | grep -Eo '[[:digit:]]' | tr -d [:space:] | tee -a tangka.txt`
		echo >> tangka.txt

	##mengambil page tugas
    	curl -s "http://ukdw.ac.id/e-class/id/kelas/detail_tugas/${LINK}" \
    	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/59.0.3071.109 Chrome/59.0.3071.109 Safari/537.36' \
    	-H 'Connection: keep-alive' \
    	-b cookies.txt \
    	--compressed -o tugas${LINK}.txt
		FILE="tugas${LINK}.txt"
		
		##parse judul tugas
		JUDUL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f5 | cut -d'<' -f1 | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Judul   : $JUDUL" >> t${LINK}.txt
		
		##parse tanggal tugas
		TGL=$(grep '<tr class="thread">' $FILE | cut -d'>' -f6 | cut -d'<' -f1 | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Tanggal : $TGL" >> t${LINK}.txt
		
		##parse matkul tugas
		MATKUL=$(sed '217q;d' $FILE | cut -d']' -f2 | cut -d'<' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Matkul  : $MATKUL" >> t${LINK}.txt
		
		##parse nama dosen tugas
	
		##parse group tugas
		GROUP=$(sed '227q;d' $FILE | cut -d'>' -f2 | cut -d'&' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		echo -e "Group   : $GROUP" >> t${LINK}.txt
		
		##parse isi tugas
		LF=$(ex +231p -scq $FILE | rev | cut -d'^' -f2 | cut -d'>' -f3 | rev)
		i=2
		while [ 1 ]
		  do
		    ISI=$(ex +231p -scq $FILE | cut -d'>' --fields=$i | cut -d'^' -f1)
		    if [ "$ISI" = "$LF" ]; then
		      echo $ISI | cut -d'<' -f1 >> t${LINK}.txt
		      break
		    fi
		    echo $ISI >> t${LINK}.txt
		    i=$(( i + 1 ))
		done
		
		echo -e " \n " >> t${LINK}.txt
		
		##parse ketentuan tugas
		K1=$(ex +232p -scq $FILE | cut -d'<' -f1)
		K2=$(ex +233p -scq $FILE | cut -d'<' -f1)
		K3=$(sed '234q;d' $FILE)
		K4=$(grep 'Tugas dikumpulkan' $FILE | cut -d'<' -f1,2 | sed 's/<b>//g')
		K=$(grep -n 'Tugas dikumpulkan' $FILE | cut -d':' -f1)
		K=$(( K + 1 ))
		K5=$(sed "${K}q;d" $FILE | awk '{gsub("<span class=\"note\">", "");print}' | awk '{gsub("</span><br/>", "");print}' )
		
		echo $K1 >> t${LINK}.txt
		echo $K2 $K3 >> t${LINK}.txt
		echo $K4 >> t${LINK}.txt
		echo $K5 >> t${LINK}.txt
		
		##encode parse HTML "tugas"
		sed -i -e 's/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&quot;/\"/g; s/#&#39;/\'"'"'/g; s/&ldquo;/\"/g; s/&rdquo;/\"/g;' t${LINK}.txt
		
		rm tugas${LINK}.txt
		((INDEX++))
	done
}

login-page

rm p*.txt
rm t*.txt
rm index.txt
rm link.txt
rm cookies.txt
rm link_pengumuman.txt
rm link_tugas.txt
