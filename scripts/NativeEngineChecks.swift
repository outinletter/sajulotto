import Foundation
import JavaScriptCore

let context = JSContext()!
context.evaluateScript("var window = globalThis;")
for name in ["solar-terms", "saju-calendar", "native-engine"] {
    context.evaluateScript(try String(contentsOfFile: "ios/Web/vendor/\(name).js", encoding: .utf8))
    precondition(context.exception == nil, "JavaScript initialization failed")
}
func chart(_ extra: [String: Any] = [:]) -> [String: Any] {
    var input: [String: Any] = ["year":2026,"month":2,"day":4,"timeVal":"unknown","longitude":135,"exactTime":"", "weekYear":2026,"weekMonth":10,"weekDay":31]
    input.merge(extra) { _, value in value }
    let json = context.objectForKeyedSubscript("nativeChart")!.call(withArguments:[input])!.toString()!
    precondition(context.exception == nil, "Native adapter failed")
    return try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
}
func pillars(_ result: [String:Any]) -> [[String:Any]] { result["pillars"] as! [[String:Any]] }
let before = chart(["exactTime":"05:01"]), after = chart(["exactTime":"05:02"])
assert(pillars(before)[0]["value"] as! String == "乙巳")
assert(pillars(after)[0]["value"] as! String == "丙午")
assert(pillars(before)[1]["value"] as! String != pillars(after)[1]["value"] as! String)
assert(pillars(chart())[3]["value"] as! String == "미상")
let historical = chart(["year":1995,"month":5,"day":12,"exactTime":"12:00","longitude":127])
assert((historical["basis"] as! [String:Any])["source"] as! String != "")
assert((historical["basis"] as! [String:Any])["longitudeCorrectionMinutes"] as! Double == -32)
let midnight = chart(["month":5,"day":12,"exactTime":"00:10","longitude":127])
let previous = chart(["month":5,"day":11,"exactTime":"12:00","longitude":127])
assert(pillars(midnight)[2]["value"] as! String == pillars(previous)[2]["value"] as! String)
let replay = chart(["year":1995,"month":5,"day":12,"exactTime":"12:00","longitude":127])
func sets(_ result: [String:Any]) -> [[Int]] {
    let json = context.objectForKeyedSubscript("nativeNumberSets")!.call(withArguments:[result["generation"]!])!.toString()!
    return try! JSONDecoder().decode([[Int]].self, from: Data(json.utf8))
}
assert(historical["numberSets"] == nil)
assert(sets(historical) == sets(replay))
for set in sets(historical) { assert(set.count == 6 && Set(set).count == 6 && set.allSatisfy { (1...45).contains($0) }) }
let days = historical["days"] as! [[String:Any]]
assert(days.count == 7 && days[0]["date"] as! String == "2026-10-25" && days[6]["date"] as! String == "2026-10-31")
assert((chart()["distribution"] as! [String:Int]).values.reduce(0,+) == 6)
assert((historical["distribution"] as! [String:Int]).values.reduce(0,+) == 8)
for year in [1900,1961,1987,2027] { _ = chart(["year":year,"month":1,"day":1]) }
let branches = ["子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥"]
for index in 0..<12 {
    let result = chart(["timeVal":String(index),"longitude":135])
    assert((pillars(result)[3]["value"] as! String).hasSuffix(branches[index]))
    assert(((result["basis"] as! [String:Any])["precision"] as! String).contains("2시간"))
}
print("PASS: native JavaScriptCore adapter, solar-term boundaries, unknown time, longitude, midnight, KST week, element counts, supported years")
