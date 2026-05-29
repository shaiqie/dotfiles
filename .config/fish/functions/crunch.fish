function crunch --description 'Compress large Resolve exports for sharing'
    if test (count $argv) -lt 1
        echo "Usage: crunch input_huge_video.mov"
        return 1
    end

    set -l input $argv[1]
    set -l output (string replace -r '\.[^.]+$' '' $input)-final.mp4

    echo "Compressing $input into a shareable MP4..."
    
    # -crf 23: Balanced quality (lower is better quality, higher is smaller size)
    # -preset slow: Takes longer but makes the file smaller
    ffmpeg -i "$input" -vcodec libx264 -crf 23 -preset slow -acodec aac "$output"
    
    if test $status -eq 0
        echo "Finished! Final file: $output"
    else
        echo "Compression failed."
    end
end
