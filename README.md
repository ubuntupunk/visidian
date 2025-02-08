```
  _   _ _     _     _ _             
 | | | (_)   (_)   | (_)            
 | | | |_ ___ _  __| |_  __ _ _ __  
 | | | | / __| |/ _` | |/ _` | '_ \ 
 \ \_/ / \__ \ | (_| | | (_| | | | |
  \___/|_|___/_|\__,_|_|\__,_|_| |_|
```

# Visidian - An Obsidian-like PKM for Vim

Visidian is a Vim plugin designed to provide Obsidian-like **Personal Knowledge Management (PKM)** functionality within Vim. It supports managing notes, interconnecting them, and organizing your knowledge using various methods, including the PARA method.

This is currently just a markdown note-taking tool with some extra functionality. If you want a more established task-management project, try org mode for vim i.e [vim-orgmode](https://github.com/jceb/vim-orgmode) or a diary and wiki, try [vim-wiki](https://github.com/vimwiki/vimwiki). If you want to assist me in testing and debugging, expect bugs, file a report and be patient. Pull requests welcome see contributions below.

## Contents

1. [Commands](#commands)
2. [PARA Method](#para-method)
3. [Combining GTD with Visidian](#combining-gtd-with-visidian)
4. [Tips for Using Visidian](#tips-for-using-visidian)
5. [Session Management](#session-management)
6. [Recommended Usage & Project Direction](#recommended-usage--project-direction)
7. [Debugging](#debugging)

---
## Installation

### Manual Installation

1. **Clone the Repository:**
   ```sh
   git clone https://github.com/yourusername/visidian.vim.git ~/.vim/pack/visidian/start/visidian.vim
   ```
### Using a Plugin Manager
* **Vim-Plug:**
Add the following to your vimrc:
```vim
Plug 'yourusername/visidian.vim'
```
Then, in Vim, run :PlugInstall.

* **Vundle:**
Add this line to your vimrc:
```vim
Plugin 'yourusername/visidian.vim'
```
Run :PluginInstall from Vim.

*  **Pathogen:**
If you use Pathogen, clone the repository into your bundle directory
```sh
git clone https://github.com/yourusername/visidian.vim.git ~/.vim/bundle/visidian.vim
```
After installation, make sure to restart Vim or source your vimrc for changes to take effect

## Generate Help Tags:
Open Vim and run:
```vim
:helptags ~/.vim/pack/visidian/start/visidian.vim/doc
```
## Commands

### Core Commands
- `:VisidianDash` - Open the Visidian dashboard with quick access to all features
- `:VisidianMenu` - Open the popup menu interface for quick navigation
- `:VisidianFile` - Create a new markdown file in your vault
- `:VisidianFolder` - Create a new folder in your vault
- `:VisidianVault` - Create or select a vault
- `:VisidianHelp` - Open Visidian help documentation

### Organization & Navigation
- `:VisidianParaGen` - Generate PARA method folder structure
- `:VisidianSearch` - Full-text search through your vault
- `:VisidianLink` - Create and manage note connections
- `:VisidianSort` - Intelligent note sorting (Coming Soon)

### Tags & References
- `:VisidianGenTags` - Generate YAML tags list (Coming Soon)
- `:VisidianGenCtags` - Generate ctags for your vault
- `:VisidianBrowseCtags` - Browse through generated ctags

### View & Interface
- `:VisidianToggleSpell` - Toggle spell checking
- `:VisidianToggleSidebar` - Toggle file explorer sidebar
- `:VisidianTogglePreview` - Toggle markdown preview (Coming Soon)

### Session Management
- `:VisidianSaveSession` - Manually save current session
- `:VisidianLoadSession` - Load a saved session

### Synchronization
- `:VisidianSync` - Sync vault with remote (Coming Soon)
- `:VisidianToggleAutoSync` - Toggle automatic syncing (Coming Soon)

## Session Management

Visidian now uses Vim's native session management to preserve your workspace state. This means:

- Your window layouts, open files, and Vim state are automatically saved
- Sessions are saved per vault in `~/.vim/sessions/visidian/`
- Sessions are automatically saved when you exit Vim
- Sessions are automatically loaded when you open the dashboard
- You can manually save/load sessions using the commands above

This feature ensures that you can pick up exactly where you left off in each vault, maintaining your workflow continuity.

## PARA Method

The PARA method, developed by Tiago Forte, stands for Projects, Areas, Resources, and Archives. Visidian provides built-in support for PARA organization with visual indicators and color coding:

- **[P]rojects** (Pink): Active tasks with a defined goal and deadline
- **[A]reas** (Green): Ongoing responsibilities without a deadline
- **[R]esources** (Blue): Topics of interest or areas of study
- **[AR]chives** (Gray): Completed projects and inactive items

### PARA Visual Integration

Visidian helps you stay oriented in your knowledge base with:

1. **Color-coded Statusline**: Shows your current PARA context with colored indicators
2. **Visual Hierarchy**: Each PARA category has its own distinct color throughout the interface
3. **Customizable Colors**: Adjust the colors to match your preferences:
   ```vim
   " In your vimrc:
   let g:visidian_para_colors = {
       \ 'projects': {'ctermfg': '168', 'guifg': '#d75f87'},
       \ 'areas': {'ctermfg': '107', 'guifg': '#87af5f'},
       \ 'resources': {'ctermfg': '110', 'guifg': '#87afd7'},
       \ 'archives': {'ctermfg': '242', 'guifg': '#6c6c6c'}
       \ }
   ```

### Getting Started with PARA

1. Create your PARA structure:
   ```vim
   :VisidianParaGen
   ```
   This creates the basic PARA folders in your vault.

2. Navigate your vault:
   - The statusline will show your current context (e.g., "[P]rojects")
   - Colors help you quickly identify different types of content
   - Use `:VisidianMenu` for quick navigation

## Combining GTD with Visidian

Getting Things Done (GTD) by David Allen can be seamlessly integrated with Visidian:

- **Capture**: Use Visidian to take quick notes or create files for any new ideas or tasks.
- **Clarify**: Review these notes, deciding whether they're actionable or not.
- **Organize**: Place actionable items into Projects or Areas. Non-actionable items can go into Resources or Archives.
- **Reflect**: Use Visidian's dashboard to review your notes regularly, updating your GTD lists.
- **Engage**: Work from your organized notes, moving items through stages like 'Next Actions' or 'Waiting For'.

**Combining PARA and GTD:**
- Use 'Projects' for GTD projects, breaking them down into tasks within markdown files.
- 'Areas' can represent contexts or areas of focus from GTD.
- 'Resources' for reference material, and 'Archives' for completed or outdated projects.

## Recommended Usage & Project Direction

### Current Recommended Approach
We strongly recommend starting with the VisidianParaGen folders structure from day one. This provides a solid foundation for organizing your knowledge using the PARA method, helping you avoid the common pitfall of unstructured note accumulation. The VisidianParaGen structure ensures your notes are organized in a way that makes them both accessible and actionable.

### Future Direction
While we currently emphasize folder-based organization, Visidian is evolving towards treating all notes as a unified stack with:
- Intelligent sorting capabilities
- Instant recall through advanced fuzzy search
- Context-aware note relationships
- Upcoming: Chat-with-your-notes functionality (planned for future releases)

This hybrid approach allows you to maintain organized structures while preparing for more advanced knowledge management features.

## Debugging

Visidian includes a debug mode that can help diagnose issues or understand the plugin's behavior. When enabled, it provides detailed logging about operations such as:
- File and note operations
- Search functionality
- Preview rendering
- Session management
- PARA folder operations

### Enabling Debug Mode

Add the following to your `vimrc`:
```vim
let g:visidian_debug = 1
```

### Viewing Debug Output

1. Debug messages are displayed in Vim's message history
2. View them using the `:messages` command
3. Messages are prefixed with component names (e.g., "Visidian Preview:", "Visidian Search:") for easy identification

### When to Use Debug Mode

Enable debug mode when:
- Setting up Visidian for the first time
- Investigating unexpected behavior
- Understanding how specific features work
- Contributing to Visidian development

### Debug Components

Different components provide specific debug information:
- **Preview**: Buffer creation, grip process management, content loading
- **Search**: Query processing, FZF integration, result handling
- **Core**: Vault operations, file management, PARA structure
- **Session**: Session saving, loading, and state management

Note: Debug mode may impact performance slightly, so it's recommended to disable it during normal use.

## Tips for Using Visidian

- **Use YAML front matter** effectively to link notes. For instance:

  ```yaml
  ---
  tags: [project, tech]
  links:
    - related_note.md
  ---

- **Regularly review** your dashboard to keep your knowledge base up-to-date.
- **Customize your workflow**: While PARA and GTD are good frameworks, feel free
to adjust Visidian's structure to match your personal productivity style.
- **Keyboard Shortcuts**: Map commands to shortcuts for efficiency. For example:

```
nnoremap <leader>d :VisidianDash<CR>
nnoremap <leader>n :VisidianFile<CR>
```
- **Note Naming**: Use consistent naming conventions or a date system for your
notes to make searching and sorting easier.

Remember, Visidian is meant to enhance your productivity, not to be a rigid
system. Experiment with different setups until you find what works best for you.

## Requirements
While Visidian is designed to work out of the box, it's recommended to have the
following installed: 
* **Vim 8.2+**: Visidian is tested on Vim 8.2 and above.
* **A File Explorer**: NERDTree for navigating your vault and managing files.
* **Markdown Previewer**: For the best experience, install a markdown previewer
  like [Grip](https://github.com/joeyespo/grip)supports GitHub Flavored Markdown,  [Markdown Preview](https://github.com/iamcco/markdown-preview.nvim)
  or [Instant Markdown Vim](https://vimawesome.com/plugin/instant-markdown-vim) 
  -- for live previews in your browser.
* **Git**: For syncing your vault with a remote repository
* **Rsync**: For syncing your vault with a remote server.
* **FZF**: For fuzzy searching within your vault.
* **Ripgrep**: For fast searching within your vault.
* **Python 3**: For running the markdown previewer.
* **Pandoc**: For converting markdown files to other formats.
* **Ctags**: For generating tags for your notes. Please install [universal-ctags](https://github.com/universal-ctags/ctags) the
successor to the exhuberant-ctags project, available via most package managers.
* **YAML parser**: For parsing YAML front matter in your notes.
* **A Markdown Linter**: For checking your markdown files for errors.
* **Vim-Markdown** [vim-markdown](https://github.com/preservim/vim-markdown) is a good option.
* **A Spell Checker**: For catching typos and errors in your notes.

## Contributing
Contributions are welcome! If you have any suggestions, bug reports, or feature
requests, please open an issue or submit a pull request.

## License

This project is licensed under the GPL General Public License - see the [LICENSE](LICENSE) file for details.

 
