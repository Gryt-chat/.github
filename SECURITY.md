# Reporting a security problem

If you've found a security problem in Gryt, email **sivert@gryt.chat**. Please don't open a public issue or pull request for it. Everybody running a Gryt server would see it before they had a chance to update.

The full policy is at [gryt.chat/security](https://gryt.chat/security). It covers what's in scope, what isn't, and what you can expect back.

## What to send

Enough to reproduce it: what you did, what happened, what you expected, and which version or address you were on. A rough note is fine. If you're not sure it counts, send it anyway.

Test against a server you run yourself rather than somebody else's. [Setting one up](https://gryt.chat/self-hosting) takes a few minutes.

## Which versions get fixes

The newest release. Each part of Gryt is released from its `main` branch, and there are no older branches that fixes get backported to.

## What happens after

Gryt is maintained by one person, so there's no promised response time. Anything being exploited, or anything that exposes other people's messages, goes ahead of everything else.

Once a fix is out, the problem gets a security advisory on the repository the fix is in. There's no bug bounty. If you'd like credit, you get it in the advisory, the release notes and the commit.
