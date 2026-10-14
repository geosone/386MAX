//  MAXEDIT.CPP - MAXedit, the editor for the 386MAX profile, CONFIG.SYS
//  and the INI files, on wxWindows 1.68E (Open 386MAX 9): MDI frame,
//  toolbar, menus (from the resource script, US/GR), edit windows
//  (wxTextWindow).  Printing, search, Save As and About are the SDK code of
//  the original in MEUTIL.C.
//  Copyright (c) 1995-6 Qualitas, Inc.  GNU General Public License version 3.
//  Open 386MAX contributors 2022-2026.

#include "wx.h"
#include "wx_tbar.h"
#include <windows.h>
#include <commdlg.h>
#include <stdio.h>
#include <string.h>
#include <io.h>

extern "C" {
#include "maxedit.h"
extern PRINTDLG pd;                     // MEUTIL.C
}
#define SETUP_MSG_DEFVARS 1
#include "messages.h"

static char szIniName[128];             // QMAX.INI in the Windows directory
static char szINISection[] = "MAXedit - General";
static char szFilesSection[] = "MAXedit - Files";
static char szHelpName[128];
static HACCEL hAccelTable;

class MeFrame;
class MeChild;
static MeFrame *pFrame = NULL;

static void MakePath(const char *pszDir, const char *pszName, char *pszTarget)
{
    int n;
    if (pszTarget != pszDir)
        strcpy(pszTarget, pszDir);
    n = strlen(pszTarget);
    if (n && pszTarget[n-1] != '\\' && pszTarget[n-1] != '/')
        strcat(pszTarget, "\\");
    strcat(pszTarget, pszName);
}

static void IniWriteInt(const char *pszKey, int nValue)
{
    char sz[16];
    sprintf(sz, "%d", nValue);
    WritePrivateProfileString(szINISection, pszKey, sz, szIniName);
}

static char *LoadStr(UINT id, char *buf, int n)
{
    LoadString(wxhInstance, id, buf, n);
    return buf;
}

// ------------------------------------------------------------------------
// the menu bar from the menu resource (without its Window menu: the MDI
// frame inserts wxWindowMenu, MAXEDIT.RC's own)

static wxMenu *MenuFromHmenu(HMENU hMenu)
{
    wxMenu *menu = new wxMenu;
    int i, n = GetMenuItemCount(hMenu);
    char sz[80];

    for (i = 0; i < n; i++) {
        UINT id = GetMenuItemID(hMenu, i);
        GetMenuString(hMenu, i, sz, sizeof(sz), MF_BYPOSITION);
        if (id == (UINT)-1)
            menu->Append(-1, sz, MenuFromHmenu(GetSubMenu(hMenu, i)));
        else if (id == 0 && !sz[0])
            menu->AppendSeparator();
        else
            menu->Append(id, sz);
    }
    return menu;
}

static wxMenuBar *MenuBarFromResource(void)
{
    HMENU hMenu = LoadMenu(wxhInstance, IDMAXEDIT);
    wxMenuBar *bar = new wxMenuBar;
    int i, n = GetMenuItemCount(hMenu);
    char sz[80];

    for (i = 0; i < n; i++) {
        HMENU hSub = GetSubMenu(hMenu, i);
        if (GetMenuState(hSub, IDM_WINDOWTILE, MF_BYCOMMAND) != (UINT)-1)
            continue;                   // the Window menu
        GetMenuString(hMenu, i, sz, sizeof(sz), MF_BYPOSITION);
        bar->Append(MenuFromHmenu(hSub), sz);
    }
    DestroyMenu(hMenu);
    return bar;
}

// ------------------------------------------------------------------------

class MeChild: public wxFrame
{
 public:
    wxTextWindow *text;
    Bool fUntitled;
    MeChild(wxFrame *parent, char *title, Bool untitled);
    ~MeChild(void);
    HWND EditHWND(void) { return text->GetHWND(); }
    void OnActivate(Bool active);
    void OnSize(int w, int h);
    Bool OnClose(void);
    Bool QueryClose(void);
    Bool Save(void);
};

class MeToolBar: public wxToolBar
{
 public:
    MeToolBar(wxFrame *frame);
    Bool OnLeftClick(int toolIndex, Bool toggleDown);
};

class MeFrame: public wxFrame
{
 public:
    MeToolBar *toolbar;
    MeChild *active;
    FARPROC lpfnOldProc;
    MeFrame(char *title, int x, int y, int w, int h);
    void AddFile(char *pszName);
    MeChild *AlreadyOpen(char *pszPath);
    void OpenFile(void);
    void OnMenuCommand(int id);
    Bool OnClose(void);
    Bool QueryCloseAll(void);
    void CloseAll(void);
};

