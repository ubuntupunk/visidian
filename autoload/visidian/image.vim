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

" Function: visidian#image#check_dependencies
" Description: Check if required Python dependencies are available
" Returns: 1 if all dependencies are met, 0 otherwise
function! visidian#image#check_dependencies()
    call visidian#debug#debug('IMAGE', 'Checking Python and Pillow dependencies')
    if !has('python3')
        call visidian#debug#error('IMAGE', 'Python3 support required for image preview')
        echohl ErrorMsg
        echom '🔧 Visidian Image Preview needs Python3! Please compile Vim with Python3 support.'
        echohl None
        return 0
    endif

python3 << EOF
import vim
try:
    from PIL import Image
    vim.command('let l:has_pillow = 1')
    vim.command("call visidian#debug#debug('IMAGE', 'Successfully imported PIL')")
except ImportError as e:
    vim.command('let l:has_pillow = 0')
    vim.command("call visidian#debug#error('IMAGE', 'PIL import error')")
    vim.command("echohl WarningMsg")
    vim.command("echom '📦 Visidian Image Preview needs the Pillow library! Install it with:'")
    vim.command("echohl None")
    vim.command("echom '   pip install Pillow'")
EOF

    let has_deps = exists('l:has_pillow') && l:has_pillow
    call visidian#debug#debug('IMAGE', 'Dependency check result: ' . (has_deps ? 'OK' : 'Failed'))
    return has_deps
endfunction

" Initialize color option (default: off)
if !exists('g:visidian_image_color')
    let g:visidian_image_color = 0
endif

" Function: visidian#image#display_image
" Description: Display an image file in a buffer using ASCII art
" Parameters:
"   - image_path: Path to the image file
function! visidian#image#display_image()
    " Test debug message
    echom "DIRECT TEST: Image display function called"
    echohl ErrorMsg
    echom "TEST MESSAGE: Image function called"
    echohl None
    
    let image_path = expand('%:p')
    
python3 << EOF
try:
    import vim
    from PIL import Image
    import os

    def rgb_to_xterm(r, g, b):
        # Convert RGB values to the closest xterm-256 color code
        # Using a simplified conversion focusing on the basic 216 color cube
        r = int((r * 5) / 255)
        g = int((g * 5) / 255)
        b = int((b * 5) / 255)
        return 16 + (36 * r) + (6 * g) + b

    # Get the image path from vim
    image_path = vim.eval('image_path')
    use_color = int(vim.eval('g:visidian_image_color'))
    
    # Open image
    img = Image.open(image_path)
    if use_color:
        # Keep color for color mode
        img_color = img.convert('RGB')
        img = img.convert('L')  # Grayscale for ASCII mapping
    else:
        img = img.convert('L')
    
    # Get terminal size
    term_width = int(vim.eval('&columns')) - 4
    term_height = int(vim.eval('&lines')) - 4
    
    # Calculate new size
    width, height = img.size
    aspect = height/float(width)
    new_width = min(term_width, width)
    new_height = int(new_width * aspect * 0.45)
    
    # Ensure it fits in terminal
    if new_height > term_height:
        new_height = term_height
        new_width = int(new_height / (aspect * 0.45))
    
    # Resize
    try:
        img = img.resize((new_width, new_height), Image.LANCZOS)
        if use_color:
            img_color = img_color.resize((new_width, new_height), Image.LANCZOS)
    except AttributeError:
        img = img.resize((new_width, new_height), Image.ANTIALIAS)
        if use_color:
            img_color = img_color.resize((new_width, new_height), Image.ANTIALIAS)
    
    # Convert to ASCII
    pixels = list(img.getdata())
    if use_color:
        pixels_color = list(img_color.getdata())
    chars = ' .:-=+*#%@'
    
    # Create ASCII art line by line
    lines = []
    for y in range(new_height):
        line = ''
        for x in range(new_width):
            pos = y * new_width + x
            pixel = pixels[pos]
            idx = int((pixel / 255.0) * (len(chars) - 1))
            char = chars[idx]
            
            if use_color:
                r, g, b = pixels_color[pos]
                color_code = rgb_to_xterm(r, g, b)
                # Add color escape sequence
                line += '\033[38;5;{}m{}'.format(color_code, char)
            else:
                line += char
                
        if use_color:
            line += '\033[0m'  # Reset color at end of line
        lines.append(line)
    
    # Create header
    header = [
        'Image: ' + os.path.basename(image_path),
        'Original: {}x{}'.format(width, height),
        'ASCII: {}x{}'.format(new_width, new_height),
        'Mode: {}'.format('Color' if use_color else 'Grayscale'),
        ''
    ]
    
    # Set buffer content
    buffer = vim.current.buffer
    buffer.options['modifiable'] = True
    buffer[:] = header + lines
    buffer.options['modifiable'] = False
    
    # Set buffer options
    vim.command('setlocal buftype=nofile')
    vim.command('setlocal nomodifiable')
    vim.command('setlocal nonumber')
    vim.command('setlocal norelativenumber')
    vim.command('setlocal signcolumn=no')
    vim.command('setlocal nowrap')
    
    # Success message
    vim.command('echohl MoreMsg')
    vim.command('echo "✨ ASCII art created successfully!"')
    vim.command('echohl None')
    
except Exception as e:
    vim.command('echohl ErrorMsg')
    vim.command('echo "Error: {}"'.format(str(e)))
    vim.command('echohl None')
EOF
endfunction

" Toggle color mode
function! visidian#image#toggle_color()
    let g:visidian_image_color = !g:visidian_image_color
    echohl MoreMsg
    echo "ASCII art color mode: " . (g:visidian_image_color ? "ON" : "OFF")
    echohl None
    " Refresh current image if in an image buffer
    if exists('b:visidian_is_image')
        call visidian#image#display_image()
    endif
endfunction

" Function: visidian#image#setup_autocmds
" Description: Set up autocommands for image handling
function! visidian#image#setup_autocmds()
    call visidian#debug#debug('IMAGE', 'Setting up image autocommands')
    
    " Only set up autocommands if dependencies are met
    if !visidian#image#check_dependencies()
        call visidian#debug#info('IMAGE', 'Image preview disabled: missing dependencies')
        return
    endif

    augroup VisidianImage
        autocmd!
        autocmd BufReadPre *.png,*.jpg,*.jpeg,*.gif,*.bmp if !exists('g:visidian_disable_image_preview') | 
            \ let b:visidian_is_image = 1 |
            \ endif
        autocmd BufRead *.png,*.jpg,*.jpeg,*.gif,*.bmp if exists('b:visidian_is_image') |
            \ call visidian#image#display_image() |
            \ endif
    augroup END

    call visidian#debug#info('IMAGE', 'Image preview enabled')
    echohl MoreMsg
    echom '🖼️  Visidian Image Preview is ready! Open any image to see the magic ✨'
    echohl None
endfunction

" Initialize autocommands
call visidian#image#setup_autocmds()