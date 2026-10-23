const fs=require("fs"),assert=require("assert");
const src=fs.readFileSync(process.argv[2],"utf8");
const body=src.match(/function autoCheck\(\): void \{\n([\s\S]*?)\n    \}/)[1];
const nameRe=eval(src.match(/nameRe: (\/.*\/)/)[1]);
function run(list,opts={}){
  const calls={backup:0,rm:null};
  const root={list,busy:false,keepAuto:7,triedOn:opts.triedOn??"",dir:"/b",nameRe,backup:()=>calls.backup++};
  const pruner={set running(v){calls.rm=this.command;}};
  const Qt={formatDateTime:()=> "20261023"};
  new Function("root","Config","Qt","pruner",body)(root,{autoBackup:opts.on??true},Qt,pruner);
  return {calls,root};
}
let r=run(["config-20261022-090000-auto.json","config-20261020-100000.json"]);
assert.strictEqual(r.calls.backup,1,"no copy today -> backup");
r=run(["config-20261022-090000-auto.json"],{triedOn:"config-20261023-"});
assert.strictEqual(r.calls.backup,0,"tried today already -> no loop");
const autos=[...Array(9)].map((_,i)=>`config-202610${String(23-i).padStart(2,"0")}-090000-auto.json`);
r=run(autos.concat(["config-20261001-100000.json","config-20261002-100000-before-restore.json"]).sort().reverse());
assert.strictEqual(r.calls.backup,0);
assert.deepStrictEqual(r.calls.rm,["rm","-f","--","/b/config-20261016-090000-auto.json","/b/config-20261015-090000-auto.json"],"only the 2 oldest autos pruned");
r=run([],{on:false}); assert.strictEqual(r.calls.backup,0,"off -> nothing");
assert.ok(nameRe.test("config-20261023-090000-auto.json") && !nameRe.test("config-x-auto.json"));
console.log("backup: daily copy, one try a day, keeps 7 autos, never deletes manual or before-restore");