class MeApp: public wxApp
{
 public:
    wxFrame *OnInit(void);
    BOOL ProcessMessage(MSG *pMsg);
};

MeApp theApp;

// ------------------------------------------------------------------------

MeChild::MeChild(wxFrame *parent, char *title, Bool untitled)
  : wxFrame(parent, title, -1, -1, -1, -1, wxMDI_CHILD | wxDEFAULT_FRAME)
{
    fUntitled = untitled;
    text = NULL;
    SetIcon(new wxIcon("MECHILD"));
    text = new wxTextWindow(this, 0, 0, -1, -1, wxNATIVE_IMPL);
    OnSize(-1, -1);
}

MeChild::~MeChild(void)
{
    if (pFrame && pFrame->active == this) {
        pFrame->active = NULL;
        hwndActive = hwndActiveEdit = NULL;
    }
}

void MeChild::OnActivate(Bool active)
{
    if (!pFrame) return;
    if (active) {
        pFrame->active = this;
        hwndActive = GetHWND();
        hwndActiveEdit = EditHWND();
        ::SetFocus(hwndActiveEdit);
    } else if (pFrame->active == this) {
        pFrame->active = NULL;
        hwndActive = hwndActiveEdit = NULL;
    }
}

// the edit window fills the child window
void MeChild::OnSize(int WXUNUSED(w), int WXUNUSED(h))
{
    int cw, ch;
    if (!text) return;
    GetClientSize(&cw, &ch);
    text->SetSize(0, 0, cw, ch);
}

Bool MeChild::OnClose(void)
{
    return QueryClose();
}

// changed: save / don't save / cancel (FALSE)
Bool MeChild::QueryClose(void)
{
    if (!text->Modified())
        return TRUE;
    switch (MPError(GetHWND(), MB_YESNOCANCEL | MB_ICONQUESTION, IDS_CLOSESAVE, (LPSTR)GetTitle())) {
    case IDYES: return Save();
    case IDNO:  return TRUE;
    default:    return FALSE;
    }
}

Bool MeChild::Save(void)
{
    char szFile[128];
    if (fUntitled) {
        if (!ChangeFile(GetHWND(), TRUE))
            return FALSE;
        fUntitled = FALSE;
    }
    strcpy(szFile, GetTitle());
    if (!text->SaveFile(szFile)) {
        MPError(GetHWND(), MB_OK | MB_ICONHAND, IDS_CANTWRITE, (LPSTR)szFile);
        return FALSE;
    }
    text->DiscardEdits();
    return TRUE;
}

// ------------------------------------------------------------------------
// toolbar: the original's buttons in groups (file, edit, windows, exit/help)

static struct { char *pszBitmap; int id; int fGap; } aTools[] = {
    { "TBNEW_BMP", IDM_FILENEW, 0 },     { "TBOPEN_BMP", IDM_FILEOPEN, 0 },
    { "TBSAVE_BMP", IDM_FILESAVE, 0 },   { "TBPRINT_BMP", IDM_FILEPRINT, 0 },
    { "TBUNDO_BMP", IDM_EDITUNDO, 1 },   { "TBCUT_BMP", IDM_EDITCUT, 0 },
    { "TBCOPY_BMP", IDM_EDITCOPY, 0 },   { "TBPASTE_BMP", IDM_EDITPASTE, 0 },
    { "TBCASC_BMP", IDM_WINDOWCASCADE, 1 }, { "TBTILE_BMP", IDM_WINDOWTILE, 0 },
    { "TBINI_BMP", IDM_EDITINI, 0 },     { "TBEXIT_BMP", IDM_FILEEXIT, 1 },
    { "TBHELP_BMP", IDM_HELPHELP, 0 },
};

MeToolBar::MeToolBar(wxFrame *frame)
  : wxToolBar(frame, 0, 0, -1, -1, wxTB_3DBUTTONS, wxVERTICAL, 1)    // 1.68: one row
{
    int i;
    SetMargins(4, 3);
    for (i = 0; i < sizeof(aTools) / sizeof(aTools[0]); i++) {
        if (aTools[i].fGap)
            AddSeparator();
        AddTool(aTools[i].id, new wxBitmap(aTools[i].pszBitmap, wxBITMAP_TYPE_BMP_RESOURCE));
    }
    Layout();
    // the MDI frame puts its client area below the toolbar's height
    float w, h;
    GetMaxSize(&w, &h);
    SetSize(0, 0, (int)w, (int)h + 2);
}

