# AI Control

A native macOS menu bar app focused on controlling macOS AI features. The app seperates cloud integrations, on-device capabilities, and features with mixed or Apple-managed routing sections. The Active section shows matching readable effective settings.

Why I created this app is I understand why people do not want AI to take over their computer without their consent. I also recognize that AI can be usedul in situations. This app is not about being anti-AI but about giving you choice and control rather than an all or nothing approach.

AI Control was initially conceived as a Swift Dialog application utilizing checkboxes to generate a configuration profile. However, after working on it and realizing the need for additional features, such as activation section and reviewing another github project, this project pivoted towards development of a menu bar application that distinguishes between cloud-based and on-device AI functionalities.

## Download the app

Prebuilt app ZIPs are distributed through this repository's **GitHub Releases** page. 

1. Open **Releases** on the repository page and choose a release.
2. Under **Assets**, download the attached app ZIP, such as `AIControl-app.zip`. GitHub's automatically generated **Source code** ZIP is the project source, not the compiled app.
3. Check the release notes for the required macOS version and processor architecture. The current build script creates an app for the build machine's architecture, not a universal binary.
4. Extract the ZIP and move **AI Control.app** to **Applications**.
5. Open the app and click its brain icon in the menu bar.

If a release does work or not yet updated in app ZIP, build from source using the instructions below.

### Current signing status

Builds created with the default script use **ad hoc signing** and are **not notarized**. macOS may block the first launch because it cannot verify the developer. After attempting to open the app, you may need to use **System Settings → Privacy & Security → Open Anyway** and confirm the prompt. Organization managed Macs may prohibit this.

Installing a configuration profile still requires separate approval in System Settings. DDM JSON exports require deployment through a supporting MDM; opening the app does not automatically install those declarations.

## Build on your Mac

Requires macOS 14+ and Xcode with Swift 5.10 or newer. Confirm that command-line builds use the full Xcode toolchain:

```bash
xcode-select --print-path
```

The expected output is:

```text
/Applications/Xcode.app/Contents/Developer
```

If a different path is selected, switch to Xcode with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`. Feature controls are gated by their minimum macOS version. Apple Intelligence requires eligible hardware, language, region, and account configuration; OS eligibility in the app does not certify feature availability.

```bash
cd AIControl
./scripts/build-app.sh
open "build/AI Control.app"
```

The app uses SwiftUI `MenuBarExtra`, stays out of the Dock, and has no main window. No third-party dependencies. The build script runs the Swift unit tests before packaging an app, then applies an ad hoc signature by default.

The app is written to `build/AI Control.app`. The app was developed within XCode with Codex (the irony of using AI in Xcode to build a tool that blocks AI isn’t lost on me).

## Controls

| Section | Features | Behavior |
| --- | --- | --- |
| Cloud | External AI integrations, external AI account sign-in, on-device-only Dictation | Select policy restrictions, then review and export/install a compatibility profile or export MDM declarations |
| Cloud | Private Cloud Compute | Explains routing; no unsupported global PCC toggle |
| On-device | Inline text predictions | Change this user’s preference directly; restore its original value or absence |
| On-device | Foundation Models framework, Xcode predictive completion | Information-only entries; no undocumented disable or asset deletion |
| Mixed / Apple-managed | Siri AI, Writing Tools, Genmoji, Image Playground, Mail, Safari, Notes, Calendar/Reminders, Visual Intelligence | Select feature restrictions; newer controls require MDM declaration deployment |

The cloud preset selects supported external AI restrictions and requires local Dictation. **It is not an “all AI stays local” mode.** 

## Applying and undoing Restrictions

Policy checkboxes represent a **draft**. Review the selected restrictions before generating an output. Unchecked features are omitted rather than explicitly enabled. The Active section separately shows restrictions whose effective values the app can verify.

- **Configuration profiles:** Use Apple's legacy `com.apple.applicationaccess` keys, "deprecated" in macOS 26.4. They can be exported or opened for manual approval in System Settings. Validate behavior on the target macOS. Remove the `AI Control` profile in System Settings to release its restrictions. Organizational policies can still prohibit a feature.
- **MDM declarations:** Preferred management format for macOS 26.4+. The exported JSON contains configurations and an activation. It is not an installable profile without a suppporting MDM. Publish the individual declarations through a supporting MDM. Siri AI, Visual Intelligence, and Calendar/Reminders editing require macOS 27+. Removing or replacing their declarations through MDM releases these restrictions.

The app does not automatically install profiles, deploy MDM declarations, override organization settings, or claim applied status from a generated file. Active status requires a matching readable effective value: forced legacy restrictions in `com.apple.applicationaccess`, or the disabled inline-prediction preference. A disabled preference appears as Active, the app does not test behavior inside every app. Restart affected apps if needed.  DDM-only restrictions remain unverifiable without an MDM status source. It intentionally leaves Apple Intelligence Reports available. Manual Mail summaries and automatic previews are different: the legacy manual-summary restriction does not disable automatic summaries.

## Compatibility and future updates

The current compatibility-profile approach is retained for this version. Many of its Apple Intelligence restriction keys are deprecated starting in macOS 26.4. Deprecation in itself does not establish a removal or guarantee continued behavior: verify each restriction on the macOS versions you deploy, including after updates. Installing a profile successfully does not by itself prove every setting is enforced.

The app already exports MDM declarations, but it does not deploy them or obtain MDM status and currently not on a future update as part of this app.

## Screenshots

### Selected restrictions

![AI Control restrictions](Screenshots/AIControl-Restrictions.png)

### Readable active settings

![AI Control active settings](Screenshots/AIControl-Active.png)

The Active view reports matching readable settings and can include restrictions applied by other profiles or management tools. It does not identify which profile has the setting. 

## Testing and release status

Run `swift test` on macOS; the build script runs these tests before packaging the app. Test each feature's behavior, or prove the absence of DDM restrictions when the list is empty.
 
Before a compiled release, test on a personal Mac and an MDM-managed Mac.

## Sources

Reviewed October 16, 2026 (UTC):

- [RemoveMacAI](https://github.com/omlahore/RemoveMacAI), reference commit `2e974cf796d5748ab5d6f2bccc9679d708ec6e2b`.
- [Apple device-management](https://github.com/apple/device-management), reference commit `09f249a06e7e3289930bf6d05f38fb562f748ebf`.
- [Intelligence settings](https://github.com/apple/device-management/blob/release/declarative/declarations/configurations/intelligence.settings.yaml).
- [External intelligence settings](https://github.com/apple/device-management/blob/release/declarative/declarations/configurations/external-intelligence.settings.yaml).
- [Siri settings](https://github.com/apple/device-management/blob/release/declarative/declarations/configurations/siri.settings.yaml).
- [Legacy restrictions](https://github.com/apple/device-management/blob/release/mdm/profiles/com.apple.applicationaccess.yaml).
- [Apple Intelligence and privacy](https://support.apple.com/guide/mac-help/mchlfc0d4779/mac).
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels).
