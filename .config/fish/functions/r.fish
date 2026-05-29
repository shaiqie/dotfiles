function r --wraps='sudo pacman -R' --description 'alias r=sudo pacman -R'
    sudo pacman -R $argv
end
