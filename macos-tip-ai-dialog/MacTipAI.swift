#!/usr/bin/env swift

import Foundation
import FoundationModels

if #available(macOS 26.0, *) {
    Task {
        do {
            let session = LanguageModelSession(
                instructions: """
                You are an IT support assistant for macOS users.
                Give one short, helpful macOS tip.
                Keep it under 40 words.
                Do not mention AI.
                """
            )

            let response = try await session.respond(to: """
            Generate a random macOS productivity, security, Finder, keyboard shortcut, network or troubleshooting tip.
            """)

            print(response.content)
            exit(0)

        } catch {
            print("Tip: Restarting your Mac can clear temporary system issues and apply pending updates.")
            exit(0)
        }
    }

    RunLoop.main.run()
} else {
    print("Tip: Press Command + Space to quickly open Spotlight and search for apps, files, or settings.")
}