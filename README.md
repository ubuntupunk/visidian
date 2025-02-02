# Visidian - An Obsidian-like PKM for Vim

Visidian is a Vim plugin designed to provide Obsidian-like **Personal Knowledge Management (PKM)** functionality within Vim. It supports managing notes, interconnecting them, and organizing your knowledge using various methods, including the PARA method.

This is currently just a markdown note-taking tool with some extra functionality. If you want a more established task-management project, try org mode for vim i.e [vim-orgmode](https://github.com/jceb/vim-orgmode) or a diary and wiki, try [vim-wiki](https://github.com/vimwiki/vimwiki). If you want to assist me in testing please bare in mind that I have yet to make an official release, so expect bugs, file a report and be patient. Pull requests welcome see contributions below.

## Contents

1. [Commands](#commands)
2. [PARA Method](#para-method)
3. [Combining GTD with Visidian](#combining-gtd-with-visidian)
4. [Tips for Using Visidian](#tips-for-using-visidian)
5. [Session Management](#session-management)

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

## Configuration
note: this section is just a placholder, fixme.

Update Your vimrc:

Add the following line to your .vimrc or init.vim if you haven't already:
```vim
set runtimepath^=~/.vim/pack/visidian/start/visidian.vim
```
## Generate Help Tags:
Open Vim and run:
```vim
:helptags ~/.vim/pack/visidian/start/visidian.vim/doc
```
## Commands
- `:VisidianDash` - Open the Visidian dashboard.
- `:VisidianFile` - Create a new markdown file in the vault.
- `:VisidianFolder` - Create a new folder in the vault.
- `:VisidianVault` - Create a new vault.
- `:VisidianLink` - Display connections between notes using YAML front matter (FIXME)
- `:VisidianParaGen` - Setup PARA folders in your vault.
- `:VisidianGenTags` - Generate Yaml Tags List in your vault. (TODO)
- `:VisidianGenCtags` - Generate Ctags File in your vault.
- `:VisidianBrowseCtags` - Browse Ctags in your vault.
- `:VisidianHelp` - Open this help document.
- `:VisidianSync` - Sync your Vault with a Remote (FIXME)
- `:VisidianToggleAutoSync` - Toggle Auto Sync.
- `:VisidianTogglePreview` - Toggle Markdown Preview.(FIXME)
- `:VisidianToggleSidebar` - Toggle Sidebar. 
- `:VisidianSearch` - Search for notes in the vault.
- `:VisidianSort` - Intelligent Sorting of Notes (FIXME)
- `:VisidianSaveSession` - Manually save the current session state
- `:VisidianLoadSession` - Manually load a saved session state

## Session Management

Visidian now uses Vim's native session management to preserve your workspace state. This means:

- Your window layouts, open files, and Vim state are automatically saved
- Sessions are saved per vault in `~/.vim/sessions/visidian/`
- Sessions are automatically saved when you exit Vim
- Sessions are automatically loaded when you open the dashboard
- You can manually save/load sessions using the commands above

This feature ensures that you can pick up exactly where you left off in each vault, maintaining your workflow continuity.

## PARA Method

The PARA method, developed by Tiago Forte, stands for Projects, Areas, Resources, and Archives. It's a simple, yet effective way to organize information:

- **Projects**: For tasks with a defined goal and deadline.
- **Areas**: Ongoing responsibilities without a deadline.
- **Resources**: Topics of interest or areas of study, not tied to immediate action.
- **Archives**: Completed projects, expired areas, or old resources.

To use PARA in Visidian, run `:VisidianParaGen` to create these folder structures in your vault.

---

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

---

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
  like [Grip](supports GitHub Flavored Markdown),  [Markdown Preview](https://github.com/iamcco/markdown-preview.nvim)
  or [Instant Markdown Vim](https://vimawesome.com/plugin/instant-markdown-vim) 
  -- for live previews in your browser.
* **Git**: For syncing your vault with a remote repository
* **Rsync**: For syncing your vault with a remote server.
* **FZF**: For fuzzy searching within your vault.
* **Ripgrep**: For fast searching within your vault.
* **Python 3**: For running the markdown previewer.
* **Pandoc**: For converting markdown files to other formats.
* **Ctags**: For generating tags for your notes. universal-ctags is the
successor to the exhuberant-ctags project, available via most package managers.
* **YAML parser**: For parsing YAML front matter in your notes.
* **A Markdown Linter**: For checking your markdown files for errors.
* **Vim-Markdown** (https://github.com/preservim/vim-markdown) is a good option.
* **A Spell Checker**: For catching typos and errors in your notes.

## Contributing
Contributions are welcome! If you have any suggestions, bug reports, or feature
requests, please open an issue or submit a pull request.

## License

This project is licensed under the GPL General Public License - see the [LICENSE](LICENSE) file for details.

 
