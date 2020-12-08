#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import enum
import argparse
from mutagen.mp4 import MP4, MP4Cover

parser = argparse.ArgumentParser(description='Optional app description')
# Argument
parser.add_argument('--file', help='A required integer positional argument')
parser.add_argument('--songtitle', help='A required integer positional argument')
parser.add_argument('--songalbum', help='A required integer positional argument')
parser.add_argument('--songartist', help='A required integer positional argument')
parser.add_argument('--songartistalbum', help='A required integer positional argument')
parser.add_argument('--songbpm', help='A required integer positional argument')
parser.add_argument('--songcopyright', help='A required integer positional argument')
parser.add_argument('--songtracknumber', help='A required integer positional argument')
parser.add_argument('--songtracktotal', help='A required integer positional argument')
parser.add_argument('--songdiscnumber', help='A required integer positional argument')
parser.add_argument('--songdisctotal', help='A required integer positional argument')
parser.add_argument('--songcompilation', help='A required integer positional argument')
parser.add_argument('--songlyricrating', help='A required integer positional argument')
parser.add_argument('--songdate', help='A required integer positional argument')
parser.add_argument('--songyear', help='A required integer positional argument')
parser.add_argument('--songgenre', help='A required integer positional argument')
parser.add_argument('--songcomposer', help='A required integer positional argument')
parser.add_argument('--songisrc', type=str, help='A required integer positional argument')
parser.add_argument('--songartwork', help='A required integer positional argument')
parser.add_argument('--songauthor', type=str, help='A required integer positional argument')
parser.add_argument('--songartists', type=str, help='A required integer positional argument')
parser.add_argument('--songengineer', type=str, help='A required integer positional argument')
parser.add_argument('--songproducer', type=str, help='A required integer positional argument')
parser.add_argument('--songmixer', type=str, help='A required integer positional argument')
parser.add_argument('--songpublisher', type=str, help='A required integer positional argument')
parser.add_argument('--songcomment', type=str, help='A required integer positional argument')
parser.add_argument('--songbarcode', type=str, help='A required integer positional argument')
parser.add_argument('--mbrainzalbumartistid', type=str, help='A required integer positional argument')
parser.add_argument('--mbrainzreleasegroupid', type=str, help='A required integer positional argument')
parser.add_argument('--mbrainzalbumid', type=str, help='A required integer positional argument')
args = parser.parse_args()

filename = args.file
bpm = int(args.songbpm)
rtng = int(args.songlyricrating)
trackn = int(args.songtracknumber)
trackt = int(args.songtracktotal)
discn = int(args.songdiscnumber)
disct = int(args.songdisctotal)
compilation = int(args.songcompilation)
copyrightext = args.songcopyright
title = args.songtitle
album = args.songalbum
artist = args.songartist
artistalbum = args.songartistalbum
date = args.songdate
year = args.songyear
genre = args.songgenre
composer = args.songcomposer
isrc = args.songisrc
picture = args.songartwork
lyricist = args.songauthor
artists = args.songartists
tracknumber = (trackn, trackt)
discnumber = (discn, disct)
engineer = args.songengineer
producer = args.songproducer
mixer = args.songmixer
label = args.songpublisher
barcode = args.songbarcode
comment = args.songcomment
albumartistid = args.mbrainzalbumartistid
releasegroupid = args.mbrainzreleasegroupid
albumid = args.mbrainzalbumid

audio = MP4(filename)
audio["\xa9nam"] = [title]
audio["\xa9alb"] = [album]
audio["\xa9ART"] = [artist]
audio["aART"] = [artistalbum]
audio["\xa9day"] = [date]
audio["\xa9gen"] = [genre]
audio["\xa9wrt"] = [composer]
audio["rtng"] = [rtng]
if bpm:
    audio["tmpo"] = [bpm]
audio["trkn"] = [tracknumber]
audio["disk"] = [discnumber]
audio["cprt"] = [copyrightext]
if lyricist:
    audio["----:com.apple.iTunes:LYRICIST"] = lyricist.encode()
if artists:
    audio["----:com.apple.iTunes:ARTISTS"] = artists.encode()
if engineer:
    audio["----:com.apple.iTunes:ENGINEER"] = engineer.encode()
if producer:
    audio["----:com.apple.iTunes:PRODUCER"] = producer.encode()
if mixer:
    audio["----:com.apple.iTunes:MIXER"] = mixer.encode()
if label:
    audio["----:com.apple.iTunes:LABEL"] = label.encode()
if barcode:
    audio["----:com.apple.iTunes:BARCODE"] = barcode.encode()
if isrc:
    audio["----:com.apple.iTunes:ISRC"] = isrc.encode()
if albumartistid:
    audio["----:com.apple.iTunes:MusicBrainz Album Artist Id"] = albumartistid.encode()
if releasegroupid:
    audio["----:com.apple.iTunes:MusicBrainz Release Group Id"] = releasegroupid.encode()
if albumid:
    audio["----:com.apple.iTunes:MusicBrainz Album Id"] = albumid.encode()


if ( compilation == 1 ):
   audio["cpil"] = [compilation]
audio["stik"] = [1]
audio["\xa9cmt"] = [comment]
with open(picture, "rb") as f:
    audio["covr"] = [
        MP4Cover(f.read(), MP4Cover.FORMAT_JPEG)
    ]
#audio["\xa9lyr"] = [syncedlyrics]
audio.pprint()
audio.save()
