function convid --description 'Extreme compatibility compression for phone/sharing'
    if test (count $argv) -lt 1
        echo "Usage: crunch input_video.mov"
        return 1
    end

    set -l input $argv[1]
    set -l output (string replace -r '\.[^.]+$' '' $input)-final.mp4

    echo "Crunching $input for maximum phone compatibility..."
    
    # -pix_fmt yuv420p: Forces 8-bit (Fixes 10-bit black screens)
    # -profile:v main: Uses a simpler H.264 profile phones understand
    # -level 4.0: Ensures older phone chips can decode it
    # -c:a aac: Standard audio
    ffmpeg -i "$input" \
        -c:v libx264 -crf 23 -preset medium \
        -pix_fmt yuv420p -profile:v main -level 4.0 \
        -c:a aac -b:a 128k -movflags +faststart \
        "$output"
    
    if test $status -eq 0
        echo "Success! Transfer $output to your phone and try again."
    else
        echo "Error: Conversion failed."
    end
end
