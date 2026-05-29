function qi --wraps='pacman -Qi' --description 'alias qi=pacman -Qi'
    pacman -Qi $argv
end
