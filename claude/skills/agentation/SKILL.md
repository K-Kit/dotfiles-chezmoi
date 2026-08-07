---
name: agentation
description: Add the Agentation visual feedback toolbar and optional live MCP sync to a React or Next.js project.
---

# Agentation setup

Set up Agentation only in a React 18+ web project.

1. Inspect the lockfile and package manifest. Install `agentation` as a development dependency with the project's existing package manager if it is absent.
2. Stop if an `Agentation` import and component already exist.
3. Add the component at the application root:

```tsx
import { Agentation } from "agentation";

{process.env.NODE_ENV === "development" && <Agentation />}
```

For Next.js App Router, place it in `app/layout.tsx` after `children`. For Pages Router, place it in `pages/_app.tsx` after the page component. For another React framework, use its root application component.

Keep the `NODE_ENV` guard so production bundles do not render the toolbar.

The shared Dotfiles MCP registry configures `agentation-mcp` for Claude and Codex. OpenCode keeps it disabled globally to avoid starting an irrelevant server in non-frontend repositories; enable `mcp.agentation` in the project configuration when live annotation sync is wanted.

After enabling MCP sync, run:

```bash
npx -y agentation-mcp doctor
```

Restart the coding agent after changing MCP configuration.
