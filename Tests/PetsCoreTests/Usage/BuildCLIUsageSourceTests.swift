import Foundation
import Testing
@testable import PetsCore

@Suite
struct BuildCLIUsageSourceTests {
    @Test
    func parserReadsCurrentWeeklyTotal() throws {
        let data = Data(#"""
        {
          "period": "weekly",
          "budget_cents": 200000,
          "current": {
            "start_date": "2026-07-13",
            "end_date": "2026-07-14",
            "tokens": 588648286,
            "input_tokens": 587188114,
            "output_tokens": 1460172
          }
        }
        """#.utf8)

        let reading = try BuildCLIUsageParser.parse(data)

        #expect(reading == PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 588_648_286
        ))
    }

    @Test
    func parserRejectsMissingCurrentUsage() {
        #expect(throws: PetUsageSourceError.invalidOutput(provider: "Claude")) {
            try BuildCLIUsageParser.parse(Data(#"{"period":"weekly"}"#.utf8))
        }
    }
}
