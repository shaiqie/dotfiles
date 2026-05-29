function qs --wraps='pacman -Qs' --description 'alias qs=pacman -Qs'
    pacman -Qs $argv
end
