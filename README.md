# slackm8

_slackm8_ will randomly shuffle a team into a specific amount of groups & invite members to the respective Slack channels.
Written in [Elm](http://elm-lang.org/).

![alt tag](https://github.com/fpapado/slackm8/blob/master/docs/old/slackm8.png)

## Deployment
Simply run:
```shell
git clone git@github.com:fpapado/slackm8.git
cd slackm8
yarn
yarn run build

# OR if you use npm
# npm install
# npm run build
```
This will pull the repo, install dependencies, and bundle and minify the scripts/html/assets from `src/` into `dist/`.

Deploy the `dist/` directory with your favourite host/server/service.

## Development
There is a compilation step from Elm into JS, and then a bundling step; these are both handled by Webpack with `src/index.js` as the entry point and `src/index.html` as the shell.

In order to run the project locally:
```shell
git clone git@github.com:fpapado/slackm8.git
cd slackm8
yarn
yarn run duv

# OR if you use npm
# npm install
# npm run dev
```
Browse to `localhost:3000` and you're set!
Webpack should handle Hot Module Replacement or reloadin gas you develop

Any additions to Elm files under `src/` should be picked up automatically by the loader. You can change the Elm source directory in `elm-package.json`.

NOTE: You could very well use `elm-make` or anything else you want. Just change the build scripts in `package.json` :)

## Slack API authorization test token
The application uses the *Legacy Slack Tester tokens*. One of the aims of the fork is to investigate the use of the more recent Slack tokens/API, but these will suffice for now.

You should be an admin of the team in question, and create create an API legacy tester token here: [https://api.slack.com/custom-integrations/legacy-tokens](https://api.slack.com/custom-integrations/legacy-tokens)

NOTE: These tokens have a number of scopes automatically, listed in the link above. If the user is admin, it also has the admin scope.
Thus, it is best to create and keep this token safe, and run the application if you are an admin yourself.

This will allow _slackm8_ to make 3 types of http requests to your slack team.

* [users.list](https://api.slack.com/methods/users.list): Listing existing users
* [channels.create](https://api.slack.com/methods/channels.create): Creating a channel
* [channels.invite](https://api.slack.com/methods/channels.invite): Inviting a User to a Channel

_slackm8_ will store your test token as 'slackm8Model' in localStorage along with the rest of the model. Your token is only accessed from localStorage or the model directly.

## Acknowledgements
This is a fork by [@fpapado](https://github.com/fpapado), for Elm 0.18 and any other changes I might want to make.

The initial Elm 0.17 application was created by [@chrisbuttery](https://github.com/chrisbuttery), and the original README & acknowledgements are preserved at `docs/old/`.

I'm not a huge fan of how Github handles forks, but I still prefer it to creating a new repository.
