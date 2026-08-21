extension Async {

    public struct Fanout: Sendable {

        public let jobs: Swift.Int

        public init(jobs: Swift.Int) {
            self.jobs = Swift.max(1, jobs)
        }
    }
}
