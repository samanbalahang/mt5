//+------------------------------------------------------------------+
//| کلاس مدیریت فیبوناچی و حد سود                                   |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include "Structures.mqh"

class CFibonacciManager
{
private:
   bool      m_useMultipleTPs;
   double    m_fiboLevels[4];
   double    m_tpPercentages[4];
   double    m_pullbackDepth;
   
public:
   CFibonacciManager();
   ~CFibonacciManager();
   
   void SetParameters(bool useMultiTP, double tp1, double tp2, double tp3, double tp4,
                      double perc1, double perc2, double perc3, double perc4,
                      double pullback);
   
   // محاسبه سطوح TP بر اساس موج
   void CalculateTPLevels(double waveStart, double waveEnd, bool isBuy, double &tpLevels[]);
   
   // محاسبه سطوح فیبوناچی اصلاحی
   void CalculateRetracementLevels(double high, double low, double &levels[]);
   
   // بررسی پولبک به سطح فیبوناچی
   bool CheckPullbackToLevel(double currentPrice, double level, double entryZoneWidth);
   
   // تریل فیبوناچی
   double CalculateFiboTrail(double highestPrice, double lowestPrice, double trailPercent);
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CFibonacciManager::CFibonacciManager()
{
   m_useMultipleTPs = true;
   m_fiboLevels[0] = 0.236;
   m_fiboLevels[1] = 0.382;
   m_fiboLevels[2] = 0.618;
   m_fiboLevels[3] = 1.0;
   
   m_tpPercentages[0] = 30;
   m_tpPercentages[1] = 30;
   m_tpPercentages[2] = 25;
   m_tpPercentages[3] = 15;
   
   m_pullbackDepth = 0.382;
}

//+------------------------------------------------------------------+
//| محاسبه سطوح حد سود                                              |
//+------------------------------------------------------------------+
void CFibonacciManager::CalculateTPLevels(double waveStart, double waveEnd, bool isBuy, double &tpLevels[])
{
   double waveLength = MathAbs(waveEnd - waveStart);
   
   for(int i = 0; i < 4; i++)
   {
      if(isBuy)
         tpLevels[i] = waveEnd + (waveLength * m_fiboLevels[i]);
      else
         tpLevels[i] = waveEnd - (waveLength * m_fiboLevels[i]);
   }
}