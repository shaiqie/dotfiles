function vinci --description 'Convert video to DaVinci Resolve friendly DNxHR/PCM format'
    if test (count $argv) -lt 1
        echo "Usage: vinci input_file.mp4 [output_file.mov]"
        return 1
    end

    set -l input $argv[1]
    set -l output $argv[2]

    # If no output name is provided, use the input name with .mov extension
    if test -z "$output"
        set output (string replace -r '\.[^.]+$' '' $input)-davinci.mov
    end

    echo "Converting $input to $output for Resolve..."
    
    # -c:v dnxhr_hq: High quality intermediate codec
    # -pix_fmt yuv422p: Required color space for Resolve Free
    # -c:a pcm_s16le: Uncompressed audio (essential for Linux)
    ffmpeg -i "$input" -c:v dnxhr_hq -pix_fmt yuv422p -c:a pcm_s16le "$output"
    
    if test $status -eq 0
        echo "Done! You can now import $output into DaVinci Resolve."
    else
        echo "Conversion failed. Check if ffmpeg is installed."
    end
end
