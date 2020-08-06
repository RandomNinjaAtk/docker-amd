#!/usr/bin/with-contenv bash
export XDG_CONFIG_HOME="/xdg"
agent="automated-music-downloader ( https://github.com/RandomNinjaAtk/docker-amd )"
Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	echo "To kill script, use the following command:"
	echo "kill -9 $processstartid"
	echo "kill -9 $processdownloadid"
	echo ""
	echo ""
	sleep 5
	echo "############################################ SCRIPT VERSION 1.0.0 ############################################"
	echo "############################################ DOCKER VERSION $VERSION ############################################"
	echo "######################################### CONFIGURATION VERIFICATION #########################################"
	error=0

	if [ "$AUTOSTART" = "true" ]; then
		echo "Automatic Start: ENABLED"
	else
		echo "Automatic Start: DISABLED"
	fi
    
    # Verify Musicbrainz DB Connectivity
	musicbrainzdbtest=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json")
	musicbrainzdbtestname=$(echo "${musicbrainzdbtest}"| jq -r '.name')
	if [ "$musicbrainzdbtestname" != "Linkin Park" ]; then
		echo "ERROR: Cannot communicate with Musicbrainz"
		echo "ERROR: Expected Response \"Linkin Park\", received response \"$musicbrainzdbtestname\""
		echo "ERROR: URL might be Invalid: $MBRAINZMIRROR"
		echo "ERROR: Remote Mirror may be throttling connection..."
		echo "ERROR: Link used for testing: ${MBRAINZMIRROR}/ws/2/artist/f59c5520-5f46-4d2c-b2c4-822eabf53419?fmt=json"
		echo "ERROR: Please correct error, consider using official Musicbrainz URL: https://musicbrainz.org"
		error=1
	else
		echo "Musicbrainz Mirror Valid: $MBRAINZMIRROR"
		if echo "$MBRAINZMIRROR" | grep -i "musicbrainz.org" | read; then
			if [ "$MBRATELIMIT" != 1 ]; then
				MBRATELIMIT="1"
			fi
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
		else
			echo "Musicbrainz Rate Limit: $MBRATELIMIT (Queries Per Second)"
			MBRATELIMIT="0$(echo $(( 100 * 1 / $MBRATELIMIT )) | sed 's/..$/.&/')"
		fi
	fi

	# verify LIBRARY
	if [ -d "$DOWNLOADS" ]; then
		echo "DOWNLOADS Location: $DOWNLOADS"
		if [ ! -f "$DOWNLOADS/amd/dlclient" ]; then
			mkdir -p "$DOWNLOADS/amd/dlclient"
			chmod 0777 -R "$DOWNLOADS/amd/dlclient"
		fi
        sed -i "s%/downloadfolder%$DOWNLOADS/amd/dlclient%g" "/xdg/deemix/config.json"
	else
		echo "ERROR: LIBRARY setting invalid, currently set to: $DOWNLOADS"
		echo "ERROR: LIBRARY Expected Valid Setting: /your/path/to/music/downloads"
		error=1
	fi

	if [ ! -z "$ARL_TOKEN" ]; then
		echo "ARL Token: Configured"
        if [ -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
            rm "$XDG_CONFIG_HOME/deemix/.arl"
        fi
         if [ ! -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then 
            echo -n "$ARL_TOKEN" > "$XDG_CONFIG_HOME/deemix/.arl"
        fi
	else
		echo "ERROR: ARL_TOKEN setting invalid, currently set to: $ARL_TOKEN"
		error=1
	fi
	
	if [ "$quality" == "FLAC" ]; then
		echo "Audio: Download Quality: FLAC"
		echo "Audio: Download Bitrate: lossless"
	elif [ "$quality" == "320" ]; then
		echo "Audio: Download Quality: MP3"
		echo "Audio: Download Bitrate: 320k"
	elif [ "$quality" == "128" ]; then
		echo "Audio: Download Quality: MP3"
		echo "Audio: Download Bitrate: 128k"
	else
		echo "Audio: Download Quality: FLAC"
		echo "Audio: Download Bitrate: lossless"
		quality="FLAC"
	fi

	if [ "$ExplicitPreferred" == "true" ]; then
		echo "Audio Explicit Preferred: ENABLED"
	else
		echo "Audio Explicit Preferred: DISABLED"
	fi

	if [ ! -z "$FilePermissions" ]; then
        echo "Audio: File Permissions: $FilePermissions"
	else
		echo "ERROR: FilePermissions not set, using default..."
		FilePermissions="666"
		echo "Audio: File Permissions: $FilePermissions"
	fi

	if [ ! -z "$FolderPermissions" ]; then
        echo "Audio: Folder Permissions: $FolderPermissions"
	else
		echo "ERROR: FolderPermissions not set, using default..."
		FolderPermissions="766"
		echo "Audio: Folder Permissions: $FolderPermissions"
	fi

	if [ $error = 1 ]; then
		echo "Please correct errors before attempting to run script again..."
		echo "Exiting..."
		exit 1
	fi
	amount=1000000000
	sleep 5
}

CacheEngine () {
	echo "######################################### STARTING CACHE ENGINE #########################################"
	wantit=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/Artist/")
	wantedtotal=$(echo "${wantit}"| jq -r '.[].sortName' | wc -l)
	MBArtistID=($(echo "${wantit}" | jq -r ".[].foreignArtistId"))

	if [ -d "/config/temp" ]; then
		rm -rf "/config/temp"
	fi
	for id in ${!MBArtistID[@]}; do
        artistnumber=$(( $id + 1 ))
		mbid="${MBArtistID[$id]}"
        LidArtistNameCap="$(echo "${wantit}" | jq -r ".[] | select(.foreignArtistId==\"${mbid}\") | .artistName")"
        sanatizedartistname="$(echo "${LidArtistNameCap}" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]//g' -e 's/^\(nul\|prn\|con\|lpt[0-9]\|com[0-9]\|aux\)\(\.\|$\)//i' -e 's/^\.*$//' -e 's/^$/NONAME/')"
		if [ "$LidArtistNameCap" ==	"Various Artists" ]; then
			continue
		fi

		if [ -f "/config/cache/$sanatizedartistname-$mbid-cache-complete" ]; then
			if ! [[ $(find "/config/cache/$sanatizedartistname-$mbid-cache-complete" -mtime +7 -print) ]]; then
				echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Skipping until cache expires..."
				continue
			fi
		fi

        mbrainzurlcount=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/$mbid?inc=url-rels&fmt=json" | jq -r ".relations | .[] | .url | .resource" | wc -l)
	
		if [ -f "/config/cache/$sanatizedartistname-$mbid-info.json" ]; then
			cachedurlcount=$(cat "/config/cache/$sanatizedartistname-$mbid-info.json" | jq -r ".relations | .[] | .url | .resource" | wc -l)
			if [ "$mbrainzurlcount" -ne "$cachedurlcount" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-info.json"
			fi
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-info.json" ]; then
			echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Caching Musicbrainz Artist Info..."
			curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/artist/$mbid?inc=url-rels+genres&fmt=json" -o "/config/cache/$sanatizedartistname-$mbid-info.json"
			sleep $MBRATELIMIT
		else 
			echo "${artistnumber} of ${wantedtotal} :: MBZDB CACHE :: $LidArtistNameCap :: Musicbrainz Artist Info Cache Valid..."
		fi
		
		
		releases=$(curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?artist=$mbid&inc=genres+recordings+url-rels+release-groups&limit=1&offset=0&fmt=json")
		sleep $MBRATELIMIT
		newreleasecount=$(echo "${releases}"| jq -r '."release-count"')
				
		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			releasecount=$(echo "${releases}"| jq -r '."release-count"')
		else
			releasecount=$(cat "/config/cache/$sanatizedartistname-$mbid-releases.json" | jq -r '.[] | ."release-count"' | head -n 1)
		fi
			
		if [ $newreleasecount != $releasecount ]; then
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Cache needs update, cleaning..."
			if [ -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
				rm "/config/cache/$sanatizedartistname-$mbid-releases.json"
			fi
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Caching $releasecount releases..."
		else
			echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Releases Cache Is Valid..."
		fi

		if [ ! -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
			if [ ! -d "/config/temp" ]; then
				mkdir "/config/temp"
				sleep 0.1
			fi	
	
			offsetcount=$(( $releasecount / 100 ))
			for ((i=0;i<=$offsetcount;i++)); do
				if [ ! -f "release-page-$i.json" ]; then
					if [ $i != 0 ]; then
						offset=$(( $i * 100 ))
						dlnumber=$(( $offset + 100))
					else
						offset=0
						dlnumber=$(( $offset + 100))
					fi
					echo "$artistnumber of $wantedtotal :: MBZDB CACHE :: $LidArtistNameCap :: Downloading Releases page $i... ($offset - $dlnumber Results)"
					curl -s -A "$agent" "${MBRAINZMIRROR}/ws/2/release?artist=$mbid&inc=genres+recordings+url-rels+release-groups&limit=100&offset=$offset&fmt=json" -o "/config/temp/$mbid-releases-page-$i.json"
					sleep $MBRATELIMIT
				fi
			done


			if [ ! -f "/config/cache/$sanatizedartistname-releases.json" ]; then
				jq -s '.' /config/temp/$mbid-releases-page-*.json > "/config/cache/$sanatizedartistname-$mbid-releases.json"
			fi

			if [ -f "/config/cache/$sanatizedartistname-$mbid-releases.json" ]; then
				rm /config/temp/$mbid-releases-page-*.json
				sleep .01
			fi

			if [ -d "/config/temp" ]; then
				sleep 0.1
				rm -rf "/config/temp"
			fi
		fi

		mbzartistinfo="$(cat "/config/cache/$sanatizedartistname-$mbid-info.json")"
		deezerurl="$(echo "$mbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"deezer\")) | .resource")"
		touch "/config/cache/$sanatizedartistname-$mbid-cache-complete"
	done
}

WantedMode () {
	echo "######################################### DOWNLOAD AUDIO (WANTED MODE) #########################################"
	missinglist=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/wanted/missing/?page=1&pagesize=${amount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate")
	missinglisttotal=$(echo "$missinglist" | jq -r '.records | .[] | .id' | wc -l)
	missinglistalbumids=($(echo "$missinglist"| jq -r '.records | .[] | .id'))

	for id in ${!missinglistalbumids[@]}; do
		currentprocess=$(( $id + 1 ))
		lidarralbumid="${missinglistalbumids[$id]}"
		albumdeezerurl=""
		error=0
		lidarralbumdata=$(curl -s --header "X-Api-Key:"${LidarrAPIkey} --request GET  "$LidarrUrl/api/v1/album?albumIds=${lidarralbumid}")
		lidarralbumdrecordids=($(echo "${lidarralbumdata}" | jq '.[] | .releases | .[] | .id'))
		albumreleasegroupmbzid=$(echo "${lidarralbumdata}"| jq -r '.[] | .foreignAlbumId')
		lidarralbumtype="$(echo "${lidarralbumdata}"| jq -r '.[] | .albumType')"
		lidarralbumtypelower="$(echo ${lidarralbumtype,,})"
		albumtitle="$(echo "${lidarralbumdata}"| jq -r '.[] | .title')"
		albumreleasedate="$(echo "${lidarralbumdata}"| jq -r '.[] | .releaseDate')"
		albumreleaseyear="${albumreleasedate:0:4}"
		albumclean="$(echo "$albumtitle" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
		albumartistmbzid=$(echo "${lidarralbumdata}"| jq -r '.[].artist.foreignArtistId')
		albumartistname=$(echo "${lidarralbumdata}"| jq -r '.[].artist.artistName')
		artistclean="$(echo "$albumartistname" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
		artistcleans="$(echo "$albumartistname" | sed -e 's/["”“]//g')"
		albumartistnamesearch="$(jq -R -r @uri <<<"${artistcleans}")"
		albumartistpath=$(echo "${lidarralbumdata}"| jq -r '.[].artist.path')
		albumbimportfolder="$DOWNLOADS/amd/import/$artistclean - $albumclean ($albumreleaseyear)-WEB-$lidarralbumtype-deemix"
		logheader="$currentprocess of $missinglisttotal :: $albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"
		filelogheader="$albumartistname :: $albumreleaseyear :: $lidarralbumtype :: $albumtitle"
		if [ -f "/config/logs/notfound.log" ]; then
			if cat "/config/logs/notfound.log" | grep -i "$albumreleasegroupmbzid" | read; then
				echo "$logheader :: PREVOUSLY NOT FOUND SKIPPING..."
				continue
			else
				echo "$logheader :: SEARCHING..."
			fi
		else
			echo "$logheader :: SEARCHING..."
		fi
		
		if [  -d "$albumbimportfolder" ]; then
			echo "$logheader :: Already Downloaded, skipping..."
			continue
		fi

		if [ "$albumartistname" !=	"Various Artists" ]; then
			albuartistreleasedata=$(find "/config/cache" -type f -iname "*-$albumartistmbzid-releases.json" -exec cat {} \;)
			albumdeezerurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"deezer\")).resource" | head -n 1)"
			# albumtidalurl="$(echo "$albuartistreleasedata" | jq -r " .[].releases | .[] | select(.\"release-group\".id==\"$albumreleasegroupmbzid\") | .relations | .[].url | select(.resource | contains(\"tidal\")).resource" | head -n 1)"
		fi
		if [ ! -z "$albumdeezerurl" ]; then
			deezeralbumid="$(echo "${albumdeezerurl}" | grep -o '[[:digit:]]*')"
			deezeralbumsearchdata=$(curl -s "https://api.deezer.com/album/deezeralbumid${deezeralbumid}")
			errocheck="$(echo "$deezeralbumsearchdata" | jq -r ".error.code")"
			if [ "$errocheck" != "null" ]; then
				echo "$logheader :: ERROR :: Provided URL is broken, fallback to fuzzy search..."
				albumdeezerurl=""
			fi
		fi


		if [[ -z "$albumdeezerurl" && -z "$albumtidalurl" ]]; then
			echo "$logheader :: FUZZY SEARCHING..."
			for id in "${!lidarralbumdrecordids[@]}"; do
				recordid=${lidarralbumdrecordids[$id]}
				recordtitle="$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .title")"
				recordmbrainzid=$(echo "${lidarralbumdata}" | jq -r ".[] | .releases | .[] | select(.id==$recordid) | .foreignReleaseId")
				albumtitle="$recordtitle"
				albumtitlecleans="$(echo "$albumtitle" | sed -e 's/["”“]//g')"
				albumclean="$(echo "$albumtitle" | sed -e 's/[^[:alnum:]\ ]//g' -e 's/[\\/:\*\?"”“<>\|\x01-\x1F\x7F]//g')"
				albumtitlesearch="$(jq -R -r @uri <<<"${albumtitlecleans}")"
				deezersearchalbumid=""
				deezeralbumtitle=""
				if [ "$albumartistname" !=	"Various Artists" ]; then
					deezersearchurl="https://api.deezer.com/search?q=artist:%22${albumartistnamesearch}%22%20album:%22${albumtitlesearch}%22"
					deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
				else
					deezersearchurl="https://api.deezer.com/search?q=album:%22${albumtitlesearch}%22"
					deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
				fi

				deezersearchcount="$(echo "$deezeralbumsearchdata" | jq -r ".total")"
				if [ "$deezersearchcount" == "0" ]; then
					if [ "$albumartistname" !=	"Various Artists" ]; then
						deezersearchurl="https://api.deezer.com/search?q=album:%22${albumtitlesearch}%22"
						deezeralbumsearchdata=$(curl -s "${deezersearchurl}")
						searchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | sort_by(.album.title) | .[] | select(.artist.name | contains(\"$artistcleans\"))")"
					else
						error=1
						continue
					fi
				else
					searchdata="$(echo "$deezeralbumsearchdata" | jq -r ".data | sort_by(.album.title) | .[]")"
				fi

				if [ "$ExplicitPreferred" == "true" ]; then
					if [ -z "$deezersearchalbumid" ]; then
						deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) | select(.album.type==\"$lidarralbumtypelower\") | .album.id" | head -n 1)"
					fi
					if [ -z "$deezersearchalbumid" ]; then
						deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) | select(.album.type==\"album\") | .album.id" | head -n 1)"
					fi
					if [ -z "$deezersearchalbumid" ]; then
						deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) | select(.album.type==\"ep\") | .album.id" | head -n 1)"
					fi
					if [ -z "$deezersearchalbumid" ]; then
						deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) | select(.album.type==\"single\") | .album.id" | head -n 1)"
					fi
					if [ -z "$deezersearchalbumid" ]; then
						deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.explicit_lyrics==true) | .album.id" | head -n 1)"
					fi
					if [ ! -z "$deezersearchalbumid" ]; then
						explicit="true"
					else
						explicit="false"
					fi
				fi
				
				if [ -z "$deezersearchalbumid" ]; then
					deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.album.type==\"$lidarralbumtypelower\") | .album.id" | head -n 1)"
				fi
				if [ -z "$deezersearchalbumid" ]; then
					deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.album.type==\"album\") | .album.id" | head -n 1)"
				fi
				if [ -z "$deezersearchalbumid" ]; then
					deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.album.type==\"ep\") | .album.id" | head -n 1)"
				fi
				if [ -z "$deezersearchalbumid" ]; then
					deezersearchalbumid="$(echo "$searchdata" | jq -r "select(.album.type==\"single\") | .album.id" | head -n 1)"
				fi
				if [ -z "$deezersearchalbumid" ]; then
					deezersearchalbumid="$(echo "$searchdata" | jq -r ".album.id" | head -n 1)"
				fi

				if [ "$explicit" == "true" ]; then
					echo "$logheader :: Explicit Release Found"
				fi

				if [ ! -z "$deezersearchalbumid" ]; then
					albumdeezerurl="https://deezer.com/album/$deezersearchalbumid"
					deezeralbumtitle="$(echo "$searchdata" | jq -r "select(.album.id==$deezersearchalbumid) | .album.title" | head -n 1)"
					error=0
					break
				else
					error=1
				fi
			done
		else
			error=0
		fi
		
		if [ $error == 1 ]; then
			echo "$logheader :: ERROR :: No deezer album url found"
			echo "$albumartistname :: $albumreleasegroupmbzid :: $albumtitle"  >> "/config/logs/notfound.log"
			continue
		fi

		if [ -f "/config/logs/download.log" ]; then
			if cat "/config/logs/download.log" | grep -i "$filelogheader :: $albumdeezerurl" | read; then
				echo "$logheader :: Already Downloaded"
				continue
			fi
		fi

		if [ -z "$deezeralbumtitle" ]; then
			deezeralbumtitle="$albumtitle"
		fi

		if [ ! -d "$albumbimportfolder" ]; then
			chmod 0777 -R "${PathToDLClient}"
			currentpwd="$(pwd)"
			echo "$logheader :: DOWNLOADING :: $deezeralbumtitle :: $albumdeezerurl..."
			if cd "${PathToDLClient}" && python3 -m deemix -b $quality "$albumdeezerurl" && cd "${currentpwd}"; then
				sleep 0.5
				if find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | read; then
					chmod $FilePermissions "$DOWNLOADS"/amd/dlclient/*
					chown -R abc:abc "$DOWNLOADS"/amd/dlclient
					echo "$logheader :: DOWNLOAD :: success"
					echo "$filelogheader :: $albumdeezerurl"  >> "/config/logs/download.log"
				else
					echo "$logheader :: DOWNLOAD :: ERROR :: No files found"
					echo "$filelogheader :: $albumdeezerurl"  >> "/config/logs/error.log"
					continue
				fi
			fi

			file=$(find "$DOWNLOADS"/amd/dlclient -iregex ".*/.*\.\(flac\|mp3\)" | head -n 1)
			if [ ! -z "$file" ]; then
				artwork="$(dirname "$file")/folder.jpg"
				if ffmpeg -y -i "$file" -c:v copy "$artwork" 2>/dev/null; then
					echo "$logheader :: DOWNLOAD :: Artwork Extracted"
				else
					echo "$logheader :: DOWNLOAD :: ERROR :: No artwork found"
				fi
			fi
		else
			echo "$filelogheader :: $albumdeezerurl"  >> "/config/logs/download.log"
		fi
		
		TagFix
		
		if [ ! -d "$DOWNLOADS/amd/import" ]; then
			mkdir -p "$DOWNLOADS/amd/import"
			chmod $FolderPermissions "$DOWNLOADS/amd/import"
			chown -R abc:abc "$DOWNLOADS/amd/import"
		fi

		if [ ! -d "$albumbimportfolder" ]; then
			mkdir -p "$albumbimportfolder"
			mv "$DOWNLOADS"/amd/dlclient/* "$albumbimportfolder"/
			chmod $FolderPermissions "$albumbimportfolder"
			chmod $FilePermissions "$albumbimportfolder"/*
			chown -R abc:abc "$albumbimportfolder"
		fi
		importalbumfolder="$albumbimportfolder"
		LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrAPIkey} --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${importalbumfolder}\"}")
		echo "$logheader :: LIDARR IMPORT NOTIFICATION SENT! :: $albumbimportfolder"
	done
}

CleanupFailedImports () {
	if [ -d "$DOWNLOADS/amd/import" ]; then
		if ! [[ $(find "$DOWNLOADS/amd/import" -mindepth 1 -type d -mmin +480 -print) ]]; then
			find "$DOWNLOADS/amd/import" -mindepth 1 -type d -mmin +480 -print -exec rm -rf "{}" \; &> /dev/null
		fi
	fi
}

CreateDownloadFolders () {
	if [ ! -d "$DOWNLOADS/amd/import" ]; then
		mkdir -p "$DOWNLOADS/amd/import"
	fi
	
	if [ ! -d "$DOWNLOADS/amd/dlclient" ]; then
		mkdir -p "$DOWNLOADS/amd/dlclient"
	else
		rm "$DOWNLOADS"/amd/dlclient/* &> /dev/null
	fi
}

SetFolderPermissions () {
	if [ -d "$DOWNLOADS/amd/import" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd/import"
		chown -R abc:abc "$DOWNLOADS/amd/import"
	fi
	
	if [ -d "$DOWNLOADS/amd/dlclient" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd/dlclient"
		chown -R abc:abc "$DOWNLOADS/amd/dlclient"
	fi
	
	if [ -d "$DOWNLOADS/amd" ]; then
		chmod $FolderPermissions "$DOWNLOADS/amd"
		chown -R abc:abc "$DOWNLOADS/amd"
	fi
}

TagFix () {
	if find "$DOWNLOADS/amd/dlclient" -iname "*.flac" | read; then
		if ! [ -x "$(command -v metaflac)" ]; then
			echo "ERROR: FLAC verification utility not installed (ubuntu: apt-get install -y flac)"
		else
			for fname in "$DOWNLOADS"/amd/dlclient/*.flac; do
				filename="$(basename "$fname")"				
				metaflac "$fname" --remove-tag=ALBUMARTIST
				metaflac "$fname" --set-tag=ALBUMARTIST="$albumartistname"
				metaflac "$fname" --set-tag=MUSICBRAINZ_ALBUMARTISTID="$albumartistmbzid"
				echo "$logheader :: FIXING TAGS :: $filename fixed..."
			done
		fi
	fi
	if find "$DOWNLOADS/amd/dlclient" -iname "*.mp3" | read; then
		if ! [ -x "$(command -v eyeD3)" ]; then
			echo "eyed3 verification utility not installed (ubuntu: apt-get install -y eyed3)"
		else
			for fname in "$DOWNLOADS"/amd/dlclient/*.mp3; do
				filename="$(basename "$fname")"
				eyeD3 "$fname" -b "$albumartistname" &> /dev/null
				eyeD3 "$fname" --user-text-frame="MusicBrainz Album Artist Id:$albumartistmbzid" &> /dev/null
				echo "$logheader :: FIXING TAGS :: $filename fixed..."
			done
		fi
	fi
}

CreateDownloadFolders
SetFolderPermissions
Configuration
CacheEngine
CleanupFailedImports
WantedMode

exit 0
