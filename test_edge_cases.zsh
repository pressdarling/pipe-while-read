#!/usr/bin/env zsh

# Test suite for pipe-while-read.zsh edge cases.
# Load the script to be tested.
source ./pipe-while-read.zsh

echo "--- Running Edge Case Tests for pipe-while-read ---"

# --- Test 1: No stdin (empty input) ---
echo "\n--- Test 1: No stdin (empty input) ---"
cat /dev/null | pipe-while-read echo "Line:"

# --- Test 2: Input with spaces, tabs, and special characters ---
echo "\n--- Test 2: Input with spaces, tabs, and special characters ---"
echo -e "foo bar\nbaz\tqux\n!@#\$%^&*()" | pipe-while-read echo "Special:"

# --- Test 3: Very long lines ---
echo "\n--- Test 3: Very long lines ---"
# Note: Reduced length from 10000 to 100 for reasonable log output.
perl -e 'print "a"x100 . "\n"' | pipe-while-read echo "Length:"

# --- Test 4: Arguments with spaces or quotes ---
echo "\n--- Test 4: Arguments with spaces or quotes ---"
echo 'file name with spaces.txt' | pipe-while-read echo "File:"

# --- Test 5: Flags together and repeated ---
echo "\n--- Test 5: Flags together and repeated ---"
echo "test" | pipe-while-read -h -n echo "HelpDryRun:"
echo "test" | pipe-while-read --dry-run --help echo "Combo:"

# --- Test 6: Piping binary data ---
# Note: This may produce mojibake, which is expected.
echo "\n--- Test 6: Piping binary data ---"
head -c 10 /dev/urandom | pipe-while-read echo "Binary:"

# --- Test 7: Command missing (should trigger usage/help) ---
echo "\n--- Test 7: Command missing ---"
echo "foo" | pipe-while-read
pipe-while-read -h

# --- Test 8: Dry-run variant to check command rendering ---
echo "\n--- Test 8: Dry-run rendering ---"
echo -e "one\ntwo" | pipe-while-read -n touch

# --- Test 9: Blank lines and lines with only whitespace ---
echo "\n--- Test 9: Blank lines and lines with only whitespace ---"
echo -e "\n \t\nfoo" | pipe-while-read echo "BlankOrWS:"

echo "\n--- Tests complete ---"

# --- Test 10: Dry-run with argument containing spaces ---
echo "line" | pipe-while-read -n echo "arg with spaces"
