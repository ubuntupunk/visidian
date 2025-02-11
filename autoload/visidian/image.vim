" visidian/autoload/image.vim

" Function: visidian#image#display_graph
" Description: Display a gnuplot graph in a vsplit buffer
" Parameters:
"   - data: List of [x, y] pairs to plot
"   - title: Title for the graph buffer (optional)
function! visidian#image#display_graph(data, ...)
    call visidian#debug#debug('IMAGE', 'Starting display_graph with data: ' . string(a:data))
    
    " Create temporary file for gnuplot data
    let tempfile = tempname()
    call writefile(map(copy(a:data), 'string(v:val[0]) . " " . string(v:val[1])'), tempfile)

    " Generate gnuplot command with enhanced styling
    let plotcmd = 'set terminal png size 800,600 enhanced font "arial,10";'
    let plotcmd .= 'set output "' . tempfile . '.png";'
    let plotcmd .= 'set title "' . (a:0 > 0 ? a:1 : 'Statistics Graph') . '";'
    let plotcmd .= 'set xlabel "Categories";'
    let plotcmd .= 'set ylabel "Count";'
    let plotcmd .= 'set style data histogram;'
    let plotcmd .= 'set style fill solid;'
    let plotcmd .= 'plot "' . tempfile . '" using 2:xticlabels(1) title "Count" with boxes'

    " Create gnuplot script
    let scriptfile = tempname() . '.gnuplot'
    call writefile([plotcmd], scriptfile)

    " Execute gnuplot
    call system('gnuplot ' . scriptfile)

    " Check if image viewer is available (using timg for terminal)
    if executable('timg')
        " Create new vsplit buffer for the graph
        vsplit
        enew
        let buffer_name = a:0 > 0 ? a:1 : 'GraphOutput'
        if buflisted(buffer_name)
            let buffer_name .= '_' . localtime()
        endif
        execute 'file ' . buffer_name
        setlocal buftype=nofile
        setlocal modifiable

        " Get terminal dimensions
        let width = winwidth(0)
        let height = winheight(0)

        " Display image using timg with geometry parameters
        let output = system('timg -g' . width . 'x' . height . ' --clear ' . tempfile . '.png')
        put =output
        normal! gg
        setlocal nomodifiable

        " Clean up temporary files
        call delete(tempfile)
        call delete(scriptfile)
        call delete(tempfile . '.png')
    else
        " Fallback to ASCII art if timg is not available
        call visidian#graph#PlotData(a:data, a:0 > 0 ? a:1 : '')
    endif

    call visidian#debug#debug('IMAGE', 'Completed display_graph')
endfunction