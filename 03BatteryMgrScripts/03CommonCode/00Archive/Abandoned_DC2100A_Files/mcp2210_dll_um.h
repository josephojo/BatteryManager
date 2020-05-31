/*****************************************************************************************/
/*                                                                                       */
/* ©2015 Microchip Technology Inc.and its subsidiaries.You may use this software and any */
/* derivatives exclusively with Microchip products.                                      */
/*                                                                                       */
/* THIS SOFTWARE IS SUPPLIED BY MICROCHIP "AS IS".NO WARRANTIES, WHETHER EXPRESS,        */
/* IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY IMPLIED WARRANTIES OF     */
/* NON - INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE, OR ITS     */
/* INTERACTION WITH MICROCHIP PRODUCTS, COMBINATION WITH ANY OTHER PRODUCTS, OR          */
/* USE IN ANY APPLICATION.                                                               */
/*                                                                                       */
/* IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE, INCIDENTAL  */
/* OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND WHATSOEVER RELATED         */
/* TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP HAS BEEN ADVISED OF THE            */
/* POSSIBILITY OR THE DAMAGES ARE FORESEEABLE.TO THE FULLEST EXTENT ALLOWED BY           */
/* LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS IN ANY WAY RELATED TO THIS SOFTWARE    */
/* WILL NOT EXCEED THE AMOUNT OF FEES, IF ANY, THAT YOU HAVE PAID DIRECTLY TO            */
/* MICROCHIP FOR THIS SOFTWARE.                                                          */
/*                                                                                       */
/* MICROCHIP PROVIDES THIS SOFTWARE CONDITIONALLY UPON YOUR ACCEPTANCE OF THESE          */
/* TERMS.                                                                                */
/*                                                                                       */
/*****************************************************************************************/

