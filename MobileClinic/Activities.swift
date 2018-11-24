
typealias Line = (start: CGPoint, end: CGPoint)

class Activity {

    let date: Date
    let score: Int
    let status: String
    let sampleImage: UIImage?
    let linesInFrames: [[Line]]

    init(date: Date, linesInFrames: [[Line]], sampleImage: UIImage?, score: Int, status: String) {
        self.date = date
        self.score = score
        self.status = status
        self.sampleImage = sampleImage
        self.linesInFrames = linesInFrames
    }
}

