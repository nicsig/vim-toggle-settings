fu! s:toggle_settings(...) abort "{{{1
    if a:0 == 7
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] = a:000
        let msg1 = '['.label.'] '.msg1
        let msg2 = '['.label.'] '.msg2

    elseif a:0 == 2
        let [ label, letter, cmd1, cmd2, msg1, msg2, test ] =
          \ [ a:1, a:2, 'setl '.a:1, 'setl no'.a:1, '['.a:1.'] ON', '['.a:1.'] OFF', '&l:'.a:1 ]
    else
        return
    endif

    let rhs3 = 'if '.test
            \ .'<bar>    exe "'.cmd2.'"<bar>echo "'.msg2.'"'
            \ .'<bar>else'
            \ .'<bar>    exe "'.cmd1.'"<bar>echo "'.msg1.'"'
            \ .'<bar>endif'

    exe 'nno <silent> [o'.letter
    \.  ' :<c-u>'.cmd1
    \.  '<bar>echo '.string(
    \                       !empty(msg1)
    \?                          msg1
    \:                          '['.label.'] ON'
    \                      ).'<cr>'

    exe 'nno <silent> ]o'.letter
    \.  ' :<c-u>'.cmd2
    \.  '<bar>echo '.string(
    \                       !empty(msg2)
    \?                          msg2
    \:                          '['.label.'] OFF'
    \                      ).'<cr>'

    exe 'nno <silent> co'.letter.' :<c-u>'.rhs3.'<cr>'
endfu

com! -nargs=+ TS call s:toggle_settings(<f-args>)

fu! s:toggle_matchparen(enable) abort "{{{1
    let cur_win = winnr()
    " commands defined in `$VIMRUNTIME/plugin/matchparen.vim`
    exe a:enable ? 'DoMatchParen' : 'NoMatchParen'
    exe cur_win.'wincmd w'
endfu

" Simple settings "{{{1

TS  hlsearch      h
TS  list          i
TS  cursorline    l
TS  cursorcolumn  L
TS  showcmd       o
TS  spell         s
TS  wrap          w

" Complex settings {{{1

TS showbreak
                \ b
                \ setl\ showbreak=↪
                \ setl\ showbreak=
                \ ON
                \ OFF
                \ !empty(&sbr)

TS colorscheme
                \ c
                \ colo\ my_seoul_light
                \ colo\ my_seoul_dark
                \ light
                \ dark
                \ g:colors_name=~?'light'

TS diff
                \ d
                \ diffthis
                \ diffoff
                \ ON
                \ OFF
                \ &l:diff

TS formatoptions
                \ f
                \ setl\ fo+=t\ fo+=c
                \ setl\ fo-=t\ fo-=c
                \ +t\ +c\ auto-wrap
                \ -t\ -c\ NO\ auto-wrap
                \ count(split(&l:fo,'\\zs'),'c')

TS number
                \ n
                \ setl\ number\ relativenumber
                \ setl\ nonumber\ norelativenumber
                \ ON
                \ OFF
                \ &l:nu

" Alternative:{{{
" The following mapping/function allows to cycle between 3 states:
"
"     1. nonumber + norelativenumber
"     2. number   +   relativenumber
"     3. number   + norelativenumber
"
"     nno <silent> con :<c-u>call <sid>toggle_numbers()<cr>
"
"     fu! s:toggle_numbers() abort
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

TS nrformats
                \ N
                \ setl\ nf+=alpha
                \ setl\ nf-=alpha
                \ +alpha
                \ -alpha
                \ count(split(&l:nf,','),'alpha')

TS MatchParen
                \ p
                \ call\ <sid>toggle_matchparen(1)
                \ call\ <sid>toggle_matchparen(0)
                \ ON
                \ OFF
                \ exists('g:loaded_matchparen')

TS spelllang
                \ S
                \ setl\ spl=fr
                \ setl\ spl=en
                \ FR
                \ EN
                \ &l:spl==#'fr'

TS fold\ title
                \ t
                \ let\ b:my_title_full=1
                \ let\ b:my_title_full=0
                \ full
                \ short
                \ get(b:,'my_title_full',0)

TS virtualedit
                \ v
                \ set\ ve=all\|redraws!
                \ set\ ve=\|redraws!
                \ ALL
                \ ø
                \ !empty(&ve)
