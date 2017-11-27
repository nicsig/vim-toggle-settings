if exists('g:autoloaded_toggle_settings')
    finish
endif
let g:autoloaded_toggle_settings = 1

" How to pass arguments to a custom command?{{{
"
" When you  must pass  strings as  arguments to  a function  called by  a custom
" command, you must ask yourself 3 questions:
"
"         • do I quote the arguments?
"         • do I separate them with commas?
"         • do I use the escape sequence `<f-args>` or `<args>`?
"
" Here's what you get, depending on your answers:
"
"         • quote     +     `<f-args>`                 ✘ too much quotes (2x)
"         • no quote  +  no `<f-args>`                 ✘ E121            (undefined variable)
"         • quote     +  no comma       +  `<args>`    ✘ E116            (arguments not separated by commas)
"}}}
" Conclusions:{{{
"
"         • you must use commas, unless you use `<f-args>`
"         • you must quote the arguments passed to the command, or use `<f-args>`
"         • but not both
"
" Prefer to manually quote the arguments, instead of using `<f-args>`.
" Why?
" It allows you to pass non strings data, like dictionaries.
"
" Except, of course, if all your arguments need to be quoted.
" In this case, use `<f-args>`.
"}}}
com! -nargs=+ TS call s:toggle_settings(<args>)

" WARNING{{{
" Don't forget to properly handle repeated (dis)activations. {{{
" Necessary when you save/restore a state with a custom variable.
"
" When you  write a function  to activate/disactivate/toggle some state,  do NOT
" assume it will only be used for repeated toggling.
" It  can also  be used  for (accidental)  repeated activation,  or (accidental)
" repeated disactivation.
"
" If the function doesn't save/restore a  state using a custom variable, there's
" no issue (ex: `s:cursorline()`).  But  if it does (ex: `s:virtualedit()`), and
" you don't handle repeated (dis)activations, it can lead to errors.
"
" For example,  if you transit to  the same state  twice, the 1st time,  it will
" work as expected: the  function will save the original state,  A, then put you
" in the new state B.
" But the 2nd time, the function will blindly save B, as if it was A.
" So, when you will invoke it to restore A, you will, in effect, restore B.
"}}}
" What should you avoid?{{{
"
" NEVER write this:
"
"            ┌─ boolean argument:
"            │
"            │      • when it's 1 it means we want to enable  some state
"            │      • "         0                     disable "
"            │
"         if a:enable                       ✘
"             let s:save = …
"                 │
"                 └─ save current state for future restoration
"             …
"         else                              ✘
"             …
"         endif
"
" Instead:
"
"         if a:enable && is_disabled        ✔
"             let s:save = …
"             …
"         elseif a:disable && is_enabled    ✔
"             …
"         endif
"}}}
" Which functions are concerned?{{{
"
" All functions make  you transit to a new known  state (are there exceptions?).
" But some of them do it from a  known state, while others do it from an UNKNOWN
" one.  The current issue concerns the  latter, because when you transit from an
" unknown state, you have to save it first for the future restoration. You don't
" need to do that when you know it in advance.
"}}}
"}}}
" Functions {{{1
fu! s:auto_open_fold(action) abort "{{{2
    if a:action ==# 'is_active'
        return exists('s:fold_options_save')
    elseif a:action ==# 'enable' && !exists('s:fold_options_save')
        let s:fold_options_save = {
        \                           'close'  : &foldclose,
        \                           'open'   : &foldopen,
        \                           'enable' : &foldenable,
        \                           'level'  : &foldlevel,
        \                         }

        " Consider setting 'foldnestmax' if you use 'indent'/'syntax' as a folding method.{{{
        "
        " If you set the local value of  'fdm' to 'indent' or 'syntax', Vim will
        " automatically fold the buffer according to its indentation / syntax.
        "
        " It can lead to deeply nested folds. This can be annoying when you have
        " to open  a lot of  folds to  read the contents  of a line.
        "
        " One way to tackle this issue  is to reduce the value of 'foldnestmax'.
        " By default  it's 20 (which is  the deepest level of  nested folds that
        " Vim can produce with these 2 methods  anyway). If you set it to 1, Vim
        " will only produce folds for the outermost blocks (functions/methods).
        "}}}
        set foldclose=all " close a fold if we leave it with any command
        set foldopen=all  " open  a fold if we enter it with any command
        set foldenable
        set foldlevel=0   " close all folds by default
    elseif a:action ==# 'disable' && exists('s:fold_options_save')
        for op in keys(s:fold_options_save)
            exe 'let &fold'.op.' = s:fold_options_save.'.op
        endfor
        norm! zMzv
        unlet! s:fold_options_save
    endif
endfu

