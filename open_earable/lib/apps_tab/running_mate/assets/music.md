# Music on the SD Card will sync to steps

### File Format

Format SD-Card with exFAT.

Example: 180_1.wav, 180_2.wav

180: bpm to sync to

number: song number, song will be chosen randomly

### Source

bpm audio files by https://www.reuneker.nl/files/metronome/

convert to .wav: `ffmpeg -i input.mp3 -c:a pcm_s16le -ac 1 -ar 44100 output.wav` or use convertMusic.sh
