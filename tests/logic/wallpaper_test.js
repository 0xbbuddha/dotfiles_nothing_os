const fs=require("fs"),assert=require("assert");
const src=fs.readFileSync(process.argv[2],"utf8");
const fns={};const re=/^    function (\w+)\(([^)]*)\)(?::\s*\w+)?\s*\{\n([\s\S]*?)\n    \}$/gm;let m;
while((m=re.exec(src)))fns[m[1]]={p:m[2].split(",").map(x=>x.split(":")[0].trim()).filter(Boolean),b:m[3]};
function make(cfg,folder,screens){
  const Config=Object.assign({wallpaper:"",wallpaperScreens:{},wallpaperFormat:"auto",dotWallpaperChar:"tamaki",wallpaperShuffle:false,wallpaperEachScreen:false,saved:0,save(){this.saved++;}},cfg);
  const env={Config,Quickshell:{env:()=>"/home/u",shellPath:p=>"/rice/"+p.replace("../../",""),screens:screens.map(n=>({name:n}))},Walls:{folderFiles:folder,refresh(){env.refreshed=true;}},Math,quietOff:{restart(){}},WallpaperAnnounce:{announce(){}}};
  const root={dotWallpaperKey:"nothing-dots",bundledWallpaper:"/rice/hypr/wallpaper.png"};env.root=root;
  for(const[n,f]of Object.entries(fns)){const k=Object.keys(env);root[n]=new Function(...k,`return function(${f.p}){${f.b}}`)(...k.map(x=>env[x]));}
  return {root,Config,env};
}
let t=make({},["/w/a.jpg","/w/b.jpg","/w/c.jpg"],["DP-1","DP-2"]);
t.root.set("/w/a.jpg","");
assert.strictEqual(t.root.wallpaperUrlFor("DP-1",3440,1440),"file:///w/a.jpg");
t.root.set("~/x.png","DP-2");
assert.strictEqual(t.root.wallpaperUrlFor("DP-2",1920,1080),"file:///home/u/x.png","per screen, ~ expanded");
assert.strictEqual(t.root.wallpaperUrlFor("DP-1",3440,1440),"file:///w/a.jpg","other screen keeps shared");
t.root.set("nothing-dots","DP-1");
assert.match(String(t.root.wallpaperUrlFor("DP-1",3440,1440)),/nothing-dots-16-9\.png$/,"ultrawide gets the wide dots");
t.root.set("/w/b.jpg",""); assert.deepStrictEqual(t.Config.wallpaperScreens,{},"all screens clears per-screen");
t.root.next(); assert.strictEqual(t.Config.wallpaper,"/w/c.jpg","in order: after b comes c");
t.root.next(); assert.strictEqual(t.Config.wallpaper,"/w/a.jpg","wraps");
t=make({wallpaperEachScreen:true,wallpaper:"/w/a.jpg"},["/w/a.jpg","/w/b.jpg","/w/c.jpg"],["DP-1","DP-2"]);
t.root.next(); const p=t.Config.wallpaperScreens; assert.ok(p["DP-1"]&&p["DP-2"]&&p["DP-1"]!==p["DP-2"],"different per screen");
t=make({wallpaperShuffle:true,wallpaper:"/w/a.jpg"},["/w/a.jpg","/w/b.jpg"],["DP-1"]);
for(let i=0;i<20;i++){const before=t.Config.wallpaper;t.root.next();assert.notStrictEqual(t.Config.wallpaper,before,"shuffle never repeats the current one");}
t=make({},[],["DP-1"]); t.root.next(); assert.ok(t.env.refreshed,"empty folder -> rescan, no change");
assert.strictEqual(t.root.resolve("",1,1),"file:///rice/hypr/wallpaper.png");
console.log("wallpapers: per screen, all screens, dots by shape, slideshow order/shuffle/per-screen");
