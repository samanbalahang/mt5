//+------------------------------------------------------------------+
//| کلاس مدیریت اندیکاتورها                                         |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include <Trade/Trade.mqh>

class CIndicatorManager
{
private:
   string    m_symbol;
   
   // هندل‌های اندیکاتور
   int       m_atrHandle;
   int       m_rsiHandle;
   int       m_volumeHandle;
   int       m_rsiH1Handle;
   int       m_atrH1Handle;
   int       m_rsiM15Handle;
   int       m_zigzagHandle;
   int       m_macdH4Handle;
   int       m_macdH1Handle;
   
   // تنظیمات
   int       m_rsiPeriod;
   bool      m_useH1;
   bool      m_useM15;
   bool      m_useElliott;
   
public:
   CIndicatorManager();
   ~CIndicatorManager();
   
   // مقداردهی اولیه
   bool Initialize(string symbol, int rsiPeriod, bool useH1, bool useM15, bool useElliott);
   
   // دریافت مقادیر اندیکاتور
   double GetATR(int timeframe, int index, int period = 14);
   double GetRSI(int timeframe, int index);
   double GetMACDMain(int timeframe, int index);
   double GetMACDSignal(int timeframe, int index);
   double GetVolume(int index);
   double GetZigZagValue(int index);
   
   // بررسی واگرایی
   bool CheckRSIDivergence(bool isBullish, int lookback);
   bool CheckMACDDivergence(bool isBullish, int lookback);
   
   // آزادسازی هندل‌ها
   void ReleaseHandles();
};

//+------------------------------------------------------------------+
//| پیاده‌سازی کلاس                                                |
//+------------------------------------------------------------------+
CIndicatorManager::CIndicatorManager()
{
   m_atrHandle = INVALID_HANDLE;
   m_rsiHandle = INVALID_HANDLE;
   m_volumeHandle = INVALID_HANDLE;
   m_rsiH1Handle = INVALID_HANDLE;
   m_atrH1Handle = INVALID_HANDLE;
   m_rsiM15Handle = INVALID_HANDLE;
   m_zigzagHandle = INVALID_HANDLE;
   m_macdH4Handle = INVALID_HANDLE;
   m_macdH1Handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                 |
//+------------------------------------------------------------------+
bool CIndicatorManager::Initialize(string symbol, int rsiPeriod, bool useH1, bool useM15, bool useElliott)
{
   m_symbol = symbol;
   m_rsiPeriod = rsiPeriod;
   m_useH1 = useH1;
   m_useM15 = useM15;
   m_useElliott = useElliott;
   
   // ایجاد هندل‌ها
   m_atrHandle = iATR(symbol, PERIOD_H4, 14);
   m_rsiHandle = iRSI(symbol, PERIOD_H4, rsiPeriod, PRICE_CLOSE);
   m_volumeHandle = iVolumes(symbol, PERIOD_H4, VOLUME_TICK);
   
   if(m_atrHandle == INVALID_HANDLE || m_rsiHandle == INVALID_HANDLE)
      return false;
   
   if(m_useH1)
   {
      m_rsiH1Handle = iRSI(symbol, PERIOD_H1, rsiPeriod, PRICE_CLOSE);
      m_atrH1Handle = iATR(symbol, PERIOD_H1, 14);
      m_macdH1Handle = iMACD(symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
   }
   
   if(m_useM15)
   {
      m_rsiM15Handle = iRSI(symbol, PERIOD_M15, 9, PRICE_CLOSE);
   }
   
   if(m_useElliott)
   {
      m_zigzagHandle = iCustom(symbol, PERIOD_H4, "Examples\\ZigZag.ex5", 12, 5, 3);
      m_macdH4Handle = iMACD(symbol, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);
   }
   
   return true;
}