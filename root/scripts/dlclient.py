import os.path as path
from os import mkdir
import sys
import click

from os.path import isfile

from deemix.app import deemix

class cli(deemix):
    def __init__(self, configFolder=None):
        super().__init__(configFolder)
        self.set.settings["downloadLocation"] = "/downloads-amd/amd/dlclient"
        self.set.settings["tracknameTemplate"] = "%discnumber%%tracknumber% - %title% %explicit%"
        self.set.settings["albumTracknameTemplate"] = "%discnumber%%tracknumber% - %title% %explicit%"
        self.set.settings["artistNameTemplate"] = "%artist% (%artist_id%)"
        self.set.settings["albumNameTemplate"] = "%artist% - %type% - %year% - %album_id% - %album% %explicit%"
        self.set.settings["createCDFolder"] = False
        self.set.settings["createAlbumFolder"] = False
        self.set.settings["saveArtworkArtist"] = True
        self.set.settings["jpegImageQuality"] = 90
        self.set.settings["embeddedArtworkSize"] = 1800
        self.set.settings["localArtworkSize"] = 1800
        self.set.settings["removeAlbumVersion"] = True
        self.set.settings["syncedLyrics"] = True
        self.set.settings["coverImageTemplate"] = "folder"
        self.set.settings["fallbackSearch"] = True
        self.set.settings["tags"]["trackTotal"] = True
        self.set.settings["tags"]["discTotal"] = True
        self.set.settings["tags"]["explicit"] = True
        self.set.settings["tags"]["length"] = False
        self.set.settings["tags"]["lyrics"] = True
        self.set.settings["tags"]["involvedPeople"] = True
        self.set.settings["tags"]["copyright"] = True
        self.set.settings["tags"]["composer"] = True
        self.set.settings["tags"]["savePlaylistAsCompilation"] = True
        self.set.settings["removeDuplicateArtists"] = True
        self.set.settings["featuredToTitle"] = "3"
        self.set.settings["tags"]["saveID3v1"] = False
        self.set.settings["tags"]["multiArtistSeparator"] = "andFeat"
        self.set.settings["tags"]["singleAlbumArtist"] = True
        self.set.saveSettings()

    def downloadLink(self, url, bitrate=None):
        for link in url:
            if ';' in link:
                for l in link.split(";"):
                    self.qm.addToQueue(self.dz, self.sp, l, self.set.settings, bitrate)
            else:
                self.qm.addToQueue(self.dz, self.sp, link, self.set.settings, bitrate)

    def requestValidArl(self):
        while True:
            arl = input("Paste here your arl:")
            if self.dz.login_via_arl(arl):
                break
        return arl

    def login(self):
        configFolder = self.set.configFolder
        if not path.isdir(configFolder):
            mkdir(configFolder)
        if path.isfile(path.join(configFolder, '.arl')):
            with open(path.join(configFolder, '.arl'), 'r') as f:
                arl = f.readline().rstrip("\n")
            if not self.dz.login_via_arl(arl):
                arl = self.requestValidArl()
        else:
            arl = self.requestValidArl()
        with open(path.join(configFolder, '.arl'), 'w') as f:
            f.write(arl)

@click.command()
@click.option('-b', '--bitrate', default=None, help='Overwrites the default bitrate selected')
@click.argument('url', nargs=-1, required=True)
def download(bitrate, url):
    app = cli()
    app.login()
    url = list(url)
    if isfile(url[0]):
        filename = url[0]
        with open(filename) as f:
            url = f.readlines()
    app.downloadLink(url, bitrate)
    click.echo("All done!")

if __name__ == '__main__':
    download()
