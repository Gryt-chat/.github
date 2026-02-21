<h3 align="center">
 <img src="owl-9.svg" width="100" alt="Logo"/><br/>
 <img src="" alt="" height="32" width="0px"/>
 Gryt Chat
 <img src="" alt="" height="32" width="0px"/>
</h3>

<p align="center">
Gryt is an open-source text-, voice- and video-chat platform that values privacy and user control of data. With Gryt, users have the ability to host their own servers, allowing them to have full control over their conversations and data. Gryt is a secure and private communication platform that empowers users to communicate freely while protecting their privacy.
</p>

<p align="center">
 <a href="https://github.com/Gryt-chat/gryt/blob/main/LICENSE">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License"/>
 </a>
 <a href="https://github.com/Gryt-chat/gryt">
  <img src="https://img.shields.io/github/stars/Gryt-chat/gryt?style=flat-square&color=yellow" alt="Stars"/>
 </a>
 <a href="https://github.com/Gryt-chat/gryt/pulls">
  <img src="https://img.shields.io/github/issues-pr/Gryt-chat/gryt?style=flat-square&color=green" alt="Pull Requests"/>
 </a>
 <a href="https://github.com/Gryt-chat/gryt/issues">
  <img src="https://img.shields.io/github/issues/Gryt-chat/gryt?style=flat-square&color=red" alt="Issues"/>
 </a>
</p>

<p align="center">
 <a href="https://gryt.chat">Website</a> ·
 <a href="https://github.com/Gryt-chat/gryt">Source Code</a> ·
 <a href="https://github.com/Gryt-chat/gryt/issues/new?template=bug_report.md">Report a Bug</a> ·
 <a href="https://github.com/Gryt-chat/gryt/issues/new?template=feature_request.md">Request a Feature</a>
</p>

---

### Why Gryt?

Most communication platforms today are owned by corporations that monetize your conversations, lock you into their ecosystem, and give you zero control over where your data lives. **Gryt exists to change that.**

- **Self-hostable** — Run your own server. Your data stays on your hardware.
- **Open source** — Every line is auditable. No telemetry, no tracking, no surprises.
- **Full-featured** — Crystal-clear voice chat, persistent text messaging, file sharing — all in one platform.
- **Modern stack** — Built with TypeScript, React, Go, and WebRTC for real-time performance.

---

### What's Inside

<table>
<tr>
<td width="50%" valign="top">

**Core Platform** — [`WebSocket-Voice`](https://github.com/Gryt-chat/gryt)

The main monorepo containing everything you need:

| Component | Built With |
|-----------|-----------|
| Web Client | React · TypeScript · Vite |
| Signaling Server | Bun · Socket.IO · ScyllaDB |
| SFU (Media Server) | Go · Pion WebRTC |
| Auth | Keycloak |
| Docs | Next.js · Fumadocs |

</td>
<td width="50%" valign="top">

**Deployment Options**

| Method | Best For |
|--------|----------|
| Docker Compose | Quick self-hosting |
| Helm Chart | Kubernetes clusters |
| Dev Scripts | Local development |

Get started in one command:

```bash
git clone https://github.com/Gryt-chat/gryt.git
cd WebSocket-Voice && ./start_dev.sh
```

</td>
</tr>
</table>

---

### Features

<table>
<tr>
<td width="33%" align="center">
<h4>Voice & Video</h4>
<p>WebRTC-powered real-time audio with noise suppression, echo cancellation, voice activity detection, and a configurable audio pipeline.</p>
</td>
<td width="33%" align="center">
<h4>Text & Files</h4>
<p>Persistent messaging backed by ScyllaDB with file uploads, image thumbnails, and S3-compatible object storage.</p>
</td>
<td width="33%" align="center">
<h4>Multi-Server</h4>
<p>Connect to multiple self-hosted servers simultaneously and switch between them seamlessly from a single client.</p>
</td>
</tr>
<tr>
<td width="33%" align="center">
<h4>Privacy First</h4>
<p>Self-host everything. Your messages, files, and voice data never touch a third-party server unless you choose to.</p>
</td>
<td width="33%" align="center">
<h4>Modern UI</h4>
<p>Clean, accessible interface built with Radix UI. Dark and light themes, responsive layout, desktop app support via Electron.</p>
</td>
<td width="33%" align="center">
<h4>Easy Deployment</h4>
<p>Docker Compose for quick setups, Helm charts for Kubernetes, and comprehensive docs to guide you through production deployment.</p>
</td>
</tr>
</table>

---

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │    │  Gryt Server    │    │   SFU Server    │
│   (React/TS)    │◄──►│  (Bun/Node.js)  │◄──►│     (Go)        │
│                 │    │                 │    │                 │
│ • Voice UI      │    │ • Signaling     │    │ • Media Relay   │
│ • Audio Proc.   │    │ • Persistence   │    │ • WebRTC        │
│ • Multi-Server  │    │ • File Uploads  │    │ • Track Mgmt    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                      │                      │
         │              ┌───────┴───────┐              │
         │              │   ScyllaDB    │              │
         │              │   + MinIO/S3  │              │
         │              └───────────────┘              │
         │                                             │
         └──────────── WebRTC Media (UDP) ─────────────┘
```

---

### Contributing

We welcome contributions of all kinds — code, documentation, bug reports, and feature ideas.

1. **Fork** the repo and create your branch from `main`
2. **Make** your changes and ensure tests pass
3. **Open** a pull request with a clear description of what you've done

Check out the [issue tracker](https://github.com/Gryt-chat/gryt/issues) for open issues, or create a [feature request](https://github.com/Gryt-chat/gryt/issues/new?template=feature_request.md) if you have an idea.

---

<p align="center">
 <sub>Made with care by the Gryt community · Licensed under <a href="https://github.com/Gryt-chat/gryt/blob/main/LICENSE">MIT</a></sub>
</p>
