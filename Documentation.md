# Visidian.vim Documentation

## Recent Changes and Improvements

### Popup Menu Enhancement (2025-02-07)

#### Issue Description
The popup menu was experiencing several issues:
- Commands were being executed arbitrarily
- Menu items were not properly executing their intended functions
- Command state was leaking between menu actions
- The first menu item's command was being reproduced for all subsequent items

#### Implementation Changes

1. **State Management**
   - Added state cleanup when opening the menu
   - Introduced proper state management for menu items and current line selection
   - Clear existing menu state variables (`s:current_line`, `s:current_menu_items`, `s:pending_cmd`) when opening menu

2. **Command Execution**
   - Implemented new helper functions for safe command execution:
     - `s:execute_menu_command(cmd)`: Safely stores and prepares command for execution
     - `s:do_execute_command()`: Handles the actual command execution after cleanup
   - Added a delay (50ms) before command execution to ensure proper cleanup
   - Prevents command interference by storing commands in a script-local variable

3. **Menu Navigation**
   - Improved handling of menu item selection
   - Added proper tracking of current line position
   - Enhanced number key quick selection functionality

#### Code Structure
```vim
" Safe command execution
function! s:execute_menu_command(cmd)
    - Stores command in s:pending_cmd
    - Cleans up existing state
    - Sets up delayed execution

function! s:do_execute_command()
    - Executes stored command
    - Cleans up after execution

function! visidian#menu()
    - Cleans up existing state
    - Sets up menu items
    - Handles popup display

function! s:menu_filter()
    - Handles menu navigation
    - Processes key inputs
    - Triggers command execution
```

#### Benefits
- More reliable command execution
- Prevented command leakage between menu actions
- Improved state management
- Better user experience with consistent menu behavior

#### Known Limitations
- Brief delay (50ms) before command execution
- State is cleared after each command execution

### Search Functionality Enhancement (2025-02-07)

#### Issue Description
The search functionality was experiencing several issues:
- Search would hang in certain situations
- Error handling was minimal
- Limited feedback during search operations
- FZF integration needed improvement

#### Implementation Changes

1. **Debug Mode**
   - Added `g:visidian_debug` option for detailed logging
   - Provides step-by-step feedback during search operations
   - Shows detailed error information when issues occur

2. **FZF Search Improvements**
   - Better error handling for FZF execution
   - Enhanced preview with grep for context
   - Proper escaping of search queries and commands
   - File existence validation before opening
   - Detailed feedback about number of files and matches

3. **Vim Search Enhancements**
   - Added pre-check for markdown files existence
   - Improved pattern escaping
   - Shows number of matches found
   - Comprehensive error handling
   - Progress feedback during search
   - Uses `noautocmd` for better performance

#### Usage
To enable debug mode, add to your vimrc or execute in Vim:
```vim
let g:visidian_debug = 1
```

The search function can be used as before, but now provides better feedback and reliability:
- Shows number of files being searched
- Displays number of matches found
- Provides clear error messages if something goes wrong
- Debug mode gives detailed information about the search process
- FZF preview uses grep to show search context

#### Known Limitations
- FZF preview requires grep to be installed
- Debug mode may produce verbose output in the message area

### Bookmarking System

Visidian provides a powerful bookmarking system that integrates GTD (Getting Things Done) and PARA (Projects, Areas, Resources, Archives) methodologies to help organize your notes.

#### Usage

The bookmarking system is accessed through a single command:

```vim
:Bookmark
```

This opens an FZF menu with the following options:

1. **Add to GTD category**
   - Inbox: Capture new ideas and notes
   - Next: Items to be worked on next
   - Waiting: Items waiting on external input
   - Someday: Future possibilities
   - Reference: Reference materials
   - Done: Completed items

2. **Add to PARA category**
   - Projects: Active projects with clear goals
   - Areas: Ongoing responsibilities
   - Resources: Topic-based reference materials
   - Archives: Completed or inactive items

3. **Add to Books category**
   - Reading: Currently reading
   - To-Read: Reading list
   - Finished: Completed books
   - Reference: Reference books and materials

4. **Add to custom category**
   - Select from user-created categories
   - Create new categories as needed

5. **Create new category**
   - Define custom category name
   - Add subcategories (comma-separated)
   - Names automatically sanitized
   - Categories persist across sessions

6. **Manage categories**
   - Edit: Modify subcategories of custom categories
   - Delete: Remove custom categories (with bookmark cleanup)
   - Sort: Alphabetically sort subcategories
   - Base categories (GTD, PARA, Books) are protected

7. **Remove a bookmark**
   - Select from existing bookmarks to remove

8. **View/jump to bookmark**
   - Browse and jump to bookmarked notes
   - Preview shows the first few lines of the note

9. **Toggle statistics view**
   - Show/hide statistics in a dedicated buffer
   - Total bookmark count
   - Bookmarks by category
   - Recent additions (last 7 days)
   - Most viewed bookmarks

#### Features

- **Persistent Storage**: 
  - Bookmarks stored in `.visidian_bookmarks.json`
  - Custom categories stored in `.visidian_categories.json`
- **FZF Integration**: Fast fuzzy finding with preview
- **Category Management**:
  - Base categories (GTD, PARA, Books) for common use cases
  - Custom categories with full CRUD operations
  - Category persistence across sessions
  - Safe deletion with bookmark cleanup
- **Preview Support**: See note content before jumping
- **Vault-aware**: Only allows bookmarking files within your vault
- **Statistics**: Track bookmark usage and view patterns in a toggleable buffer

#### Example Workflow

1. Capture a new idea:
   ```
   :Bookmark
   > Select "add:gtd"
   > Select "inbox"
   > Enter bookmark name
   ```

2. Move to active project:
   ```
   :Bookmark
   > Select "add:para"
   > Select "projects"
   > Enter bookmark name
   ```

3. Jump to a bookmark:
   ```
   :Bookmark
   > Select "view"
   > Fuzzy find your bookmark
   ```

#### Tips

- Use GTD categories for task and workflow management
- Use PARA categories for knowledge and resource organization
- Use Books category for tracking reading materials
- Preview helps quickly find the right note
- Regular cleanup of bookmarks helps maintain organization

### Messaging Guidelines

Visidian uses two distinct types of messages:

1. **User Messages** (`echo`/`echohl`)
   - Immediate feedback about operations that directly affect the user's workflow
   - Examples:
     - Vault creation/selection confirmations
     - File/directory creation notifications
     - Operation success/failure messages
     - Sync status updates
     - Session management notifications

2. **Debug Messages** (`visidian#debug#*`)
   - Detailed information about internal operations
   - Different levels: ERROR, WARN, INFO, DEBUG, TRACE
   - Controlled by `g:visidian_debug_level`
   - Examples:
     - Function entry/exit points
     - Variable state tracking
     - Operation timing
     - Internal error details
     - Path resolution information

#### When to Use Each Type

Use **User Messages** when:
- Confirming successful completion of user-initiated actions
- Reporting immediate operation results
- Providing necessary feedback for user interaction
- Showing progress of long-running operations

Use **Debug Messages** when:
- Tracking internal program flow
- Logging detailed error information
- Recording state changes
- Providing developer-oriented information

#### Message Categories

The debug system uses these categories to organize messages:
- CORE: Core plugin functionality
- UI: User interface operations
- SESSION: Session management
- SYNC: Synchronization operations
- SPELL: Spell checking functionality
- TAGS: Tag generation and management
- PARA: PARA method implementation

### Usage
The popup menu can be accessed using the default keybinding or command (refer to README.md for details). Menu items will now execute their intended commands reliably without interference from previous actions.
