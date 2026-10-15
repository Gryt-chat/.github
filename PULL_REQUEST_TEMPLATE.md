## What does this change?

<!-- A short description of the change and why it's needed. Link the issue if there is one. -->

## How did you test it?

<!-- What you ran or clicked, and on which platform. "It builds" and "CI passes" don't count. -->

## AI and responsibility

AI assistance is allowed anywhere in Gryt, as long as you say so. Some areas get a closer look: the SFU, authentication and identity code, the client's key handling, the image worker, the reports endpoint and the data layer are read line by line before anything merges. Details and the exact paths: https://docs.gryt.chat/docs/about/ai

- [ ] This PR contains AI-assisted code
- [ ] I've read every line of this PR, I can explain any of it, and I'm responsible for it
- [ ] This PR touches a review-required path (expect a slower, closer review)

<!-- If you used AI, which tool, and what did it do? Wrote it, wrote parts, wrote the tests, reviewed it? -->

## Checklist

- [ ] I've signed the [CLA](https://github.com/Gryt-chat/.github/blob/main/CLA.md), or I'm in the Gryt-chat organisation
- [ ] Under about 300 changed lines, or there's an issue we agreed on first: #
- [ ] No new dependencies or vendored code, or they were agreed on an issue
- [ ] Tests and linting pass (`yarn test`, `yarn lint`, `go test ./...`, `go fmt ./...`)
- [ ] Documentation is updated if needed
- [ ] No breaking changes, or they're clearly marked
