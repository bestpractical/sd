" vim:et:sw=2:fdm=marker:
" SD Ticket Syntax File
" Maintainer:   Yo-An Lin < cornelius.howl@gmail.com >
" URL:          http://www.vim.org/scripts/script.php?script_id=2614
" Last Change:	09 Apr 21 04/21/2009
" Version:      0.1
" Intro: 
"
"   This syntax file is for ticket summary file of SD (peer-to-peer bug
"   tracking system)
"   http://syncwith.us/
"
" Usage:
"   To let vim known the editing file is SD ticket
"   add the below settings to your .vimrc
"
" au BufNewFile,BufRead *
"     \ if getline(1) =~ "required ticket metadata" |
"     \   setf sdticket |
"     \ endif
"

" For version 5.x: Clear all syntax items.
" For version 6.x: Quit when a syntax file was already loaded.
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn region sdHeader  start="^===" end="===$"
syn region sdColumn  start="^\w\+"  end=":"

syn keyword sdStatus new open close
syn keyword sdComponent core 

if version >= 508 || !exists("did_sdticket_syn_inits")
    if version < 508
        let did_sdticket_syn_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    " The default highlighting.
    HiLink sdHeader Comment
    HiLink sdColumn Identifier
    HiLink sdStatus Type
    delcommand HiLink
endif

let b:current_syntax = "sdticket"
