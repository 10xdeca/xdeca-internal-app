# CLAUDE.md

This is an internal team app for XDECA. Not a public app.

## Project Overview

- **Package ID**: `com.xdeca.internal`
- **Flutter app** for iOS and Android
- Distributed via TestFlight (iOS) and Play Store internal testing (Android)

## Features

1. **Team Activity Log** - Fetches and displays entries from a GitHub-hosted `team.log` file with background sync and push notifications
2. **Meeting Recorder** - Records audio, transcribes with OpenAI Whisper, uploads to Outline wiki (wiki.xdeca.com)

## Deployment

CI/CD is automated via GitHub Actions. To deploy a new version:

```bash
git tag v1.0.XX
git push origin v1.0.XX
```

This automatically builds and deploys to:
- iOS: TestFlight (auto-available to testers)
- Android: Play Store internal track (auto-rolls out to testers)

## Key Files

- `lib/main.dart` - App entry point, team log viewer, navigation
- `lib/screens/meeting_recorder_screen.dart` - Meeting recorder with Whisper integration
- `lib/services/transcription_service.dart` - OpenAI Whisper API
- `lib/services/outline_service.dart` - Outline wiki API
- `.github/workflows/deploy.yml` - CI/CD deployment workflow

## Secrets (GitHub Actions)

### iOS
- `IOS_CERTIFICATE_BASE64` - Distribution certificate (.p12)
- `IOS_CERTIFICATE_PASSWORD` - Certificate password
- `IOS_PROVISIONING_PROFILE_BASE64` - App Store provisioning profile
- `KEYCHAIN_PASSWORD` - Temporary keychain password
- `APP_STORE_CONNECT_API_KEY` - App Store Connect API key (.p8 contents)
- `APP_STORE_CONNECT_KEY_ID` - API key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID

### Android
- `KEYSTORE_BASE64` - Upload keystore (.jks)
- `KEYSTORE_PASSWORD` - Keystore password
- `KEY_PASSWORD` - Key password
- `KEY_ALIAS` - Key alias
- `GOOGLE_PLAY_SERVICE_ACCOUNT` - Service account JSON

## App Configuration

Users configure in-app settings:
- **OpenAI API Key** - For Whisper transcription ($0.006/min)
- **Outline URL** - Wiki instance (default: https://wiki.xdeca.com)
- **Outline API Token** - Generated in Outline settings
- **Collection** - Where to save meeting transcripts