#ifdef __cplusplus
extern "C"{
#endif

#ifndef _WIN32
#  define __cdecl    /* nothing */
#  define __stdcall  /* nothing */
#  define __fastcall /* nothing */
#endif /* _WIN32 */

// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the MCP2210_DLL_UM_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// MCP2210_DLL_UM_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.

//for projects importing the .lib, use the MCP2210_LIB preprocessor definition
#ifndef MCP2210_LIB
#ifdef MCP2210_DLL_UM_EXPORTS
#define MCP2210_DLL_UM_API __declspec(dllexport)
#else
#define MCP2210_DLL_UM_API __declspec(dllimport)
#endif
#else 
#define MCP2210_DLL_UM_API
#endif

#define MPC2210_LIBRARY_VERSION_SIZE            64              /* version string maximum byte size including null character */
#define MPC2210_SERIAL_NUMBER_LENGTH            10              /* MPC2210 HID serial number length - count of wide characters */

/* chip setting constants */
#define MCP2210_GPIO_NR                         9               /* there are 9 GPIO pins */
// GPIO Pin Designation
#define MCP2210_PIN_DES_GPIO                    0x00            /* pin configured as GPIO */
#define MCP2210_PIN_DES_CS                      0x01            /* pin configured as chip select - CS */
#define MCP2210_PIN_DES_FN                      0x02            /* pin configured as dedicated function pin */
// VM/NVRAM selection - use it as cfgSelector parameter
#define MCP2210_VM_CONFIG                       0               /* designates current chip setting - Volatile Memory */
#define MCP2210_NVRAM_CONFIG                    1               /* designates power-up chip setting - NVRAM          */
// remote wake-up enable/disable
#define MCP2210_REMOTE_WAKEUP_ENABLED           1
#define MCP2210_REMOTE_WAKEUP_DISABLED          0
// interrupt counting mode
#define MCP2210_INT_MD_CNT_HIGH_PULSES          0x4
#define MCP2210_INT_MD_CNT_LOW_PULSES           0x3
#define MCP2210_INT_MD_CNT_RISING_EDGES         0x2
#define MCP2210_INT_MD_CNT_FALLING_EDGES        0x1
#define MCP2210_INT_MD_CNT_NONE                 0x0
// SPI bus release enable/disable
#define MCP2210_SPI_BUS_RELEASE_ENABLED         0
#define MCP2210_SPI_BUS_RELEASE_DISABLED        1
// SPI bus release ACK pin value
#define MCP2210_SPI_BUS_RELEASE_ACK_LOW         0
#define MCP2210_SPI_BUS_RELEASE_ACK_HIGH        1
// SPI maximum transfer attempts threshold
#define MCP2210_XFER_RETRIES                    200
// min and max current amount from USB host
#define MCP2210_MIN_USB_AMPERAGE                2
#define MCP2210_MAX_USB_AMPERAGE                510
// USB string descriptor params
#define MCP2210_DESCRIPTOR_STR_MAX_LEN          29              /* maximum UNICODE size of the string descriptors, without NULL terminator */

// SPI Mode selection
#define MCP2210_SPI_MODE0                       0x00
#define MCP2210_SPI_MODE1                       0x01
#define MCP2210_SPI_MODE2                       0x02
#define MCP2210_SPI_MODE3                       0x03
// GP8 firmware error workaround bit
#define MCP2210_GP8CE_MASK                      0x80000000

// NVRAM chip settings protection access control
#define MCP2210_NVRAM_PASSWD_LEN                   8            /* the password must be a NULL terminated string of 8 characters (bytes) */
#define MCP2210_NVRAM_NO_PROTECTION             0x00
#define MCP2210_NVRAM_PROTECTED                 0x40
#define MCP2210_NVRAM_LOCKED                    0x80
#define MCP2210_NVRAM_PASSWD_CHANGE             0xA5

/* MCP2210 UM DLL API definition */
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetLibraryVersion(wchar_t *version);

/* API for getting access to the USB device */
MCP2210_DLL_UM_API int   __stdcall Mcp2210_GetLastError();
MCP2210_DLL_UM_API int   __stdcall Mcp2210_GetConnectedDevCount(unsigned short vid, unsigned short pid);
MCP2210_DLL_UM_API void* __stdcall Mcp2210_OpenByIndex(unsigned short vid, unsigned short pid, unsigned int index, wchar_t *devPath, unsigned long *devPathsize);
MCP2210_DLL_UM_API void* __stdcall Mcp2210_OpenBySN(unsigned short vid, unsigned short pid, wchar_t *serialNo, wchar_t *devPath, unsigned long *devPathsize);
MCP2210_DLL_UM_API int   __stdcall Mcp2210_Close(void *handle);
MCP2210_DLL_UM_API int   __stdcall Mcp2210_Reset(void *handle);

/* USB settings */
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetUsbKeyParams(void *handle, unsigned short *pvid, unsigned short *ppid,
                                                         unsigned char *ppwrSrc, unsigned char *prmtWkup, unsigned short *pcurrentLd);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetUsbKeyParams(void *handle, unsigned short vid, unsigned short pid,
                                                         unsigned char pwrSrc, unsigned char rmtWkup, unsigned short currentLd);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetManufacturerString(void *handle, wchar_t *manufacturerStr);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetManufacturerString(void *handle, wchar_t *manufacturerStr);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetProductString(void *handle, wchar_t *productStr);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetProductString(void *handle, wchar_t *productStr);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetSerialNumber(void *handle, wchar_t *serialStr);

/* API to access GPIO settings and values */
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetGpioPinDir(void *handle, unsigned int *pgpioDir);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetGpioPinDir(void *handle, unsigned int gpioSetDir);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetGpioPinVal(void *handle, unsigned int *pgpioPinVal);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetGpioPinVal(void *handle, unsigned int gpioSetVal, unsigned int *pgpioPinVal);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetGpioConfig(void *handle, unsigned char cfgSelector, unsigned char *pGpioPinDes, unsigned int *pdfltGpioOutput,
                                                       unsigned int *pdfltGpioDir, unsigned char *prmtWkupEn, unsigned char *pintPinMd, unsigned char *pspiBusRelEn);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetGpioConfig(void *handle, unsigned char cfgSelector, unsigned char *pGpioPinDes, unsigned int dfltGpioOutput,
                                                       unsigned int dfltGpioDir, unsigned char rmtWkupEn, unsigned char intPinMd, unsigned char spiBusRelEn);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetInterruptCount(void *handle, unsigned int *pintCnt, unsigned char reset);

/* API to control SPI transfer */
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetSpiConfig(void *handle, unsigned char cfgSelector, unsigned int *pbaudRate, unsigned int *pidleCsVal,
                                                      unsigned int *pactiveCsVal, unsigned int *pCsToDataDly, unsigned int *pdataToCsDly,
                                                      unsigned int *pdataToDataDly, unsigned int *ptxferSize, unsigned char *pspiMd);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetSpiConfig(void *handle, unsigned char cfgSelector, unsigned int *pbaudRate, unsigned int *pidleCsVal,
                                                      unsigned int *pactiveCsVal, unsigned int *pCsToDataDly, unsigned int *pdataToCsDly,
                                                      unsigned int *pdataToDataDly, unsigned int *ptxferSize, unsigned char *pspiMd);

MCP2210_DLL_UM_API int __stdcall Mcp2210_xferSpiData(void *handle, unsigned char *pdataTx, unsigned char *pdataRx,
                                                     unsigned int *pbaudRate, unsigned int *ptxferSize, unsigned int csmask);

MCP2210_DLL_UM_API int __stdcall Mcp2210_xferSpiDataEx(void *handle, unsigned char *pdataTx, unsigned char *pdataRx,
                                                       unsigned int *pbaudRate, unsigned int *ptxferSize, unsigned int csmask,
                                                       unsigned int *pidleCsVal, unsigned int *pactiveCsVal, unsigned int *pCsToDataDly,
                                                       unsigned int *pdataToCsDly, unsigned int *pdataToDataDly, unsigned char *pspiMd);

MCP2210_DLL_UM_API int __stdcall Mcp2210_CancelSpiTxfer(void *handle, unsigned char *pspiExtReqStat, unsigned char *pspiOwner);
MCP2210_DLL_UM_API int __stdcall Mcp2210_RequestSpiBusRel(void *handle, unsigned char ackPinVal);
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetSpiStatus(void *handle, unsigned char *pspiExtReqStat, unsigned char *pspiOwner, unsigned char *pspiTxferStat);

/* EEPROM read/write API */
MCP2210_DLL_UM_API int __stdcall Mcp2210_ReadEEProm(void *handle, unsigned char address, unsigned char *pcontent);
MCP2210_DLL_UM_API int __stdcall Mcp2210_WriteEEProm(void *handle, unsigned char address, unsigned char content);

/* Access control API */
MCP2210_DLL_UM_API int __stdcall Mcp2210_GetAccessCtrlStatus(void *handle, unsigned char *pAccessCtrl, unsigned char *pPasswdAttemptCnt, unsigned char *pPasswdAccepted);
MCP2210_DLL_UM_API int __stdcall Mcp2210_EnterPassword(void *handle, char *passwd);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetAccessControl(void *handle, unsigned char accessConfig, char *currentPasswd, char *newPasswd);
MCP2210_DLL_UM_API int __stdcall Mcp2210_SetPermanentLock(void *handle);


/**************************** Error Codes ************************/
#define E_SUCCESS                                0
#define E_ERR_UNKOWN_ERROR                      -1
#define E_ERR_INVALID_PARAMETER                 -2
#define E_ERR_BUFFER_TOO_SMALL                  -3

/* memory access errors */
#define E_ERR_NULL                              -10  /* NULL pointer parameter */
#define E_ERR_MALLOC                            -20  /* memory allocation error */
#define E_ERR_INVALID_HANDLE_VALUE              -30  /* invalid file handler use */

/* errors connecting to HID device */
#define E_ERR_FIND_DEV                          -100  
#define E_ERR_NO_SUCH_INDEX                     -101  /* we tried to connect to a device with a non existent index */
#define E_ERR_DEVICE_NOT_FOUND                  -103  /* no device matching the provided criteria was found */
#define E_ERR_INTERNAL_BUFFER_TOO_SMALL         -104  /* internal function buffer is too small */
#define E_ERR_OPEN_DEVICE_ERROR                 -105  /* an error occurred when trying to get the device handle */
#define E_ERR_CONNECTION_ALREADY_OPENED         -106  /* connection already opened */
#define E_ERR_CLOSE_FAILED                      -107
#define E_ERR_NO_SUCH_SERIALNR                  -108  /* no device found with the given serial number */
#define E_ERR_HID_RW_TIMEOUT                    -110  /* HID file operation timeout. Device may be disconnected */
#define E_ERR_HID_RW_FILEIO                     -111  /* HID file operation unknown error. Device may be disconnected */

/* MCP2210 device command reply errors */
#define E_ERR_CMD_FAILED                        -200
#define E_ERR_CMD_ECHO                          -201
#define E_ERR_SUBCMD_ECHO                       -202

#define E_ERR_SPI_CFG_ABORT                     -203  /* SPI configuration change refuzed because transfer is in progress */
#define E_ERR_SPI_EXTERN_MASTER                 -204  /* the SPI bus is owned by external master, data transfer not possible */
#define E_ERR_SPI_TIMEOUT                       -205  /* SPI transfer attempts exceeded the MCP2210_XFER_RETRIES threshold */
#define E_ERR_SPI_RX_INCOMPLETE                 -206  /* the number of bytes received after the SPI transfer 
                                                         is less than configured transfer size */ 
#define E_ERR_SPI_XFER_ONGOING                  -207

/* MCP2210 device password protection */
#define E_ERR_BLOCKED_ACCESS                    -300   /* the command cannot be executed because the device settings are  
                                                          either password protected or permanently locked */
#define E_ERR_EEPROM_WRITE_FAIL                 -301   /* EEPROM write failure due to FLASH memory failure */   

#define E_ERR_NVRAM_LOCKED                      -350   /* NVRAM is permanently locked, no password is accepted */
#define E_ERR_WRONG_PASSWD                      -351   /* password mismatch, but number of attempts is less than 5 */
#define E_ERR_ACCESS_DENIED                     -352   /* password mismatch, but the number of attempts exceeded 5,
                                                          so the NVRAM access is denied until the next device reset */
#define E_ERR_NVRAM_PROTECTED                   -353   /* NVRAM access control protection is already enabled, so
                                                          the attempt to enable it twice is rejected */
#define E_ERR_PASSWD_CHANGE                     -354    /* NVRAM access control is not enabled, so password change is 
                                                          not allowed */

/* MCP2210 USB descriptors */
#define E_ERR_STRING_DESCRIPTOR                 -400   /* the NVRAM string descriptor is invalid */
#define E_ERR_STRING_TOO_LARGE                  -401   /* the size of the input string exceds the limit */

#ifdef __cplusplus
}
#endif 