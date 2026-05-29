function sp --wraps='sudo pacman -Ss' --description 'alias sp=sudo pacman -Ss'
    sudo pacman -Ss $argv
end
