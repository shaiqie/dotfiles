function rip --wraps="expac --timefmt='%Y-%m-%d %T' '%l\\t%n %v' | sort | tail -200 | nl" --wraps=/usr/bin/rip --description 'alias rip=/usr/bin/rip'
    /usr/bin/rip $argv
end
