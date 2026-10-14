/****************************************************************************
    MAXMETER.CPP

    MAXmeter, the Windows resource monitor, on wxWindows 1.68E (Open 386MAX
    9).  Same displays, settings (QMAX.INI [MAXmeter]) and GoAhead link as
    the Win16 SDK version (MAXMETER.C, Rex Conn 1995 for Qualitas Inc.):
    date, time, free memory (Windows 3.x), free GDI and User resources,
    free low DOS memory (with GoAhead).  The window has no caption: the
    left mouse button moves it, the right one opens the menu that was the
    system menu.

    Copyright (C) 1995 Qualitas, Inc.  GNU General Public License version 3.
    Open 386MAX contributors 2022-2026.
****************************************************************************/

#include "wx.h"
#include "wx_timer.h"
#include <windows.h>
#include <commdlg.h>
#include <dos.h>
#include <stdio.h>
#include <string.h>

#define SETUP_MSG_DEFVARS 1
#include "messages.h"
#include "resource.h"
#include "cversion.h"
#include <mversion.h>

// texts of the dialogs and the menu (the Win16 version had them in the
// resource script)
#ifdef LANG_GR
static char szCfgTitle[]  = "MAXmeter Einstellungen";
static char szCfgShow[]   = " Anzeige ";
static char *aszItem[]    = { "&Datum", "Uhr&zeit", "&Speicher", "&GDI Ressourcen",
                              "&User Ressourcen", "&LoDOS Speicher" };
static char szCfgTime[]   = " Zeit&format ";
static char *aszTimeFmt[] = { "12 Stunden (am/pm)", "24 Stunden" };
static char szCfgTop[]    = "&Immer im Vordergrund";
static char szOK[]        = "OK";
static char szCancel[]    = "&Abbrechen";
static char szAboutTitle[]= "Info über MAXmeter";
static char szClose[]     = "&Schließen";
#else
static char szCfgTitle[]  = "Configure MAXmeter";
static char szCfgShow[]   = " Display ";
static char *aszItem[]    = { "&Date", "&Time", "&Memory", "&GDI Resources",
                              "&User Resources", "&Low DOS Memory" };
static char szCfgTime[]   = " Time &Format ";
static char *aszTimeFmt[] = { "12-hour (am/pm)", "24-hour" };
static char szCfgTop[]    = "&Always on top";
static char szOK[]        = "OK";
static char szCancel[]    = "&Cancel";
static char szAboutTitle[]= "About MAXmeter";
static char szClose[]     = "&Close";
#endif

// GoAhead (GOAHEAD.DRV, Windows 3.x): messages of the installable driver
#define LCLDRV_REGISTER                 0x0801
#define LCLDRV_UNREGISTER               0x0802
#define LCLDRV_QUERYCLOSE               0x0803
#define LCLDRV_QUERYENABLE              0x0804
#define LCLDRV_QUERYLOWSEG              0x0806
#define IDC_MEMCHANGED                  1019
#define IDC_TASKCHANGED                 1020
static char szDrvName[] = "goahead.drv";

static char szINISection[] = "MAXmeter";
static char szTitle[] = "MAXmeter";

// display items, in this order
enum { IT_DATE, IT_TIME, IT_FREE, IT_GDI, IT_USER, IT_DOS, IT_COUNT };
static char *aszKey[IT_COUNT] = { "date", "time", "memory", "gdi", "user", "dosmem" };
static char *aszTemplate[IT_COUNT] = { "12-30-99", "22:22:22p", "222222 Kb",
                                       "GDI: 55%", "User: 55%", "DOS: 55%" };

struct MeterItem {
    int  nKind;
    int  x, w;              // position and width in the bar
    char szText[24];
    long lPercent;          // GDI/User/DOS: bar length, else -1
};

class MeterCanvas;
class MeterFrame;

// ------------------------------------------------------------------------
// settings in QMAX.INI (Windows directory) [MAXmeter]

static char szIniName[128];
static char szHelpName[128];

static int IniInt(const char *pszKey, int nDefault)
{
    return GetPrivateProfileInt(szINISection, pszKey, nDefault, szIniName);
}

static void IniWriteInt(const char *pszKey, int nValue)
{
    char sz[16];
    sprintf(sz, "%d", nValue);
    WritePrivateProfileString(szINISection, pszKey, sz, szIniName);
}

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

