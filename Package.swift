// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SideNotes",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "SideNotesCore", targets: ["SideNotesCore"]),
        .executable(name: "SideNotes", targets: ["SideNotesApp"]),
        .executable(name: "SideNotesCoreTests", targets: ["SideNotesCoreTests"])
    ],
    targets: [
        .target(
            name: "SideNotesCore",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "SideNotesApp",
            dependencies: ["SideNotesCore"]
        ),
        .executableTarget(name: "SideNotesCoreTests", dependencies: ["SideNotesCore"])
    ]
)
