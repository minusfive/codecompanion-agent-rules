# Project Agent Rules

## Project Overview

This is a Neovim extension for CodeCompanion which automatically detects and loads project rule files to the chat context. It handles the complexity of discovering and managing rule files across your project hierarchy.

## Code Quality Standards

- Maintain clear separation of concerns between file detection, path resolution, and reference management
- All functions should have a single responsibility with descriptive names
- Variable naming should follow Lua conventions (snake_case)
- Cache results where possible to avoid redundant file system operations
- Use `Neovim ^0.11` APIs for file operations for cross-platform compatibility
- Use strict Lua type annotations (`---@type`) for all variables, parameters, and return values
- Document complex functions with LuaDoc comments to improve maintainability

## Error Handling Requirements

- All file system operations must have proper error handling
- Fail gracefully when files don't exist or permissions are denied
- Log meaningful error messages at appropriate levels (debug vs error)
- Never throw unhandled exceptions that could crash CodeCompanion

## Performance Considerations

- Minimize file system operations, especially in large projects
- Use caching mechanisms to avoid redundant path traversals
- Debounce events that can trigger in rapid succession
- Consider async operations for expensive tasks
- Be mindful of memory usage with large rule files
- Implement intelligent throttling based on project size and file count
- Batch filesystem operations when multiple files need to be accessed
- Cache parsed rule content, not just file paths
- Use lazy loading for rule file content until needed
- Consider tiered caching with frequently accessed rules kept in memory

## Common Issues to Detect

- Path normalization issues (especially between Windows/Unix)
- Race conditions between file detection and reference addition
- Memory leaks from accumulated references
- Inefficient path traversal algorithms
- Excessive logging in non-debug mode

## Testing Instructions

1. Test with nested project structures to verify correct directory traversal
2. Verify behavior with various rule file types (.rules, AGENT.md, etc.)
3. Check performance with large projects containing many files
4. Test edge cases like empty rule files, very large rule files
5. Verify correct handling of Unicode paths and filenames
6. Test the extension with concurrent CodeCompanion operations

## Implementation Guidelines

- When extending functionality, follow the existing event-based architecture
- Use the CodeCompanion utilities where available rather than reimplementing
- Consider backward compatibility when modifying public functions
- Document any non-obvious code with clear comments
- Prefer functional patterns over imperative code where appropriate
- Follow CodeCompanion's extension patterns for structure and naming conventions
- Namespace all functions and variables properly to avoid conflicts with other extensions
- Expose functionality through well-defined exports when appropriate
- Use CodeCompanion's config object to modify behavior rather than direct patching
- Register for appropriate CodeCompanion events rather than creating custom event loops
- Handle extension enable/disable states properly with cleanup procedures

## Agent Instructions

When analyzing this codebase:

1. Pay special attention to the path traversal and file detection logic
2. Verify that event handlers properly clean up resources
3. Check for potential race conditions in the reference management
4. Look for places where error handling could be improved
5. Suggest optimizations for performance-critical sections
6. Identify any potential security issues with file path handling

## Preventing Hallucinations

- Only reference files that actually exist in the project
- Do not assume default configurations unless explicitly defined
- Verify paths before attempting to read files
- Use strict type checking when processing user input
- Double-check autocmd patterns to ensure they match intended events only

## Extension Maintainability

- Keep configuration options focused and well-documented
- Provide clear feedback to users when operations succeed or fail
- Use descriptive variable names that reflect their purpose
- Include debug logging that's comprehensive but not overwhelming
- Ensure proper cleanup on disable/unload to prevent resource leaks
