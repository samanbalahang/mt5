//+------------------------------------------------------------------+
//| کلاس اجرای معاملات                                              |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include <Trade/Trade.mqh>
#include "Structures.mqh"

class CTradeExecutor
{
private:
   CTrade    m_trade;
   ulong     m_magicNumber;
   
   bool      m_positionOpen;
   ulong     m_positionTicket;
   double    m_positionVolume;
   
   // مدیریت چندین TP
   bool      m_useMultipleTPs;
   double    m_tpLevels[4];
   double    m_tpPercentages[4];
   bool      m_tpHit[4];
   double    m_remainingVolume;
   
public:
   CTradeExecutor();
   ~CTradeExecutor();
   
   void Initialize(ulong magic);
   void SetMultipleTPParameters(bool useMulti, double &tpLevels[], double &percentages[]);
   
   // باز کردن معامله
   bool OpenPosition(bool isBuy, double volume, double price, double sl, double tp, string comment);
   
   // مدیریت حد سودهای چندگانه
   void CheckAndClosePartialTPs();
   
   // بستن معامله
   bool ClosePosition();
   bool ClosePartialPosition(double percent);
   
   // به‌روزرسانی حد ضرر
   bool UpdateStopLoss(double newSL);
   
   // وضعیت پوزیشن
   bool IsPositionOpen() { return m_positionOpen; }
   double GetPositionVolume() { return m_positionVolume; }
   
   // مدیریت هیستوری
   int GetTotalTradesToday();
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor()
{
   m_magicNumber = 8888;
   m_positionOpen = false;
   m_positionTicket = 0;
   m_positionVolume = 0.0;
   m_remainingVolume = 0.0;
   
   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   m_trade.SetAsyncMode(false);
}

//+------------------------------------------------------------------+
//| باز کردن پوزیشن جدید                                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::OpenPosition(bool isBuy, double volume, double price, double sl, double tp, string comment)
{
   bool result = false;
   
   if(isBuy)
      result = m_trade.Buy(volume, _Symbol, price, sl, tp, comment);
   else
      result = m_trade.Sell(volume, _Symbol, price, sl, tp, comment);
   
   if(result)
   {
      m_positionOpen = true;
      m_positionTicket = m_trade.ResultOrder();
      m_positionVolume = volume;
      m_remainingVolume = volume;
      
      // ریست آرایه TP
      for(int i = 0; i < 4; i++)
         m_tpHit[i] = false;
   }
   
   return result;
}