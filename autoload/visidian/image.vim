" visidian/autoload/image.vim

" Function: visidian#image#display_graph
" Description: Display a gnuplot graph in a vsplit buffer
" Parameters:
"   - data: List of [x, y] pairs to plot
"   - title: Title for the graph buffer (optional)
function! visidian#image#display_graph(data, ...)
    call visidian#debug#debug('IMAGE', 'Starting display_graph with data: ' . string(a:data))
    
    " Create temporary files with .dat and .png extensions
    let tempfile = tempname()
    let datafile = tempfile . '.dat'
    let pngfile = tempfile . '.png'
    let scriptfile = tempfile . '.gnuplot'

    " Write data to temporary file
    call writefile(map(copy(a:data), 'string(v:val[0]) . " " . string(v:val[1])'), datafile)

    " Generate gnuplot command with enhanced styling
    let plotcmd = 'set terminal png size 800,600 enhanced font "arial,10";'
    let plotcmd .= 'set output "' . pngfile . '";'
    let plotcmd .= 'set title "' . (a:0 > 0 ? a:1 : 'Statistics Graph') . '";'
    let plotcmd .= 'set xlabel "Categories";'
    let plotcmd .= 'set ylabel "Count";'
    let plotcmd .= 'set style data histogram;'
    let plotcmd .= 'set style fill solid;'
    let plotcmd .= 'plot "' . datafile . '" using 2:xticlabels(1) title "Count" with boxes'

    " Create gnuplot script
    call writefile([plotcmd], scriptfile)

    " Execute gnuplot and check for success
    let gnuplot_output = system('gnuplot ' . scriptfile)
    if v:shell_error != 0
        call visidian#debug#debug('IMAGE', 'Error running gnuplot: ' . gnuplot_output)
        return
    endif

    " Check if the PNG file was created
    if !filereadable(pngfile)
        call visidian#debug#debug('IMAGE', 'PNG file was not created: ' . pngfile)
        return
    endif

    " Create new vsplit buffer for the graph
    vsplit
    enew

    " Set buffer name
    let buffer_name = a:0 > 0 ? a:1 : 'GraphOutput'
    if buflisted(buffer_name)
        let buffer_name .= '_' . localtime()
    endif

    " Set buffer options before naming it
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal modifiable
    setlocal noreadonly
    setlocal bufhidden=wipe

    " Name the buffer
    execute 'silent file ' . buffer_name

    " Get terminal dimensions
    let width = winwidth(0)
    let height = winheight(0)

    " Check if we're in Kitty terminal
    if exists('$KITTY_WINDOW_ID') && executable('timg')
        " Use timg with Kitty protocol
        let timg_cmd = 'timg -pk --compress -g' . width . 'x' . height . ' --clear ' . pngfile
        let output = system(timg_cmd)
        
        if v:shell_error != 0
            call visidian#debug#debug('IMAGE', 'Error running timg with Kitty protocol: ' . output)
            " Try fallback to regular timg
            let timg_cmd = 'timg -g' . width . 'x' . height . ' --clear ' . pngfile
            let output = system(timg_cmd)
            
            if v:shell_error != 0
                call visidian#debug#debug('IMAGE', 'Error running timg fallback: ' . output)
                " Fallback to ASCII art
                call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
                return
            endif
        endif
    elseif executable('timg')
        " Use regular timg
        let timg_cmd = 'timg -g' . width . 'x' . height . ' --clear ' . pngfile
        let output = system(timg_cmd)
        
        if v:shell_error != 0
            call visidian#debug#debug('IMAGE', 'Error running timg: ' . output)
            " Fallback to ASCII art
            call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
            return
        endif
    else
        " Fallback to ASCII art if no image display is available
        call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
        return
    endif

    " Clear buffer and insert output
    silent! %delete _
    silent! 0put =output
    normal! gg
    setlocal nomodifiable

    " Clean up temporary files
    call delete(datafile)
    call delete(scriptfile)
    call delete(pngfile)

    call visidian#debug#debug('IMAGE', 'Completed display_graph')
endfunction