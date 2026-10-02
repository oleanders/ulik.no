# ulik.no

Terminal-inspirert hjemmeside for AI-eksperimenter, små prosjekter og digitale sidespor på ulik.no

## Creating a project

If you're seeing this, you've probably already done this step. Congrats!

```sh
# create a new project
npx sv create my-app
```

To recreate this project with the same configuration:

```sh
# recreate this project
bun x sv@0.15.3 create --template minimal --types ts --install bun .
```

## Developing

Once you've created a project and installed dependencies with `npm install` (or `pnpm install` or `yarn`), start a development server:

```sh
npm run dev

# or start the server and open the app in a new browser tab
npm run dev -- --open
```

## Building

To create a production version of your app:

```sh
npm run build
```

You can preview the production build with `npm run preview`.

> To deploy your app, you may need to install an [adapter](https://svelte.dev/docs/kit/adapters) for your target environment.

## Pull request previews

`Firebase PR preview` builds every opened, updated or reopened PR. For same-repository
PRs, it publishes the static build to channel `pr-<number>` on the existing
`beta-ulik-no` Hosting site in project `eidjord`, using the existing `GCP_SA_KEY`
secret. It never deploys to a live channel. The Firebase action maintains its standard PR comment with the
public test URL, commit and expiry after a successful deployment. Channels expire
7 days after their last deployment, including after a PR is closed.

The build job receives no Firebase secrets. A fresh deployment runner downloads
only the static build and uses a fixed, beta-only configuration; it does not
execute PR code or read the PR's Firebase configuration. Fork and Dependabot PRs
are built but skip deployment and commenting. No extra credentials are created. A current-head check skips outdated builds; if a
new commit arrives during deployment, the comment labels the deployed commit and
the next serialized run refreshes it.

This workflow can preview its own PR. To enable it for the other open PRs, merge
this workflow first, then update those branches from `main` (or reopen the PRs
once their merge result contains the workflow). A PR build/deploy failure leaves
the previous successful preview and its commit-labelled comment in place.

References: [Firebase previews](https://firebase.google.com/docs/hosting/github-integration),
[Hosting deploy action](https://github.com/FirebaseExtended/action-hosting-deploy),
[GitHub PR events and fork restrictions](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request).