// ------------------------------------------------------------------------
// the values

static int fWin95 = 0;              // Windows 4.x: no free memory, no GoAhead
static HDRVR hDriver = NULL;        // GoAhead
static int fGoAhead = 0;
static DWORD dwTotalDOS = 0;        // free low DOS (bytes, from GoAhead)
static int fAmPm = 1;
static char cDateSep = '-', cTimeSep = ':';
static int nDateFmt = 0;            // [intl] iDate: 0 m-d-y, 1 d-m-y, 2 y-m-d

static void QueryCountryInfo(void)
{
    char sz[4];
    nDateFmt = GetProfileInt("intl", "iDate", 0);
    GetProfileString("intl", "sDate", "-", sz, sizeof(sz)); cDateSep = sz[0];
    GetProfileString("intl", "sTime", ":", sz, sizeof(sz)); cTimeSep = sz[0];
}

static void ItemValue(MeterItem *pItem)
{
    struct dostime_t t;
    struct dosdate_t d;
    int a, b, c, h;

    pItem->lPercent = -1;
    switch (pItem->nKind) {
    case IT_DATE:
        _dos_getdate(&d);
        a = d.month; b = d.day; c = d.year % 100;
        if (nDateFmt == 1) { a = d.day; b = d.month; }
        else if (nDateFmt == 2) { a = d.year % 100; b = d.month; c = d.day; }
        sprintf(pItem->szText, "%2u%c%02u%c%02u", a, cDateSep, b, cDateSep, c);
        break;
    case IT_TIME:
        _dos_gettime(&t);
        h = t.hour;
        if (fAmPm) {
            char cAP = (h < 12) ? 'A' : 'P';
            if (h == 0) h = 12; else if (h > 12) h -= 12;
            sprintf(pItem->szText, "%2d%c%02d%c%02d%c", h, cTimeSep, t.minute, cTimeSep, t.second & 0xFE, cAP);
        } else
            sprintf(pItem->szText, "%02d%c%02d%c%02d", h, cTimeSep, t.minute, cTimeSep, t.second & 0xFE);
        break;
    case IT_FREE:
        sprintf(pItem->szText, "%6lu Kb", GetFreeSpace(0) >> 10);
        break;
    case IT_GDI:
        pItem->lPercent = GetFreeSystemResources(GFSR_GDIRESOURCES);
        sprintf(pItem->szText, "GDI: %2.2ld%%", pItem->lPercent);
        break;
    case IT_USER:
        pItem->lPercent = GetFreeSystemResources(GFSR_USERRESOURCES);
        sprintf(pItem->szText, "User: %2.2ld%%", pItem->lPercent);
        break;
    case IT_DOS: {
        long lPct = 0;
        if (hDriver) {
            // lowest free segment ever seen: size of the DOS area
            DWORD dwSizeDOS = (640L*1024L) - 16L * SendDriverMessage(hDriver, LCLDRV_QUERYLOWSEG, 0, 0);
            if (dwSizeDOS)
                lPct = (long)((dwTotalDOS * 100L) / dwSizeDOS);
        }
        pItem->lPercent = lPct;
        sprintf(pItem->szText, "DOS: %2.2ld%%", lPct);
        break; }
    }
}

// ------------------------------------------------------------------------

class MeterTimer: public wxTimer
{
 public:
    MeterFrame *frame;
    void Notify(void);
};

class MeterCanvas: public wxCanvas
{
 public:
    MeterFrame *frame;
    int xDrag, yDrag;               // mouse position in the window at the press
    Bool fDragging;
    MeterCanvas(MeterFrame *pFrame, int w, int h);
    void OnPaint(void);
    void OnEvent(wxMouseEvent& event);
};

class MeterFrame: public wxFrame
{
 public:
    MeterCanvas *canvas;
    MeterTimer timer;
    wxMenu *menu;
    wxFont *font;
    MeterItem aItem[IT_COUNT];
    int nItems;
    int dxBar, dyBar;
    FARPROC lpfnOldProc;

    MeterFrame(void);
    ~MeterFrame(void);
    void Layout(void);
    void Draw(wxDC *dc, Bool fAll);
    void Tick(void);
    void SavePosition(void);
    void MakeFont(void);
    Bool OnClose(void);
    void OnMenuCommand(int id);
    void Configure(void);
    void ChooseFont(void);
    void About(void);
};

