# iphoneprorestomp4

For when you're insane enough to record ProRes video on an iPhone but not insane enough to have a 1tb+ iCloud account. Created to allow for local backup of ProRes originals and more manageable, but still high quality, iPhone/iCloud copies keeping all metadata intact. But could obviously be used to just reencode and delete the ProRes originals. Bitrates can be changed within the script. Could probably be mostly done with ffmpeg I guess, but where's the fun in that? Will probably add log conversion when I upgrade my phone. Not sure when that will be.

Required software
[qaac](https://github.com/nu774/qaac)
[mp4box](https://github.com/gpac/gpac/wiki/mp4box)
[x264](https://artifacts.videolan.org/x264/release-win64/)
[exifTool](https://exiftool.org/)
[lsmashSource](https://github.com/HomeOfAviSynthPlusEvolution/L-SMASH-Works/releases/)
[ffmpeg](https://www.ffmpeg.org/download.html)
[AviSynth+](https://github.com/AviSynth/AviSynthPlus)

Initially tried feeding the mov straight to x264 without avs, but ran into issues with 1-frame differences on 2-pass encoding.

Known issue: Cannot copy lens information from stock camera app. This is unfortunately inherent to exiftool.

NOTE: Created with chatgpt
