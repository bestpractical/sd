# add this to your bash_completion.d directory

# handle the multi-word git sd command specially
function _gitsd_() { 
    _prophet_ "git sd" 
}
function _prophet_()
{
    COMPREPLY=($($1 _gencomp ${COMP_WORDS[COMP_CWORD]}))
}

complete -F _prophet_ sd
complete -F _gitsd_ git sd
