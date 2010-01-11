# add this to your bash_completion.d directory
function _prophet_()
{
    COMPREPLY=($($1 _gencomp ${COMP_WORDS[COMP_CWORD]}))
}

complete -F _prophet_ sd
