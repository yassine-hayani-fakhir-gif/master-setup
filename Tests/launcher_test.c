#include <assert.h>
#include <setjmp.h>
#include <stdio.h>
#include <string.h>
#include "../src/Launcher.c"
static jmp_buf jump;
static D result;static int mode,messages,created;
static void copy(W*d,const W*s){while((*d++=*s++));}
static int contains(const W*s,const W*t){for(;*s;s++){int i=0;while(t[i]&&t[i]==s[i])i++;if(!t[i])return 1;}return 0;}
API D GetModuleFileNameW(void*a,W*b,D c){copy(b,L"C:\\Path with spaces\\MasterSetup.exe");D n=0;while(b[n])n++;return n;}
API D GetSystemDirectoryW(W*b,D n){copy(b,L"C:\\Windows\\System32");return 19;}
API D GetTempPathW(D n,W*b){copy(b,L"C:\\Temp\\");return 8;}
API D GetCurrentProcessId(void){return 123;}
API D GetLastError(void){return 5;}
API D GetFileAttributesW(const W*p){return mode==3?0xffffffff:0x80;}
API void* CreateFileW(const W*p,D access,D share,void*sec,D disposition,D attr,void*unused){
 assert(((SECURITY*)sec)->inherit==1);assert(sizeof(SECURITY)==24);
 if(mode==4)return (void*)-1;
 return access==0x40000000?(void*)10:(void*)11;
}
API int MessageBoxW(void*a,const W*b,const W*c,D d){messages++;assert(contains(b,L"Error code:"));if(mode==3)assert(contains(b,L"App.ps1 is missing"));return 1;}
API int CreateProcessW(const W*exe,W*args,void*a,void*b,int inherit,D flags,void*c,const W*dir,void*si,void*pi){
 created++;assert(flags==0x10);STARTUP*s=si;assert(sizeof(STARTUP)==104);assert(s->cb==104);
 assert(contains(args,L"-ExecutionPolicy RemoteSigned"));
 assert(contains(args,L"\"C:\\Path with spaces\\App.ps1\""));
 assert(!contains(args,L"Bypass"));assert(inherit);assert(s->flags==0x101);
 assert(s->show==0);assert(contains(args,L"-WindowStyle Hidden"));
 assert(s->input==(void*)11&&s->output==(void*)10&&s->error==(void*)10);
 assert(contains(logpath,L"MasterSetup-startup-123.log"));
 ((PROCESS*)pi)->process=(void*)12;((PROCESS*)pi)->thread=(void*)13;
 return mode!=1;
}
API D WaitForSingleObject(void*a,D b){return mode==5?0xffffffff:0;}
API int GetExitCodeProcess(void*a,D*b){*b=mode==2?1:0;return 1;}
API int CloseHandle(void*a){return 1;}
API void ExitProcess(D n){result=n;longjmp(jump,1);}
int main(void){for(mode=0;mode<6;mode++){
 memset(exe,0,sizeof(exe));memset(args,0,sizeof(args));memset(dir,0,sizeof(dir));
 memset(script,0,sizeof(script));memset(logpath,0,sizeof(logpath));memset(message,0,sizeof(message));
 messages=0;created=0;if(!setjmp(jump))entry();
 assert(result==(mode?1:0));assert(messages==(mode?1:0));
 assert(created==((mode==3||mode==4)?0:1));
}puts("PASS: startup success, process failure, script error, missing App.ps1, log failure, wait failure; redirected diagnostics and quoted paths.");}
