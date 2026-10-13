/* print.h of the Windows 3.1 SDK (printer driver interface: DEVMODE,
   DeviceCapabilities, ...): OpenWatcom has these in drivinit.h */
#include <drivinit.h>

#ifdef __cplusplus
extern "C" {
#endif
/* print.h functions missing in OpenWatcom's win16.h */
HDC WINAPI ResetDC(HDC, const DEVMODE FAR *);
#ifdef __cplusplus
}
#endif
