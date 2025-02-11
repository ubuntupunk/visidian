function! visidian#graph#DrawLineGraph(data)
  let max_y = max(a:data)
  let min_y = min(a:data)
  let height = 10 " Fixed height for simplicity
  let width = len(a:data)

  " Clear the current buffer and use a vertical split
  vsplit
  enew
  file LineGraphOutput
  normal! gg"_dG

  " Draw axes
  call append(0, repeat('-', width + 1))
  for i in range(height)
    call append(i + 1, '|')
  endfor

  " Draw the data points
  for i in range(width)
    let y = float2nr((a:data[i] - min_y) / (max_y - min_y) * (height - 1))
    call setline(height - y, getline(height - y) . '*')
  endfor

  " Adjust cursor position
  normal! G$
endfunction

" Example data
"let data = [2, 4, 6, 3, 5, 7, 1, 9]
"call visidian#graph#DrawLineGraph(data)

function! visidian#graph#PlotData(data)
  " Check if gnuplot is available
  if executable('gnuplot')
    " Write data to a temporary file
    let tempfile = tempname()
    call writefile(map(copy(a:data), 'v:val[0] . " " . v:val[1]'), tempfile)

    " Generate gnuplot command
    let plotcmd = 'plot "' . tempfile . '" with lines'
    let gnuplotcmd = 'gnuplot -e "set terminal dumb; set output; ' . plotcmd . '"'

    " Run gnuplot and capture output
    let graph = system(gnuplotcmd)

    " Display graph in a new vertical split buffer and name it
    vsplit
    enew
    file GraphOutput
    setlocal buftype=nofile
    put =graph
    setlocal nomodifiable
  else
    " Fallback to DrawLineGraph if gnuplot is not available
    call visidian#graph#DrawLineGraph(map(copy(a:data), 'v:val[1]'))
  endif
endfunction

" Example data
"let data = [['0', '2'], ['1', '4'], ['2', '6'], ['3', '3'], ['4', '5'], ['5', '7'], ['6', '1'], ['7', '9']]
"call visidian#graph#PlotData(data)