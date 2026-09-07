# 0002 — Least-privilege permission for brave-search

Status: accepted
Date: 2026-09-04
Roma: .claude/roma/also-add-to-my-rome-2026-09-04

## Context
settings.json permissions.allow currently grants MCP servers at server granularity (mcp__code-navigator). The brave-search server is launched with --enabled-tools brave_web_search, so only one of its tools is reachable today, but a server-level grant would silently pre-approve any tool the server exposes later (image, news, local search) after a version bump. The reddit MCP server's tool names are not known from the repo.

## Decision
Permit brave-search at tool granularity: mcp__brave-search__brave_web_search in permissions.allow. Permit reddit at server granularity (mcp__reddit) because its tool ids are unverified; narrow it to specific tool ids in a follow-up once they are observed at runtime. The tools: frontmatter of legatus lists the servers (mcp__brave-search, mcp__reddit) — availability — while permissions.allow decides which calls run without a prompt.

## Consequences
A future brave-search release that adds tools cannot use them unprompted; the prompt is the signal to revisit the grant. Asymmetry between the two entries must be explained in the plan and in the ADR, or a future reader will 'fix' it into a server-level grant. settings.json has no test suite: a typo in a tool id fails silently at runtime as a permission prompt, so the verify step parses the JSON and asserts both entries are present.
