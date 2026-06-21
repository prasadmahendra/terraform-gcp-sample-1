# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 5. Terraform Operations

**All terraform commands must be run via the `tf.sh` wrapper script from the `terraform/` directory.**

The script handles GKE cluster authentication, environment-specific state/vars, and provider setup.

### Usage

```
sh tf.sh -e <environment> -a <action> [-t <target>] [extra args...]
```

- **`-e`**: Environment name — `dev`, `prod`, `dev-training`, `prod-training`
- **`-a`**: Terraform action — `plan`, `apply`, `init`, `state`, `import`, `destroy`, `upgrade`, `providers`, `force-unlock`, `taint`, `untaint`
- **`-t`**: Optional `-target` (repeatable for multiple targets)
- Extra positional args are passed through to terraform

### Common Examples

```bash
# Plan
sh tf.sh -e prod -a plan

# Apply
sh tf.sh -e prod -a apply

# Apply targeting a specific resource
sh tf.sh -e prod -a apply -t 'module.container-cluster-default-keda-config'

# State operations
sh tf.sh -e prod -a state list
sh tf.sh -e prod -a state rm 'module.example[0].resource_type.resource_name'
sh tf.sh -e prod -a state show 'module.example[0].resource_type.resource_name'
sh tf.sh -e prod -a state mv 'old.address' 'new.address'

# Import a resource
sh tf.sh -e prod -a import 'module.example.resource_type.name' 'resource-id'

# Initialize (install providers, set up backend)
sh tf.sh -e prod -a init

# Upgrade providers and regenerate lock file
sh tf.sh -e prod -a upgrade
```

### Key Notes

- Always run from the `terraform/` root directory (not `deployment/`). The script `cd`s into `deployment/` internally.
- The script authenticates to GKE clusters and sets up kubeconfig before running terraform.
- State files and var files are per-environment under `environments/<env>/`.
- When converting `kubernetes_manifest` to `kubectl_manifest` (or any resource type change), you must `state rm` the old entries before apply — terraform cannot migrate state across resource types.
