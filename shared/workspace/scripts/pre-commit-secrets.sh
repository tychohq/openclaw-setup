#!/usr/bin/env bash
# Pre-commit hook: scan staged files for API key patterns
# Install: cp this file to ~/.openclaw/.git/hooks/pre-commit && chmod +x ~/.openclaw/.git/hooks/pre-commit

PATTERNS=(
    'sk-proj-[a-zA-Z0-9]'
    'sk-or-v1-[a-zA-Z0-9]'
    'sk-ant-api[a-zA-Z0-9]'
    'AIzaSy[a-zA-Z0-9]'
    'GOCSPX-[a-zA-Z0-9_-]'
    'BSAI[a-zA-Z0-9]'
    'ghp_[a-zA-Z0-9]{36}'
    'gho_[a-zA-Z0-9]{36}'
    'xoxb-[0-9]'
    'xoxp-[0-9]'
    'AKIA[0-9A-Z]{16}'
    'sk_live_[a-zA-Z0-9]'
    'sk_test_[a-zA-Z0-9]'
    'AC[a-f0-9]{32}'
    '"[a-f0-9]{64}"'
)

FAILED=0

for pattern in "${PATTERNS[@]}"; do
    matches=$(git diff --cached -U0 --diff-filter=ACM | grep -E "^\+" | grep -v "^+++" | grep -E "$pattern" 2>/dev/null)
    if [ -n "$matches" ]; then
        if [ "$FAILED" -eq 0 ]; then
            echo "ERROR: Potential secrets detected in staged changes:"
            echo ""
        fi
        echo "  Pattern: $pattern"
        echo "$matches" | head -5 | sed 's/^/    /'
        echo ""
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo "Commit blocked. Remove secrets or use 'git commit --no-verify' to bypass."
    exit 1
fi
