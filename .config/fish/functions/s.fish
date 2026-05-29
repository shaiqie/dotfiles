function s --wraps='pacman -Ss' --description 'alias s=pacman -Ss'
    pacman -Ss $argv
end
