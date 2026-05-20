# Code Snuggie

Code Snuggie is a an agent that creates a reliable devcontainer setup for another repository or npm starter. The human setup is intentionally small: give this codespace permission to write to the destination repository, start a fresh codespace, and ask Codex to do the rest.

## Human Setup

1. Create an empty GitHub repository for the generated project, such as `my-org/my-generated-app`.

2. In this repository, update [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) so Codespaces can write to that exact destination repository. Keep this least-privilege; the normal Code Snuggie workflow needs only `contents: write` and `pull_requests: write`.

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

3. Commit and push that devcontainer change to this `code-snuggie-control-center` repository.

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

## Security Note

The Code Snuggie Control Center includes the Docker-in-Docker devcontainer extension so Codex can build and validate generated devcontainers. Docker-in-Docker requires the Control Center container to run in privileged mode, which has security implications because processes inside the codespace have more control over the codespace VM. Since this runs inside a GitHub-hosted Codespaces VM, that privileged access should not affect your local machine, but you should still treat the codespace itself as a privileged development environment.
