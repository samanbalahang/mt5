//+------------------------------------------------------------------+
//| کلاس مدیریت ورود در تایم‌فریم M15                               |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include "Structures.mqh"
#include "IndicatorManager.mqh"

class CM15EntryManager
{
private:
   bool      m_enabled;
   int       m_maxWaitHours;
   double    m_entryZoneWidth;
   int       m_rsiPeriod;
   double    m_rsiEntryLevel;
   bool      m_waitForPullback;
   int       m_maxPullbackBars;
   double    m_pullbackDepth;
   bool      m_useCandleBasedSL;
   int       m_slWickOffset;
   double    m_slBufferPercent;
   int       m_initialSLPips;
   
   M15_EntryPoint m_entryPoint;
   CIndicatorManager *m_indicators;
   
   datetime  m_signalTime;
   double    m_h4BreakPrice;
   bool      m_isBuy;
   
public:
   CM15EntryManager();
   ~CM15EntryManager();
   
   void SetParameters(bool enabled, int maxHours, double zoneWidth, int rsiPeriod, double rsiEntry,
                      bool waitPullback, int maxPullBars, double pullbackDepth,
                      bool candleSL, int wickOffset, double bufferPercent, int initSL);
   
   void Initialize(CIndicatorManager *indicators);
   
   // تنظیم سیگنال اولیه
   void SetSignal(bool isBuy, double breakPrice, datetime signalTime);
   
   // جستجوی نقطه ورود در M15
   bool FindEntryPoint();
   
   // دریافت نقطه ورود
   M15_EntryPoint GetEntryPoint() { return m_entryPoint; }
   
   // محاسبه حد ضرر بر اساس کندل
   double CalculateCandleBasedSL(double entryPrice, bool isBuy, double candleLow, double candleHigh);
   
   // بررسی انقضای سیگنال
   bool IsSignalExpired();
   
   // ریست
   void Reset();
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CM15EntryManager::CM15EntryManager()
{
   m_enabled = true;
   m_maxWaitHours = 12;
   m_entryZoneWidth = 5.0;
   m_rsiPeriod = 9;
   m_rsiEntryLevel = 40.0;
   m_waitForPullback = true;
   m_maxPullbackBars = 10;
   m_pullbackDepth = 0.382;
   m_useCandleBasedSL = true;
   m_slWickOffset = 2;
   m_slBufferPercent = 10;
   m_initialSLPips = 40;
   
   m_entryPoint.isConfirmed = false;
}