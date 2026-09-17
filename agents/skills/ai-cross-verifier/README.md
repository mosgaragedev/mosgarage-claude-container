# AI Cross-Verifier Skill

Cross-verify Claude-generated plans and code using OpenAI Codex (gpt-5-medium) and Google Gemini CLI for independent validation and comparative analysis.

## Overview

This skill enables you to get second opinions on Claude's code and plans by running independent verification through:

- **OpenAI Codex** (gpt-5-medium model) - Advanced code understanding and analysis
- **Google Gemini CLI** - Google's multimodal AI for code and plan review

You can choose to verify with **Codex only**, **Gemini only**, or **both for comparative analysis**.

## Prerequisites

### Required CLI Tools

1. **OpenAI Codex CLI** - Install and authenticate:
   ```bash
   # Check if installed
   command -v codex

   # Install (if not present)
   # Follow: https://platform.openai.com/docs/guides/codex

   # Login
   codex login
   ```

2. **Google Gemini CLI** - Install and configure:
   ```bash
   # Check if installed
   command -v gemini

   # Install (if not present)
   # Follow: https://github.com/google-gemini/gemini-cli

   # Configure API key
   export GEMINI_API_KEY="your-api-key"
   ```

### Verify Installation

```bash
# Test Codex
codex exec "Hello, test"

# Test Gemini
gemini -p "Hello, test"
```

## How to Use

### Invoking the Skill

The skill auto-activates when you mention cross-verification keywords:

```
You: "Please cross-verify this code using Codex and Gemini"
You: "I need a second opinion on this plan"
You: "Verify this implementation with other AI models"
```

Or invoke manually:

```bash
# In Claude CLI
/skill ai-cross-verifier
```

### Interactive Workflow

The skill will guide you through 3 prompts:

#### 1. Select Verification Mode

```
AI CROSS-VERIFICATION MODE SELECTION
====================================

Please select verification mode:

1. Codex Only     - OpenAI Codex (gpt-5-medium) verification only
2. Gemini Only    - Google Gemini CLI verification only
3. Both (Compare) - Run both and generate comparative analysis

Enter choice [1-3]:
```

**Choose based on your needs:**
- **Codex Only** - Fast, focused on OpenAI's perspective
- **Gemini Only** - Fast, Google's AI perspective
- **Both** - Best quality, consensus analysis (slower, uses both APIs)

#### 2. Identify Verification Target

```
VERIFICATION TARGET
===================

What would you like to verify?

1. File(s)        - Verify existing file(s) by path
2. Code Snippet   - Verify code provided inline
3. Plan/Text      - Verify plan or technical text

Enter choice [1-3]:
```

**Examples:**
- **File(s)**: `/path/to/auth.js` or `/inc/php_upgrade.inc`
- **Code Snippet**: Paste code directly when prompted
- **Plan/Text**: Paste implementation plan or technical document

#### 3. Select Verification Type

```
VERIFICATION TYPE
=================

Select verification focus:

1. Code Review           - Bug detection, best practices, code quality
2. Plan Validation       - Completeness, feasibility, technical accuracy
3. Both Review + Plan    - Comprehensive analysis (code + plan)

Enter choice [1-3]:
```

**Choose based on what you're verifying:**
- **Code Review** - For code files or snippets
- **Plan Validation** - For implementation plans, architecture docs
- **Both** - For comprehensive code + approach analysis

### Example Sessions

#### Example 1: Code Review with Both AIs

```
You: "Cross-verify the authentication module in auth.js"

AI Cross-Verifier:
  Mode: 3 (Both - Codex + Gemini)
  Target: 1 (File)
    → Enter file path: /src/auth.js
  Type: 1 (Code Review)

  [Runs Codex and Gemini in parallel]

  Output: Comparative analysis showing:
    ✓ Consensus Issues (both found)
      - CRITICAL: SQL injection vulnerability in login function
      - HIGH: Missing input validation on username field

    ⚠ Codex-Specific Findings
      - MEDIUM: Inefficient token generation algorithm

    ⚠ Gemini-Specific Findings
      - MEDIUM: Consider rate limiting for failed login attempts

    Recommendations: Fix consensus issues first, then evaluate
    single-source findings
```

#### Example 2: Plan Validation with Gemini Only