class MeterApp: public wxApp
{
 public:
    wxFrame *OnInit(void);
};

MeterApp theApp;
static MeterFrame *pMeter = NULL;

// GoAhead posts WM_USER with the free low DOS memory in lParam
extern "C" LRESULT CALLBACK __export MeterSubclassProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (msg == WM_USER && pMeter) {
        if (lParam > 1000L)
            dwTotalDOS = lParam;
        pMeter->Tick();
        return 0;
    }
    return CallWindowProc(pMeter->lpfnOldProc, hWnd, msg, wParam, lParam);
}

void MeterTimer::Notify(void)
{
    frame->Tick();
}

// ------------------------------------------------------------------------

MeterCanvas::MeterCanvas(MeterFrame *pFrame, int w, int h)
  : wxCanvas(pFrame, 0, 0, w, h, 0)
{
    frame = pFrame;
    fDragging = FALSE;
}

void MeterCanvas::OnPaint(void)
{
    frame->Draw(GetDC(), TRUE);
}

void MeterCanvas::OnEvent(wxMouseEvent& event)
{
    float x, y;
    event.Position(&x, &y);

    if (event.RightDown()) {
        PopupMenu(frame->menu, x, y);
    } else if (event.LeftDown()) {
        xDrag = (int)x; yDrag = (int)y;
        fDragging = TRUE;
        CaptureMouse();
    } else if (event.Dragging() && fDragging) {
        POINT pt;
        GetCursorPos(&pt);
        frame->Move(pt.x - xDrag, pt.y - yDrag);
    } else if (event.LeftUp() && fDragging) {
        fDragging = FALSE;
        ReleaseMouse();
        frame->SavePosition();
    }
}

// ------------------------------------------------------------------------

static void MenuProc(wxMenu& WXUNUSED(menu), wxCommandEvent& event)
{
    if (pMeter)
        pMeter->OnMenuCommand(event.commandInt);
}

MeterFrame::MeterFrame(void)
  : wxFrame(NULL, szTitle, 0, 0, 100, 20,
            (IniInt("topmost", 1) ? wxSTAY_ON_TOP : 0), "MAXmeter")
{
    canvas = NULL;
    font = NULL;
    lpfnOldProc = NULL;
    timer.frame = this;

    menu = new wxMenu(NULL, (wxFunction)MenuProc);
    menu->Append(IDM_CONFIGURE, szM_Config);
    menu->AppendSeparator();
    menu->Append(IDM_FONT, szM_Font);
    menu->AppendSeparator();
    menu->Append(IDM_HELP, szM_Over);
    menu->Append(IDM_HELPSEARCH, szM_Search);
    menu->AppendSeparator();
    menu->Append(IDM_HELPTS, szM_TechS);
    menu->AppendSeparator();
    menu->Append(IDM_ABOUT, szM_About);
    menu->AppendSeparator();
    menu->Append(IDM_CLOSE, szClose);

    SetIcon(new wxIcon("MAXICON"));
    MakeFont();
    canvas = new MeterCanvas(this, 100, 20);
    Layout();
    timer.Start(2000);
}

MeterFrame::~MeterFrame(void)
{
    timer.Stop();
    if (hDriver) {
        SendDriverMessage(hDriver, LCLDRV_UNREGISTER, (LPARAM)(WORD)GetHWND(), 0);
        CloseDriver(hDriver, 0, 0);
        hDriver = NULL;
    }
    WinHelp(GetHWND(), szHelpName, HELP_QUIT, 0L);
    pMeter = NULL;
}

void MeterFrame::MakeFont(void)
{
    char szFace[LF_FACESIZE];
    int nSize, nWeight, nItalic;

    GetPrivateProfileString(szINISection, "Font", "System", szFace, sizeof(szFace), szIniName);
    nSize = IniInt("FontSize", 10);
    nWeight = IniInt("FontWeight", FW_BOLD);
    nItalic = IniInt("FontItalic", 0);
    font = wxTheFontList->FindOrCreateFont(nSize, wxSWISS, nItalic ? wxITALIC : wxNORMAL,
                                           nWeight >= FW_BOLD ? wxBOLD : wxNORMAL, FALSE, szFace);
}

