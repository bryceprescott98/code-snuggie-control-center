# Code Snuggie

Code Snuggie is a an agent that createx a reliable devcontainer setup for another repository or npm starter. The human setup is intentionally small: give this codespace permission to write to the destination repository, start a fresh codespace, and ask Codex to do the rest.

## Human Setup

1. Create an empty GitHub repository for the generated project, such as `my-org/my-generated-app`.

2. In this repository, update [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) so Codespaces can write to that destination repository:

   ```jsonc
   {
     "customizations": {
       "codespaces": {
         "repositories": {
           "my-org/my-generated-app": {
             "permissions": {
               "contents": "write",
               "pull_requests": "write"
             }
           }
         }
       }
     }
   }
   ```

3. Commit and push that devcontainer change to this `code-snuggie-app` repository.

4. Create a new codespace from that commit and approve the repository-access prompt from GitHub.

5. Before starting the Codex thread, select **Full Access** for the thread permissions. Use a more restrictive permission mode only if you want Codex to ask before routine actions like creating files, installing dependencies, running checks, committing, pushing, or opening a pull request.

6. Ask Codex what you want generated. Examples:

   ```text
   Create a Codespaces-ready repo for https://github.com/excalidraw/excalidraw and open a PR to my-org/my-generated-app.
   ```

   ```text
   Create a Codespaces-ready Remotion starter from https://www.npmjs.com/package/remotion and open a PR to my-org/my-generated-app.
   ```

Codex will create the job under `.code-snuggie/jobs/<job-name>/workspace/`, validate the generated devcontainer, push a branch to the destination repository, and open a pull request. The command-level workflow lives in the local `code-snuggie` skill, not in this README.

GitHub documents the repository-access prompt in [Managing access to other repositories within your codespace](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-repository-access-for-your-codespaces).
