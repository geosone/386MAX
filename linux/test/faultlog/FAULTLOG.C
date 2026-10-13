/* FAULTLOG.EXE - minimal "Dr. Watson" for the Windows 3.1 tests of
 * linux/test/win311.sh (FAULTLOG=1: WIN FAULTLOG.EXE PROGRAM ARGS): starts
 * the program and logs every fault (exception, CS:IP, module and segment
 * number) to C:\FAULT.LOG; Windows then handles it as usual. */
#include <windows.h>
#include <toolhelp.h>

extern void FAR PASCAL FaultHandler(void);

static int nFaults;

static void LogLine(LPSTR line, int n)
{
    HFILE hf = _lopen("C:\\FAULT.LOG", OF_WRITE);
    if (hf == HFILE_ERROR)
        hf = _lcreat("C:\\FAULT.LOG", 0);
    if (hf != HFILE_ERROR) {
        _llseek(hf, 0, 2);
        _lwrite(hf, line, n);
        _lclose(hf);
    }
}

/* called by FaultHandler (FLTHND.ASM) in the faulting task: only record */
static volatile UINT fNum[16], fIP[16], fCS[16];
static volatile int nRec;

void FAR PASCAL FaultLog(UINT num, UINT ip, UINT cs)
{
    if (nRec < 16) {
        fNum[nRec] = num; fIP[nRec] = ip; fCS[nRec] = cs;
        nRec++;
    }
}

/* timer: write what was recorded, with module and segment number */
static void Flush(void)
{
    GLOBALENTRY ge;
    MODULEENTRY me;
    char line[160];
    static BOOL bTick;

    if (!bTick) {
        bTick = TRUE;
        LogLine(line, wsprintf(line, "faultlog: timer running\r\n"));
    }
    while (nFaults < nRec) {
        UINT cs = fCS[nFaults];
        lstrcpy(me.szModule, "?");
        ge.dwSize = sizeof(ge);
        me.dwSize = sizeof(me);
        ge.wData = 0;
        if (GlobalEntryHandle(&ge, (HGLOBAL)cs) && ge.hOwner)
            ModuleFindHandle(&me, (HMODULE)ge.hOwner);
        LogLine(line, wsprintf(line, "fault %u at %04X:%04X module %s segment %u\r\n",
                fNum[nFaults], cs, fIP[nFaults], (LPSTR)me.szModule, ge.wData));
        nFaults++;
    }
}

int PASCAL WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmd, int nShow)
{
    MSG msg;
    FARPROC fp;
    char line[160];
    BOOL ok;

    if (hPrev)
        return 0;
    fp = MakeProcInstance((FARPROC)FaultHandler, hInst);
    ok = InterruptRegister(NULL, fp);
    LogLine(line, wsprintf(line, "faultlog: InterruptRegister %d, starting %s\r\n", ok, lpCmd));
    if (!ok)
        return 1;
    if (*lpCmd)
        WinExec(lpCmd, SW_SHOWNORMAL);
    SetTimer(NULL, 1, 250, NULL);
    while (GetMessage(&msg, NULL, 0, 0)) {
        if (msg.message == WM_TIMER)
            Flush();
        DispatchMessage(&msg);
    }
    InterruptUnRegister(NULL);
    return 0;
}
