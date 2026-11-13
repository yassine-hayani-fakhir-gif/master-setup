#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <setjmp.h>
#include "../Kit/native/DiskGuard.c"
static jmp_buf env;
static D code;
static int mode;
static char writtenPlan[4096],firstPlan[4096];
static int writes;
API W* GetCommandLineW(void){return mode==11?L"guard --plan":(mode==9||mode==10||mode==12)?L"guard --verify":L"guard";}
API int WriteFile(void*h,const void*b,D n,D*out,void*ov){memcpy(writtenPlan,b,n);writtenPlan[n]=0;if(!writes++){memcpy(firstPlan,b,n);firstPlan[n]=0;}*out=n;return 1;}
static void copy(W*d,const W*s){while((*d++=*s++));}
API D GetModuleFileNameW(void*a,W*b,D c){copy(b,L"E:\\AtelierAuto\\test\\DiskGuard.exe");D n=0;while(b[n])n++;return n;}
API D GetPrivateProfileStringW(const W*a,const W*k,const W*d,W*out,D n,const W*p){
 if(k[0]=='F')copy(out,mode==7?L"1":L"2");
 else if(k[0]=='S'&&k[1]=='t')copy(out,mode==7?L"0":L"1");
 else if(k[0]=='S')copy(out,L"42949672960");
 else copy(out,mode==7?L"01020304":L"0102030405060708090A0B0C0D0E0F10");
 D x=0;while(out[x])x++;return x;
}
API int GetFirmwareType(D*p){*p=(mode==1||mode==7)?1:2;return 1;}
API void* CreateFileW(const W*p,D a,D b,void*c,D d,D e,void*f){
 if(d==2)return (void*)201;
 if(p[4]=='E'&&p[5]==':')return (void*)200;
 int i=0;for(int k=17;p[k];k++)i=i*10+p[k]-'0';
 if(i==3||i==4||((mode==2||(mode>=8&&mode<=11))&&i==5))return (void*)(Q)(100+i);
 return (void*)-1;
}
API int CloseHandle(void*h){return 1;}
API int DeviceIoControl(void*h,D op,void*in,D ins,void*out,D cap,D*got,void*ov){
 int i=(int)(Q)h-100;
 if(op==0x2d1080){D*x=out;x[0]=7;x[1]=mode==6?3:4;x[2]=1;*got=12;return 1;}
 if(op==0x2d1400){if(mode==5)return 0;memset(out,0,cap);((D*)out)[7]=i==4?7:17;*got=36;return 1;}
 if(op==0x700f0){((Q*)out)[0]=16;((Q*)out)[1]=((mode==10&&i==5)||mode==12)?1:0;*got=16;return 1;}
 if(op==0x7405c){*(Q*)out=42949672960ULL+(mode==3?512:0);*got=8;return 1;}
 if(op==0x70050){memset(out,0,cap);*(D*)out=mode==7?0:1;for(int j=0;j<16;j++)((unsigned char*)out)[8+j]=j+1;if(mode==4||((mode>=8&&mode<=11)&&i==5))((unsigned char*)out)[8]=0;*got=48;return 1;}
 return 0;
}
API void ExitProcess(D c){code=c;longjmp(env,1);}
int main(void){
 for(mode=0;mode<13;mode++){
  writes=0;memset(planPath,0,sizeof(planPath));memset(path,0,sizeof(path));memset(ini,0,sizeof(ini));memset(val,0,sizeof(val));
  if(!setjmp(env))entry();
  if(mode==11){assert(writes==2);assert(strstr(firstPlan,"offline disk")!=0);assert(strstr(writtenPlan,"online disk")!=0);assert(strstr(writtenPlan,"select disk 5")!=0);assert(strstr(writtenPlan,"select disk 3")==0);assert(strstr(writtenPlan,"select disk 4")==0);}
  assert(code==((mode==0||mode==7||mode==8||mode==10||mode==11)?13:1));
 }
 puts("PASS: 13 scenarios; GPT/MBR identity, duplicates, size, source protection, disk isolation plan and verified offline/online states.");return 0;
}
