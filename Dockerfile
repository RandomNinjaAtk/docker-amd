FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="Automated Music Downloader"
ENV VERSION="0.0.1"
ENV MBRAINZMIRROR="https://musicbrainz.org"
ENV XDG_CONFIG_HOME="/xdg"
ENV PathToDLClient="/root/scripts/deemix"

RUN \
	echo "************ install dependencies ************" && \
	echo "************ install packages ************" && \
	apt-get update -y && \
	apt-get install -y --no-install-recommends \
		wget \
		nano \
		unzip \
		git \
		jq \
		mp3val \
		flac \
		opus-tools \
		eyed3 \
		beets \
		python3 \
		ffmpeg \
		python3-pip \
		libchromaprint-tools \
		imagemagick \
		python3-pythonmagick \
		kid3-cli \
		cron && \
	rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/* && \
	echo "************ install beets plugin dependencies ************" && \
	pip3 install --no-cache-dir -U \
		requests \
		Pillow \
		pylast \
		mutagen \
		pyacoustid && \
	echo "************ download dl client ************" && \
	echo "************ make directory ************" && \
	mkdir -p ${PathToDLClient} && \
	mkdir -p "${XDG_CONFIG_HOME}/deemix" && \
	echo "************ download dl client repo ************" && \
	git clone https://codeberg.org/RemixDev/deemix.git ${PathToDLClient} && \
	echo "************ install pip dependencies ************" && \
	pip3 install -r /root/scripts/deemix/requirements.txt --user && \
	echo "************ customize dlclient ************" && \
	sed -i 's/"downloadLocation": "",/"downloadLocation": "\/downloadfolder",/g' "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"tracknameTemplate\": \"%artist% - %title%\"/\"tracknameTemplate\": \"%discnumber%%tracknumber% - %title% %explicit%\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"albumTracknameTemplate\": \"%tracknumber% - %title%\"/\"albumTracknameTemplate\": \"%discnumber%%tracknumber% - %title% %explicit%\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"artistNameTemplate\": \"%artist%\"/\"artistNameTemplate\": \"%artist% (%artist_id%)\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"albumNameTemplate\": \"%artist% - %album%\"/\"albumNameTemplate\": \"%artist% - %type% - %year% - %album_id% - %album% %explicit%\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"createCDFolder\": true/\"createCDFolder\": false/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"saveArtworkArtist\": false/\"saveArtworkArtist\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"jpegImageQuality\": 80/\"jpegImageQuality\": 90/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"embeddedArtworkSize\": 800/\"embeddedArtworkSize\": 1800/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"localArtworkSize\": 1400/\"localArtworkSize\": 1800/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"removeAlbumVersion\": false/\"removeAlbumVersion\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"syncedLyrics\": false/\"syncedLyrics\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"coverImageTemplate\": \"cover\"/\"coverImageTemplate\": \"folder\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"fallbackSearch\": false/\"fallbackSearch\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"trackTotal\": false/\"trackTotal\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"discTotal\": false/\"discTotal\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"explicit\": false/\"explicit\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"length\": true/\"length\": false/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"lyrics\": false/\"lyrics\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"involvedPeople\": false/\"involvedPeople\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"copyright\": false/\"copyright\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"composer\": false/\"composer\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"savePlaylistAsCompilation\": false/\"savePlaylistAsCompilation\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"removeDuplicateArtists\": false/\"removeDuplicateArtists\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"featuredToTitle\": \"0\"/\"featuredToTitle\": \"3\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"saveID3v1\": true/\"saveID3v1\": false/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"multiArtistSeparator\": \"default\"/\"multiArtistSeparator\": \"andFeat\"/g" "/root/scripts/deemix/deemix/app/default.json" && \
	sed -i "s/\"singleAlbumArtist\": false/\"singleAlbumArtist\": true/g" "/root/scripts/deemix/deemix/app/default.json" && \
	cp "/root/scripts/deemix/deemix/app/default.json" "/xdg/deemix/config.json" && \
	chmod 0777 -R "/xdg/deemix"
	
WORKDIR /

# copy local files
COPY root/ /

# ports and volumes
VOLUME /config
