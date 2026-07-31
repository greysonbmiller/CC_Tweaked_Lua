import time
import pyautogui
import os

# Initial wait
print("Waiting 5 seconds... switch to your target input window.")
time.sleep(5)

# Define the input file path
file_path = os.path.join(os.getcwd(), "input.txt")

# Read the content of the file
try:
    with open(file_path, 'r', encoding='utf-8') as file:
        lines = file.readlines()
except FileNotFoundError:
    print("input.txt not found in the current directory.")
    exit(1)

# Determine if the file uses tabs or spaces for indentation
# This is a simple heuristic; it assumes consistent indentation
indent_char = '\t'
indent_size = 1 # Assuming 1 tab character represents one indent level
if all(not line.startswith('\t') for line in lines) and any(' ' * 2 in line or ' ' * 4 in line for line in lines):
    # If no tabs but some lines have multiple leading spaces, assume spaces
    indent_char = ' '
    # Try to guess common space indentation (e.g., 2 or 4 spaces)
    for line in lines:
        if line.strip(): # Only consider non-empty lines
            leading_spaces = len(line) - len(line.lstrip(' '))
            if leading_spaces > 0:
                # Assuming 4 spaces is a common indent size
                if leading_spaces % 4 == 0:
                    indent_size = 4
                    break
                elif leading_spaces % 2 == 0:
                    indent_size = 2
                    break


previous_indent_level = 0

for i, line in enumerate(lines):
    # Calculate current line's indentation level based on leading whitespace
    current_line_stripped = line.lstrip(indent_char)
    current_indent_level = (len(line) - len(current_line_stripped)) // indent_size

    # Adjust indentation from the previous line's end to the current line's start
    if current_indent_level > previous_indent_level:
        # Indent in
        for _ in range(current_indent_level - previous_indent_level):
            pyautogui.press('tab')
    elif current_indent_level < previous_indent_level:
        # De-indent out
        for _ in range(previous_indent_level - current_indent_level):
            pyautogui.press('backspace') # Backspace removes one level of indentation after an Enter

    # Type the actual content of the line (without leading whitespace)
    # Remove newline character to control enter manually
    content_to_type = current_line_stripped.rstrip('\n')
    for char in content_to_type:
        pyautogui.write(char, interval=0.008)

    # After finishing typing the line, press Enter
    pyautogui.press('enter')

    # Update previous_indent_level for the next iteration
    previous_indent_level = current_indent_level