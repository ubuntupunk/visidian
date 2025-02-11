command! -nargs=0 Image call DisplayImage()

if !has("python")
    echo "image.vim requires python support"
    finish
endif

au BufRead *.png,*.jpg,*.jpeg :call DisplayImage()

function! DisplayImage()
set nowrap
python << EOF
from __future__ import division
import vim
from PIL import Image

def getAsciiImage(imageFile, maxWidth, maxHeight):
    try:
        img = Image.open(imageFile)
    except:
        exit("Cannot open image %s" % imageFile)

    # We want to stretch the image a little wide to compensate for
    # the rectangular/taller shape of fonts.
    # The width:height ratio will be 2:1
    width, height = img.size
    width = width * 2

    scale = maxWidth / width
    imageAspectRatio = width / height
    winAspectRatio = maxWidth / maxHeight

    if winAspectRatio > imageAspectRatio:
        scale = scale * (imageAspectRatio / winAspectRatio)

    scaledWidth = int(scale * width)
    scaledHeight = int(scale * height)

    # Use the original image size to scale the image
    img = img.resize((scaledWidth, scaledHeight))
    pixels = img.load()

    colorPalette = "@%#*+=-:. "
    lencolor = len(colorPalette)

    # Delete the current buffer so that we dont overwrite the real image file
    vim.command("bd!")
    # get a new buffer
    # enew is safe enough since we did not specified a buftype, so we
    # cannot save this
    vim.command("enew")

    # clear the buffer
    vim.current.buffer[:] = None

    for y in xrange(scaledHeight):
        asciiImage = ""
        for x in xrange(scaledWidth):
            rgb = pixels[x, y]
            if not isinstance(rgb, tuple):
                rgb = (rgb,)
            asciiImage += colorPalette[int(sum(rgb) / len(rgb) / 256 * lencolor)]
        vim.current.buffer.append(asciiImage)

    return asciiImage
    
vim.command("let imagefile = expand('%:p')")
imagefile = vim.eval("imagefile")

width = vim.current.window.width
height = vim.current.window.height

getAsciiImage(imagefile, width, height)

EOF
endfunction

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

        " Display image using timg
        let output = system('timg ' . tempfile . '.png')
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