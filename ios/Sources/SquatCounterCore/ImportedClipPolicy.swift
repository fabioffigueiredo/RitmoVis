/// An imported clip has no user-selected target in this release. If a second
/// person is detected anywhere, provisional counts must not be published.
public enum ImportedClipPolicy {
    public static func requiresSelection(candidateCounts: [Int]) -> Bool {
        candidateCounts.contains { $0 > 1 }
    }
}
