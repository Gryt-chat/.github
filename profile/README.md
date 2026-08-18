<p align="center">
  <img src="https://raw.githubusercontent.com/Gryt-chat/client/main/public/logo.svg" width="88" alt="Gryt" />
</p>

<h1 align="center">Gryt</h1>

<p align="center">
  Voice and text chat you host yourself.<br />
  Your server, your hardware, your conversations.
</p>

<p align="center">
  <a href="https://github.com/Gryt-chat/gryt/releases"><img src="https://img.shields.io/github/v/release/Gryt-chat/gryt?include_prereleases&style=flat-square&label=release&color=968FF8" alt="Latest release" /></a>
  <a href="https://github.com/Gryt-chat/gryt"><img src="https://img.shields.io/github/stars/Gryt-chat/gryt?style=flat-square&color=968FF8" alt="Stars" /></a>
  <a href="https://github.com/Gryt-chat/gryt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-968FF8?style=flat-square" alt="AGPL-3.0" /></a>
</p>

<p align="center">
  <a href="https://gryt.chat">Website</a> ·
  <a href="https://app.gryt.chat">Try it</a> ·
  <a href="https://docs.gryt.chat">Docs</a> ·
  <a href="https://github.com/Gryt-chat/gryt/releases">Download</a>
</p>

---

### Why

Most voice platforms are owned by companies that monetise the conversation and
decide who gets to leave. Gryt is built the other way round — you run the
server, the data sits on your disk, and nobody needs an account with us to talk
to you.

<table>
<tr>
<td width="50%" valign="top">

**No account required**

A server chooses which identities it admits. Guests hold a keypair on their own
device. An account carries your identity *between* servers — it is not the price
of entry.

</td>
<td width="50%" valign="top">

**Real-time voice**

Go and Pion WebRTC relay audio without transcoding. Noise suppression, echo
cancellation and voice activity detection run on the client.

</td>
</tr>
<tr>
<td valign="top">

**Yours to run**

Docker Compose, Helm, or a Cloudflare Tunnel. One compose file can host as many
servers as you like — they share an SFU.

</td>
<td valign="top">

**Desktop and web**

Electron app for Linux, macOS and Windows with auto-updates, plus a browser
client. The desktop app can host a server on its own.

</td>
</tr>
<tr>
<td valign="top">

**Files and messages**

Persistent chat backed by SQLite, uploads to any S3-compatible store, and
thumbnails generated out of process so a bad image cannot take the server down.

</td>
<td valign="top">

**Open about how it is built**

Gryt is developed partly with AI assistance. The
[policy](https://docs.gryt.chat/docs/guide/ai) says which parts of the codebase
never merge without a human reading the whole diff.

</td>
</tr>
</table>

---

### Get started

```bash
git clone --recurse-submodules https://github.com/Gryt-chat/gryt.git
cd gryt && ./ops/start_dev.sh
```

Or read the [deployment guide](https://docs.gryt.chat/docs/deployment/docker-compose)
to put it on a real machine.

### Repositories

| | | |
|---|---|---|
| [`gryt`](https://github.com/Gryt-chat/gryt) | Monorepo, ops, releases | Shell |
| [`client`](https://github.com/Gryt-chat/client) | Desktop and web app | React · Electron |
| [`server`](https://github.com/Gryt-chat/server) | Signalling, chat, uploads | Node · Socket.IO |
| [`sfu`](https://github.com/Gryt-chat/sfu) | Media relay | Go · Pion |
| [`voice`](https://github.com/Gryt-chat/voice) | Voice engine shared by the apps | TypeScript |
| [`auth`](https://github.com/Gryt-chat/auth) | Accounts, optional | Keycloak |
| [`image-worker`](https://github.com/Gryt-chat/image-worker) | Thumbnails | Sharp |
| [`cli`](https://github.com/Gryt-chat/cli) | Terminal server manager | Go · Bubble Tea |
| [`ui`](https://github.com/Gryt-chat/ui) · [`docs`](https://github.com/Gryt-chat/docs) · [`site`](https://github.com/Gryt-chat/site) | Components, docs, landing page | |

> [!NOTE]
> Gryt is in beta. Breaking changes happen between releases.

### Sponsors

<!-- sponsors:start -->
<!-- Monthly sponsors only, which is what the $25 and $500 tiers promise. A
     one-off payment is credited in the release notes and listed on
     gryt.chat/sponsors, not here. -->

Nobody sponsoring monthly yet.

<!-- sponsors:end -->

What sponsoring pays for, the tiers, and everyone who has sponsored:
[gryt.chat/sponsors](https://gryt.chat/sponsors) ·
[Sponsor Gryt](https://github.com/sponsors/Gryt-chat)

<p align="center">
  <sub>AGPL-3.0 · Built in Norway · <a href="https://docs.gryt.chat/docs/guide/contributing">Contributing</a></sub>
</p>
