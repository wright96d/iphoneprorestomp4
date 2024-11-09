# Define paths
$qaacPath = "C:\path\to\qaac_2.79\x64\qaac64.exe"
$mp4boxPath = "C:\Program Files\GPAC\mp4box.exe"
$x264Path = "C:\path\to\x264-r3198-da14df5.exe"
$exifToolPath = "C:\path\to\exiftool.exe"
$lsmashSourcePath = "C:\path\to\L-SMASH-Works-r1194.0.0.0\x64\LSMASHSource.dll"

# Prompt for folder path
$folderPath = Read-Host "Enter the folder path containing the MOV files"

# Main processing loop
$movFiles = Get-ChildItem -Path $folderPath -Filter *.mov
foreach ($movFile in $movFiles) {
    Write-Host "Processing file: $($movFile.FullName)"
    
    # Extract metadata from MOV file using ffprobe
    $ffprobeOutput = ffprobe -v quiet -print_format json -show_format -show_streams $movFile.FullName | ConvertFrom-Json
    $audioStream = $ffprobeOutput.streams | Where-Object { $_.codec_type -eq 'audio' }
    $videoStream = $ffprobeOutput.streams | Where-Object { $_.codec_type -eq 'video' }
    
    # Extract frame rate
    $frameRateParts = $videoStream.r_frame_rate -split '/'
    $frameRate = [double]($frameRateParts[0] / $frameRateParts[1])

    $bitDepth = $audioStream.bits_per_sample
    $videoResolution = ($($videoStream.width) * $($videoStream.height))
    $frameRateRounded = [math]::Ceiling($frameRate)
    $colorPrimaries = $videoStream.color_primaries
    $transferCharacteristics = $videoStream.color_transfer
    $matrixCoefficients = $videoStream.color_space
    $creationDate = $ffprobeOutput.format.tags.creation_time

    # Extract audio to WAV
    $wavFilePath = Join-Path -Path $movFile.DirectoryName -ChildPath "$($movFile.BaseName).wav"
    ffmpeg -i $movFile.FullName -vn -acodec pcm_s${bitDepth}le $wavFilePath

    # Encode WAV to M4A
    $m4aFilePath = Join-Path -Path $movFile.DirectoryName -ChildPath "$($movFile.BaseName).m4a"
    Start-Process -NoNewWindow -FilePath $qaacPath -ArgumentList "--ignorelength -s --no-optimize --start -1024s --no-delay -V 127 -o $m4aFilePath $wavFilePath" -Wait

    # Determine bitrate based on resolution and frame rate
    $bitrate = switch ("$($videoResolution)-$($frameRaterounded)") {
        "2073600-24" { 20000 }
        "2073600-30" { 25000 }
        "2073600-60" { 50000 }
        "8294400-24" { 80000 }        
        "8294400-30" { 100000 }
        "8294400-60" { 200000 }
        default { 25000 }  # Default to 25mbps if no match
    }

    # Create AVS file
    $avsFilePath = Join-Path -Path $movFile.DirectoryName -ChildPath "$($movFile.BaseName).avs"
    $avsContent = @"
LoadPlugin("$lsmashSourcePath")
LWLibavVideoSource("$($movFile.FullName)")
ConvertBits(8,dither=1)
"@
    $avsContent | Set-Content -Path $avsFilePath

    # Encode video using x264 with the AVS file
    $outputVideoFilePath = Join-Path -Path $movFile.DirectoryName -ChildPath "$($movFile.BaseName).264"
    $keyint = [math]::Ceiling($frameRate * 8)
    $keyintMin = [math]::Ceiling($frameRate / 8)
    $rcLookahead = [math]::Ceiling($frameRate * 2)
    $ref = [math]::Ceiling($frameRate / 6)
    
    $x264ArgsCommon = "--bitrate $bitrate --preset slow --force-cfr --profile high --level 5.1 --keyint $keyint --min-keyint $keyintMin --rc-lookahead $rcLookahead --ref $ref --colorprim $colorPrimaries --transfer $transferCharacteristics --colormatrix $matrixCoefficients"
    
    # Execute x264 first pass command
    Start-Process -NoNewWindow -FilePath $x264Path -ArgumentList "--slow-firstpass --pass 1 $x264ArgsCommon -o NUL $avsFilePath" -Wait

    # Execute x264 second pass command
    Start-Process -NoNewWindow -FilePath $x264Path -ArgumentList "--pass 2 $x264ArgsCommon -o $outputVideoFilePath $avsFilePath" -Wait

    # Combine video and audio using mp4box
    $outputFilePath = Join-Path -Path $movFile.DirectoryName -ChildPath "$($movFile.BaseName).mp4"
    Start-Process -NoNewWindow -FilePath $mp4boxPath -ArgumentList "-add `"$outputVideoFilePath#1:lang=und:name=:ID=1`" -add `"$m4aFilePath#1:delay=0:lang=eng:name=:ID=2`" -new `"$outputFilePath`"" -Wait

    # Copy metadata using exiftool with suppressed warnings and prompts
    $exifToolArgs = "-q -q -api largefilesupport=1 -TagsFromFile `"$movFile`" -all:all -Rotation `"$outputFilePath`" -m -P -overwrite_original_in_place"
    Start-Process -NoNewWindow -FilePath $exifToolPath -ArgumentList $exifToolArgs -Wait

    # Set creation and modified dates
    Set-ItemProperty -Path $outputFilePath -Name CreationTime -Value $creationDate
    Set-ItemProperty -Path $outputFilePath -Name LastWriteTime -Value $creationDate

    # Clean up temporary files
    Remove-Item -Path $wavFilePath -Force
    Remove-Item -Path $m4aFilePath -Force
    Remove-Item -Path $outputVideoFilePath -Force
    Remove-Item -Path $avsFilePath -Force
    Remove-Item -Path "$($movFile.FullName).lwi" -Force

    Write-Host "Completed processing for file: $($movFile.FullName)"
}