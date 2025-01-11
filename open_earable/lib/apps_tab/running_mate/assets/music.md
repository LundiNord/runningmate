# Music on the SD Card will sync to steps

The App expects 30–200 bpm audio files on the SD Card to sync the steps to the music.

### File Format

Format SD-Card with exFAT.

Example: 180_1.wav, 180_2.wav

180: bpm to sync to

number: song number, song will be chosen randomly.
The Number of songs available can be set in app settings.

only WAV Files, Format tag: PCM, single Channels (Mono), 44100 Sample rate,
and 16 Bits per Sample audio files are supported.

### Source

bpm audio files by https://www.reuneker.nl/files/metronome/

convert to .wav: `ffmpeg -i input.mp3 -c:a pcm_s16le -ac 1 -ar 44100 output.wav` or use convertMusic.sh for batch conversion.
