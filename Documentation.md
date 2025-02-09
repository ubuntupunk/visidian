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

### Usage
The popup menu can be accessed using the default keybinding or command (refer to README.md for details). Menu items will now execute their intended commands reliably without interference from previous actions.
