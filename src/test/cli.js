// compile a .bas (or several, .cls too) from the command line - scratch tool, not delivered
var fs=require('fs');
global.window=global;
eval(fs.readFileSync(require('path').join(__dirname, '..', 'js', 'ntc_lib.js'),'utf8').replace(/^var /gm,'global.'));
eval(fs.readFileSync(require('path').join(__dirname, '..', 'js', 'ntc_parser.js'),'utf8').replace(/^var /gm,'global.').replace('function IFtoPF','global.IFtoPF = function IFtoPF').replace('function ntcParse','global.ntcParse = function ntcParse'));
eval(fs.readFileSync(require('path').join(__dirname, '..', 'js', 'ntc_compiler.js'),'utf8').replace('function ntcCompile','global.ntcCompile = function ntcCompile'));
var args=process.argv.slice(2), opts={}, files=[];
var mapFile=null;
args.forEach(function(a){ if(a==="--turbo")opts.turbo=true; else if(a.indexOf("--platform=")===0)opts.platform=a.substr(11); else if(a.indexOf("--amsdos=")===0)opts.amsdos=a.substr(9); else if(a==='--nocomments')opts.sourcecomments=false; else if(a==='--layout')opts.showlayout=true; else if(a.indexOf('--map=')===0)mapFile=a.substr(6); else files.push({name:a.replace(/^.*\//,''),text:fs.readFileSync(a,'utf8')}); });
var r=ntcCompile(files.length===1?files[0].text:files,opts);
r.errors.forEach(function(e){console.error('ERR '+(e.file||'')+':'+e.line+': '+e.msg);});
(r.warnings||[]).forEach(function(e){console.error('WARN '+(e.file||'')+':'+e.line+': '+e.msg);});
if(opts.showlayout)(r.layout||[]).forEach(function(l){console.error('LAYOUT '+l);});
console.log(r.asm);
if(mapFile)fs.writeFileSync(mapFile,r.map+'\n');
