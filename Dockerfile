FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="Automated Music Downloader"
ENV VERSION="1.0.1"
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
		r128gain \
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
	chmod 0777 -R "/xdg/deemix"
	
WORKDIR /

# copy local files
COPY root/ /

# ports and volumes
VOLUME /config