fu! s:cursorline(enable) abort "{{{2
    " 'cursorline' only in the active window and not in insert mode.
    if a:enable
        setl cursorline
        augroup my_cursorline
            au!
            au VimEnter,WinEnter * setl cursorline
            au WinLeave          * setl nocursorline
            au InsertEnter       * setl nocursorline
            au InsertLeave       * setl cursorline
        augroup END
    else
        setl nocursorline
        sil! au! my_cursorline
        sil! aug! my_cursorline
    endif
endfu

fu! s:formatprg(scope) abort "{{{2
    if a:scope ==# 'global' && (!exists('s:local_fp_save') || !has_key(s:local_fp_save, bufnr('%')))
        if !exists('s:local_fp_save')
            let s:local_fp_save = {}
        endif
        " use a dictionary to  save the local value of 'fp'  in any buffer where
        " we use our mappings to toggle the latter
        let s:local_fp_save[bufnr('%')] = &l:fp
        setl fp<
    elseif a:scope ==# 'local' && exists('s:local_fp_save') && has_key(s:local_fp_save, bufnr('%'))
        " `js-beautify` is a formatting tool for js, html, css.
        "
        " Installation:
        "
        "         sudo npm -g install js-beautify
        "
        " Documentation:
        "
        "         https://github.com/beautify-web/js-beautify
        "
        " The tool has  many options, you can use the  ones you find interesting
        " in the value of 'fp'.
        let &l:fp = get(s:local_fp_save, bufnr('%'), &l:fp)
        unlet! s:local_fp_save[bufnr('%')]
    endif
    echo '[formatprg] '.(!empty(&l:fp) ? &l:fp : &g:fp)
endfu

fu! s:matchparen(enable) abort "{{{2
    if empty(globpath(&rtp, 'plugin/my_matchparen.vim', 0, 1, 1))
        echo printf('no  %s  file was found in the runtimepath', 'plugin/matchparen.vim')
        return
    endif
    let cur_win = winnr()
    if a:enable && !exists('g:loaded_matchparen') || !a:enable && exists('g:loaded_matchparen')
        runtime plugin/my_matchparen.vim
    endif
    exe cur_win.'wincmd w'
    echo '[matchparen] '.(exists('g:loaded_matchparen') ? 'ON' : 'OFF')
endfu

fu! s:stl_list_position(enable) abort "{{{2
    let g:my_stl_list_position = a:enable ? 1 : 0
    redraws!
endfu

fu! s:toggle_settings(...) abort "{{{2
    if a:0 == 7
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] = a:000
        let msg1 = '['.label.'] '.msg1
        let msg2 = '['.label.'] '.msg2

    elseif a:0 == 5
        let [ label, letter, cmd1, cmd2, test ] = a:000

        let rhs3 =  '     if '.test
        \          .'<bar>    exe '.string(cmd2)
        \          .'<bar>else'
        \          .'<bar>    exe '.string(cmd1)
        \          .'<bar>endif'

        exe 'nno <silent> [o'.letter.' :<c-u>'.cmd1.'<cr>'
        exe 'nno <silent> ]o'.letter.' :<c-u>'.cmd2.'<cr>'
        exe 'nno <silent> co'.letter.' :<c-u>'.rhs3.'<cr>'

        return

    elseif a:0 == 2
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] =
          \ [ a:1, a:2, 'setl '.a:1, 'setl no'.a:1, '['.a:1.'] ON', '['.a:1.'] OFF', '&l:'.a:1 ]
    else
        return
    endif

    let rhs3 =  '     if '.test
    \          .'<bar>    exe '.string(cmd2).'<bar>echo '.string(msg2)
    \          .'<bar>else'
    \          .'<bar>    exe '.string(cmd1).'<bar>echo '.string(msg1)
    \          .'<bar>endif'

    exe 'nno <silent> [o'.letter.' :<c-u>'.cmd1.'<bar>echo '.string(msg1).'<cr>'
    exe 'nno <silent> ]o'.letter.' :<c-u>'.cmd2.'<bar>echo '.string(msg2).'<cr>'
    exe 'nno <silent> co'.letter.' :<c-u>'.rhs3.'<cr>'
endfu

fu! s:virtualedit(action) abort "{{{2
    if a:action ==# 'is_all'
        return exists('s:ve_save')
    elseif a:action ==# 'enable' && !exists('s:ve_save')
        let s:ve_save = &ve
        set ve=all
    elseif a:action ==# 'disable' && exists('s:ve_save')
        let &ve = get(s:, 've_save', 'block')
        unlet! s:ve_save
    endif
    redraws!
endfu

