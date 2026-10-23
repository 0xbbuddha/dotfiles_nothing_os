const fs=require("fs"),assert=require("assert");
const src=fs.readFileSync(process.argv[2],"utf8");
const body=src.match(/onStreamFinished: \{\n                let tree;([\s\S]*?)\n            \}\n        \}\n    \}/)[1];
const human=new Function("bytes",src.match(/function human\(bytes: real\): string \{\n([\s\S]*?)\n    \}/)[1]);
const sample={blockdevices:[
 {path:"/dev/nvme0n1",label:null,size:1e12,fstype:null,mountpoint:null,rm:false,hotplug:false,type:"disk",tran:"nvme",pkname:null,children:[
   {path:"/dev/nvme0n1p2",label:"root",size:9e11,fstype:"btrfs",mountpoint:"/",rm:false,hotplug:false,type:"part",tran:null,pkname:"nvme0n1"}]},
 {path:"/dev/sda",label:null,size:2e12,fstype:null,mountpoint:null,rm:false,hotplug:true,type:"disk",tran:"sata",pkname:null,children:[
   {path:"/dev/sda1",label:"data",size:2e12,fstype:"ext4",mountpoint:"/data",rm:false,hotplug:true,type:"part",tran:null,pkname:"sda"}]},
 {path:"/dev/sdb",label:null,size:64e9,fstype:null,mountpoint:null,rm:true,hotplug:true,type:"disk",tran:"usb",pkname:null,children:[
   {path:"/dev/sdb1",label:"KEY",size:64e9,fstype:"vfat",mountpoint:null,rm:true,hotplug:true,type:"part",tran:null,pkname:"sdb"},
   {path:"/dev/sdb2",label:null,size:1e9,fstype:"crypto_LUKS",mountpoint:null,rm:true,hotplug:true,type:"part",tran:null,pkname:"sdb"}]},
 {path:"/dev/zram0",label:null,size:8e9,fstype:"swap",mountpoint:"[SWAP]",rm:false,hotplug:false,type:"disk",tran:null,pkname:null}]};
let got=null;const root={human,arrived:()=>{},set list(v){got=v;}};
new Function("root","text",body)(root,JSON.stringify(sample));
assert.deepStrictEqual(got.map(d=>[d.path,d.disk,d.label,d.size,d.encrypted]),[["/dev/sdb1","/dev/sdb","KEY","64 GB",false],["/dev/sdb2","/dev/sdb","sdb2","1.0 GB",true]]);
console.log("drives: only the USB stick's partitions listed, internal SATA/NVMe/zram ignored");
