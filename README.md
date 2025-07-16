# shared

Shared resources and tools, mainly GitHub Actions reusable workflows and Makefile dev tools.

This is a [Crickets and Comb](https://cricketsandcomb.org) resource.

## Setup

You can use the reusable workflows in `.github/workflows/` like any GitHub Actions reusable workflow (see https://docs.github.com/en/actions/sharing-automations/reusing-workflows). See `reference_package` for examples, https://github.com/crickets-and-comb/reference_package.

But, to use the dev tools in `Makefile`, and to run the local workflow files during development, you'll need to add `shared` as a Git submodule to your repo.

See https://git-scm.com/book/en/v2/Git-Tools-Submodules

### Adding `shared` Git submodule to a repo for the first time

If this shared repo hasn't yet been added to a repo where you want to start using it, create this as a Git submodule in that repo by running and committing:

```bash
  $ git submodule add git@github.com:crickets-and-comb/shared.git
  $ git commit -m "Add shared submod."
```

See https://git-scm.com/book/en/v2/Git-Tools-Submodules

### Initializing in a fresh clone

Once you've done that, or if this shared repo has already been added to a repo you're using but you're using a fresh clone of that repo, initialize this Git submodule:

```bash
  $ git submodule init
  $ git submodule update
```

See https://git-scm.com/book/en/v2/Git-Tools-Submodules

You'll need to `cd` into shared and checkout main, as it starts as a detached head, and that can cause problems with updating later with git submodule update. It's a good practice to just cd in shared and checkout and update the branch you want (typically main) directly, instead of using git submodule update.

### Setting tokens and keys

The shared workflows rely on a Personal Access Token (PAT) (to checkout this submodule so they can use the make targets). You need to create a PAT with repo access and add it to the consuming repo's action secrets as `CHECKOUT_SHARED`. See GitHub for how to set up PATs (hint: check the developer settings on your personal account) and how to add secrets to a repo's actions (hint: check the repo's settings).

Note: Using a PAT tied to a single user like this is less than ideal. Figuring out how to get around this is a welcome security upgrade.

And, if you want to use the workflow that auto-deletes PRs from outside your org, `block_outside_PRs.yml`, you need a secret named `ORG_READ_TOKEN` that has org read permissions.

Similarly, the workflow that runs QC, `CI.yml`, needs a key in the environment/secrets. To run the `safety` tool in the `security` make target, you need to register (for free) with Safety and get an API key: https://safetycli.com. You can use the key in two ways: by passing it to the `safety` command with the `--key` flag, or by adding it to your env as `SAFETY_API_KEY`. We do both, depending on which shared resource you're using and in what context. To use your key to run the workflow on GitHub, add it to your repo's secrets as `SAFETY_API_KEY`. To run the workflow locally, you need `SAFETY_API_KEY` in your env, in your `.env` file. This will work for running the `security` make target or `safety` locally, too, but you can also pass it to `make security` (after the command to use the var in the Makefile: `make security SAFETY_API_KEY=supersecretkey`).

### Docs deployment

We use `peaceiris/actions-gh-pages` to deploy docs to GitHub Pages (e.g., https://crickets-and-comb.github.io/reference_package/). You'll need to keep a branch on the remote called `gh-pages`.

## Usage

You can use this repo as a submodule to another repo in order to make use of the shared tools here. See the `Makefile` and `.github/workflows` in `reference_package` for example usage: https://github.com/crickets-and-comb/reference_package. This will show you how to make use of the dev tools in the shared Makefile, as well as CI/CD and other shared workflows.

See the setup section above, but once you've set up this submodule in your consuming repo, you'll want to periodically update it to get updates to the shared tools:

```bash
  $ git submodule update --remote --merge
```

This will update all Git submodules. To be more specific to shared, and perhaps more easy to remember, simple navigate into the shared subdirectory and pull:

```bash
  $ cd shared
  $ git checkout main
  $ git pull
```

Either way will pull the latest commit on the submodule's remote. Note that, while you'll be able to run with this updated shared submodule, you'll still want to commit that update to your consuming repo to track that update. After updating, you'll see an unstaged change in the submodule's commit hash that the consuming repo tracks:

```bash
$ git submodule update --remote --merge
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 2), reused 3 (delta 2), pack-reused 0 (from 0)
Unpacking objects: 100% (3/3), 1.49 KiB | 761.00 KiB/s, done.
From github.com:crickets-and-comb/shared
   c5be642..b8cc5aa  my/shared/branch -> origin/my/shared/branch
Updating c5be642..b8cc5aa
Fast-forward
 Makefile | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
Submodule path 'shared': merged in 'b8cc5aa3881af14404a491624c9251f4f774cefb'
$ 
$ 
$ git diff
diff --git a/shared b/shared
index c5be642..b8cc5aa 160000
--- a/shared
+++ b/shared
@@ -1 +1 @@
-Subproject commit c5be6421082ec103687282c1a12cf16d7968384a
+Subproject commit b8cc5aa3881af14404a491624c9251f4f774cefb
$ 
$ git add shared
$ git commit -m "Update shared submodule."
```

The shared repo contains dev tools that consuming repos depend on, namely reusable workflows (for running QC/tests and CI/CD on GitHub) and make recipes/targets for running QC/tests locally while developing.

Consuming Makefiles should point to the shared submodule as a subdirectory. But, consuming workflows should point to the shared reusable workflows via GitHub. You can point workflows at the shared workflows in the submodule directory (say for trying out uncommitted changes to a shared workflow) and run the workflows from `act` (see the `run-act` in the shared Makefile), but they will not run on the GitHub runners unless they point via GitHub (see `reference_package` for examples: https://github.com/crickets-and-comb/reference_package).

You can override shared make targets or add new targets that aren't in the shared Makefile by adding them to the consuming repo's top-level Makefile.

### Workflows: usage and limitations

The shared workflows (in `.github/workflows` or `shared/.github/workflows` from the consuming workflow) are reusable workflows, meaning they can can be called from within other workflows. See https://docs.github.com/en/actions/sharing-automations/reusing-workflows.

See also the `reference_package` `.github/workflows/test_install_dispatch.yml` workflow for an example: https://github.com/crickets-and-comb/reference_package. Here we've wrapped a single reusable workflow in another so we can dispatch it manually from the consuming repo.

While wrapping a single workflow for manual dispatch can be handy, you'll also want to wrap these shared workflows into a single workflow calling them in the desired order (QC/test, build, publish, test installation, deploy docs). See the `reference_package` `.github/workflows/CI_CD.yml` workflow for an example: https://github.com/crickets-and-comb/reference_package

#### Publishing to PyPi

Shared workflows are split into different aspects of CI/CD, but they don't cover all of them. Specifically, they don't cover publishing packages to PyPi. This is because PyPi doesn't allow trusted publishing from reusable workflows. See the `reference_package` `.github/workflows/CI_CD.yml` workflow for an example: https://github.com/crickets-and-comb/reference_package. Here we've defined publishing jobs within the same workflow that calls shared workflows to create a full CI/CD pipeline.

#### TEST_OR_PROD

Some of the workflows have a `TEST_OR_PROD` parameter. This is to control which aspects run. Some jobs and steps only run on `TEST_OR_PROD=test`, some only on `TEST_OR_PROD=prod`, some only on both, some no matter what. While the parameter defaults to "dev", this value does not enable anything in particular; it's just an unambiguous way to say neither "test" nor "prod". This is useful for avoiding deployment during development. For example, passing "dev" (or not "test" or "prod") skips uploading build artifacts to GitHub for later use, since attempting this locally with the `run-act` make target will fail (see `.github/workflows/build_dist.yml` and `Makefile`).

See the `reference_package` `.github/workflows/CI_CD.yml` workflow for an example of passing `TEST_OR_PROD`: https://github.com/crickets-and-comb/reference_package. Here we've set up the CI/CD pipeline to run on all pull requests (PRs), on pushes to main, and on manual dispatch. For pull requests, we only run QC, pre-publishing testing, and building (`TEST_OR_PROD=dev`). We don't want to publish any packages or documentation until the pull request has been approved and merged to main. On pushes to main (approved PRs), we run the same bits as PRs, and if those pass again, we run a test release to TestPyPi followed by a test installation (`TEST_OR_PROD=test`). The manual workflow_dispatch allows you to run from GitHub Actions with any parameters on any branch at any time. For instance, once you see that the test deployment succeeded and you're ready to release to PyPi and publish documentation to GitHub Pages, you then manually dispatch the workflow again with `TEST_OR_PROD=prod`.

#### Developing workflows

When developing the workflows themselves, you'll want to try them out locally before trying them on GitHub (which costs $ for every second of runtime). We use `act` and Docker to run workflows locally. Since `act` doesn't work with Mac and Windows architecture, it skips/fails them, but it is a good test of the Linux build.

You can use a make target for that:

```bash
  $ make run-act
```

That will run `.github/workflows/CI_CD.yml`. But, you can also run any workflow you'd like by using `act` directly. See https://nektosact.com.

To use this tool, you'll need to have Docker installed and running on your machine: https://www.docker.com/. You'll also need to install `act` in your terminal:

```bash
  $ brew install act
```

NOTE: To be more accurate `run-act` copies `CI_CD.yml` to `CI_CD_act.yml` and runs it. It does this so you can optionally override `set-CI-CD-file` to update the CI-CD file run by `act`. This is useful if you've overriden another shared make target (e.g., `full-test`), because `act` will not honor *that* override and will use the shared version of it if you use the GitHub URL to call a shared workflow that uses the target. You'll need to use the relative path to call the workflow.

So, for instance, if you have overridden `full-test` in your consuming repo's `Makefile`

```
export
include shared/Makefile

full-test: # Run all the tests. (NOTE: this means running `run-act` requires switching the path to the shared CI workflow to a relative path in CI_CD_act.yml.)
	$(MAKE) unit
```

and you have this job in your `CI_CD.yml`:

```YML
jobs:
  CI:
    name: QC and Tests
    uses: crickets-and-comb/shared/.github/workflows/CI.yml@main
    secrets: inherit
```

You will need to change it to this in `CI_CD_act.yml`:

```YML
jobs:
  CI:
    name: QC and Tests
    uses: ./shared/.github/workflows/CI.yml
    secrets: inherit
```

This is because `shared/.github/workflows/CI.yml` calls the `full-test` make target, which you've overridden in this hypothetical.

Note also that, GitHub actions will fail if it sees a workflow using relative paths for workflow calls. This means that you will need to add `CI_CD_act.yml` to `.gitignore`.

You may want to use GitHub to test out the changes you pushed to the shared branch you're developing in. To checkout the right commit of the shared submodule when testing a workflow on GitHub, you'll need to check a few things. First, make sure you have the branch set in your consuming repo's `.gitmodules` file. Second, make sure you've committed, in the consuming repo, the commit hash you're testing of the shared repo submodule. Thirdly, make sure the workflow call URLs are set to the dev branch like  `crickets-and-comb/shared/.github/workflows/CI.yml@dev-branch`.

It's tricky developing shared workflows, but if you're just developing the consuming repo's package itself, you shouldn't need to even use `run-act`. The `full*` make targets in `Makefile` should suffice. They will run on your local machine without Docker and will look in your shared submodule without any special direction.

## Matrix build and support window

We run test workflows on a matrix of Python versions and OS versions.

While we run installation tests on Ubuntu, macOS, and Windows to ensure published packages work on all three, we run pre-publishing QC only on Ubuntu and macOS. The reason for this is that QC uses our dev tools and we don't yet support dev on Windows. Supporting Windows dev tools may only require a simple set of changes (e.g., conditionally setting filepath syntax), and is a welcome upgrade on the list of TODOs.

We run QC and installation tests on a Python matrix as well (3.11 - 3.13 at time of writing). We set this matrix based on the Scientific Python SPEC 0 support window https://scientific-python.org/specs/spec-0000/#support-window. This support window includes common packages for scientific computing (e.g., `numpy` and `pandas`), and we recommend keeping relevant dependencies pinned within this support window when consuming these shared tools.

See `.github/workflows/CI.yml` and `.github/workflows/test_install.yml`.

## Acknowledgement

To start this repo, I borrowed, modified, and added to some of the idiomatic structure and tools of IHME's Central Computation GBD team from when I worked with them in 2022-2024.