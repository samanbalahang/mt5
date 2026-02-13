//+------------------------------------------------------------------+
//| کلاس مدیریت ریسک                                                |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include <Trade/Trade.mqh>

class CRiskManager
{
private:
   double    m_riskPercent;
   double    m_minLot;
   double    m_maxLot;
   int       m_stopLossPips;
   int       m_takeProfitPips;
   bool      m_useATR;
   double    m_atrSLMultiplier;
   double    m_atrTPMultiplier;
   double    m_breakevenPercent;
   
public:
   CRiskManager();
   ~CRiskManager();
   
   void SetParameters(double risk, double minLot, double maxLot, int slPips, int tpPips,
                      bool useATR, double atrSL, double atrTP, double bePercent);
   
   // محاسبه حجم معامله
   double CalculateLotSize(double stopLossPips);
   
   // محاسبه حد ضرر
   double CalculateStopLoss(double entryPrice, bool isBuy, double atrValue, double candleLow, double candleHigh);
   
   // محاسبه حد سود
   double CalculateTakeProfit(double entryPrice, bool isBuy, double atrValue);
   
   // بررسی فعالسازی بریک ایون
   bool ShouldMoveToBreakeven(double currentPrice, double entryPrice, bool isBuy);
   
   // محاسبه تریل بر اساس درصد
   double CalculateTrailStop(double currentPrice, double entryPrice, double trailPercent, bool isBuy);
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_riskPercent = 1.0;
   m_minLot = 0.01;
   m_maxLot = 1.0;
   m_stopLossPips = 40;
   m_takeProfitPips = 80;
   m_useATR = true;
   m_atrSLMultiplier = 1.5;
   m_atrTPMultiplier = 3.0;
   m_breakevenPercent = 50.0;
}

//+------------------------------------------------------------------+
//| محاسبه حجم معامله بر اساس ریسک                                 |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double stopLossPips)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (m_riskPercent / 100.0);
   
   double lotSize = riskAmount / (stopLossPips * tickValue * 10);
   lotSize = MathRound(lotSize / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(m_minLot, MathMin(m_maxLot, lotSize));
   
   return lotSize;
}