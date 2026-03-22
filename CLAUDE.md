# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShadowClone - AI残像カメラ** is an iOS camera app that creates afterimage (残像) / shadow clone effects on videos using Apple's Vision framework for real-time person segmentation. Users can either record live camera footage or import existing videos, and the app composites multiple person silhouettes over time to produce a trailing shadow clone effect.

- **Bundle ID:** `toshihide.matsuda.ShadowClone`
- **Min iOS:** 15.0
- **App Store:** https://apps.apple.com/jp/app/shadowclone-ai残像カメラ/id6443941131
- **Privacy Policy:** `docs/privacy-policy.html` (GitHub Pages)

## Architecture

MVC pattern with singleton Manager classes:

- **ViewControllers:** `ViewController` (home), `CameraViewController` (live capture), `VideoViewController` (video processing), `CompositImageViewController` (base class for image composition)
- **Managers:** `AVCaptureManager` (camera/audio I/O singleton), `VisionManager` (person segmentation singleton)
- **Utilities:** `AppUtil` (device detection), `CIImage+extends` (image processing), `AVAsset+extension`, `CMSampleBuffer+CVImageBuffer`
- **ObjC Bridge:** `ObjcUtil` for hardware name detection via `sysctlbyname`

## Build & Run

This project uses CocoaPods. After cloning:

```bash
cd /path/to/AfterImage
pod install
open ShadowClone.xcworkspace
```

Always open the `.xcworkspace` (not `.xcodeproj`).

### Dependencies (CocoaPods)

- `Toast-Swift` (~> 5.0.0) - Toast notification UI

## Key Technical Details

### Person Segmentation Pipeline

1. Capture video frame → `CVPixelBuffer` → `CIImage`
2. `VisionManager.personImage()` extracts person mask via `VNGeneratePersonSegmentationRequest`
3. Background removal using `CIBlendWithMask` filter
4. Frame queue maintains N previous person silhouettes (configurable via `queueSize`)
5. Composite all frames using `CISourceOverCompositing` filter chain
6. Display result on `AVPlayerLayer`

### Threading Model

- **Main thread:** UI updates only
- **videoOutputQueue:** Video frame capture processing
- **cameraSaveQueue:** Writing video buffers to file
- **videoQueue/audioQueue:** Used in `VisionManager.applyProcessingOnVideo()` for file-based video processing

### Settings

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Interval | 0.1–3.0s | 0.1s | Time between adding frames to composition queue |
| Clone Count | 2–10 | 10 | Number of afterimage frames to maintain |
| AI Quality | accurate/balanced/fast | balanced | `VNGeneratePersonSegmentationRequest.QualityLevel` |

### Pixel Format

The app negotiates pixel format at startup: prefers `kCVPixelFormatType_OneComponent32Float` (requires Neural Engine / A11+), falls back to `kCVPixelFormatType_32BGRA`.

### Video Recording (Camera mode)

- Frame rate: 20 FPS (hardcoded)
- Preset: `.high` (1920x1080)
- Output: HEVC or H.264 `.mp4`
- Audio: Linear PCM capture → AAC output

### Camera Switching

`AVCaptureManager.initializeCamera()` creates fresh `AVCaptureVideoDataOutput` and `AVCaptureAudioDataOutput` instances on each call to prevent state leakage between sessions. The previous session is fully torn down before creating a new one.

## Localization

10 languages supported: ja, en, en-AU, en-GB, en-IN, es, es-419, fr, fr-CA, zh-Hans.
String files at `Resources/[lang].lproj/Localizable.strings`. Use `NSLocalizedString()` for all user-facing strings.

## File Structure

```
AfterImage/
├── AppDelegate.swift           # App lifecycle
├── SceneDelegate.swift         # Scene lifecycle, global state & helpers
├── ViewController.swift        # Home screen
├── CameraViewController.swift  # Live camera recording
├── VideoViewController.swift   # Video file processing
├── CompositImageViewController.swift  # Base composition logic
├── AVPlayerLayerView.swift     # Custom video display view
├── Manager/
│   ├── AVCaptureManager.swift  # Camera/audio I/O singleton
│   └── VisionManager.swift     # Vision framework singleton
├── Util/
│   ├── AppUtil.swift           # Device detection
│   ├── CIImage+extends.swift   # Image processing extensions
│   ├── AVAsset+extension.swift # Video asset helpers
│   └── CMSampleBuffer+CVImageBuffer.swift
├── Base.lproj/
│   ├── Main.storyboard         # Main UI (UIKit)
│   └── LaunchScreen.storyboard
└── docs/
    └── privacy-policy.html     # Privacy policy (GitHub Pages)
```

## Coding Conventions

- UI is UIKit-based (Storyboard + programmatic styling)
- Singletons accessed via `.shared` pattern
- Japanese comments are common throughout the codebase
- Global functions and constants are declared in `SceneDelegate.swift` (e.g., `requestAppStoreReview()`)
- `ciContext` is a global `CIContext` instance for image processing

## Common Pitfalls

- Always use `.xcworkspace`, not `.xcodeproj`
- `ObjcUtil` requires the bridging header (`AfterImage-Bridging-Header.h`)
- Camera orientation handling differs between iPhone (portrait only) and iPad (all orientations)
- Video frames skip the first few frames in camera recording to avoid dark frames during camera initialization