// widths of the items, size and position of the bar
void MeterFrame::Layout(void)
{
    wxDC *dc = canvas->GetDC();
    float w, h, hText = 0;
    int i, x = 4;

    fAmPm = IniInt("AmPm", 1);
    QueryCountryInfo();
    dc->SetFont(font);
    nItems = 0;
    for (i = 0; i < IT_COUNT; i++) {
        if (!IniInt(aszKey[i], 1)) continue;
        if (i == IT_FREE && fWin95) continue;
        if (i == IT_DOS && !fGoAhead) continue;
        dc->GetTextExtent(aszTemplate[i], &w, &h);
        if (h > hText) hText = h;
        aItem[nItems].nKind = i;
        aItem[nItems].x = x;
        aItem[nItems].w = (int)w + 8;
        aItem[nItems].szText[0] = '\0';
        ItemValue(&aItem[nItems]);
        x += aItem[nItems].w + 6;
        nItems++;
    }
    dxBar = x - 2;
    dyBar = (int)hText + 8;
    if (dyBar < GetSystemMetrics(SM_CYCAPTION))
        dyBar = GetSystemMetrics(SM_CYCAPTION);

    int left = IniInt("left", GetSystemMetrics(SM_CXSCREEN) - dxBar);
    int top = IniInt("top", 0);
    SetClientSize(dxBar, dyBar);
    canvas->SetSize(0, 0, dxBar, dyBar);
    Move(left, top);
    canvas->Refresh();
}

static wxColour SysColour(int nIndex)
{
    COLORREF c = GetSysColor(nIndex);
    return wxColour(GetRValue(c), GetGValue(c), GetBValue(c));
}

// draw the bar: every item in a sunken frame, resources with a bar in
// green (> 50% free), yellow (> 30%) or red
void MeterFrame::Draw(wxDC *dc, Bool fAll)
{
    wxColour cFace = SysColour(COLOR_BTNFACE);
    wxColour cShadow = SysColour(COLOR_BTNSHADOW);
    wxColour cHilite = SysColour(COLOR_BTNHIGHLIGHT);
    wxColour cText = SysColour(COLOR_BTNTEXT);
    wxBrush *bFace = wxTheBrushList->FindOrCreateBrush(&cFace, wxSOLID);
    wxPen *pFace = wxThePenList->FindOrCreatePen(&cFace, 1, wxSOLID);
    wxPen *pShadow = wxThePenList->FindOrCreatePen(&cShadow, 1, wxSOLID);
    wxPen *pHilite = wxThePenList->FindOrCreatePen(&cHilite, 1, wxSOLID);
    int i;

    dc->BeginDrawing();
    dc->SetFont(font);
    if (fAll) {
        dc->SetPen(pFace);
        dc->SetBrush(bFace);
        dc->DrawRectangle(0, 0, dxBar, dyBar);
    }
    for (i = 0; i < nItems; i++) {
        MeterItem *p = &aItem[i];
        int x = p->x, y = 2, w = p->w, h = dyBar - 4;
        float tw, th;

        if (fAll) {
            dc->SetPen(pShadow);
            dc->DrawLine(x - 1, y - 1, x + w, y - 1);
            dc->DrawLine(x - 1, y - 1, x - 1, y + h);
            dc->SetPen(pHilite);
            dc->DrawLine(x - 1, y + h, x + w + 1, y + h);
            dc->DrawLine(x + w, y - 1, x + w, y + h);
        }
        dc->SetPen(pFace);
        dc->SetBrush(bFace);
        dc->DrawRectangle(x, y, w, h);
        if (p->lPercent >= 0) {
            wxColour cBar(p->lPercent > 50 ? 0 : 255, p->lPercent > 30 ? 255 : 0, 0);
            wxBrush *bBar = wxTheBrushList->FindOrCreateBrush(&cBar, wxSOLID);
            int n = (int)((long)w * p->lPercent / 100);
            if (n > 0) {
                dc->SetPen(wxThePenList->FindOrCreatePen(&cBar, 1, wxSOLID));
                dc->SetBrush(bBar);
                dc->DrawRectangle(x, y, n, h);
            }
        }
        dc->SetTextForeground(&cText);
        dc->SetBackgroundMode(wxTRANSPARENT);
        dc->GetTextExtent(p->szText, &tw, &th);
        dc->DrawText(p->szText, x + (w - tw) / 2, y + (h - th) / 2);
    }
    dc->EndDrawing();
}

