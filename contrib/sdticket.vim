" vim:et:sw=2:fdm=marker:
" SD Ticket Syntax File
" Maintainer:   Yo-An Lin < cornelius.howl@gmail.com >
" URL:          http://www.vim.org/scripts/script.php?script_id=2614
" Last Change:  08/17/2009
" Version:      0.2
" Intro: 
"
"   This syntax file is for ticket create/update template of SD (a
"   peer-to-peer bug tracking system)
"       http://syncwith.us/
"
" Usage:
"   To let vim know the editing file is an SD ticket, add the following to
"   your .vimrc and copy or link this file to your vim syntax directory
"   (usually ~/.vim/syntax):
"
" au BufNewFile,BufRead *
"     \ if getline(1) =~ '\(required ticket metadata\)\|\(errors in this ticket\)' |
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

" takes the string output of 'sd settings', offsets for the start and end of
" the JSON value of a setting not including the [], and returns a list of the
" elements with the quotes stripped
func! s:ConvertSubstrToList(str, start, end)
  return map(
  \  split(
  \    strpart(
  \      a:str, a:start, a:end - a:start,
  \    ),
  \  ',',
  \  ),
  \  "substitute( v:val, '\"', '', 'g' )",
  \ )
endfunc

syn region sdHeader  start="^===" end="===$"
syn region sdComment start="^#" end="$"
syn region sdColumn  start="^\w\+:\@="  end=":"

" try to get the valid statuses, components, milestones etc. from the settings
" for the current sd replica
" assumes SD_REPO is set and sd command is sd, otherwise will fall back to
" defaults
let s:settings = system("sd settings")

if s:settings =~ '\(not found\)\|\(Compilation failed\)'
  " user is running some wrapper script or sd is broken; use sd defaults
  syn keyword sdStatus new open closed stalled rejected
  syn keyword sdComponent core ui docs tests
  syn keyword sdMilestone alpha beta 1.0
else
  " parse the settings we found and setup syntax for them
  let s:milestones_offset = matchend(s:settings, "milestones: [")
  let s:closing_bracket_offset = match(s:settings, "]", s:milestones_offset)
  let s:milestones = s:ConvertSubstrToList(s:settings, s:milestones_offset, s:closing_bracket_offset)

  let s:components_offset = matchend(s:settings, "components: [")
  let s:closing_bracket_offset = match(s:settings, "]", s:components_offset)
  let s:components = s:ConvertSubstrToList(s:settings, s:components_offset, s:closing_bracket_offset)

  let s:statuses_offset = matchend(s:settings, "statuses: [")
  let s:closing_bracket_offset = match(s:settings, "]", s:statuses_offset)
  let s:statuses = s:ConvertSubstrToList(s:settings, s:statuses_offset, s:closing_bracket_offset)

  for s:list in [s:milestones, s:components, s:statuses]
    for s:group in ['sdMilestone', 'sdComponent', 'sdStatus']
      let s:syntax = 'syn keyword ' . s:group . ' ' . join(s:list)
      exec s:syntax
    endfor
  endfor
endif

if version >= 508 || !exists("did_sdticket_syn_inits")
    if version < 508
        let did_sdticket_syn_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    " The default highlighting.
    HiLink sdHeader Comment
    HiLink sdComment Comment
    HiLink sdColumn Label
    " do we want these to be different colours?
    HiLink sdStatus Type
    HiLink sdMilestone Type
    HiLink sdComponent Type
    delcommand HiLink
endif

let b:current_syntax = "sdticket"
