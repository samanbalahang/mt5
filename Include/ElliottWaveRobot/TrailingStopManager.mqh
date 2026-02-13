//+------------------------------------------------------------------+
//| کلاس مدیریت تریلینگ استاپ                                       |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include "Structures.mqh"
#include "ElliottWaveAnalyzer.mqh"
#include "FibonacciManager.mqh"

class CTrailingStopManager
{
private:
   bool      m_useWaveTrailing;
   bool      m_useH1FiboTrailing;
   double    m_wave1TrailPercent;
   double    m_wave3TrailPercent;
   double    m_wave5TrailPercent;
   double    m_breakevenPercent;
   
   CElliottWaveAnalyzer *m_waveAnalyzer;
   CFibonacciManager    *m_fiboManager;
   
public:
   CTrailingStopManager();
   ~CTrailingStopManager();
   
   void SetParameters(bool useWave, bool useFibo, double wave1, double wave3, double wave5, double bePercent);
   void Initialize(CElliottWaveAnalyzer *waveAnalyzer, CFibonacciManager *fiboManager);
   
   // محاسبه تریل استاپ بر اساس موج الیوت
   double CalculateWaveBasedTrail(double currentPrice, double entryPrice, double highestPrice, 
                                  double lowestPrice, EWAVE_PHASE currentWave);
   
   // محاسبه تریل فیبوناچی در H1
   double CalculateH1FiboTrail();
   
   // بررسی نیاز به بریک ایون
   bool CheckBreakeven(double currentPrice, double entryPrice, bool isBuy);
   
   // دریافت بهترین تریل
   double GetOptimalTrail(double currentPrice, double entryPrice, double highestPrice, 
                          double lowestPrice, EWAVE_PHASE currentWave, bool isBuy);
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CTrailingStopManager::CTrailingStopManager()
{
   m_useWaveTrailing = true;
   m_useH1FiboTrailing = true;
   m_wave1TrailPercent = 30;
   m_wave3TrailPercent = 50;
   m_wave5TrailPercent = 70;
   m_breakevenPercent = 50;
}