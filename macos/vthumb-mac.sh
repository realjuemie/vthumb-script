#!/bin/zsh
set -e
path='.'; count=16; cols=4; width=1920; recurse=0; force=0
while [[ $# -gt 0 ]]; do
 case "$1" in
  -Path) path="$2"; shift 2;; -Count) count="$2"; shift 2;; -Cols) cols="$2"; shift 2;; -Width) width="$2"; shift 2;; -Recurse) recurse=1; shift;; -Force) force=1; shift;; -h|--help) echo 'vthumb-mac.sh [-Path 路径] [-Count 数量] [-Cols 列数] [-Width 宽度] [-Recurse] [-Force]'; exit 0;; *) path="$1"; shift;;
 esac
done
command -v ffmpeg >/dev/null || { echo '未找到 ffmpeg，请先运行 install-mac.sh'; exit 1; }
python3 - "$path" "$count" "$cols" "$width" "$recurse" "$force" <<'PY'
import os,sys,subprocess,tempfile,shutil,math,json
from PIL import Image,ImageDraw,ImageFont
root,count,cols,width,recurse,force=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),int(sys.argv[5]),int(sys.argv[6])
ext={'.mp4','.mov','.mkv','.avi','.webm','.m4v','.ts','.mts','.m2ts','.wmv','.flv','.mpeg','.mpg','.vob','.ogv','.rmvb','.3gp','.3g2','.asf','.divx','.ogm'}
def sample_time(dur,i,count):
 default=dur*i/(count+1)
 if i!=1: return default
 # Move the first thumbnail earlier on long videos, while skipping likely black leaders.
 early=max(dur*0.02,min(3.0,dur*0.1))
 return min(default,early)
files=[]
for d,ds,fs in os.walk(root):
 for f in fs:
  if os.path.splitext(f)[1].lower() in ext: files.append(os.path.join(d,f))
 if not recurse: ds[:]=[]
for video in sorted(files):
 out=video+'.png'
 if os.path.exists(out) and not force: print('Skip existing:',out); continue
 j=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=width,height','-of','json',video],text=True)); v=next(x for x in j['streams'] if 'width' in x); dur=float(j['format']['duration']); aspect=v['width']/v['height']; tmp=tempfile.mkdtemp(prefix='vthumb_'); frames=[]
 try:
  for i in range(1,count+1):
   t=sample_time(dur,i,count); p=os.path.join(tmp,f'{i:03}.jpg'); subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-ss',str(t),'-i',video,'-frames:v','1','-vf','scale=640:-2','-q:v','3','-y',p],check=True); frames.append((p,t))
  margin,gap=10,8; tw=(width-margin*2-gap*(cols-1))//cols; th=round(tw/aspect); rows=math.ceil(len(frames)/cols); header=110; sheet=Image.new('RGB',(width,header+margin+rows*th+(rows-1)*gap+margin),'white'); d=ImageDraw.Draw(sheet); font=ImageFont.load_default()
  name=os.path.basename(video); maxc=max(20,width//9); lines=[name[i:i+maxc] for i in range(0,len(name),maxc)]+[f'Resolution: {v["width"]}x{v["height"]}',f'Duration: {dur:.0f}s']
  for i,line in enumerate(lines): d.text((12,8+i*18),line,fill='black')
  for i,(p,t) in enumerate(frames):
   im=Image.open(p).convert('RGB').resize((tw,th)); x=margin+(i%cols)*(tw+gap); y=header+margin+(i//cols)*(th+gap); sheet.paste(im,(x,y)); stamp=f'{int(t//60):02}:{int(t%60):02}'; box=d.textbbox((0,0),stamp,font=font); sw=box[2]-box[0]; sx=x+(tw-sw)//2; d.rectangle((sx-6,y+th-22,sx+sw+6,y+th-2),fill=(0,0,0)); d.text((sx,y+th-20),stamp,font=font,fill='white')
  sheet.save(out); print('Created:',out)
 finally: shutil.rmtree(tmp,ignore_errors=True)
PY
