function phony --description 'Convert Resolve export to mobile-friendly MP4'
    if test (count $argv) -lt 1
        echo "Usage: tophone input_huge_video.mov"
        return 1
    end

    set -l input $argv[1]
    set -l output (string replace -r '\.[^.]+$' '' $input)-mobile.mp4

    echo "Converting $input for mobile playback..."
    
    # -c:v libx264: Standard H.264 video
    # -pix_fmt yuv420p: Crucial! Most phones CANNOT play yuv422p (Resolve's default)
    # -c:a aac: Standard mobile audio
    # -b:a 192k: Good audio quality
    # -movflags +faststart: Allows the video to start playing before fully downloaded
    ffmpeg -i "$input" -c:v libx264 -pix_fmt yuv420p -preset slow -crf 22 -c:a aac -b:a 192k -movflags +faststart "$output"
    
    if test $status -eq 0
        echo "Done! Transfer $output to your phone."
    else
        echo "Conversion failed."
    end
end