// every 2 seconds (and on GoAhead's message): redraw what changed
void MeterFrame::Tick(void)
{
    int i, fChanged = 0;
    for (i = 0; i < nItems; i++) {
        MeterItem old = aItem[i];
        ItemValue(&aItem[i]);
        if (strcmp(old.szText, aItem[i].szText) || old.lPercent != aItem[i].lPercent)
            fChanged = 1;
    }
    if (fChanged)
        Draw(canvas->GetDC(), FALSE);
}

void MeterFrame::SavePosition(void)
{
    int x, y;
    GetPosition(&x, &y);
    IniWriteInt("left", x);
    IniWriteInt("top", y);
}

Bool MeterFrame::OnClose(void)
{
    SavePosition();
    return TRUE;
}

void MeterFrame::OnMenuCommand(int id)
{
    switch (id) {
    case IDM_CONFIGURE: Configure(); break;
    case IDM_FONT:      ChooseFont(); break;
    case IDM_HELP:      WinHelp(GetHWND(), szHelpName, HELP_KEY, (DWORD)(LPSTR)szHKEY_MOver); break;
    case IDM_HELPSEARCH:WinHelp(GetHWND(), szHelpName, HELP_PARTIALKEY, (DWORD)(LPSTR)""); break;
    case IDM_HELPTS:    WinHelp(GetHWND(), szHelpName, HELP_KEY, (DWORD)(LPSTR)szHKEY_TechS); break;
    case IDM_ABOUT:     About(); break;
    case IDM_CLOSE:     if (OnClose()) delete this; break;
    }
}

// ------------------------------------------------------------------------
// dialogs

static int nDlgResult;

static void DlgButtonProc(wxButton& button, wxCommandEvent& WXUNUSED(event))
{
    nDlgResult = (int)(long)button.GetClientData();
    ((wxDialogBox *)button.GetParent())->Show(FALSE);
}

