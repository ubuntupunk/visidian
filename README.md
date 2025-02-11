```
  _   _ _     _     _ _             
 | | | (_)   (_)   | (_)            
 | | | |_ ___ _  __| |_  __ _ _ __  
 | | | | / __| |/ _` | |/ _` | '_ \ 
 \ \_/ / \__ \ | (_| | | (_| | | | |
  \___/|_|___/_|\__,_|_|\__,_|_| |_|
```

<p align="center">
  <a href="https://www.buymeacoffee.com/ubuntupunk">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=ubuntupunk&button_colour=FF5F5F&font_colour=ffffff&font_family=Inter&outline_colour=000000&coffee_colour=FFDD00" />
  </a>
</p>

# Visidian - An Obsidian-like PKM for Vim

Visidian is a Vim plugin designed to provide Obsidian-like **Personal Knowledge Management (PKM)** functionality within Vim. It supports managing notes, interconnecting them, and organizing your knowledge using various methods, including the PARA method.

This is currently just a markdown note-taking tool with some extra functionality. If you want a more established task-management project, try org mode for vim i.e [vim-orgmode](https://github.com/jceb/vim-orgmode) or a diary and wiki, try [vim-wiki](https://github.com/vimwiki/vimwiki). If you want to assist me in testing and debugging, expect bugs, file a report and be patient. Pull requests welcome see contributions below.

## Contents

1. [Commands](#commands)
2. [PARA Method](#para-method)
3. [Combining GTD with Visidian](#combining-gtd-with-visidian)
4. [Tips for Using Visidian](#tips-for-using-visidian)
5. [Session Management](#session-management)
6. [Bookmarking](#bookmarking)
7. [Recommended Usage & Project Direction](#recommended-usage--project-direction)
8. [Debugging](#debugging)
9. [Chat Integration](#chat-integration)

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
Plug 'ubuntupunk/visidian.vim'
```
Then, in Vim, run :PlugInstall.

* **Vundle:**
Add this line to your vimrc:
```vim
Plugin 'ubuntupunk/visidian.vim'
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
- `:VisidianNote` - Create a new markdown note in your vault
- `:VisidianFolder` - Create a new folder in your vault
- `:VisidianVault` - Create or select a vault
- `:VisidianHelp` - Open Visidian help documentation

### Organization & Navigation
- `:VisidianParaGen` - Generate PARA method folder structure
- `:VisidianSearch` - Full-text search through your vault
- `:VisidianToggleSearch` - Toggle search mode
- `:VisidianLink` - Create and manage note connections
- `:VisidianSort` - Sort notes using PARA method
- `:VisidianImport` - Import and sort files using PARA

### Session Management
- `:VisidianSession` - Interactive session management menu with options to:
  - Save current session
  - Load last session
  - List available sessions
  - Choose and load a specific session
  - Clear session history

### View & Interface
- `:VisidianToggleSpell` - Toggle spell checking
- `:VisidianToggleSidebar` - Toggle file explorer sidebar
- `:VisidianTogglePreview` - Toggle markdown preview
- `:VisidianToggleAutoSync` - Toggle automatic syncing

### Debug Commands
- `:VisidianDebug <level>` - Set the debug level
- `:VisidianDebugCat <tab>` - Set which categories to debug.

You can tab into levels and categories to narrow down the debug output.

## Session Management

Visidian now uses Vim's native session management to preserve your workspace state. This means:

- Your window layouts, open files, and Vim state are automatically saved
- Sessions are saved per vault in `~/.vim/sessions/visidian/`
- Sessions are automatically saved when you exit Vim
- Sessions are automatically loaded when you open the dashboard
- You can manually save/load sessions using the commands above

This feature ensures that you can pick up exactly where you left off in each vault, maintaining your workflow continuity.

## Bookmarks

The bookmarking system in Visidian is designed around GTD (Getting Things Done) and PARA (Projects, Areas, Resources, Archives) methodologies, making it easy to organize and track important notes and references.

### Categories

Bookmarks are organized into several predefined categories:

- **GTD Categories**
  - Inbox: For capturing new items
  - Next: For immediate action items
  - Waiting: For items pending on others
  - Someday: For future possibilities
  - Reference: For reference materials
  - Done: For completed items

- **PARA Categories**
  - Projects: Current projects with deadlines
  - Areas: Areas of ongoing responsibility
  - Resources: Topic-based resources
  - Archives: Completed or inactive items

- **Books Categories**
  - Reading: Currently reading
  - To-Read: Reading list
  - Finished: Completed books
  - Reference: Reference materials

- **Custom Categories**
  - Create your own categories
  - Manage and organize as needed

### Usage

Access the bookmarking system through:
- Command: `:VisidianBook`
- Menu: Press your leader key and select "Bookmarks" from the popup menu

### Features

- Add bookmarks to any category
- Create custom categories
- Edit and delete categories
- Sort bookmarks within categories
- View bookmark statistics
- FZF integration for fuzzy finding bookmarks
- Persistent storage across sessions

### Example

```vim
" Add a bookmark to GTD category
:VisidianBook
" Select 'add:gtd' from the menu
" Choose 'next' as the subcategory
" Select the current note

" Create a custom category
:VisidianBook
" Select 'category:new'
" Enter category name and subcategories
```

The bookmarking system helps maintain an organized knowledge base, making it easier to find and manage important notes within your vault.

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

## Chat Integration

Visidian includes an AI-powered chat feature that can help analyze and work with your notes. The chat system supports multiple LLM providers:

### Supported Providers
- OpenAI (GPT-3.5/4)
- Google Gemini
- Anthropic Claude
- DeepSeek

### Smart Context with Vector Search

The chat feature uses a RAG-like approach to provide relevant context from your notes:

1. **Vector Store**: Notes are automatically indexed into a vector store when saved
2. **Semantic Search**: When you ask a question, the system finds the most relevant note chunks
3. **Smart Context**: Only the most relevant context is included in the conversation

#### Configuration

```vim
" Maximum number of relevant chunks to include (default: 5)
let g:visidian_chat_max_context_chunks = 5

" Minimum similarity threshold for including chunks (default: 0.7)
let g:visidian_chat_similarity_threshold = 0.7

" Vector store provider (default: 'openai')
let g:visidian_vectorstore_provider = 'openai'  " or 'gemini'

" Path to store vector embeddings (default: ~/.cache/visidian/vectorstore)
let g:visidian_vectorstore_path = '~/.cache/visidian/vectorstore'
```

#### Commands

- `:call visidian#chat#index_vault()` - Index all markdown files in your vault
- `:call visidian#chat#index_current_note()` - Manually index current note

Notes are automatically indexed when saved. The vector store enables semantic search across your entire vault, helping the AI provide more relevant responses based on your notes' content.

### Configuration
Add the following to your vimrc to configure the chat feature:

```vim
" Select your preferred provider (default: 'openai')
" Options: 'openai', 'gemini', 'anthropic', 'deepseek'
let g:visidian_chat_provider = 'openai'

" Configure API keys (or use environment variables)
let g:visidian_chat_openai_key = 'your-openai-key'
let g:visidian_chat_gemini_key = 'your-gemini-key'
let g:visidian_chat_anthropic_key = 'your-anthropic-key'
let g:visidian_chat_deepseek_key = 'your-deepseek-key'

" Customize models (optional)
let g:visidian_chat_model = {
    \ 'openai': 'gpt-4',
    \ 'gemini': 'gemini-pro',
    \ 'anthropic': 'claude-3-opus',
    \ 'deepseek': 'deepseek-chat'
    \ }

" Set chat window width (default: 80)
let g:visidian_chat_window_width = 100
```

### Usage
- Press `<Leader>cc` to open the chat window
- Type your query and press Enter
- Press `q` to close the chat window

The chat feature automatically includes context from your current note and any linked notes (via `[[links]]`), allowing the AI to provide more relevant responses.

## Configuration

You can customize Visidian's behavior with the following variables in your `.vimrc`:

### Debug Settings

```vim
" Enable/disable debug mode (default: 1)
let g:visidian_debug = 0

" Set debug level (default: 'WARN')
let g:visidian_debug_level = 'INFO'

" Set debug categories (default: ['ALL'])
let g:visidian_debug_categories = ['CORE', 'PARA', 'BOOKMARKS']
```

### Other Settings

## Dependencies

For full functionality, Visidian requires the following:

* **Required:**
   * [fzf](https://github.com/junegunn/fzf) - For fuzzy finding

* **Optional but recommended:**
  * [fzf.vim](https://github.com/junegunn/fzf.vim) - For enhanced preview functionality

Install these dependencies before using Visidian for the best experience.

## Debugging

Visidian includes a comprehensive debugging system to help troubleshoot issues. You can control debugging output using the following commands:

### Debug Commands

1. `:VisidianDebug <level>` - Set the debug level
   - ERROR: Only show errors
   - WARN: Show warnings and errors
   - INFO: Show general information
   - DEBUG: Show detailed debug information
   - TRACE: Show very detailed trace information

2. `:VisidianDebugCat <categories>` - Set which categories to debug
   - ALL: Enable all categories
   - CORE: Core functionality
   - SESSION: Session management
   - PREVIEW: Markdown preview
   - SEARCH: Search functionality
   - CACHE: Cache operations
   - PARA: PARA system
   - UI: User interface
   - SYNC: Sync operations
   - BOOKMARKS: Bookmarking system
   - LINK: Link management
   - NOTES: Note operations

Both commands support tab completion for available options.

### Example Usage

```vim
" Enable debug logging for bookmarks
:VisidianDebug DEBUG
:VisidianDebugCat BOOKMARKS

" Enable all debug output
:VisidianDebug DEBUG
:VisidianDebugCat ALL

" Only show errors for sync operations
:VisidianDebug ERROR
:VisidianDebugCat SYNC
```

Debug messages can be viewed using the Vim `:messages` command.

For more detailed information, see `:help visidian-debugging`.

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
nnoremap <leader>n :VisidianNote<CR>
```
- **Note Naming**: Use consistent naming conventions or a date system for your
notes to make searching and sorting easier.

Remember, Visidian is meant to enhance your productivity, not to be a rigid
system. Experiment with different setups until you find what works best for you.

## Contributing
Contributions are welcome! If you have any suggestions, bug reports, or feature
requests, please open an issue or submit a pull request.

## License

This project is licensed under the GPL General Public License - see the [LICENSE](LICENSE) file for details.

 
