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
import sys
vim.command("call visidian#debug#debug('IMAGE', 'Python path: ' . string(sys.path))")
vim.command("call visidian#debug#debug('IMAGE', 'Python executable: ' . string(sys.executable))")

try:
    from PIL import Image
    vim.command('let l:has_pillow = 1')
    vim.command("call visidian#debug#debug('IMAGE', 'Successfully imported PIL version: ' . string(Image.__version__))")
except ImportError as e:
    vim.command('let l:has_pillow = 0')
    vim.command("call visidian#debug#error('IMAGE', 'Python Pillow library (PIL) import error: ' . string(str(e)))")
    vim.command("echohl WarningMsg")
    vim.command("echom '📦 Visidian Image Preview needs the Pillow library! Install it with:'")
    vim.command("echohl None")
    vim.command("echom '   pip install Pillow'")
EOF

    let has_deps = exists('l:has_pillow') && l:has_pillow
    call visidian#debug#debug('IMAGE', 'Dependency check result: ' . (has_deps ? 'OK' : 'Failed'))
    return has_deps
endfunction

" Function: visidian#image#display_image
" Description: Display an image file in a buffer using ASCII art
" Parameters:
"   - image_path: Path to the image file
function! visidian#image#display_image()
    " Direct echo test
    echom "DIRECT TEST: Image display function called"
    echohl ErrorMsg
    echom "TEST MESSAGE: Image function called"
    echohl None
    
    " Test debug message
    call visidian#debug#error('IMAGE', 'TEST: Image display function called')
    call visidian#debug#debug('IMAGE', 'Starting image display process')
    
    if !visidian#image#check_dependencies()
        call visidian#debug#error('IMAGE', 'Dependencies check failed')
        return
    endif

    let image_path = expand('%:p')
    call visidian#debug#debug('IMAGE', 'Attempting to display image: ' . image_path)

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
import sys

def create_ascii_image(image_path, max_width=None, max_height=None):
    try:
        vim.command("call visidian#debug#debug('IMAGE', 'Python: Starting ASCII conversion')")
        vim.command(f"call visidian#debug#debug('IMAGE', 'Python path: {sys.executable}')")
        
        # Open the image with detailed error handling
        try:
            img = Image.open(image_path)
            vim.command(f"call visidian#debug#debug('IMAGE', 'Successfully opened image - Format: {img.format}, Mode: {img.mode}, Size: {img.size}')")
        except FileNotFoundError:
            vim.command(f"call visidian#debug#error('IMAGE', 'File not found: {image_path}')")
            vim.command("echohl ErrorMsg")
            vim.command("echom '😕 Sorry! Could not find the image file.'")
            vim.command("echohl None")
            return
        except PermissionError:
            vim.command(f"call visidian#debug#error('IMAGE', 'Permission denied: {image_path}')")
            vim.command("echohl ErrorMsg")
            vim.command("echom '😕 Sorry! Permission denied when trying to read the image.'")
            vim.command("echohl None")
            return
        except Exception as e:
            vim.command(f"call visidian#debug#error('IMAGE', 'Error opening image: {str(e)}')")
            vim.command("echohl ErrorMsg")
            vim.command("echom '😕 Sorry! Could not open the image.'")
            vim.command("echohl None")
            return

        # Convert to RGB if necessary
        if img.mode != 'RGB':
            vim.command(f"call visidian#debug#debug('IMAGE', 'Converting from {img.mode} to RGB mode')")
            img = img.convert('RGB')

        # Get terminal dimensions
        vim.command('let l:term_width = &columns')
        vim.command('let l:term_height = &lines')
        term_width = int(vim.eval('l:term_width'))
        term_height = int(vim.eval('l:term_height'))
        vim.command(f"call visidian#debug#debug('IMAGE', 'Terminal dimensions: {term_width}x{term_height}')")

        # Calculate dimensions while maintaining aspect ratio
        img_width, img_height = img.size
        aspect_ratio = img_height / float(img_width)
        
        # Calculate new dimensions (terminal characters are roughly twice as tall as wide)
        new_width = min(term_width - 4, img_width)
        new_height = int(new_width * aspect_ratio * 0.5)  # 0.5 to account for terminal character aspect ratio
        
        # Ensure height fits in terminal
        if new_height > term_height - 4:
            new_height = term_height - 4
            new_width = int(new_height / aspect_ratio * 2)

        vim.command(f"call visidian#debug#debug('IMAGE', 'Resizing image from {img_width}x{img_height} to {new_width}x{new_height}')")
        
        # Resize image with antialiasing
        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        vim.command("call visidian#debug#debug('IMAGE', 'Image resized with LANCZOS resampling')")
        
        # Convert to grayscale first using PIL's convert
        img = img.convert('L')
        vim.command("call visidian#debug#debug('IMAGE', 'Converted to grayscale')")
        
        # Get pixel data directly as a list
        pixels = list(img.getdata())
        
        # Reshape pixels into rows
        pixels = [pixels[i:i + new_width] for i in range(0, len(pixels), new_width)]
        vim.command("call visidian#debug#debug('IMAGE', 'Pixel data processed')")
        
        # Convert to ASCII with a better character set and proper brightness mapping
        # ASCII chars from darkest to lightest
        ascii_chars = ' .:-=+*#%@'[::-1]  # Reversed to match brightness
        char_width = len(ascii_chars) - 1
        
        ascii_img = []
        for row in pixels:
            ascii_row = ''
            for pixel in row:
                # Map pixel value (0-255) to ascii character
                char_idx = int((pixel / 255.0) * char_width)
                ascii_row += ascii_chars[char_idx]
            ascii_img.append(ascii_row)
        
        vim.command("call visidian#debug#debug('IMAGE', 'ASCII conversion complete')")
        
        # Add image information
        header = [
            f'Image: {os.path.basename(image_path)}',
            f'Size: {img_width}x{img_height}',
            f'Mode: {img.mode}',
            f'Format: {img.format}',
            ''
        ]
        
        # Set buffer content
        vim.current.buffer[:] = []  # Clear buffer
        vim.current.buffer.options['modifiable'] = True
        vim.current.buffer[0:0] = header + ascii_img
        vim.current.buffer.options['modifiable'] = False
        vim.current.buffer.options['modified'] = False
        
        # Set buffer options
        vim.command('setlocal nowrap')
        vim.command('setlocal nomodifiable')
        vim.command('setlocal buftype=nofile')
        vim.command('setlocal nonumber')
        vim.command('setlocal norelativenumber')
        vim.command('setlocal signcolumn=no')
        
        vim.command("call visidian#debug#debug('IMAGE', 'Buffer setup complete')")
        
        # Add success message after drawing
        vim.command("echohl MoreMsg")
        vim.command(f"echom '✨ Voilà! {os.path.basename(image_path)} is now ASCII art!'")
        vim.command("echohl None")
        vim.command("call visidian#debug#info('IMAGE', 'Successfully displayed ASCII art')")

    except Exception as e:
        vim.command(f"call visidian#debug#error('IMAGE', 'Error creating ASCII art: {str(e)}')")
        vim.command("echohl ErrorMsg")
        vim.command("echom '😢 Something went wrong while creating ASCII art'")
        vim.command("echohl None")

try:
    create_ascii_image(vim.eval('image_path'))
except Exception as e:
    vim.command(f"call visidian#debug#error('IMAGE', 'Unexpected error: {str(e)}')")
EOF
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