void MeterFrame::Configure(void)
{
    wxDialogBox *dlg = new wxDialogBox(this, szCfgTitle, TRUE, -1, -1, 330, 230);
    wxCheckBox *aCheck[IT_COUNT];
    Bool aEnabled[IT_COUNT];
    wxGroupBox *gb;
    int i, n;

    gb = new wxGroupBox(dlg, szCfgShow, 10, 8, 140, 150);
    for (i = 0; i < IT_COUNT; i++) {
        aCheck[i] = new wxCheckBox(dlg, (wxFunction)NULL, aszItem[i], 20, 28 + 20 * i, 125, 18);
        aCheck[i]->SetValue(IniInt(aszKey[i], 1) != 0);
        aEnabled[i] = !((i == IT_FREE && fWin95) || (i == IT_DOS && !fGoAhead));
        if (!aEnabled[i]) aCheck[i]->Enable(FALSE);
    }
    wxRadioBox *rb = new wxRadioBox(dlg, (wxFunction)NULL, szCfgTime, 165, 8, 145, 70,
                                    2, aszTimeFmt, 2, wxVERTICAL);
    rb->SetSelection(IniInt("AmPm", 1) ? 0 : 1);
    wxCheckBox *cbTop = new wxCheckBox(dlg, (wxFunction)NULL, szCfgTop, 170, 90, 145, 18);
    cbTop->SetValue(IniInt("topmost", 1) != 0);
    wxButton *bOK = new wxButton(dlg, (wxFunction)DlgButtonProc, szOK, 70, 168, 80, 26);
    bOK->SetClientData((char *)1L);
    bOK->SetDefault();
    wxButton *bCancel = new wxButton(dlg, (wxFunction)DlgButtonProc, szCancel, 170, 168, 80, 26);
    bCancel->SetClientData((char *)0L);
    dlg->Centre(wxBOTH);

    for (;;) {
        nDlgResult = 0;
        dlg->Show(TRUE);
        if (!nDlgResult) break;
        for (i = n = 0; i < IT_COUNT; i++)
            if (aCheck[i]->GetValue() && aEnabled[i]) n++;
        if (n) break;
        wxMessageBox(szMsg_Select, szMsg_App, wxOK | wxICON_EXCLAMATION, dlg);
    }
    if (nDlgResult) {
        for (i = 0; i < IT_COUNT; i++)
            if (aEnabled[i])
                IniWriteInt(aszKey[i], aCheck[i]->GetValue() ? 1 : 0);
        IniWriteInt("AmPm", rb->GetSelection() == 0);
        IniWriteInt("topmost", cbTop->GetValue() ? 1 : 0);
        SetWindowPos(GetHWND(), cbTop->GetValue() ? HWND_TOPMOST : HWND_NOTOPMOST,
                     0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        SavePosition();
        Layout();
    }
    delete dlg;
}

void MeterFrame::ChooseFont(void)
{
    wxFontData data;
    data.SetInitialFont(font);
    data.EnableEffects(FALSE);
    wxFontDialog *dlg = new wxFontDialog(this, &data);
    if (dlg->Show(TRUE)) {
        wxFont *f = dlg->GetFontData().GetChosenFont();
        if (f) {
            WritePrivateProfileString(szINISection, "Font", f->GetFaceName(), szIniName);
            IniWriteInt("FontSize", f->GetPointSize());
            IniWriteInt("FontWeight", f->GetWeight() == wxBOLD ? FW_BOLD : FW_NORMAL);
            IniWriteInt("FontItalic", f->GetStyle() == wxITALIC);
            SavePosition();
            MakeFont();
            Layout();
        }
    }
    delete dlg;
}

void MeterFrame::About(void)
{
    char sz[256];
    sprintf(sz, "MAXmeter\nVersion %s\n\n%s", VER_PRODUCTVERSION_STR, VER_LEGALCOPYRIGHT2_STR);
    wxMessageBox(sz, szAboutTitle, wxOK | wxCENTRE, this);
}

// ------------------------------------------------------------------------

wxFrame *MeterApp::OnInit(void)
{
    char szDir[128], szMaxPath[128], szTemp[128];
    DWORD dwVersion = GetVersion();
    HWND hWnd;

    if ((dwVersion & 0xFF) >= 4 || ((dwVersion >> 8) & 0xFF) >= 50)
        fWin95 = 1;

    // only one MAXmeter: bring the running one to the front
    if ((hWnd = FindWindow(NULL, szTitle)) != NULL) {
        SetWindowPos(hWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_SHOWWINDOW);
        return NULL;
    }

    GetWindowsDirectory(szDir, sizeof(szDir));
    MakePath(szDir, "QMAX.INI", szIniName);
    GetPrivateProfileString("CONFIG", "Qualitas MAX Path", "c:\\qmax", szMaxPath, sizeof(szMaxPath), szIniName);
    GetPrivateProfileString("CONFIG", "Qualitas MAX Help", "maxhelp.hlp", szTemp, sizeof(szTemp), szIniName);
    MakePath(szMaxPath, szTemp, szHelpName);

    pMeter = new MeterFrame;

    // GoAhead: installed (loaded from SYSTEM.INI [boot] drivers=) if its
    // close count is not 0 after one open/close of our own
    if (!fWin95) {
        if ((hDriver = OpenDriver(szDrvName, NULL, 0)) != NULL)
            CloseDriver(hDriver, 0, 0);
        if ((hDriver = OpenDriver(szDrvName, NULL, 0)) != NULL) {
            if (SendDriverMessage(hDriver, LCLDRV_QUERYCLOSE, 0, 0)) {
                SendDriverMessage(hDriver, LCLDRV_REGISTER, (LPARAM)(WORD)pMeter->GetHWND(),
                                  MAKELONG(IDC_MEMCHANGED, IDC_TASKCHANGED));
                fGoAhead = SendDriverMessage(hDriver, LCLDRV_QUERYENABLE, 0, 0) == 0;
            } else {
                CloseDriver(hDriver, 0, 0);
                hDriver = NULL;
            }
        }
        pMeter->lpfnOldProc = (FARPROC)SetWindowLong(pMeter->GetHWND(), GWL_WNDPROC,
                                (LONG)MakeProcInstance((FARPROC)MeterSubclassProc, wxhInstance));
    }
    pMeter->Layout();
    pMeter->Show(TRUE);
    return pMeter;
}
