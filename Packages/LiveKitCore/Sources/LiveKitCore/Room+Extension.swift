import LiveKit

internal extension Room {
    /// A participant with `agent` in their identity.
    var agentParticipant: Participant? {
        remoteParticipants.values.first { participant in
            guard let identity = participant.identity else {
                return false
            }
            // Use String(describing:) for the most robust conversion
            return String(describing: identity).contains("agent")
        }
    }
}