Bool MeToolBar::OnLeftClick(int toolIndex, Bool WXUNUSED(toggleDown))
{
    if (pFrame)
        pFrame->OnMenuCommand(toolIndex);
    return TRUE;
}

// ------------------------------------------------------------------------

// WM_INITMENU: enable/grey items like the original (InitializeMenu)
extern "C" LRESULT CALLBACK __export MeFrameProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (msg == WM_INITMENU) {
        HMENU hmenu = (HMENU)wParam;
        UINT status;
        int i;
        if (hwndActiveEdit) {
            long l;
            EnableMenuItem(hmenu, IDM_EDITUNDO,
                SendMessage(hwndActiveEdit, EM_CANUNDO, 0, 0L) ? MF_ENABLED : MF_GRAYED);
            l = SendMessage(hwndActiveEdit, EM_GETSEL, 0, 0L);
            status = (HIWORD(l) == LOWORD(l)) ? MF_GRAYED : MF_ENABLED;
            EnableMenuItem(hmenu, IDM_EDITCUT, status);
            EnableMenuItem(hmenu, IDM_EDITCOPY, status);
            EnableMenuItem(hmenu, IDM_EDITCLEAR, status);
            EnableMenuItem(hmenu, IDM_EDITPASTE,
                IsClipboardFormatAvailable(CF_TEXT) ? MF_ENABLED : MF_GRAYED);
            status = *szSearch ? MF_ENABLED : MF_GRAYED;
            EnableMenuItem(hmenu, IDM_SEARCHNEXT, status);
            EnableMenuItem(hmenu, IDM_SEARCHPREV, status);
            EnableMenuItem(hmenu, IDM_EDITSELECT, MF_ENABLED);
            EnableMenuItem(hmenu, IDM_SEARCHFIND, MF_ENABLED);
            status = MF_ENABLED;
        } else {
            status = MF_GRAYED;
            for (i = IDM_EDITFIRST; i <= IDM_EDITLAST; i++)
                EnableMenuItem(hmenu, i, status);
            for (i = IDM_SEARCHFIRST; i <= IDM_SEARCHLAST; i++)
                EnableMenuItem(hmenu, i, status);
            EnableMenuItem(hmenu, IDM_FILEPRINT, status);
        }
        EnableMenuItem(hmenu, IDM_EDITINI, MF_ENABLED);
        EnableMenuItem(hmenu, IDM_FILESAVE, status);
        EnableMenuItem(hmenu, IDM_FILESAVEAS, status);
        EnableMenuItem(hmenu, IDM_WINDOWTILE, status);
        EnableMenuItem(hmenu, IDM_WINDOWCASCADE, status);
        EnableMenuItem(hmenu, IDM_WINDOWICONS, status);
        EnableMenuItem(hmenu, IDM_WINDOWCLOSEALL, status);
    }
    return CallWindowProc(pFrame->lpfnOldProc, hWnd, msg, wParam, lParam);
}

MeFrame::MeFrame(char *title, int x, int y, int w, int h)
  : wxFrame(NULL, title, x, y, w, h, wxMDI_PARENT | wxDEFAULT_FRAME, "MAXedit")
{
    active = NULL;
    pFrame = this;
    SetIcon(new wxIcon("MEFRAME"));
    SetMenuBar(MenuBarFromResource());
    toolbar = new MeToolBar(this);
    SetToolBar(toolbar);
    hwndFrame = GetHWND();
    pd.lStructSize = sizeof(PRINTDLG);
    pd.hwndOwner = hwndFrame;
    lpfnOldProc = (FARPROC)SetWindowLong(GetHWND(), GWL_WNDPROC,
                      (LONG)MakeProcInstance((FARPROC)MeFrameProc, wxhInstance));
}

MeChild *MeFrame::AlreadyOpen(char *pszPath)
{
    wxNode *node;
    for (node = GetChildren()->First(); node; node = node->Next()) {
        wxWindow *win = (wxWindow *)node->Data();
        if (win->IsKindOf(CLASSINFO(wxFrame)) && win != toolbar &&
            !stricmp(((wxFrame *)win)->GetTitle(), pszPath))
            return (MeChild *)win;
    }
    return NULL;
}

