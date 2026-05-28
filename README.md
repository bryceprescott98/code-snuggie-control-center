# Code Snuggie

![Code Snuggie character](assets/small-code-snuggie-character-no-bg.png)

#### Code Snuggie is an AI agent that turns repos and packages into ready-to-use Codespaces

- The current version targets Python and Node.js projects.
- The human setup is intentionally small:
  - create a new repo for your project,
  - give Code Snuggie Control Center permission to write to that destination repo and
  - ask Code Snuggie to do the rest.

## Why Code Snuggie?

- 🛡️ **Worried about supply-chain attacks** or running unknown code on your local machine?
- 🤖 **Tired of approving every tiny step** for your coding agent, but not comfortable going full YOLO on your own computer?
- 🐳 **Hate writing Dockerfiles, fixing devcontainer configs, and installing dependencies** before you can actually build or try anything?

Same.

**Code Snuggie helps get a GitHub repo or starter package running in a Codespace sandbox in minutes** without making you hand-write the Dockerfile or devcontainer setup first.

Once you are inside your **Code Snuggie-prepped Codespace**, Codex is there to help you inspect, run, and modify the code.

And because you are in a **Codespace** — not on your local machine — you can let Codex move faster without that _“what did I just approve?”_ feeling.

## Human Setup

1. Create an empty GitHub repository for the generated project, such as `my-org/my-generated-app`.

2. Separately, clone this repository and update [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) so Codespaces can write to the destination repository you created in Step 1. Keep this least-privilege; the normal Code Snuggie workflow needs only `contents: write` and `pull_requests: write`. Add the new destination repository to [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) like this:

   ```jsonc
   {
     "customizations": {
       "codespaces": {
         "repositories": {
           "my-org/my-generated-app": {
             "permissions": {
               "contents": "write",
               "pull_requests": "write",
             },
           },
         },
       },
     },
   }
   ```

   See further details regarding managing access to other repositories within a codespace [here](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-repository-access-for-your-codespaces).

3. Commit and push that devcontainer change to your forked `code-snuggie-control-center` repository.

4. Create a new codespace from your Code Snuggie Control Center fork and approve the repository-access prompt from GitHub.

5. Connect to Codex in your Code Snuggie Control Center codespace. Before starting the Codex thread, select **Full Access** for the thread permissions. Use a more restrictive permission mode only if you want Codex to ask before routine actions like creating files, installing dependencies, running checks, committing, pushing, or opening a pull request.

6. Ask Codex what you want generated. Examples:

   > Create a Codespaces-ready repo for https://github.com/excalidraw/excalidraw and open a PR to my-org/my-generated-app.

   > Create a Codespaces-ready Remotion starter from https://www.npmjs.com/package/remotion and open a PR to my-org/my-generated-app.

Codex will use the Code Snuggie skill and scripts to create the job under `.code-snuggie/jobs/<job-name>/workspace/`, validate the generated devcontainer, push a branch to the destination repository, and open a pull request.

## Current Support

Code Snuggie currently supports Python and Node.js projects. If you would like support for another language or stack, please open an issue.

## Security Note

The Code Snuggie Control Center includes the Docker-in-Docker devcontainer extension so Codex can build and validate generated devcontainers. Docker-in-Docker requires the Control Center container to run in privileged mode, which has security implications because processes inside the codespace have more control over the codespace VM. Since this runs inside a GitHub-hosted Codespaces VM, that privileged access should not affect your local machine, but you should still treat the codespace itself as a privileged development environment.
