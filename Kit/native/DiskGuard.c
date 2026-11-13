/* Disk identity guard. Writes only isolation-plan files on source USB; no write IOCTLs. Developed by Yassine. */
typedef unsigned short W;
typedef unsigned int D;
typedef unsigned long long Q;
#define API __attribute__((ms_abi))
extern API D GetModuleFileNameW(void*,W*,D);
extern API D GetPrivateProfileStringW(const W*,const W*,const W*,W*,D,const W*);
extern API void* CreateFileW(const W*,D,D,void*,D,D,void*);
extern API int DeviceIoControl(void*,D,void*,D,void*,D,D*,void*);
extern API int CloseHandle(void*);
extern API int GetFirmwareType(D*);
extern API void ExitProcess(D);
extern API W* GetCommandLineW(void);
extern API int WriteFile(void*,const void*,D,D*,void*);
static char plan[4096];
static D planLen;
static W planPath[32768];
static W path[32768], ini[32768], val[128];
static unsigned char layout[65536] __attribute__((aligned(8)));
static unsigned char descriptor[4096] __attribute__((aligned(8)));
static void append(W*d,const W*s){while(*d)d++;while((*d++=*s++));}
static int hex(W c){if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;if(c>='A'&&c<='F')return c-'A'+10;return -1;}
static Q number(const W*s){Q x=0;while(*s){if(*s<'0'||*s>'9')return 0;x=x*10+*s++-'0';}return x;}
static D get(const W*k){return GetPrivateProfileStringW(L"Target",k,L"",val,128,ini);}
static int matches(const unsigned char*l,D len,D style,const unsigned char*id,D n,Q actual,Q expected){
 if(len<8+n || *(const D*)l!=style || actual!=expected || !expected)return 0;
 for(D j=0;j<n;j++)if(l[8+j]!=id[j])return 0;
 return 1;
}
static void text(const char*s){while(*s&&planLen<4095)plan[planLen++]=*s++;}
static int has(const W*s,const W*part){for(;*s;s++){D i=0;while(part[i]&&s[i]==part[i])i++;if(!part[i])return 1;}return 0;}
static void offline(D i){text("select disk ");if(i>=10)plan[planLen++]='0'+i/10;plan[planLen++]='0'+i%10;text("\r\noffline disk\r\n");}
API void entry(void){
 int makePlan=has(GetCommandLineW(),L" --plan"),verify=has(GetCommandLineW(),L" --verify");
 D len=GetModuleFileNameW(0,path,32000),got=0,fw=0;
 if(!len||len>=32000||path[1]!=':')ExitProcess(1);
 /* The source volume must be on a different physical disk. */
 W vol[]=L"\\\\.\\X:";vol[4]=path[0];
 void*h=CreateFileW(vol,0,3,0,3,0,0);D dev[3]={0};
 if(h==(void*)-1)ExitProcess(1);
 int ok=DeviceIoControl(h,0x2d1080,0,0,dev,sizeof(dev),&got,0);CloseHandle(h);
 if(!ok||got<12)ExitProcess(1);
 while(len&&path[len-1]!=92)len--;path[len]=0;append(ini,path);append(ini,L"target.ini");
 if(!get(L"Firmware")||!GetFirmwareType(&fw)||fw!=number(val))ExitProcess(1);
 if(!get(L"Style"))ExitProcess(1);D style=(D)number(val);if(style>1)ExitProcess(1);
 if(!get(L"Size"))ExitProcess(1);Q size=number(val);
 D n=style==1?16:4;unsigned char id[16]={0};D nonzero=0;
 if(get(L"Identity")!=n*2)ExitProcess(1);
 for(D j=0;j<n;j++){int a=hex(val[j*2]),b=hex(val[j*2+1]);if(a<0||b<0)ExitProcess(1);id[j]=a*16+b;nonzero|=id[j];}
 if(!nonzero)ExitProcess(1);
 D found=0,index=0,internal=0;D others[32],otherCount=0;int allOffline=1;int readableAttrs=1;
 for(D i=0;i<32;i++){
  W disk[64]=L"\\\\.\\PhysicalDrive";W num[4]={0};if(i>=10){num[0]='0'+i/10;num[1]='0'+i%10;}else num[0]='0'+i;append(disk,num);
  h=CreateFileW(disk,0x80000000,3,0,3,0,0);if(h==(void*)-1)continue;
  D query[3]={0};Q length=0;
  ok=DeviceIoControl(h,0x2d1400,query,sizeof(query),descriptor,sizeof(descriptor),&got,0);
  if(!ok||got<32){CloseHandle(h);ExitProcess(1);}
  D bus=*(D*)(descriptor+28);
  if(i==dev[1]||bus==7){CloseHandle(h);continue;}
  internal++;
  ok=DeviceIoControl(h,0x7405c,0,0,&length,8,&got,0);
  int isTarget=ok&&got==8&&DeviceIoControl(h,0x70050,0,0,layout,sizeof(layout),&got,0)&&matches(layout,got,style,id,n,length,size);
  if(isTarget){found++;index=i;if(verify){Q attrs[2]={0};if(!DeviceIoControl(h,0x700f0,0,0,attrs,sizeof(attrs),&got,0)||got<16||(attrs[1]&1))allOffline=0;}}
  else {
   Q attrs[2]={0};int attrOK=DeviceIoControl(h,0x700f0,0,0,attrs,sizeof(attrs),&got,0)&&got>=16;
   if(!attrOK)readableAttrs=0;
   if(!attrOK||!(attrs[1]&1))others[otherCount++]=i;
   if(verify&&(!attrOK||!(attrs[1]&1)))allOffline=0;
  }
  CloseHandle(h);
 }
 /* Identity must be unique. Other disks must be offline for the final check. */
 if(found!=1||(verify&&!allOffline))ExitProcess(1);
 if(makePlan){
  if(!readableAttrs)ExitProcess(1);
  planLen=0;
  for(D j=0;j<otherCount;j++)offline(others[j]);
  text("exit\r\n");
  append(planPath,path);append(planPath,L"isolate.txt");
  h=CreateFileW(planPath,0x40000000,0,0,2,0,0);
  if(h==(void*)-1)ExitProcess(1);
  D written=0;ok=WriteFile(h,plan,planLen,&written,0);CloseHandle(h);
  if(!ok||written!=planLen)ExitProcess(1);
  planLen=0;
  for(D j=0;j<otherCount;j++){
   text("select disk ");D i=others[j];if(i>=10)plan[planLen++]='0'+i/10;plan[planLen++]='0'+i%10;text("\r\nonline disk\r\n");
  }
  text("exit\r\n");
  planPath[0]=0;append(planPath,path);append(planPath,L"restore.txt");
  h=CreateFileW(planPath,0x40000000,0,0,2,0,0);if(h==(void*)-1)ExitProcess(1);
  written=0;ok=WriteFile(h,plan,planLen,&written,0);CloseHandle(h);
  if(!ok||written!=planLen)ExitProcess(1);
 }
 ExitProcess(10+index);
}