// a new edit window, empty or with the file
void MeFrame::AddFile(char *pszName)
{
    char sz[160];
    MeChild *child;
    OFSTRUCT of;

    if (!pszName) {
        child = new MeChild(this, LoadStr(IDS_UNTITLED, sz, sizeof(sz)), TRUE);
        child->Show(TRUE);
        return;
    }
    of.szPathName[0] = '\0';
    ::OpenFile(pszName, &of, OF_PARSE);
    if (!of.szPathName[0])
        return;
    if ((child = AlreadyOpen((char *)of.szPathName)) != NULL) {
        BringWindowToTop(child->GetHWND());
        return;
    }
    if (_access((char *)of.szPathName, 0) != 0) {
        MPError(hwndFrame, MB_OK | MB_ICONHAND, IDS_CANTOPEN, (LPSTR)of.szPathName);
        return;
    }
    child = new MeChild(this, (char *)of.szPathName, FALSE);
    if (!child->text->LoadFile((char *)of.szPathName)) {
        MPError(hwndFrame, MB_OK | MB_ICONHAND, IDS_CANTREAD, (LPSTR)of.szPathName);
        delete child;
        return;
    }
    child->Show(TRUE);
}

void MeFrame::OpenFile(void)
{
    char szFile[128];
    OPENFILENAME ofn;

    strcpy(szFile, "*.INI");
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(OPENFILENAME);
    ofn.hwndOwner = GetHWND();
    ofn.lpstrFilter = (LPSTR)"INI Files (*.INI)\0*.INI\0Profile Files (*.PRO)\0*.PRO\0All Files (*.*)\0*.*\0";
    ofn.nFilterIndex = 1;
    ofn.lpstrFile = (LPSTR)szFile;
    ofn.nMaxFile = sizeof(szFile);
    ofn.Flags = OFN_HIDEREADONLY | OFN_FILEMUSTEXIST;
    if (GetOpenFileName(&ofn) && *szFile)
        AddFile(szFile);
}

Bool MeFrame::QueryCloseAll(void)
{
    wxNode *node;
    for (node = GetChildren()->First(); node; node = node->Next()) {
        wxWindow *win = (wxWindow *)node->Data();
        if (win->IsKindOf(CLASSINFO(wxFrame)) && !((MeChild *)win)->QueryClose())
            return FALSE;
    }
    return TRUE;
}

void MeFrame::CloseAll(void)
{
    wxNode *node;
    while ((node = GetChildren()->First()) != NULL) {
        wxWindow *win = NULL;
        for (; node; node = node->Next())
            if (((wxWindow *)node->Data())->IsKindOf(CLASSINFO(wxFrame))) {
                win = (wxWindow *)node->Data();
                break;
            }
        if (!win) break;
        delete win;
    }
    active = NULL;
    hwndActive = hwndActiveEdit = NULL;
}

Bool MeFrame::OnClose(void)
{
    RECT rc;
    if (!IsIconic(GetHWND())) {
        GetWindowRect(GetHWND(), &rc);
        IniWriteInt("left", rc.left);
        IniWriteInt("top", rc.top);
        IniWriteInt("width", rc.right - rc.left);
        IniWriteInt("height", rc.bottom - rc.top);
    }
    if (!QueryCloseAll())
        return FALSE;
    WinHelp(GetHWND(), szHelpName, HELP_QUIT, 0L);
    return TRUE;
}

