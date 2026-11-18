const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = {window:{}, document:{getElementById:()=>({value:"",addEventListener(){}})}, console, Date, setTimeout};
vm.createContext(context);
for (const file of ['vendor/solar-terms.js','vendor/saju-calendar.js']) vm.runInContext(fs.readFileSync(file,'utf8'),context);
const html=fs.readFileSync('ios/Web/index.html','utf8');
const inline=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');
vm.runInContext(inline,context);
vm.runInContext(`
const functions = {getYearPillar,getMonthPillar,getDayPillar};
function check(input) {return SolarManager.chart({year:2026,month:2,day:4,timeVal:'unknown',longitude:135,...input},functions);}
window.before=check({exactTime:'05:01'});
window.after=check({exactTime:'05:02'});
window.unknown=check({});
window.historical=check({year:1995,month:5,day:12,exactTime:'12:00'});
window.midnight=check({month:5,day:12,exactTime:'00:10',longitude:127});
window.previousDay=getDayPillar(2026,5,11);
window.normal=check({month:5,day:12,exactTime:'12:00',longitude:127});
window.zero=check({month:5,day:12,timeVal:'0'});
`,context);
const w=context.window;
assert.equal(w.before.yearPillar.stemIdx,1); assert.equal(w.before.yearPillar.branchIdx,5);
assert.equal(w.after.yearPillar.stemIdx,2); assert.equal(w.after.yearPillar.branchIdx,6);
assert.equal(w.before.monthPillar.branchIdx,1); assert.equal(w.after.monthPillar.branchIdx,2);
assert.equal(w.unknown.hourPillar.stemIdx,null);assert(w.unknown.basis.warnings.length>0);
assert(w.after.basis.source.includes('한국천문연구원'));assert(w.historical.basis.source.includes('Astronomy Engine'));
assert.equal(w.midnight.dayPillar.stemIdx,w.previousDay.stemIdx);
assert.equal(w.midnight.dayPillar.branchIdx,w.previousDay.branchIdx);
assert.equal(w.normal.basis.longitudeCorrectionMinutes,-32);
assert.equal(w.zero.hourPillar.branchIdx,0);
assert(w.after.basis.warnings.some(x=>x.includes('경계')));
for(const [year,terms] of Object.entries(w.SajuSolarTerms.years)) {
 assert.equal(terms.length,24);assert(terms.every(Number.isFinite));
 assert(terms.every((v,i)=>!i||v>terms[i-1]),year);
}
assert(fs.readFileSync('vendor/solar-terms.js').equals(fs.readFileSync('ios/Web/vendor/solar-terms.js')));
assert(fs.readFileSync('vendor/saju-calendar.js').equals(fs.readFileSync('ios/Web/vendor/saju-calendar.js')));
console.log('PASS: 입춘 전후 연·월주, 절입 경고, 시각 미상, 과거 출처, 자정 날짜 보정, 경도, 129년 데이터, 번들 일치');
// Native rendering uses the same pure functions without a DOM or WebView.
const nativeContext = {window:{}, Date};
vm.createContext(nativeContext);
for (const file of ['solar-terms','saju-calendar','native-engine']) vm.runInContext(fs.readFileSync('ios/Web/vendor/'+file+'.js','utf8'), nativeContext);
const result = JSON.parse(vm.runInContext(`nativeChart({year:1995,month:5,day:12,timeVal:'unknown',longitude:127,exactTime:'',weekYear:2026,weekMonth:10,weekDay:31})`,nativeContext));
assert.equal(result.pillars.length,4); assert.equal(result.pillars[3].value,'미상'); assert.equal(result.days.length,7);
assert.equal(result.days[0].date,'2026-10-25'); assert.equal(result.days[6].date,'2026-10-31');
assert.equal(result.basis.longitudeCorrectionMinutes,-32);
console.log('PASS: native adapter has no DOM dependency and preserves original calculation results');
