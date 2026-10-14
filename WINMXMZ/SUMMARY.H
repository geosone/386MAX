// SUMMARY.H - Maximize complete summary dialog (Open 386MAX 9, wxWindows)
//
// Copyright (C) 1995 Qualitas, Inc.  GNU General Public License version 3.
// Open 386MAX contributors 2022-2026.

class CSummary : public MxDialog
{
public:
	CSummary(int nKBLowFree);

	void GetPString( LPCSTR lpEntry, LPCSTR lpDefault, char *pszBuff, int nSize );
	int GetPInt( LPCSTR lpEntry, int nDefault );
	int m_nKBLowFree;

	BOOL OnInitDialog(void);
	BOOL OnCommand(int id, int notify);
	void OnOK(void);
};
