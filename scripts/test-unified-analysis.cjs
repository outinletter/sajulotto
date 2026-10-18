const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const nodes = new Map();
function node(id) {
 if (!nodes.has(id)) nodes.set(id, {value:id==='inputExactTime'?'12:00':id.startsWith('reflection-')?'private journal':'',innerHTML:'',textContent:'',classList:{add(){},remove(){}},querySelectorAll:()=>Array.from({length:6},()=>({classList:{remove(){}},innerHTML:''}))});
 return nodes.get(id);
}
let saved;
const context={console,Date,setTimeout(){},window:{webkit:{messageHandlers:{reflectionSave:{postMessage(entries){saved=entries;}}}}},document:{getElementById:node}};
node('inputBirth').addEventListener=()=>{};node('destinyForm').addEventListener=()=>{};
vm.createContext(context);
for(const path of ['vendor/solar-terms.js','vendor/saju-calendar.js']) vm.runInContext(fs.readFileSync(path,'utf8'),context);
const html=fs.readFileSync('ios/Web/index.html','utf8');
vm.runInContext([...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n'),context);
function run(day){vm.runInContext(`buildWeeklyDashboard('test',{year:1995,month:5,day:${day}},'unknown',127.02); generateFinalNumbers();`,context);return JSON.stringify(context.window.sajuWeeklyContext);}
const first=run(12), data=JSON.parse(first);
assert.equal(data.days.find(d=>d.score===Math.max(...data.days.map(x=>x.score))).day,data.selectedDay);
assert.equal(data.numberSets.length,5);
for(const set of data.numberSets){assert.equal(new Set(set).size,6);assert(set.every(n=>n>=1&&n<=45));}
assert.equal(saved.length,5);assert.deepEqual(JSON.parse(JSON.stringify(saved.map(e=>e.numbers))),data.numberSets);
assert(!first.includes('private journal'));
assert.equal(run(12),first);assert.notEqual(run(13),first);
assert.equal((html.match(/<textarea id="reflection-/g)||[]).length,5);
console.log('PASS: merged inputs, best weekly day, five valid sets, deterministic replay, birth-sensitive seed, journal privacy and archive payload');
