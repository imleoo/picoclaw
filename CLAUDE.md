# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PicoClaw is an ultra-lightweight personal AI assistant written in Go, designed to run on resource-constrained hardware (<10MB RAM). It's a multi-channel chatbot framework that connects various messaging platforms (Telegram, Discord, Slack, WeChat, etc.) to LLM providers (Anthropic, OpenAI, OpenRouter, etc.).

## Build Commands

```bash
# Build for current platform
make build

# Run code generation (embeds workspace files)
make generate

# Build for specific platforms
make build-linux-arm      # Raspberry Pi Zero 2 W (32-bit)
make build-linux-arm64    # Raspberry Pi Zero 2 W (64-bit)
make build-linux-mipsle   # MIPS devices
make build-all            # All platforms

# Build web launcher (requires pnpm)
make build-launcher

# Install to ~/.local/bin
make install
```

## Testing & Quality

```bash
# Run all tests
make test

# Run specific test
go test -run TestName -v ./pkg/session/

# Run benchmarks
go test -bench=. -benchmem -run='^$' ./...

# Code quality checks
make fmt    # Format code
make vet    # Static analysis
make lint   # Full linter (golangci-lint)
make check  # Complete pre-commit check (deps + fmt + vet + test)
```

## Development Workflow

1. Always run `make generate` before building (embeds workspace files via go:embed)
2. Run `make check` before committing to catch issues early
3. Use feature branches, never push directly to `main`
4. All CI checks must pass before merge

### Branch Protection Rules

**IMPORTANT**: This repository enforces strict branch protection via Git hooks:

1. ❌ **Prohibit direct push to `main` branch**
   - All changes must go through Pull Requests
   - Create feature branches: `git checkout -b feature/your-feature`

2. ❌ **Prohibit direct push to `wmnn` branch**
   - No direct commits allowed on wmnn branch

3. ✅ **Only allow merges from `main` to `wmnn`**
   - Correct workflow:
     ```bash
     git checkout wmnn
     git merge main
     git push origin wmnn
     ```

**Install Git hooks** (required for new clones):
```bash
./scripts/install-git-hooks.sh
```

To bypass hooks in emergencies (not recommended):
```bash
git push --no-verify
```

## Architecture

### Core Components

**pkg/agent/** - AI agent orchestration and conversation management
- Handles LLM interactions, tool calls, and conversation state
- Manages multi-turn conversations with context

**pkg/providers/** - LLM provider implementations
- `anthropic/` - Claude API integration
- `openai_compat/` - OpenAI-compatible providers (OpenRouter, etc.)
- `claude_cli_provider.go` - Claude Code CLI integration
- `codex_cli_provider.go` - GitHub Copilot CLI integration
- `factory.go` - Provider factory with fallback support
- `fallback.go` - Automatic provider failover logic

**pkg/channels/** - Messaging platform integrations
- Each channel (telegram/, discord/, slack/, etc.) implements the Channel interface
- `manager.go` - Channel lifecycle management and message routing
- `base.go` - Base channel implementation with common functionality

**pkg/session/** - Conversation session management
- Maintains conversation history and context
- Handles session persistence and recovery

**pkg/mcp/** - Model Context Protocol support
- MCP server integration for extended tool capabilities
- Tool discovery and execution

**pkg/routing/** - Message routing and user management
- Routes messages between channels and agents
- Handles user authentication and authorization

**pkg/memory/** - Persistent storage
- SQLite-based storage for conversations and state
- Session history and user preferences

**pkg/tools/** - Built-in tool implementations
- Web search, file operations, and other utilities

**pkg/skills/** - Extensible skill system
- User-defined commands and workflows

**web/** - Web console interface
- `frontend/` - React + TypeScript + Vite + TanStack Router
- `backend/` - Go HTTP server serving the web UI

### Key Design Patterns

**Provider Fallback Chain**: Providers can be chained with automatic failover on errors. Configure via `PICOCLAW_PROVIDER_FALLBACK_CHAIN` environment variable.

**Channel Abstraction**: All messaging platforms implement a common `Channel` interface, making it easy to add new platforms.

**Event Bus**: `pkg/bus/` provides pub/sub for decoupled component communication.

**Embedded Resources**: Workspace files and skills are embedded at build time using `go:embed` directives.

## Configuration

Configuration is loaded from:
1. Environment variables (highest priority)
2. `.env` file in working directory
3. `config.json` in `~/.picoclaw/`

Key environment variables:
- `ANTHROPIC_API_KEY` - Claude API key
- `OPENAI_API_KEY` - OpenAI API key
- `OPENROUTER_API_KEY` - OpenRouter API key
- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `DISCORD_BOT_TOKEN` - Discord bot token
- `PICOCLAW_PROVIDER_FALLBACK_CHAIN` - Provider fallback order

See `.env.example` for complete list.

## Adding New Features

### Adding a New Channel

1. Create directory in `pkg/channels/<channel_name>/`
2. Implement the `Channel` interface from `pkg/channels/interfaces.go`
3. Register in `pkg/channels/registry.go`
4. Add configuration struct with env tags
5. Add documentation in `docs/channels/<channel_name>/`

### Adding a New Provider

1. Implement `Provider` interface from `pkg/providers/types.go`
2. Add factory method in `pkg/providers/factory.go`
3. Support streaming responses for better UX
4. Handle rate limiting and errors appropriately

## Testing Notes

- Use `testify` for assertions (`github.com/stretchr/testify`)
- Mock external dependencies (LLM APIs, channels)
- Integration tests use `_integration_test.go` suffix
- Benchmarks use `_bench_test.go` suffix or `Benchmark` prefix

## Common Gotcases

- **CGO_ENABLED=0**: Build uses static linking for portability
- **MIPS builds**: Require special ELF e_flags patching (see Makefile)
- **go:embed**: Changes to workspace files require `make generate`
- **Provider cooldown**: Failed providers have exponential backoff
- **Message splitting**: Long responses are automatically split per channel limits
