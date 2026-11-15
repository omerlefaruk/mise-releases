# Mise for Windows

Official download and update repository for Mise. The application source repository is separate and private.

## Install

1. Download `Mise-Setup-<version>.exe` from https://misecloud.cloud, https://omerlefaruk.github.io/mise-releases/ or the latest release at https://github.com/omerlefaruk/mise-releases/releases/latest.
2. Run it. No admin rights are needed. Mise is unsigned, so Windows may show "Windows protected your PC". Click More info, then Run anyway. Get Mise only from these locations, and never turn off Windows security or antivirus.
3. Your browser opens. Sign in to your Mise account and approve the PC. Sign-up needs an invite code.

Mise needs Windows 10 or later on a 64-bit PC.

## Use

Mise runs in the background on your PC and starts when you sign in to Windows. You use it in your browser at https://api.misecloud.cloud. Claude Code, Codex, Claude Desktop and Pi on the PC connect to Mise automatically. The `mise` command is available in a new terminal.

Your projects and media stay on your PC. Mise cloud keeps your account and linked PCs, and passes requests between your browser or AI tools and your PC. Read https://omerlefaruk.github.io/mise-releases/privacy.html before you send sensitive content to an external provider.

## Updates

Each release has the installer, `mise-service.json`, the app archive and the packages archive. Installed Mise reads `mise-service.json` from the latest release every few hours, checks each file by SHA-256 and switches to the new version when no work is running. If the new version does not start correctly, Mise goes back to the previous one. The files are unsigned; checksums find damaged files but do not prove the publisher.

Releases up to 0.0.13 are the older desktop application. It does not update to 0.1.0 by itself. Uninstall the older app first, then install 0.1.0 with the installer. Your projects are kept.

## Uninstall

Open Settings › Apps › Installed apps › Mise › Uninstall. Your projects and settings in the `.mise` folder are kept.

## Support

Use this repository's issue tracker for non-sensitive installation and update questions. Never post credentials, private project content or personal reference media in a public issue.
