# GitLab mirror and `glab` authentication

Same layout as `satisfactory-server-k8s`: see that repo’s `docs/GITLAB_MIRROR.md` for full steps.

Summary:

1. `glab auth login --hostname gitlab.com` **or** `export GITLAB_TOKEN=...`
2. `glab auth status` should show an authenticated user.
3. `glab repo create dk-raas/dkai/game-servers/windrose-server-k8s --private` (adjust visibility to match org policy).
4. Configure `HARBOR_*` CI variables on the GitLab project for image push.

The GitHub repository needs a `GITLAB_TOKEN` secret with push access to the mirror project.
