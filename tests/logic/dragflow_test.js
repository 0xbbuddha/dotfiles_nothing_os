const fs=require("fs"),assert=require("assert");
const src=fs.readFileSync(process.argv[2],"utf8");
const fns={};const re=/^    function (\w+)\(([^)]*)\)(?::\s*\w+)?\s*\{\n([\s\S]*?)\n    \}$/gm;let m;
while((m=re.exec(src)))fns[m[1]]={p:m[2].split(",").map(x=>x.split(":")[0].trim()).filter(Boolean),b:m[3]};

function make(sizes,maxWidth,spacing){
  const root={sizes,maxWidth,spacing,from:-1,to:-1,emitted:null};
  const env={root};
  for(const[n,f]of Object.entries(fns)){const k=Object.keys(env);root[n]=new Function(...k,`return function(${f.p}){${f.b}}`)(...k.map(x=>env[x]));}
  root._layout=root._pack();
  root.swapped=(f,t)=>{root.emitted=[f,t];};
  return root;
}

const sq=(w,h)=>({width:w,height:h});
// A clean 2x2 grid: two 100px tiles per row, 10px gaps, wrapping at 220.
let t=make([sq(100,100),sq(100,100),sq(100,100),sq(100,100)],220,10);
assert.deepStrictEqual(t._layout[0],{x:0,y:0,w:100,h:100});
assert.deepStrictEqual(t._layout[1],{x:110,y:0,w:100,h:100});
assert.deepStrictEqual(t._layout[2],{x:0,y:110,w:100,h:100});
assert.deepStrictEqual(t._layout[3],{x:110,y:110,w:100,h:100},"wraps once a tile would cross maxWidth");

// A tile too wide for the row on its own still gets a row, not a loop:
// x stays 0 for the first tile of any row regardless of width.
t=make([sq(300,50),sq(50,50)],220,10);
const wide=t._pack();
assert.strictEqual(wide[0].x,0);
assert.strictEqual(wide[1].x,0,"a tile that cannot share a row wraps the next one too");
assert.strictEqual(wide[1].y,60);

// nearestIndex: whichever tile's centre is closest, the dragged one
// included - hovering back over your own start answers with your own
// index, which is how drop() below ends up a no-op there.
t=make([sq(100,100),sq(100,100),sq(100,100),sq(100,100)],220,10);
assert.strictEqual(t.nearestIndex(50,50),0,"inside tile 0 lands on tile 0");
assert.strictEqual(t.nearestIndex(160,50),1,"inside tile 1 lands on tile 1");
assert.strictEqual(t.nearestIndex(50,160),2,"inside tile 2 lands on tile 2");
assert.strictEqual(t.nearestIndex(160,160),3,"inside tile 3 lands on tile 3");

// drop() emits swapped(from, to) only when both are set and differ -
// a swap, not an insertion, so there is nothing to shift in between.
t=make([sq(100,100),sq(100,100)],220,10);
t.from=0; t.to=1;
t.drop();
assert.deepStrictEqual(t.emitted,[0,1]);
assert.strictEqual(t.from,-1);
assert.strictEqual(t.to,-1);

t=make([sq(100,100),sq(100,100)],220,10);
t.from=0; t.to=0; t.emitted=null;
t.drop();
assert.strictEqual(t.emitted,null,"dropping back on yourself fires nothing");

console.log("dragflow: packs into rows, wraps on overflow, nearest tile by centre, drop swaps once");
