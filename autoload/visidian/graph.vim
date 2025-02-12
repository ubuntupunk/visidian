" Function: visidian#graph#DrawLineGraph
" Description: Draws a simple line graph in a Vim buffer using ASCII characters.
" Parameters:
"   - data: List of numerical values to plot.
"   - title (optional): Title for the graph buffer.
" Usage: call visidian#graph#DrawLineGraph([1, 2, 3], 'My Line Graph')
function! visidian#graph#DrawLineGraph(data, ...)
  call visidian#debug#debug('GRAPH', 'Starting DrawLineGraph with data: ' . string(a:data))

  " Check if data is valid
  if empty(a:data) || type(a:data) != v:t_list || empty(filter(copy(a:data), 'type(v:val) == v:t_number'))
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
  if empty(a:data) || type(a:data) != v:t_list
    call visidian#debug#debug('GRAPH', 'Invalid data format for PlotData')
    return
  endif

  " Use image display if possible
  if executable('gnuplot') && executable('timg')
    call visidian#image#display_graph(a:data, a:0 > 0 ? a:1 : '')
  else
    " Fallback to ASCII art if requirements not met
    let y_values = map(copy(a:data), 'str2float(v:val[1])')
    call visidian#graph#DrawLineGraph(y_values, a:0 > 0 ? a:1 : '')
  endif

  call visidian#debug#debug('GRAPH', 'Completed PlotData')
endfunction

" Function: visidian#graph#DrawNetworkGraph
" Description: Draws a network graph of notes and their connections using ASCII characters.
" Parameters:
"   - nodes: List of note filenames that are nodes in the graph
"   - edges: List of [from, to] pairs representing links between notes
"   - title (optional): Title for the graph buffer
" Usage: call visidian#graph#DrawNetworkGraph(['note1.md', 'note2.md'], [['note1.md', 'note2.md']], 'Note Graph')
function! visidian#graph#DrawNetworkGraph(nodes, edges, ...)
    if !has('python3')
        call visidian#debug#error('GRAPH', 'Python3 support required for network graph visualization')
        return
    endif

    call visidian#debug#debug('GRAPH', 'Starting DrawNetworkGraph with nodes: ' . string(a:nodes))

python3 << EOF
import vim
import math
from collections import defaultdict

