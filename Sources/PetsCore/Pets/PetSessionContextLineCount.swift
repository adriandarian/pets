public enum PetSessionContextLineCount {
    public static let supportedRange = 1...4
    public static let defaultValue = 2

    public static func clamped(_ lineCount: Int) -> Int {
        min(max(lineCount, supportedRange.lowerBound), supportedRange.upperBound)
    }
}
