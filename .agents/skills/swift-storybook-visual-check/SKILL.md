---
name: swift-storybook-visual-check
description: "Launch and visually verify an exact StorybookKit page in a host app on an iOS Simulator, then capture screenshot evidence. Use after UI changes, when inspecting a SwiftUI preview or BookPage, or when duplicate page names require source-file and line qualifiers."
---

# Swift Storybook Visual Check

Use the standard Storybook launch contract to open one page, verify the rendered UI, and capture evidence.

## Confirm the host adapter

Before launching, confirm that the host app handles Storybook arguments during startup and replaces its normal root with Storybook. The package defines the launch contract, but each host must connect that contract to its app lifecycle and include StorybookKit in the selected build configuration.

If the adapter is absent, stop and report that prerequisite. Do not claim that launch arguments alone can change an unintegrated app.

## Select the page

Use these arguments:

```text
--storybook
--storybook <name>
--storybook --storybook-name=<name>
--storybook <name> --storybook-fullscreen
--storybook <name> --storybook-file <fileID>
--storybook <name> --storybook-file <fileID> --storybook-line <line>
--storybook <name> --storybook-fullscreen --storybook-file <fileID> --storybook-line <line>
```

- Use `--storybook` alone only when the catalog is the requested result.
- Pass the page name as the positional value immediately after `--storybook`.
- Add `--storybook-fullscreen` after the page name to verify an iOS/iPadOS preview without Storybook's navigation presentation. On Mac Catalyst, the argument falls back to ordinary push navigation; the floating control and **Open Fullscreen** catalog action are not available.
- For an empty or hyphen-led name, pass one exact argument in the form
  `--storybook-name=<name>` after `--storybook`.
- Treat `<fileID>` as the compiler source identifier, commonly `Module/Path/File.swift`.
- Treat `<line>` as the preview declaration's positive source line number.

Selection is exact. Do not guess, fuzzy-match, or choose the first duplicate. Start with the name when it is known to be unique. If Storybook reports not found or ambiguous, read the displayed or logged candidates and retry with the exact file, then the line when needed. Preserve argument values as distinct launch-argument entries so spaces in names remain intact.

## Launch and verify

1. Select a simulator-compatible debug build whose host adapter includes StorybookKit.
2. Build and install the host app with the available build tooling.
3. Boot or select a simulator and launch the installed app with the chosen arguments using the available device tooling.
   Preserve scheme-provided inherited arguments when the tooling exposes that option.
4. Wait for the UI to settle, then inspect the view or accessibility hierarchy.
5. Verify the opened page's identifier has the exact form
   `storybook.page|<name-byte-count>:<name>|<fileID-byte-count>:<fileID>|<line>`.
   Both byte counts are UTF-8 byte counts. This source-qualified marker proves
   that another same-name page did not open.
6. Verify that the requested page is visible and that no not-found, ambiguous-selection, invalid-request, crash, or normal-app startup screen replaced it. A launch diagnostic exposes `storybook.launch.failure` instead of a page identifier and lists each corrected launch argument as a separate selectable row.
7. Inspect the rendered UI for the requested change, including clipping, overlap, missing content, unexpected loading state, and incorrect presentation.

Use the host's own scheme, bundle identifier, and supported simulator. Do not assume a particular repository, Xcode integration, command wrapper, or device-control tool.

## Navigation, toolbar, and fullscreen checks

Viewport exports call `makeViewPortPreview()` and render a preview factory
directly, without running `BookPageDestination` or UIKit's `fullScreenCover`.
They cannot verify a preview-owned `NavigationStack`, navigation toolbars,
fullscreen presentation, Storybook chrome suppression, or controller/modal
presentation. For those behaviors, launch the qualified page with
`--storybook-fullscreen` in a live Simulator, inspect the hierarchy, and
exercise the relevant interaction. Use viewport exports only for isolated
content and layout checks.

For fullscreen return-flow checks on iOS/iPadOS, use the floating control
identified by `storybook.fullscreen.menu`. No custom host window or UIKit
scene-delegate setup is required. Open a catalog row's context menu and select
**Open Fullscreen** so the test can verify that search and list navigation state
survive returning. Search for `e`, scroll the results, then open **Open
Fullscreen** while the catalog search field is active. Verify the query and
scroll position remain, catalog editing ends, and Preview-owned input can still
autofocus. Drag the control from its lower-trailing starting position, release
with velocity toward each horizontal edge, and catch it while its spring is in
flight. Touch and scroll outside the control to verify pass-through behavior.
The control avoids a docked keyboard but does not move around a floating or
undocked keyboard.

Tap the control and verify the native action sheet. If UIKit shows **Cancel**,
choose it; otherwise dismiss outside. Either dismissal must preserve the same
Preview and its state. Choose **Return to Catalog** while a Preview-owned
presentation is open and verify the catalog returns. Also focus a Preview text
field and test native editing/Undo; the floating control must not take
first-responder status or interrupt input.
Viewport exports cannot cover these interactions.

For safe-area checks, launch `Fullscreen Safe Area Plain` and verify its indigo
background reaches the display edges while both labels remain inside the safe
area. Then launch `Fullscreen Safe Area Navigation Stack`, check the teal root,
push detail, and verify the pink detail background, safe-area labels, back
navigation, and toolbars. These fixtures are appended after the existing
line-58 and line-80 selectors.

## Capture evidence

For isolated content and layout checks, prefer a viewport artifact when the host
supports it: it excludes Storybook chrome, fits a root `ScrollView` to full
height, and exports a
`UIViewController` as its whole presented window (`renderMode:
presentedViewController`). Launch a fully qualified page with:

```text
--storybook <name> --storybook-file <module/file.swift> --storybook-line <line>
--storybook-render viewport --storybook-export-id <safe-id> --storybook-appearance light|dark
```

Retrieve `image.png` and `manifest.json` from
`Library/Application Support/StorybookViewportExports/<id>` through
`simctl get_app_container … data`; verify selector, render mode, appearance,
dimensions, and SHA-256. For this demo, use
the host's simulator tooling directly. Remove transient menus, keyboards,
touch markers, and unrelated system overlays before a controller presentation
is rendered. Its Simulator screenshot is diagnostic-only.

Otherwise, verify the hierarchy first, remove transient menus, keyboards,
touch markers, and unrelated system overlays when possible, then capture a
clean simulator screenshot to a stable path. Never use clipboard or
photo-library transport; end any interaction session before reporting.

## Fail honestly

Do not silently fall back to the catalog, another matching page, or a build-only result. If the build, host adapter, simulator launch, exact resolution, hierarchy verification, or screenshot capture fails, report the failed stage and the concrete diagnostic. State plainly when no trustworthy screenshot was produced.
