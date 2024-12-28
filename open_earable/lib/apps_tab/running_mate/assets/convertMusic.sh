#!/bin/bash

# Directory containing mp3 files
input_dir="audio"
output_dir="converted"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Loop through all mp3 files in the input directory
for input_file in "$input_dir"/*.mp3; do
  # Extract the base name of the file (without extension)
  base_name=$(basename "$input_file" .mp3)
  # Define the output file path
  output_file="$output_dir/${base_name}.wav"
  # Convert mp3 to wav using ffmpeg
  ffmpeg -i "$input_file" -c:a pcm_s16le -ac 1 -ar 44100 "$output_file"
done