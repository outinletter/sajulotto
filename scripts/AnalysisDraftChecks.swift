import Foundation

@main struct AnalysisDraftChecks {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("draft.json")
        let birth = WeeklyWindow.date(from: "1995-05-12")!
        let sunday = WeeklyWindow.date(from: "2026-10-25")!
        let saturday = WeeklyWindow.date(from: "2026-10-31")!
        let nextSunday = WeeklyWindow.date(from: "2026-11-01")!
        let key = AnalysisDraftStore.key(birth: birth, time: nil, longitude: 126.978, timeBranch: "6", now: sunday)
        assert(key == AnalysisDraftStore.key(birth: birth, time: nil, longitude: 126.978, timeBranch: "6", now: saturday))
        assert(key != AnalysisDraftStore.key(birth: birth, time: nil, longitude: 126.978, timeBranch: "6", now: nextSunday))
        assert(key != AnalysisDraftStore.key(birth: birth, time: nil, longitude: 126.978, timeBranch: "7", now: sunday))
        assert(key != AnalysisDraftStore.key(birth: birth, time: nil, longitude: 129.076, timeBranch: "6", now: sunday))
        let store = AnalysisDraftStore(file: file)
        store.state.inputs = AnalysisDraftInputs(name: "LOCAL TEST", birthText: "1995", timeBranch: "6", longitude: 126.978)
        store.state.answers = ["joy": "partial answer"]
        try store.save()
        let partial = AnalysisDraftStore(file: file)
        assert(partial.state.inputs == store.state.inputs && partial.state.answers == store.state.answers)
        let frozenChart = Data("immutable weekly chart fixture".utf8)
        store.state.sessions[key] = AnalysisSessionDraft(preparedAt: sunday, chartData: frozenChart,
            answers: store.state.answers, questions: ["joy": "reference-day question"], numberSets: [], questionsStarted: true,
            answersCompleted: false, showingNumbers: false, answersNeedSaving: false, savedInput: "local birth input")
        store.state.currentSessionKey = key
        try store.save()
        let reopened = AnalysisDraftStore(file: file)
        assert(reopened.state.currentSessionKey == key)
        assert(reopened.state.sessions[key]?.chartData == frozenChart)
        assert(reopened.state.sessions[key]?.answers["joy"] == "partial answer")
        reopened.state.currentSessionKey = nil // Back to the birth screen must retain the weekly cache.
        reopened.state.inputs.name = "RENAMED"
        try reopened.save()
        let returned = AnalysisDraftStore(file: file)
        assert(returned.state.inputs.birthText == "1995" && returned.state.inputs.name == "RENAMED")
        assert(returned.state.sessions[key]?.chartData == frozenChart && returned.state.answers["joy"] == "partial answer")
        let corrupt = Data("broken draft".utf8)
        try corrupt.write(to: file)
        let protected = AnalysisDraftStore(file: file)
        assert(!protected.readable)
        do { try protected.save(); assertionFailure("unreadable draft overwritten") } catch ReflectionError.unreadable { }
        let preserved = try Data(contentsOf: file)
        assert(preserved == corrupt)
        try protected.reset()
        assert(protected.readable && protected.state.sessions.isEmpty && protected.state.inputs.birthText.isEmpty)
        assert(!FileManager.default.fileExists(atPath: file.path))
        print("PASS: incomplete input/answers survive reopen; same-birth weekly identity and chart cache remain fixed; back/reset and corruption protection")
    }
}
