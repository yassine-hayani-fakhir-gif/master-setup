/* Local launcher with startup diagnostics. Hidden-console compatibility launch. No downloads or policy bypass. */
typedef unsigned short W;
typedef unsigned int D;
typedef unsigned long long Q;
#define API __attribute__((ms_abi))
extern API D GetModuleFileNameW(void*,W*,D);
extern API D GetSystemDirectoryW(W*,D);
extern API D GetTempPathW(D,W*);
extern API D GetCurrentProcessId(void);
extern API D GetLastError(void);
extern API D GetFileAttributesW(const W*);
extern API void* CreateFileW(const W*,D,D,void*,D,D,void*);
extern API int MessageBoxW(void*,const W*,const W*,D);
extern API int CreateProcessW(const W*,W*,void*,void*,int,D,void*,const W*,void*,void*);
extern API D WaitForSingleObject(void*,D);
extern API int GetExitCodeProcess(void*,D*);
extern API int CloseHandle(void*);
extern API void ExitProcess(D);
typedef struct {
 D cb;W *reserved,*desktop,*title;D x,y,xsize,ysize,xcount,ycount,fill,flags;
 unsigned short show,reserved2;void *reservedBytes,*input,*output,*error;
} STARTUP;
typedef struct {void *process,*thread;D processId,threadId;} PROCESS;
typedef struct {D length;void* descriptor;int inherit;} SECURITY;
static W exe[32768],dir[32768],args[32768],script[32768],logpath[32768],message[32768];
static void append(W*d,const W*s){while(*d)d++;while((*d++=*s++));}
static void number(W*d,D n){W t[16];D i=0;do{t[i++]=(W)(48+n%10);n/=10;}while(n);while(*d)d++;while(i)*d++=t[--i];*d=0;}
API void entry(void){
 D n=GetModuleFileNameW(0,dir,15000),k=GetSystemDirectoryW(exe,15000),code=1;
 void* log=0;void* input=0;
 if(!n||n>=15000||!k||k>=15000){code=GetLastError();goto fail;}
 while(n&&dir[n-1]!=92)n--;if(!n)goto fail;dir[n]=0;
 append(script,dir);append(script,L"App.ps1");
 if(GetFileAttributesW(script)==0xffffffff){append(message,L"App.ps1 is missing. Extract the COMPLETE ZIP, then open MasterSetup.exe inside the extracted folder.\r\n");code=2;goto fail;}
 k=GetTempPathW(15000,logpath);
 if(!k||k>=15000){code=GetLastError();goto fail;}
 append(logpath,L"MasterSetup-startup-");number(logpath,GetCurrentProcessId());append(logpath,L".log");
 static SECURITY security={sizeof(SECURITY),0,1};
 log=CreateFileW(logpath,0x40000000,3,&security,2,0x80,0);
 if(log==(void*)-1){log=0;code=GetLastError();goto fail;}
 input=CreateFileW(L"NUL",0x80000000,3,&security,3,0x80,0);
 if(input==(void*)-1){input=0;code=GetLastError();goto fail;}
 append(exe,L"\\WindowsPowerShell\\v1.0\\powershell.exe");
 append(args,L"\"");append(args,exe);
 append(args,L"\" -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \"");
 append(args,script);append(args,L"\"");
 static STARTUP si;static PROCESS pi;si.cb=sizeof(si);si.flags=0x101;si.show=0;
 si.input=input;si.output=log;si.error=log;
 if(!CreateProcessW(exe,args,0,0,1,0x00000010,0,dir,&si,&pi)){code=GetLastError();goto fail;}
 CloseHandle(pi.thread);
 D wait=WaitForSingleObject(pi.process,0xffffffff);
 if(wait!=0||!GetExitCodeProcess(pi.process,&code)){code=GetLastError();}
 CloseHandle(pi.process);CloseHandle(input);input=0;CloseHandle(log);log=0;
 if(!code)ExitProcess(0);
 fail:
 if(input)CloseHandle(input);if(log)CloseHandle(log);
 append(message,L"Master Setup could not start. Error code: ");number(message,code);
 if(logpath[0]){append(message,L"\r\n\r\nStartup journal:\r\n");append(message,logpath);}
 append(message,L"\r\n\r\nSend the error or this journal for diagnosis. You can also run Start-MasterSetup.cmd. No security settings were changed.");
 MessageBoxW(0,message,L"Master Setup - Startup diagnostic",0x10);ExitProcess(1);
}
