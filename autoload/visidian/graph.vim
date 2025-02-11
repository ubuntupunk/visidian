" Function: visidian#graph#DrawLineGraph
" Description: Draws a simple line graph in a Vim buffer using ASCII characters.
" Parameters:
"   - data: List of numerical values to plot.
"   - title (optional): Title for the graph buffer.
" Usage: call visidian#graph#DrawLineGraph([1, 2, 3], 'My Line Graph')
" Function: visidian#graph#DrawLineGraph
" Description: Draws a simple line graph in a Vim buffer using ASCII characters.
" Parameters:
"   - data: List of numerical values to plot.
"   - title (optional): Title for the graph buffer.
" Usage: call visidian#graph#DrawLineGraph([1, 2, 3], 'My Line Graph')
function! visidian#graph#DrawLineGraph(data, ...)
  call visidian#debug#debug('GRAPH', 'Starting DrawLineGraph with data: ' . string(a:data))

  " Check if data is valid
  if empty(a:data) || type(a:data) != v:t_list || empty(filter(copy(a:data), 'v:val->type(v:val) == v:t_number'))
    call visidian#debug#debug('GRAPH', 'Invalid data provided for graph')
    return
  endif

  let max_y = max(a:data)
  let min_y = min(a:data)
  let height = 10 " Fixed height for simplicity
  let width = len(a:data)

  " Use provided title or default
  let buffer_name = a:0 > 0 ? a:1 : 'LineGraphOutput'
  if buflisted(buffer_name)
    let buffer_name .= '_' . localtime()
  endif

  " Clear the current buffer and use a vertical split
  vsplit
  enew
  execute 'file ' . buffer_name
  normal! gg"_dG

  " Draw axes - using setline for performance
  let axis_lines = repeat(['|'], height)
  let axis_lines += [repeat('-', width + 1)]
  call setline(1, axis_lines)

  " Draw the data points
  for i in range(width)
    let y = float2nr((a:data[i] - min_y) / (max_y - min_y) * (height - 1))
    let line = getline(height - y)
    call setline(height - y, line . '*')
  endfor

  " Adjust cursor position
  normal! G$
  call visidian#debug#debug('GRAPH', 'Completed DrawLineGraph')
endfunction

" Function: visidian#graph#PlotData
" Description: Plots data using gnuplot if available, or falls back to DrawLineGraph.
" Parameters:
"   - data: List of [x, y] pairs to plot.
"   - title (optional): Title for the graph buffer.
" Usage: call visidian#graph#PlotData([[0, 1], [1, 2]], 'My Plot')

" Function: visidian#graph#PlotData
" Description: Plots data using gnuplot if available, or falls back to DrawLineGraph.
" Parameters:
"   - data: List of [x, y] pairs to plot, where x and y are strings representing numbers.
"   - title (optional): Title for the graph buffer.
" Usage: call visidian#graph#PlotData([[0, 1], [1, 2]], 'My Plot')
function! visidian#graph#PlotData(data, ...)
  call visidian#debug#debug('GRAPH', 'Starting PlotData with data: ' . string(a:data))

  " Check if data is valid
  if empty(a:data) || type(a:data) != v:t_list || !v:val is# filter(a:data, 'type(v:val) == v:t_list && len(v:val) == 2 && type(v:val[0]) == v:t_string && type(v:val[1]) == v:t_string')
    call visidian#debug#debug('GRAPH', 'Invalid data format for PlotData')
    return
  endif

  " Check if gnuplot is available
  if executable('gnuplot')
    " Write data to a temporary file
    let tempfile = tempname()
    call writefile(map(copy(a:data), 'string(v:val[0]) . " " . string(v:val[1])'), tempfile)

    " Generate gnuplot command
    let plotcmd = 'plot "' . tempfile . '" with lines'
    let gnuplotcmd = 'gnuplot -e "set terminal dumb size 80,24; set xlabel \"X Axis\"; set ylabel \"Y Axis\"; ' . plotcmd . '"'

    " Run gnuplot and capture output
    let graph = system(gnuplotcmd)

    " Use provided title or default
    let buffer_name = a:0 > 0 ? a:1 : 'GraphOutput'
    if buflisted(buffer_name)
      let buffer_name .= '_' . localtime()
    endif

    " Display graph in a new vertical split buffer and name it
    vsplit
    enew
    execute 'file ' . buffer_name
    setlocal buftype=nofile
    setlocal modifiable
    setlocal noreadonly
    put =graph
    setlocal nomodifiable
  else
    " Fallback to DrawLineGraph if gnuplot is not available
    let y_values = map(copy(a:data), 'str2float(v:val[1])')
    call visidian#graph#DrawLineGraph(y_values, a:0 > 0 ? a:1 : '')
  endif
  call visidian#debug#debug('GRAPH', 'Completed PlotData')
endfunction

" Example data
"let data = [2, 4, 6, 3, 5, 7, 1, 9]
"call visidian#graph#DrawLineGraph(data, 'My Line Graph')

" Example data
"let data = [['0', '2'], ['1', '4'], ['2', '6'], ['3', '3'], ['4', '5'], ['5', '7'], ['6', '1'], ['7', '9']]
"call visidian#graph#PlotData(data, 'My Plot')
"PlotData expects data in the format [[x1, y1], [x2, y2], ...]