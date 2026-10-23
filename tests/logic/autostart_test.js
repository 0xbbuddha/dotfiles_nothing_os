const fs=require("fs"),assert=require("assert");
const src=fs.readFileSync(process.argv[2],"utf8");
const fns={};const re=/^    function (\w+)\(([^)]*)\)(?::\s*\w+)?\s*\{\n([\s\S]*?)\n    \}$/gm;let m;
while((m=re.exec(src)))fns[m[1]]={p:m[2].split(",").map(x=>x.split(":")[0].trim()).filter(Boolean),b:m[3]};
function make(installed,running,apps){
  const launched=[],warns=[];
  const entries=Object.fromEntries(installed.map(id=>[id,{command:[id==="flat"?"flatpak":"/usr/bin/"+id,"--x"],execute(){launched.push(id);}}]));
  const env={DesktopEntries:{byId:id=>entries[id],applications:{values:Object.values(entries)}},
    Config:{autostartApps:apps,autostartDelay:3,save(){}},console:{warn:w=>warns.push(w)},
    delay:{interval:0,restart(){}},check:{pending:"",command:[],set running(v){env.pend=this.command[3];}},pend:null};
  const root={started:[],skipped:[],ran:false,queue:[],waited:0};env.root=root;
  for(const[n,f]of Object.entries(fns)){const k=Object.keys(env);root[n]=new Function(...k,`return function(${f.p}){${f.b}}`)(...k.map(x=>env[x]));}
  // emulate check.onExited
  const exitBody=src.match(/onExited: \(code\) => \{\n([\s\S]*?)\n        \}/)[1];
  const onExit=new Function("check","root","code",exitBody);
  const drive=()=>{root.startAll();while(env.pend!==null){const b=env.pend;env.pend=null;env.check.pending=env.check.pending;onExit(env.check,root,running.includes(b)?0:1);}};
  return{root,launched,warns,drive,env};
}
let t=make(["discord","steam","flat"],["steam"],["discord","steam","gone","flat"]);
t.drive();
assert.deepStrictEqual(t.launched,["discord","flat"]);
assert.deepStrictEqual(t.root.skipped.map(x=>x.id+":"+x.why),["steam:already running","gone:not installed"]);
assert.strictEqual(t.env.check.command[0],"pgrep");
console.log("autostart queue ok: launched",t.launched.join(","),"| skipped",t.root.skipped.map(x=>x.id).join(","));
