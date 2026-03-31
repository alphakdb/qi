\d .qi

env:{$[count v:getenv x;v;y]}
HOME:env[`HOME;env[`USERPROFILE;"."]]

/ can override `.conf with an env variable or entry in ~/.qi/qi.conf or .qi/qi.conf
.conf.URL:env[`QI_URL;"https://raw.githubusercontent.com/alphakdb/qi/refs/heads/main/"]
.conf.API:env[`QI_API;"https://api.github.com/repos/"]
.conf.RAW:env[`QI_REPO_RAW;"https://raw.githubusercontent.com/"]
.conf.TOKEN:env[`GITHUB_TOKEN;""]
.conf.QBIN:env[`QBIN;first .z.X]
.conf.QI_HOME:env[`QI_HOME;HOME,"/.qi"]
.conf.QI_CMD:env[`QI_CMD;""]
.conf.HUB_PORT:"J"$env[`HUB_PORT;"8000"]

`WIN`MAC`LIN set'"wml"=first string .z.o;
LOCAL:hsym`$$[WIN;ssr[system"cd";"\\";"/"];first system"pwd"]
.conf.STACKS:env[`QI_STACKS;1_string` sv LOCAL,`stacks]
.conf.SCRIPTS:env[`QI_SCRIPTS;1_string` sv LOCAL,`scripts]
.conf.DATA:env[`QI_DATA;1_string` sv LOCAL,`data]

/ can override in ~/.qi/qi.conf or .qi/qi.conf
.conf.CORES:.z.c
.conf.FIRST_CORE:2

