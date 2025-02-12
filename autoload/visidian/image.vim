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
except ImportError:
    vim.command('let l:has_pillow = 0')
    vim.command("call visidian#debug#error('IMAGE', 'Python Pillow library (PIL) is required for image preview')")
    vim.command("echohl WarningMsg")
    vim.command("echom '📦 Visidian Image Preview needs the Pillow library! Install it with:'")
    vim.command("echohl None")
    vim.command("echom '   pip install Pillow'")
EOF

    return exists('l:has_pillow') && l:has_pillow
endfunction

" Function: visidian#image#display_image
" Description: Display an image file in a buffer using ASCII art
" Parameters:
"   - image_path: Path to the image file
function! visidian#image#display_image()
    if !visidian#image#check_dependencies()
        return
    endif

    let image_path = expand('%:p')
    if !filereadable(image_path)
        call visidian#debug#error('IMAGE', 'Cannot read image file: ' . image_path)
        echohl ErrorMsg
        echom '❌ Oops! Cannot read image: ' . fnamemodify(image_path, ':t')
        echohl None
        return
    endif

python3 << EOF
import vim
from PIL import Image
import os

def create_ascii_image(image_path, max_width=None, max_height=None):
    try:
        # Open the image
        img = Image.open(image_path)
        vim.command("echohl MoreMsg")
        vim.command("echom '🎨 Converting image to ASCII art...'")
        vim.command("echohl None")
    except Exception as e:
        vim.command(f"call visidian#debug#error('IMAGE', 'Failed to open image: {str(e)}')")
        vim.command("echohl ErrorMsg")
        vim.command("echom '😕 Sorry! Could not open the image.'")
        vim.command("echohl None")
        return []

    # Convert to RGB if necessary
    if img.mode != 'RGB':
        img = img.convert('RGB')

    # Get window dimensions
    if max_width is None:
        max_width = int(vim.eval('winwidth(0)'))
    if max_height is None:
        max_height = int(vim.eval('winheight(0)'))

    # Calculate new dimensions preserving aspect ratio
    width, height = img.size
    aspect_ratio = width / height
    window_ratio = max_width / max_height

    if window_ratio > aspect_ratio:
        new_height = max_height
        new_width = int(aspect_ratio * new_height)
    else:
        new_width = max_width
        new_height = int(new_width / aspect_ratio)

    # Account for terminal character aspect ratio (characters are taller than wide)
    new_width = new_width * 2

    # Resize image
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Define ASCII characters from darkest to lightest
    ascii_chars = '@%#*+=-:. '

    # Convert image to ASCII
    ascii_lines = []
    for y in range(new_height):
        line = ''
        for x in range(new_width // 2):  # Divide by 2 to account for character aspect ratio
            # Get pixel RGB values
            r, g, b = img.getpixel((x * 2, y))
            # Convert to grayscale using perceived luminance
            gray = int(0.2989 * r + 0.5870 * g + 0.1140 * b)
            # Map grayscale value to ASCII character
            char_idx = int((gray / 255) * (len(ascii_chars) - 1))
            line += ascii_chars[char_idx]
        ascii_lines.append(line)

    return ascii_lines

# Get image path from Vim
image_path = vim.eval('image_path')

try:
    # Create ASCII art
    ascii_lines = create_ascii_image(image_path)

    if ascii_lines:
        # Clear current buffer
        vim.command('setlocal modifiable')
        vim.current.buffer[:] = None

        # Insert ASCII art
        vim.current.buffer.append(ascii_lines)

        # Remove empty first line
        if len(vim.current.buffer) > 0 and vim.current.buffer[0] == '':
            vim.command('1delete _')

        # Set buffer options
        vim.command('setlocal buftype=nofile')
        vim.command('setlocal bufhidden=hide')
        vim.command('setlocal noswapfile')
        vim.command('setlocal nomodifiable')
        vim.command('setlocal nowrap')

        # Add file info header
        filename = os.path.basename(image_path)
        info = Image.open(image_path)
        header = [
            f'Image: {filename}',
            f'Size: {info.size[0]}x{info.size[1]}',
            f'Mode: {info.mode}',
            f'Format: {info.format}',
            ''
        ]
        vim.current.buffer[0:0] = header

        # Add success message after drawing
        vim.command("echohl MoreMsg")
        vim.command(f"echom '✨ Voilà! {os.path.basename(image_path)} is now ASCII art!'")
        vim.command("echohl None")

except Exception as e:
    vim.command(f"call visidian#debug#error('IMAGE', 'Error creating ASCII art: {str(e)}')")
    vim.command("echohl ErrorMsg")
    vim.command("echom '😢 Something went wrong while creating ASCII art'")
    vim.command("echohl None")

EOF
endfunction

" Function: visidian#image#setup_autocmds
" Description: Set up autocommands for image handling
function! visidian#image#setup_autocmds()
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