import Foundation

/// Input item for the overlap layout engine.
public struct TimelineLayoutInput: Equatable, Sendable {
    public let id: String
    public let startMinute: Int
    public let endMinute: Int

    public init(id: String, startMinute: Int, endMinute: Int) {
        self.id = id
        self.startMinute = startMinute
        self.endMinute = max(endMinute, startMinute + TimelineMath.minBlockDurationMinutes)
    }
}

/// Output frame geometry (normalized horizontal column + count) for a timed block.
public struct TimelineLayoutPlacement: Equatable, Sendable {
    public let id: String
    public let column: Int
    public let totalColumns: Int
    public let startMinute: Int
    public let endMinute: Int

    public init(id: String, column: Int, totalColumns: Int, startMinute: Int, endMinute: Int) {
        self.id = id
        self.column = column
        self.totalColumns = max(1, totalColumns)
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}

/// Computes non-overlapping horizontal columns for simultaneous/overlapping blocks
/// grouped into connected overlap clusters (Google Calendar / Apple Calendar style).
public enum OverlapLayoutEngine {
    public static func layout(items: [TimelineLayoutInput]) -> [String: TimelineLayoutPlacement] {
        guard !items.isEmpty else { return [:] }

        // Sort by start time ascending, then longer duration first so broader blocks anchor left.
        let sorted = items.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute {
                return lhs.startMinute < rhs.startMinute
            }
            let lhsDur = lhs.endMinute - lhs.startMinute
            let rhsDur = rhs.endMinute - rhs.startMinute
            if lhsDur != rhsDur {
                return lhsDur > rhsDur
            }
            return lhs.id < rhs.id
        }

        // Partition into connected overlap clusters.
        var clusters: [[TimelineLayoutInput]] = []
        var currentCluster: [TimelineLayoutInput] = []
        var clusterMaxEnd = -1

        for item in sorted {
            if currentCluster.isEmpty {
                currentCluster = [item]
                clusterMaxEnd = item.endMinute
            } else if item.startMinute < clusterMaxEnd {
                currentCluster.append(item)
                clusterMaxEnd = max(clusterMaxEnd, item.endMinute)
            } else {
                clusters.append(currentCluster)
                currentCluster = [item]
                clusterMaxEnd = item.endMinute
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        var placements: [String: TimelineLayoutPlacement] = [:]
        placements.reserveCapacity(items.count)

        for cluster in clusters {
            // Greedy column assignment within each cluster.
            var columnEndMinutes: [Int] = []
            var assigned: [(TimelineLayoutInput, Int)] = []

            for item in cluster {
                if let colIndex = columnEndMinutes.firstIndex(where: { $0 <= item.startMinute }) {
                    columnEndMinutes[colIndex] = item.endMinute
                    assigned.append((item, colIndex))
                } else {
                    let newCol = columnEndMinutes.count
                    columnEndMinutes.append(item.endMinute)
                    assigned.append((item, newCol))
                }
            }

            let totalCols = max(1, columnEndMinutes.count)
            for (item, col) in assigned {
                placements[item.id] = TimelineLayoutPlacement(
                    id: item.id,
                    column: col,
                    totalColumns: totalCols,
                    startMinute: item.startMinute,
                    endMinute: item.endMinute
                )
            }
        }

        return placements
    }
}
