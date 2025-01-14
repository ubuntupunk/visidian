# Visidian - An Obsidian-like PKM for Vim

Visidian is a Vim plugin designed to provide Obsidian-like Personal Knowledge Management (PKM) functionality within Vim. It supports managing notes, interconnecting them, and organizing your knowledge using various methods, including the PARA method.

This is currently just a note-taking tool. If you want a more established task-management project, try org mode for vim i.e [vim-orgmode](https://github.com/jceb/vim-orgmode).
## Contents

1. [Commands](#commands)
2. [PARA Method](#para-method)
3. [Combining GTD with Visidian](#combining-gtd-with-visidian)
4. [Tips for Using Visidian](#tips-for-using-visidian)

---


## Installation

### Manual Installation

1. **Clone the Repository:**
   ```sh
   git clone https://github.com/yourusername/visidian.vim.git ~/.vim/pack/visidian/start/visidian.vim
   ```

### Using a Plugin Manager

-- Vim-Plug:
Add the following to your vimrc:
```vim
Plug 'yourusername/visidian.vim'
```
Then, in Vim, run :PlugInstall.

-- Vundle:
Add this line to your vimrc:
```vim
Plugin 'yourusername/visidian.vim'
```
Run :PluginInstall from Vim.

-- Pathogen:
If you use Pathogen, clone the repository into your bundle directory
```sh
git clone https://github.com/yourusername/visidian.vim.git ~/.vim/bundle/visidian.vim
```
After installation, make sure to restart Vim or source your vimrc for changes to take effect

## Configuration
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

- `:VisidianDashboard` - Open the Visidian dashboard.
- `:VisidianNewFile` - Create a new markdown file in the vault.
- `:VisidianNewFolder` - Create a new folder in the vault.
- `:VisidianNewVault` - Create a new vault.
- `:VisidianLinkNotes` - Display connections between notes using YAML front matter.
- `:VisidianSetVault` - Set or reset the vault path.
- `:VisidianPara` - Setup PARA folders in your vault.
- `:VisidianHelp` - Open this help document.
- `:VisidianSync` - Sync your Vault with a Remote
---

## PARA Method

The PARA method, developed by Tiago Forte, stands for Projects, Areas, Resources, and Archives. It's a simple, yet effective way to organize information:

- **Projects**: For tasks with a defined goal and deadline.
- **Areas**: Ongoing responsibilities without a deadline.
- **Resources**: Topics of interest or areas of study, not tied to immediate action.
- **Archives**: Completed projects, expired areas, or old resources.

To use PARA in Visidian, run `:VisidianPara` to create these folder structures in your vault.

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