/ file system
tostr:{$[0=count x;"";0=t:type x;.z.s each x;t in -10 10h;x;string x]}
tosym:{$[0=count x;`$();0=t:type x;.z.s each x;t in -11 11h;x;`$tostr x]}
path:{$[0>type x;hsym tosym x;` sv @[raze tosym x;0;hsym]]}  / `:path/to/file
spath:1_string path@                                         / "path/to/file"
ospath:$[WIN;ssr[;"/";"\\"]spath@;spath]                       / "path/to/file (Mac/Linux) path\to\file (Windows)"
local:{path(LOCAL;x)}
qihome:{path(.conf.QI_HOME;x)} 
exists:{not()~key path x}
ext:{$[x like"*",y;x;`$tostr[x],y]}
dotq:ext[;".q"]
paths:{a where(last each` vs'a:(raze/){$[p~k:key p:path x;p;.z.s each` sv'p,'k where not k like".*"]}x)like tostr(),y}
apaths:{$[11h=type d:key p:path x;raze p,.z.s each` sv/:p,/:d;d]}
cp:{[src;targ] path[targ]0:read0 path src}
deldir:hdel each desc apaths@
/ basic logging function
print:{[typ;msg] -1 string[.z.p]," ",typ," ",string[.z.w]," ",$[10=abs type msg;msg;-3!msg];}
{x set $[x=`fatal;{print[x;y];exit 1};print]string x}each`info`error`fatal;

/ try-catch
tryx:{[func;args;catch] $[`ERR~first r:.[func;args;{(`ERR;x)}];(0b;catch;r 1);(1b;r;"")]}
try:{tryx[x;enlist y;z]}    / for monadic (1 arg) functions

/ web & json
online:{first try[system;"curl --connect-timeout 1 1.1.1.1";0]}
curl:{system("curl -fsSL ",$[count tk:.conf.TOKEN;"-H \"Authorization: Bearer ",tk,"\" ";""]),x}
jcurl:.j.k raze curl@
fetch:{[url;p]
  info "fetch: ",cmd:"curl -L -s -o ",(sp:ospath p)," ",url;
  path[p]1:0#0x;
  if[not first r:try[system;cmd;0];
    @[hdel;p;0];
    '$[online`;"Problem fetching ",sp,": ",r 2;"Tried to fetch ",sp, " but could not connect to the internet"],"\n"];
  system cmd;
  }
  
readj:.j.k raze read0 path@
formatj:{o:x in"{[";p:o-c:(n:next x)in"}]";l:o|c|x=",";w:("\""=prev x)&(x=":")&n<>" ";"\n"vs raze x,'(w#'" "),'(l#'"\n"),'(2*l*sums p)#'" "}
readpkgs:{[p] ([]k:key a)!get a:readj[p]`packages}

/ config loading
infer:{
  if[(t:type x)in 0 98 99h;:.z.s each x];
  if[t<>10;:x];
  if[x~enlist"*";:"*"];
  if[x like"'*'";:1_-1_x];
  if[x like"[A-z]";:x];
  if[a~inter[a:-1_x]v:.Q.n," .:-";:get x];
  if[" "in x;:.z.s each" "vs x];
  if[x[0 10]like"[1-2]D";if[not null p:"P"$x;:p]];
  $[":"=x 0;`$x;0=s:sum x="`";x;"`"<>x 0;x;`$1_$[s=1;x;"`"vs x]]}

parseconf:{[p]
  s@:where(s:read0 p)like"[A-z]*";
  s@:where 1=sum each s="=";
  s:trim @[s;where"#"in's;first"#"vs];
  if[count err:select from(a:flip`k`v!("S*";"=")0:s)where 0=count each v;
    show err;fatal"Badly formed ",1_string p];
  (1#.q),a[`k]!infer each a`v}

loadconf:{if[exists p:ext[path x;".conf"];info".qi.loadconf ",spath p;.conf,:parseconf[p],topts]}
loadparams:{if[exists p:ext[path x;".params"];info".qi.loadparams ",spath p;.params,:parseconf[p],topts]}

/ package management
pkgs:1#.q;isproc:0b
.qi.system:{[cmd] info cmd;system cmd}
loadf:{.qi.system"l ",spath x}

loadpkg:{[mode;p;name]
  pkgs[name]:p;
  if[`quit in key opts;-1 ospath p;exit 0];
  if[mode in`schemas`full;loadschemas name];
  if[name in`cli;:info string[name]," installed"];
  if[WIN;if["feed"~packages[name;`kind];importx[`fetch;"deps-win"]]];
  if[mode=`full;
    loadconf(p;`defaults);
    loadparams(p;`defaults);
    loadconf(.conf.QI_HOME;name);
    loadconf local(`.qi;name);
    system"d .";
    loadf(p;dotq name);
    if[exists p2:local(`src;name;` sv name,`q);loadf p2];
    if[name=`log;.qi,:.conf.LOGLEVELS#.log]];
  }

frompkg:{[pkg;f]
  if[null p:pkgs pkg;
    importx[`fetch;pkg];
    p:pkgs pkg];
  loadf(p;dotq f);
  }

fromsrc:{[pkg;f] loadf local(`src;pkg;dotq f);}
fromstacksrc:{[pkg;f] loadf(.conf.STACKS;.proc.self.stackname;`src;pkg;dotq f);}

load1schema:{[p]
  info "load1schema ",tostr f:last` vs p;
  tab:first` vs f;
  a:("SC";",")0:p;
  sv[`;`.schemas.t,tab]set r:flip a[0]!a[1]$\:();
  sv[`;`.schemas.c,tab]set a 0;
  @[`.;tab;:;r]
  }

loadschemas:{[pkg] load1schema each paths[path(pkgs pkg;`schemas);"*.csv"];}
autostart:{if[getconf[`AUTO_START;0b]|`start in key opts;$[0~sf:@[get;`..start;0];'"No start function defined";sf[]]]}
getopt:{$[(::)~o:opts x;"";o]}

checkpackages:{[force]
  if[force|not exists f:local`.qi`index.json;fetch[.conf.URL,".qi/index.json";f]];
  if[not`packages in key`.qi;
    a:readpkgs f;
    if[exists cf:local`.qi`custom.json;
      a:a upsert readpkgs cf];
    packages::update sha:{""}each i from a]
  }

getconf:{[name;default] $[(::)~v:.conf name;default;v]}
loadfromvendor:{[mode;name] $[exists pv:local(`vendor;name);[loadpkg[mode;pv;tosym name];1b];0b]}
requireconfs:{[c] if[count m:((),c)except key .conf;'"Missing required setting(s) in .conf: ",","sv string m]}
clearregistry:{{$[exists p:local(`.qi;x);hdel p;`]}each`index.json`index.lock.json;}

parsecmd:{[cmd;subj]
  checkpackages ex:any m:cmd in`update`refresh`upgrade;
  if[last m;  / upgrade
    if[count lx:last lf:readlock`;
      importx[`fetch]each flip(exec k from lx;`upgrade);
      fetch[.conf.URL,"qi.q";.z.f]]];
  if[cmd=`vendor;ex:1b;
    if[not subj in exec k from .qi.packages;'"Unrecognized package: ",tostr subj];
    importx[`fetch;subj];
    if[not(src:pkgs subj)~dest:local`vendor,subj;info"Vendoring to ",spath dest;os.cp[src;dest]]];
  if[ex;exit 0];
  if[not ishub::cmd=`hub;if[loadfromvendor[`full;cmd];: autostart`;]];
  if[not[ishub]&count select from(pk:0!.qi.packages)where k=cmd;
    :import cmd];
  isproc::ishub|0<count a:select from pk where cmd like/:(string[k],'"*");
  if[not isproc|cmd in`status,ctrl:`up`down`kill;'"Unrecognized command: ",tostr cmd];
  import`proc;
  if[cmd=`status;.proc.showstatus subj;exit 0];
  if[cmd in ctrl;.proc[cmd]subj;if[not[WIN]&cmd=`up;system"sleep 0.3"];exit 0];
  import pkg:first a`k;
  if[not ishub;.proc.init cmd];
  if[not null st:.proc.self.stackname;
    loadconf(sd:.conf.STACKS;st;`stack);
    loadconf(sd;st;pkg);
    loadconf(sd;st;nm:.proc.self.name);
    if[exists p1:path(.conf.STACKS;st;`src;`common.q);loadf p1];
    if[exists p2:path(.conf.STACKS;st;`src;pkg;` sv pkg,`q);loadf p2];
    if[exists p3:path(.conf.STACKS;st;`src;pkg;` sv nm,`q);loadf p3]];
  @[get;` sv `,pkg,`init;::][];
  autostart`;
  }

os.ensuredir:{if[not exists x;system"mkdir ",$[WIN;"";"-p "],ospath x]};
os.mv:$[WIN;{[src;dst]system"powershell -NoProfile -Command \"Move-Item -Path '",ospath[src],"' -Destination '",ospath[dst],"' -Force\""};{[src;dst]system"mv ",spath[src]," ",spath dst}]
os.cp:{[dir1;dir2] 
  os.ensuredir dir2;
  system $[WIN;"copy ";"cp -r "],ospath[(dir1;"*")]," ",ospath(dir2;`);
  };
os.cpfile:{[src;dst] system $[WIN;"copy ";"cp "],ospath[src]," ",ospath dst};

readlock:{$[exists p:local`.qi`index.lock.json;(p;readpkgs p);(p;())]}

importx:{[mode;x]
  if[not null pkgs name:first` vs first sx:(),tosym x;if[name in key`;:(::)]];
  option:last 1_sx;
  if[null name;assert];
  if[name in key`;:(::)];
  if[loadfromvendor[mode;name];:(::)];
  checkpackages 0b;
  packages,:last lockf:readlock`;
  if[not count repo:(m:packages name)`repo;'string[name]," is not a valid package"];
  if[newlock:(upgrade:option=`upgrade)|not count osha:sha:m`sha;
    isTag:m[`ref]like"v[0-9]*";
    obj:jcurl[.conf.API,repo,"/git/refs/",$[isTag;"tags";"heads"],"/",m`ref]`object;
    sha:obj`sha;
    if[isTag;
      if["tag"~obj`type;
        sha:jcurl[.conf.API,repo,"/git/tags/",obj`sha][`object]`sha]];
    if[osha~sha;:()]];  / No action needed if sha is unchanged. TODO - test this with tags
  if[newlock;
    info"Writing new lock file";
    packages[name;`sha]:sha;
    lockf[0]0:formatj .j.j {enlist[`packages]!enlist(exec k from key x)!get x}select from packages where 0<count each sha];
  vfiles:();
  if[not exists dir:qihome(`cache;repo;sha);
    tree_sha:jcurl[.conf.API,repo,"/git/commits/",sha][`tree]`sha;
    treeInfo:`typ xcol`type`path#/:jcurl[.conf.API,repo,"/git/trees/",tree_sha,"?recursive=1"]`tree;
    {[name;repo;sha;file]
      url:.conf.RAW,repo,"/",sha,"/",f:file;
      isexec:0b;  / is executable
      if[name=`cli;
        if[isexec:f like"dist/*";
          if[not $[WIN;f like"*.exe";LIN;f like"*linux*";f like"*",(3#first system"uname -m"),"*"];:()];
          f:first"-"vs 5_f]];
      if[not exists p:qihome(`cache;repo;sha;f);
        fetch[url;p];
        if[isexec&not WIN;@[system;"chmod +x ",sp;{error"Failed to set +x perms on ",x,": ",y}sp:spath p]]];
      }[name;repo;sha]each vfiles:exec path from treeInfo where typ like"blob"];
  if[vend:getconf[`AUTO_VENDOR;0];if[not exists pv:local`vendor,name;info"Vendoring to ",spath pv;os.cp[dir;pv]]];
  loadpkg[mode;$[vend;pv;dir];name]}

tcounts:{`n xdesc([]t;n:(count get@)each t:tables x)}

/ (t)opts -> (typed) command line options as a dict
topts:infer each opts:(1#.q),first each .Q.opt .z.x
import:importx`full
\d .
{if[.qi.exists p:.qi.local`src`common.q;.qi.loadf p]}[]
{if[10=type x;.qi.parsecmd .`$(x;y)]}. .z.x 0 1;