```
You: "Quick validation of my database migration plan with Gemini"

AI Cross-Verifier:
  Mode: 2 (Gemini Only)
  Target: 3 (Plan/Text)
    → [Paste plan when prompted]
  Type: 2 (Plan Validation)

  [Runs Gemini verification]

  Output: Plan validation report:
    ✓ Completeness: 8/10
    ✓ Feasibility: 9/10

    Missing Steps:
      - Rollback procedure not defined
      - Index migration strategy unclear

    Recommendations:
      1. Add detailed rollback plan
      2. Document index recreation strategy
      3. Consider data validation checkpoints
```

#### Example 3: Comprehensive Code + Plan Review

```
You: "Verify both the code and approach for this refactoring"

AI Cross-Verifier:
  Mode: 3 (Both)
  Target: 2 (Code Snippet)
    → [Paste refactored code]
  Type: 3 (Both Review + Plan)

  [Runs both AIs for dual analysis]

  Output: Dual-perspective comparative report:

    CODE QUALITY CONSENSUS:
      ✓ Clean separation of concerns
      ✓ Good error handling

    IMPLEMENTATION APPROACH CONSENSUS:
      ⚠ Breaking API changes not documented
      ⚠ Migration path unclear

    CODEX PERSPECTIVE:
      + Suggests builder pattern for complex initialization

    GEMINI PERSPECTIVE:
      + Recommends versioning strategy for API changes

    Synthesis: Code quality excellent, but implementation
    rollout needs better planning
```

## Understanding Output

### Comparative Analysis (Both Mode)

When using both AIs, the output is structured as:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONSENSUS FINDINGS (Both AIs Agree)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CRITICAL] SQL injection in user input
  └─ Codex: Use parameterized queries
  └─ Gemini: Implement prepared statements
  └─ Confidence: HIGH (both agree)
```

**Interpretation:**
- **Consensus findings** - High confidence, both AIs identified
- **Priority first** - Address these issues immediately
- **Code examples** - Use specific recommendations from either AI

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CODEX-SPECIFIC FINDINGS (Codex Only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[MEDIUM] Performance optimization opportunity
  └─ Finding: Cache database query results
  └─ Gemini: Did not identify this issue
  └─ Confidence: MEDIUM (single source)
```

**Interpretation:**
- **Single-source findings** - Worth investigating but lower confidence
- **Evaluate individually** - May be valid but needs human judgment
- **Consider context** - May be specific to AI's training/perspective

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONFLICTING ASSESSMENTS (Disagreements)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CONFLICT] Error handling approach
  └─ Codex: Use exceptions for error flow
  └─ Gemini: Return error objects, avoid exceptions
  └─ Analysis: Trade-off between clarity vs performance
  └─ Recommendation: Choose based on project conventions
```

**Interpretation:**
- **Conflicts reveal nuances** - Both approaches may be valid
- **Consider trade-offs** - Evaluate based on your specific context
- **Project standards** - Align with existing codebase patterns

### Confidence Levels

```
✓ HIGH:   Issues identified by both AIs (consensus)
⚠ MEDIUM: Issues identified by one AI only (single source)
⚡ LOW:    Conflicting assessments (requires human judgment)
```

## CLI Commands Reference

### Codex CLI Commands

```bash
# Basic verification (non-interactive)
codex exec "Review this code: [code]"

# Interactive mode
codex
# Then paste verification prompt

# Check available commands
codex --help
```

### Gemini CLI Commands

```bash
# Basic verification (using -p flag)
gemini -p "Review this code: [code]"

# Alternative: positional argument (also works)
gemini "Review this code: [code]"

# With model selection
gemini -m gemini-pro -p "Verify: [code]"

# Interactive mode
gemini
# Then paste verification prompt

# Check options
gemini --help
```

### Parallel Execution

```bash
# Run both AIs simultaneously
(codex exec "$PROMPT" > /tmp/codex_result.txt 2>&1) &
(gemini -p "$PROMPT" > /tmp/gemini_result.txt 2>&1) &
wait