def create_ascii_network(nodes, edges, width=80, height=20):
    # Initialize node positions using a simple circular layout
    node_positions = {}
    node_count = len(nodes)
    radius = min(width // 4, height // 2)
    center_x = width // 2
    center_y = height // 2

    # Position nodes in a circle
    for i, node in enumerate(nodes):
        angle = 2 * math.pi * i / node_count
        x = center_x + int(radius * math.cos(angle))
        y = center_y + int(radius * math.sin(angle))
        node_positions[node] = (x, y)

    # Create empty canvas
    canvas = [[' ' for _ in range(width)] for _ in range(height)]

    # Draw edges
    for start, end in edges:
        if start in node_positions and end in node_positions:
            x1, y1 = node_positions[start]
            x2, y2 = node_positions[end]
            
            # Simple line drawing using Bresenham's algorithm
            dx = abs(x2 - x1)
            dy = abs(y2 - y1)
            x, y = x1, y1
            sx = 1 if x1 < x2 else -1
            sy = 1 if y1 < y2 else -1
            err = dx - dy

            while True:
                if 0 <= x < width and 0 <= y < height:
                    canvas[y][x] = '-' if dx > dy else '|'
                if x == x2 and y == y2:
                    break
                e2 = 2 * err
                if e2 > -dy:
                    err -= dy
                    x += sx
                if e2 < dx:
                    err += dx
                    y += sy

    # Draw nodes
    for node, (x, y) in node_positions.items():
        if 0 <= x < width and 0 <= y < height:
            # Draw node marker
            canvas[y][x] = '@'
            
            # Draw truncated node name
            name = node.replace('.md', '')[:10]
            for i, char in enumerate(name):
                if x + i + 2 < width:
                    canvas[y][x + 2 + i] = char

    return [''.join(row) for row in canvas]

# Get data from Vim
nodes = vim.eval('a:nodes')
edges = vim.eval('a:edges')
title = vim.eval('a:0 > 0 ? a:1 : "Network Graph"')

# Create the ASCII network
graph = create_ascii_network(nodes, edges)

# Clear current buffer and create new one
vim.command('vsplit')
vim.command('enew')
vim.command('file ' + title.replace(' ', '_'))

# Write the graph to the buffer
vim.current.buffer[:] = graph

# Set buffer options
vim.command('setlocal buftype=nofile')
vim.command('setlocal bufhidden=hide')
vim.command('setlocal noswapfile')
vim.command('setlocal nomodifiable')
EOF

    call visidian#debug#debug('GRAPH', 'Completed DrawNetworkGraph')
endfunction

" Function: visidian#graph#ShowNoteGraph
" Description: Creates and displays a network graph of the current note and its connections
" Usage: call visidian#graph#ShowNoteGraph()
function! visidian#graph#ShowNoteGraph() abort
    call visidian#debug#debug('GRAPH', 'Starting graph visualization')
    
    let current_file = expand('%:p')
    if empty(current_file)
        call visidian#debug#error('GRAPH', 'No file open in current buffer')
        echohl ErrorMsg
        echom '❌ Please open a note file first!'
        echohl None
        return
    endif
    
    call visidian#debug#debug('GRAPH', 'Getting links from current file: ' . current_file)
    let links = visidian#links#get_links_in_file(current_file)
    if empty(links)
        call visidian#debug#info('GRAPH', 'No links found in current file')
        echohl WarningMsg
        echom '📝 This note has no links yet. Try adding some!'
        echohl None
        return
    endif
    
    " Get all markdown files in the vault
    let vault_path = g:visidian_vault_path
    let files = globpath(vault_path, '**/*.md', 0, 1)
    let files = map(files, 'fnamemodify(v:val, ":t")')
    call visidian#debug#debug('GRAPH', 'Found ' . len(files) . ' markdown files in vault')

    " Get links from the current file
    call visidian#debug#debug('GRAPH', 'Getting links from current file')
    let edges = []
    let links = visidian#links#get_links_in_file(expand('%:p'))
    for link in links
        let target = link.target . '.md'
        if index(files, target) >= 0
            call add(edges, [current_file, target])
            call visidian#debug#debug('GRAPH', 'Added edge: ' . current_file . ' -> ' . target)
        endif
    endfor

    " Get backlinks to the current file
    call visidian#debug#debug('GRAPH', 'Getting backlinks for current file')
    let backlinks = visidian#links#get_backlinks(current_file)
    for backlink in backlinks
        let source = fnamemodify(backlink.source, ':t')
        call add(edges, [source, current_file])
        call visidian#debug#debug('GRAPH', 'Added backlink edge: ' . source . ' -> ' . current_file)
    endfor

    " Get connected nodes (files that are either linked to or from)
    let connected_nodes = []
    for edge in edges
        if index(connected_nodes, edge[0]) < 0
            call add(connected_nodes, edge[0])
        endif
        if index(connected_nodes, edge[1]) < 0
            call add(connected_nodes, edge[1])
        endif
    endfor
    call visidian#debug#debug('GRAPH', 'Found ' . len(connected_nodes) . ' connected nodes')

    " Draw the network graph
    call visidian#debug#debug('GRAPH', 'Drawing network graph')
    call visidian#graph#DrawNetworkGraph(connected_nodes, edges, 'Note Graph: ' . current_file)
    call visidian#debug#info('GRAPH', 'Graph visualization complete')
endfunction

" Example data
"let data = [2, 4, 6, 3, 5, 7, 1, 9]
"call visidian#graph#DrawLineGraph(data, 'My Line Graph')

" Example data
"let data = [['0', '2'], ['1', '4'], ['2', '6'], ['3', '3'], ['4', '5'], ['5', '7'], ['6', '1'], ['7', '9']]
"call visidian#graph#PlotData(data, 'My Plot')
"PlotData expects data in the format [[x1, y1], [x2, y2], ...]