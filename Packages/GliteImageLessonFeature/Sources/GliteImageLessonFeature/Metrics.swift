import Foundation
import CoreGraphics

/// Numeric constants that influence layout or timing.
/// Having them in one place avoids scattering "magic numbers" across the codebase.
enum Metrics {
    enum Timing {
        /// Timeout (in *nanoseconds*) used to clear the user-image loading spinner.
        static let userImageTimeout: UInt64 = 15 * 1_000_000_000
    }
} 