# View results
echo "=== CODEX ==="
cat /tmp/codex_result.txt
echo "=== GEMINI ==="
cat /tmp/gemini_result.txt
```

## Best Practices

### When to Use Each Mode

**Codex Only:**
- Quick code reviews
- OpenAI ecosystem preference
- Cost-conscious (single API call)
- Codex-specific features needed

**Gemini Only:**
- Google ecosystem preference
- Multimodal analysis (images, diagrams)
- Cost-conscious (single API call)
- Gemini-specific capabilities needed

**Both (Comparative):**
- Critical code or decisions
- Need high confidence through consensus
- Want diverse perspectives
- Can afford double API costs

### Verification Tips

1. **Be Specific** - Focus verification on specific aspects (security, performance, etc.)
2. **Provide Context** - Include relevant background in your prompts
3. **Iterate** - Use findings to improve, then re-verify if needed
4. **Human Judgment** - AI analysis informs decisions, doesn't replace them
5. **Document** - Save verification reports for future reference

### Cost Optimization

```bash
# For routine checks: Use single AI
Mode: 1 (Codex Only) or 2 (Gemini Only)

# For critical code: Use both
Mode: 3 (Both)

# Batch verifications: Group multiple files
Target: 1 (Files) → provide multiple paths
```

## Troubleshooting

### Codex Issues

**Authentication Error:**
```bash
# Re-authenticate
codex logout
codex login
```

**Model Not Available:**
```bash
# Check available commands and models
codex --help

# Check model information
codex models
```

### Gemini Issues

**API Key Error:**
```bash
# Set API key
export GEMINI_API_KEY="your-api-key"

# Verify
echo $GEMINI_API_KEY
```

**CLI Not Found:**
```bash
# Install Gemini CLI
# Follow: https://github.com/google-gemini/gemini-cli

# Verify installation
which gemini
gemini --version
```

### Parallel Execution Issues

**Background Jobs Not Completing:**
```bash
# Check job status
jobs

# Wait manually
wait $(jobs -p)

# Check output files exist
ls -lah /tmp/codex_result.txt /tmp/gemini_result.txt
```

## FAQ

**Q: Can I use other OpenAI models besides gpt-5-medium?**
A: Yes, modify the skill's SKILL.md or specify different model with `-m` flag.

**Q: Does this work with Claude Code's existing workflows?**
A: Yes, invoke during any Claude session for independent verification.

**Q: Are API costs involved?**
A: Yes, both Codex and Gemini may have API usage costs. Check respective pricing.

**Q: Can I customize verification prompts?**
A: Yes, edit the prompt templates in SKILL.md to match your needs.

**Q: How long does verification take?**
A: Single AI: 5-30 seconds. Both AIs: 10-60 seconds (parallel execution).

**Q: Can I save verification results?**
A: Yes, outputs are shown in CLI. Save manually or redirect to files.

## Advanced Usage

### Custom Prompt Templates

Edit `.claude/skills/ai-cross-verifier/SKILL.md` to customize prompts:

```markdown
### Code Review Prompts

**Template for Code Review:**

ROLE: You are an expert [YOUR DOMAIN] code reviewer...
TASK: Review focusing on [YOUR CRITERIA]...
```

### Integration with CI/CD

```bash
#!/bin/bash
# pre-commit hook example

echo "Running AI cross-verification..."

# Verify changed files
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM "*.js" "*.py")

for file in $CHANGED_FILES; do
    echo "Verifying: $file"
    # Use Codex for quick pre-commit check
    codex exec "Quick review for bugs: $(cat $file)"
done
```

### Batch Verification Script

```bash
#!/bin/bash
# verify_all.sh - Verify multiple files

FILES=("src/auth.js" "src/database.js" "src/api.js")

for file in "${FILES[@]}"; do
    echo "=== Verifying: $file ==="

    # Run verification
    codex exec "Review $(cat $file)" > "reports/${file}.codex.txt"
    gemini -p "Review $(cat $file)" > "reports/${file}.gemini.txt"

    echo "Results saved to reports/"
done
```

## Resources

- **OpenAI Codex**: https://platform.openai.com/docs/guides/codex
- **Google Gemini**: https://ai.google.dev/gemini-api/docs
- **Gemini CLI**: https://github.com/google-gemini/gemini-cli
- **Prompt Engineering**: https://platform.openai.com/docs/guides/prompt-engineering

## Support

For issues with:
- **This skill**: Check `.claude/skills/ai-cross-verifier/SKILL.md`
- **Codex CLI**: https://platform.openai.com/docs
- **Gemini CLI**: https://github.com/google-gemini/gemini-cli/issues
- **Claude Code**: https://github.com/anthropics/claude-code/issues

## Version History

- **v1.0** (2025-10-20) - Initial release
  - Codex (gpt-5-medium) verification
  - Gemini CLI verification
  - Comparative analysis mode
  - Code review + plan validation
