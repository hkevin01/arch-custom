# Copilot Configuration

## Behavior
- Plan before coding. No code without an approved plan.
- TDD: write tests first, then implementation.
- Max file length: 500 lines. Max function length: 50 lines.
- Follow OWASP Top 10 security practices at all times.

## Agent Settings
- Max 100 tool calls per session (chat.agent.maxRequests: 100).
- Auto-approve only safe read-only terminal commands.
- Never auto-approve: rm, kill, eval, curl with pipes, chmod, chown.
- chat.tools.global.autoApprove remains false per OWASP A01.

## Code Standards
- Python:  snake_case functions/vars, PascalCase classes, UPPER_SNAKE_CASE constants.
- Java:    camelCase methods, PascalCase classes, UPPER_SNAKE_CASE constants.
- C++:     Google style — snake_case/camelCase functions, PascalCase classes.
- Bash:    snake_case functions and variables, UPPER_CASE env vars.