void MeFrame::OnMenuCommand(int id)
{
    DWORD dwFlags;
    switch (id) {
    case IDM_FILENEW:     AddFile(NULL); break;
    case IDM_FILEOPEN:    OpenFile(); break;
    case IDM_FILESAVE:    if (active) active->Save(); break;
    case IDM_FILESAVEAS:
        if (active && ChangeFile(active->GetHWND(), active->fUntitled)) {
            active->fUntitled = FALSE;
            active->Save();
        }
        break;
    case IDM_FILEPRINT:   if (active) PrintFile(active->GetHWND(), active->EditHWND()); break;
    case IDM_FILESETUP:
        dwFlags = pd.Flags;
        pd.Flags |= PD_PRINTSETUP;
        PrintDlg(&pd);
        pd.Flags = dwFlags;
        break;
    case IDM_FILEEXIT:    if (OnClose()) delete this; break;
    case IDM_HELPHELP:    WinHelp(GetHWND(), szHelpName, HELP_KEY, (DWORD)(LPSTR)szHKEY_Over); break;
    case IDM_HELPSEARCH:  WinHelp(GetHWND(), szHelpName, HELP_PARTIALKEY, (DWORD)(LPSTR)""); break;
    case IDM_HELPTS:      WinHelp(GetHWND(), szHelpName, HELP_KEY, (DWORD)(LPSTR)szHKEY_TechS); break;
    case IDM_HELPABOUT: {
        FARPROC lpfn = MakeProcInstance((FARPROC)AboutDlgProc, wxhInstance);
        DialogBox(wxhInstance, IDD_ABOUT, GetHWND(), (DLGPROC)lpfn);
        FreeProcInstance(lpfn);
        break; }
    case IDM_EDITCOPY:    if (hwndActiveEdit) SendMessage(hwndActiveEdit, WM_COPY, 0, 0L); break;
    case IDM_EDITPASTE:   if (hwndActiveEdit) SendMessage(hwndActiveEdit, WM_PASTE, 0, 0L); break;
    case IDM_EDITCUT:     if (hwndActiveEdit) SendMessage(hwndActiveEdit, WM_CUT, 0, 0L); break;
    case IDM_EDITCLEAR:   if (hwndActiveEdit) SendMessage(hwndActiveEdit, EM_REPLACESEL, 0, (LONG)(LPSTR)""); break;
    case IDM_EDITSELECT:  if (hwndActiveEdit) SendMessage(hwndActiveEdit, EM_SETSEL, 0, MAKELONG(0, 0xe000)); break;
    case IDM_EDITUNDO:    if (hwndActiveEdit) SendMessage(hwndActiveEdit, EM_UNDO, 0, 0L); break;
    case IDM_SEARCHFIND:  if (hwndActiveEdit) Find(); break;
    case IDM_SEARCHNEXT:  if (hwndActiveEdit) FindNext(); break;
    case IDM_SEARCHPREV:  if (hwndActiveEdit) FindPrev(); break;
    case IDM_EDITINI:     AddFile(szIniName); break;
    case IDM_WINDOWTILE:                // the MDI frame's own commands
    case IDM_WINDOWCASCADE:             // (from the toolbar)
    case IDM_WINDOWICONS:
        SendMessage(GetHWND(), WM_COMMAND, id, 0L);
        break;
    case IDM_WINDOWCLOSEALL:
        if (QueryCloseAll())
            CloseAll();
        break;
    }
}

// ------------------------------------------------------------------------

BOOL MeApp::ProcessMessage(MSG *pMsg)
{
    if (pFrame && hAccelTable && TranslateAccelerator(pFrame->GetHWND(), hAccelTable, pMsg))
        return TRUE;
    return wxApp::ProcessMessage(pMsg);
}

wxFrame *MeApp::OnInit(void)
{
    char sz[260], szDir[128], szMaxPath[128], szTemp[128];
    int x, y, w, h;
    char *pszKeys, *p;

    hInst = wxhInstance;
    GetWindowsDirectory(szDir, sizeof(szDir));
    MakePath(szDir, "QMAX.INI", szIniName);
    GetPrivateProfileString("CONFIG", "Qualitas MAX Path", "c:\\qmax", szMaxPath, sizeof(szMaxPath), szIniName);
    GetPrivateProfileString("CONFIG", "Qualitas MAX Help", "maxhelp.hlp", szTemp, sizeof(szTemp), szIniName);
    MakePath(szMaxPath, szTemp, szHelpName);
    hAccelTable = LoadAccelerators(wxhInstance, IDMAXEDIT);

    x = GetPrivateProfileInt(szINISection, "left", 20, szIniName);
    y = GetPrivateProfileInt(szINISection, "top", 20, szIniName);
    w = GetPrivateProfileInt(szINISection, "width", 560, szIniName);
    h = GetPrivateProfileInt(szINISection, "height", 400, szIniName);
    MeFrame *frame = new MeFrame(LoadStr(IDS_APPNAME, sz, sizeof(sz)), x, y, w, h);
    frame->Show(TRUE);

    // the files of QMAX.INI [MAXedit - Files] ("name=" lines), else the
    // startup files and the Windows INI files
    pszKeys = new char[2048];
    if (GetPrivateProfileString(szFilesSection, NULL, "", pszKeys, 2048, szIniName) > 0) {
        for (p = pszKeys; *p; p += strlen(p) + 1)
            frame->AddFile(p);
    } else {
        frame->AddFile("c:\\config.sys");
        frame->AddFile("c:\\autoexec.bat");
        GetWindowsDirectory(szDir, sizeof(szDir));
        MakePath(szDir, "system.ini", sz);
        frame->AddFile(sz);
        MakePath(szDir, "win.ini", sz);
        frame->AddFile(sz);
    }
    delete[] pszKeys;
    return frame;
}