" Mappings {{{1
" Simple "{{{2

TS  'cursorcolumn', 'o'
TS  'hlsearch'    , 'h'
TS  'list'        , 'I'
TS  'spell'       , 's'
TS  'showcmd'     , 'W'
TS  'wrap'        , 'w'

" Complex {{{2

TS 'showbreak',
\  'B',
\  'setl showbreak=↪',
\  'setl showbreak=',
\  'ON',
\  'OFF',
\  '!empty(&sbr)'

" In   our  vimrc   we  manually   set  `g:seoul256_background`   to  choose   a
" custom  lightness.   When we  change  the  colorscheme,  from light  to  dark,
" `g:seoul256_background` has a value which will be interpreted as the desire to
" set a light colorscheme:
"
"         ~/.vim/plugged/seoul256.vim/colors/seoul256.vim
"
" This  is not  what we  want. We want  a dark  one. So, we  must make  sure the
" variable is deleted before trying to load the dark colorscheme.
TS 'colorscheme',
\  'C',
\  'colo seoul256-light<bar>call <sid>cursorline(0)',
\  'unlet! g:seoul256_background <bar> colo seoul256 <bar> call <sid>cursorline(1)',
\  'get(g:, "colors_name", "") =~? "light"'

TS 'conceal',
\  'c',
\  'setl cole=2',
\  'setl cole=3',
\  'Partial',
\  'Full',
\  '&l:cole==2'

TS 'diff',
\  'd',
\  'diffthis',
\  'diffoff',
\  'ON',
\  'OFF',
\  '&l:diff'

TS 'formatoptions',
\  'f',
\  'setl fo+=c',
\  'setl fo-=c',
\  '+c: auto-wrap comments ON',
\  '-c: auto-wrap comments OFF',
\  'index(split(&l:fo, "\\zs"), "c") >= 0'

TS 'stl list position',
\  'i',
\  'call <sid>stl_list_position(1)',
\  'call <sid>stl_list_position(0)',
\  'get(g:, "my_stl_list_position", 0) == 1'

TS 'cursorline',
\  'l',
\  'call <sid>cursorline(1)',
\  'call <sid>cursorline(0)',
\  'ON',
\  'OFF',
\  'exists("#my_cursorline")'

TS 'number',
\  'n',
\  'setl number relativenumber',
\  'setl nonumber norelativenumber',
\  '&l:nu'

" Alternative:{{{
" The following mapping/function allows to cycle through 3 states:
"
"     1. nonumber + norelativenumber
"     2. number   +   relativenumber
"     3. number   + norelativenumber
"
"     nno <silent> con :<c-u>call <sid>numbers()<cr>
"
"     fu! s:numbers() abort
"         " The key '01' (state) is not necessary because no command in the dictionary
"         " brings us to it.
"         " However, if we got in this state by accident, hitting the mapping would raise
"         " an error (E716: Key not present in Dictionary).
"         " So, we include it, and give it a value which brings us to state '11'.
"
"         exe {
"           \   '00' : 'setl nu | setl rnu',
"           \   '11' : 'setl nornu',
"           \   '01' : 'setl nonu',
"           \   '10' : 'setl nonu | setl nornu',
"           \ }[&l:nu.&l:rnu]
"     endfu
"}}}

TS 'nrformats',
\  'N',
\  'setl nf+=alpha',
\  'setl nf-=alpha',
\  '+alpha',
\  '-alpha',
\  'index(split(&l:nf, ","), "alpha") >= 0'

TS 'MatchParen',
\  'p',
\  'call <sid>matchparen(1)',
\  'call <sid>matchparen(0)',
\  'exists("g:loaded_matchparen")'

" `gq` is  currently used  to format comments,  but it would  also be  useful to
" execute formatting tools such as js-beautify.
TS 'formatprg',
\  'q',
\  'call <sid>formatprg("global")',
\  'call <sid>formatprg("local")',
\  '&g:fp ==# &l:fp'

TS 'spelllang',
\  'S',
\  'setl spl=fr',
\  'setl spl=en',
\  'FR',
\  'EN',
\  '&l:spl ==# "fr"'

TS 'fold title',
\  't',
\  'let b:my_title_full=1 <bar> redraw!',
\  'let b:my_title_full=0 <bar> redraw!',
\  'full',
\  'short',
\  'get(b:, "my_title_full", 0)'

TS 'virtualedit',
\  'v',
\  'call <sid>virtualedit("enable")',
\  'call <sid>virtualedit("disable")',
\  'ALL',
\  '∅',
\  '<sid>virtualedit("is_all")'

" Vim uses `z` as a prefix to build all fold-related commands in normal mode.
TS 'auto open folds',
\  'z',
\  'call <sid>auto_open_fold("enable")',
\  'call <sid>auto_open_fold("disable")',
\  'ON',
\  'OFF',
\  '<sid>auto_open_fold("is_active")'
"    │
"    └─ We can't use a  script-local variable, because we can't
"    access it from a mapping:
"
"               exists('s:my_var')       ✘
"               exists('<sid>my_var')    ✘
