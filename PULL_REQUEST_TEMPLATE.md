## What does this change?

<!-- A short description of the change and why it's needed. -->

## AI disclosure

AI assistance is allowed anywhere in Gryt, as long as it's disclosed. Some areas
are audited more critically — the SFU, authentication and identity code, the
client's key handling, the image worker and the data layer are read line by line
before anything merges. Full details and the exact paths:
https://docs.gryt.chat/docs/guide/ai

- [ ] This PR contains AI-assisted code
- [ ] This PR touches a review-required path (expect a slower, closer review)

## Checklist

- [ ] Tests pass (`yarn test`, `go test ./...`)
- [ ] Code is linted (`yarn lint`, `go fmt ./...`)
- [ ] Documentation is updated if needed
- [ ] No breaking changes (or clearly marked)
